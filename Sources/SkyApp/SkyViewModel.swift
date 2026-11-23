import Foundation
import ServiceManagement
import SkyCore
import SwiftUI

@MainActor
final class SkyViewModel: ObservableObject {
    @Published var settings: SkySettings
    @Published private(set) var snapshot: SkySnapshot
    @Published private(set) var timelineSamples: [TimelineSample]
    @Published var previewHour: Double? = nil
    @Published var isScrubbing: Bool = false
    @Published var isDemoPlaying: Bool = false
    @Published var locationNotice: String? = nil
    @Published var launchAtLogin: Bool = false

    private let desktopManager: DesktopWindowManager
    private let windEngine = AmbientWindEngine()
    private let locationManager = LocationManager()
    private var clockTimer: Timer?
    private var demoTimer: Timer?
    private var lastTimelineDayKey: String = ""

    var onPhaseChanged: ((DayPhase) -> Void)?

    var isPreviewing: Bool {
        previewHour != nil
    }

    var displayedHour: Double {
        previewHour ?? snapshot.solar.localHour
    }

    var displayedTimeString: String {
        SolarAstronomy.formatHour(displayedHour)
    }

    var sunriseString: String {
        snapshot.daylight.sunriseHour.map(SolarAstronomy.formatHour) ?? "--:--"
    }

    var sunsetString: String {
        snapshot.daylight.sunsetHour.map(SolarAstronomy.formatHour) ?? "--:--"
    }

    var daylightDurationString: String {
        let totalMin = Int((snapshot.daylight.daylightHours * 60.0).rounded())
        return "\(totalMin / 60)小时\(totalMin % 60)分"
    }

    var resolutionSummary: String {
        desktopManager.primaryResolutionSummary
    }

    init() {
        let loaded = SkySettings.load()
        let now = Date()
        let initialSnap = SolarAstronomy.snapshot(date: now, location: loaded.location)
        let samples = SolarAstronomy.timelineSamples(for: now, location: loaded.location)

        self.settings = loaded
        self.snapshot = initialSnap
        self.timelineSamples = samples
        self.desktopManager = DesktopWindowManager(initialSnapshot: initialSnap)
        self.lastTimelineDayKey = Self.dayKey(for: now, location: loaded.location)
        self.launchAtLogin = Self.readLaunchAtLoginStatus()

        setupLocationCallbacks()
        syncAllOutputs()
        startClockTimer()
    }

    private func setupLocationCallbacks() {
        locationManager.onLocationUpdated = { [weak self] loc in
            guard let self = self else { return }
            self.settings.location = loc
            self.settings.useAutoLocation = true
            self.settings.save()
            self.refreshNow(forceTimeline: true)
        }
        locationManager.onStatusMessage = { [weak self] msg in
            self?.locationNotice = msg
        }
    }

    private func startClockTimer() {
        clockTimer?.invalidate()
        clockTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.previewHour == nil else { return }
                self.refreshNow(forceTimeline: false)
            }
        }
    }

    func refreshNow(forceTimeline: Bool = false) {
        let targetDate = effectiveDate()
        let prevPhase = snapshot.phase
        let newSnap = SolarAstronomy.snapshot(date: targetDate, location: settings.location)
        self.snapshot = newSnap

        let key = Self.dayKey(for: targetDate, location: settings.location)
        if forceTimeline || key != lastTimelineDayKey {
            lastTimelineDayKey = key
            self.timelineSamples = SolarAstronomy.timelineSamples(for: targetDate, location: settings.location)
        }

        if prevPhase != newSnap.phase {
            onPhaseChanged?(newSnap.phase)
        }
        syncAllOutputs()
    }

    private func effectiveDate() -> Date {
        let now = Date()
        guard let hour = previewHour else { return now }
        let start = SolarAstronomy.startOfLocalDay(for: now, timeZone: settings.location.timeZone)
        return start.addingTimeInterval(hour * 3600.0)
    }

    private func syncAllOutputs() {
        desktopManager.update(
            snapshot: snapshot,
            style: settings.style,
            showStars: settings.showStars,
            showMoon: settings.showMoon,
            starIntensity: settings.starIntensity,
            isActive: settings.isWallpaperActive,
            isAnimatingFast: isScrubbing || isDemoPlaying
        )
        windEngine.update(
            enabled: settings.ambientWindEnabled && settings.isWallpaperActive,
            volume: settings.ambientWindVolume,
            sunElevationDegrees: snapshot.solar.elevationDegrees
        )
    }

    // MARK: - User Actions

    func scrubTo(hour: Double, activeDrag: Bool) {
        stopDemoTour()
        let clamped = max(0.0, min(23.98, hour))
        self.previewHour = clamped
        self.isScrubbing = activeDrag
        refreshNow(forceTimeline: false)
    }

    func finishScrubbing() {
        self.isScrubbing = false
        syncAllOutputs()
    }

    func returnToNow() {
        stopDemoTour()
        self.previewHour = nil
        self.isScrubbing = false
        refreshNow(forceTimeline: false)
    }

    func jumpToPresetHour(_ hour: Double) {
        stopDemoTour()
        self.previewHour = max(0.0, min(23.98, hour))
        self.isScrubbing = false
        refreshNow(forceTimeline: false)
    }

    func toggleDemoTour() {
        if isDemoPlaying {
            stopDemoTour()
        } else {
            startDemoTour()
        }
    }

    private func startDemoTour() {
        isDemoPlaying = true
        if previewHour == nil {
            previewHour = (snapshot.daylight.sunriseHour ?? 6.5) - 0.8
        }
        demoTimer?.invalidate()
        // Smooth 30Hz sweep covering 24h in ~18 seconds
        demoTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isDemoPlaying else { return }
                let next = ((self.previewHour ?? 6.0) + (24.0 / (18.0 * 30.0))).truncatingRemainder(dividingBy: 24.0)
                self.previewHour = next
                self.refreshNow(forceTimeline: false)
            }
        }
        syncAllOutputs()
    }

    func stopDemoTour() {
        guard isDemoPlaying else { return }
        isDemoPlaying = false
        demoTimer?.invalidate()
        demoTimer = nil
        syncAllOutputs()
    }

    func selectCity(_ city: SkyLocation) {
        settings.location = city
        settings.useAutoLocation = false
        settings.save()
        locationNotice = nil
        refreshNow(forceTimeline: true)
    }

    func requestAutoLocation() {
        locationManager.requestCurrentLocation()
    }

    func setStyle(_ style: SkyStyle) {
        settings.style = style
        settings.save()
        syncAllOutputs()
    }

    func setShowStars(_ enabled: Bool) {
        settings.showStars = enabled
        settings.save()
        syncAllOutputs()
    }

    func setShowMoon(_ enabled: Bool) {
        settings.showMoon = enabled
        settings.save()
        syncAllOutputs()
    }

    func setStarIntensity(_ value: Double) {
        settings.starIntensity = max(0.3, min(1.5, value))
        settings.save()
        syncAllOutputs()
    }

    func setAmbientWindEnabled(_ enabled: Bool) {
        settings.ambientWindEnabled = enabled
        settings.save()
        syncAllOutputs()
    }

    func setAmbientWindVolume(_ value: Double) {
        settings.ambientWindVolume = max(0.0, min(1.0, value))
        settings.save()
        syncAllOutputs()
    }

    func setWallpaperActive(_ active: Bool) {
        settings.isWallpaperActive = active
        settings.save()
        syncAllOutputs()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = Self.readLaunchAtLoginStatus()
        } catch {
            locationNotice = "开机自启需从 /Applications/Sky.app 运行后启用"
            launchAtLogin = Self.readLaunchAtLoginStatus()
        }
    }

    func shutdown() {
        stopDemoTour()
        clockTimer?.invalidate()
        windEngine.stop()
    }

    private static func readLaunchAtLoginStatus() -> Bool {
        SMAppService.mainApp.status == .enabled
    }

    private static func dayKey(for date: Date, location: SkyLocation) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = location.timeZone
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        return "\(comps.year ?? 0)-\(comps.month ?? 0)-\(comps.day ?? 0)-\(location.name)"
    }
}
