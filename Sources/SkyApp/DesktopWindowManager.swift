import AppKit
import MetalKit
import SkyCore

@MainActor
final class DesktopWindowManager {
    private struct ScreenSurface {
        let screen: NSScreen
        let window: NSWindow
        let mtkView: MTKView
        let renderer: SkyRenderer
        let pixelWidth: Int
        let pixelHeight: Int
        var isVisible: Bool
    }

    private var surfaces: [ScreenSurface] = []
    private var latestSnapshot: SkySnapshot
    private var style: SkyStyle = .pure
    private var showStars: Bool = true
    private var showMoon: Bool = false
    private var starIntensity: Double = 1.0
    private var ambientMotion: Bool = false
    private var spanAcrossDisplays: Bool = true
    private var weather: WeatherState? = nil
    private var isActive: Bool = true
    private var isAnimatingFast: Bool = false
    private var isScreenAsleep: Bool = false

    private var observers: [NSObjectProtocol] = []

    var screenCount: Int {
        surfaces.count
    }

    var primaryResolutionSummary: String {
        guard let first = surfaces.first else { return "Metal" }
        let countSuffix = surfaces.count > 1 ? " · \(surfaces.count) 屏" : ""
        let modeSuffix = (isAnimatingFast || shouldAnimateContinuously()) ? " · 动态" : " · 极低功耗"
        return "Metal \(first.pixelWidth)×\(first.pixelHeight)\(countSuffix)\(modeSuffix)"
    }

    init(initialSnapshot: SkySnapshot, spanAcrossDisplays: Bool) {
        self.latestSnapshot = initialSnapshot
        self.spanAcrossDisplays = spanAcrossDisplays
        setupObservers()
        rebuildWindows()
    }

    deinit {
        for obs in observers {
            NotificationCenter.default.removeObserver(obs)
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
    }

    private func setupObservers() {
        let screenObs = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.rebuildWindows()
            }
        }
        observers.append(screenObs)

        let sleepObs = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isScreenAsleep = true
                self?.updateFramePacing()
            }
        }
        observers.append(sleepObs)

        let wakeObs = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isScreenAsleep = false
                self?.updateFramePacing()
                self?.drawOnceAll()
            }
        }
        observers.append(wakeObs)
    }

    func rebuildWindows() {
        for surface in surfaces {
            surface.mtkView.isPaused = true
            surface.window.orderOut(nil)
            surface.window.close()
        }
        surfaces.removeAll()

        guard let context = SkyMetalContext.shared else { return }

        let screens = NSScreen.screens
        let slices = PanoramaLayout.computeSlices(frames: screens.map(\.frame), spanAcrossDisplays: spanAcrossDisplays)
        let desktopLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))

        for (idx, screen) in screens.enumerated() {
            let scale = max(1.0, screen.backingScaleFactor)
            let pixelSize = CGSize(
                width: (screen.frame.width * scale).rounded(),
                height: (screen.frame.height * scale).rounded()
            )
            let slice = idx < slices.count ? slices[idx] : DisplaySlice.fullScreen(aspect: Double(pixelSize.width / max(1.0, pixelSize.height)))

            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.setFrame(screen.frame, display: false)
            window.level = desktopLevel
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
            window.ignoresMouseEvents = true
            window.isOpaque = true
            window.hasShadow = false
            window.canHide = false
            window.backgroundColor = .black
            window.isReleasedWhenClosed = false

            let mtkView = MTKView(frame: NSRect(origin: .zero, size: screen.frame.size), device: context.device)
            mtkView.wantsLayer = true
            mtkView.colorPixelFormat = .bgra8Unorm
            mtkView.framebufferOnly = true
            mtkView.enableSetNeedsDisplay = false
            mtkView.autoResizeDrawable = false
            mtkView.drawableSize = pixelSize
            mtkView.layer?.isOpaque = true
            mtkView.layer?.contentsScale = scale
            if let metalLayer = mtkView.layer as? CAMetalLayer {
                metalLayer.contentsScale = scale
                metalLayer.drawableSize = pixelSize
                metalLayer.maximumDrawableCount = 2 // cuts VRAM & RSS by ~33% per 4K display!
                metalLayer.colorspace = screen.colorSpace?.cgColorSpace ?? CGColorSpaceCreateDeviceRGB()
            }

            let renderer = SkyRenderer(context: context, initialSnapshot: latestSnapshot, slice: slice)
            renderer.update(
                snapshot: latestSnapshot,
                style: style,
                showStars: showStars,
                showMoon: showMoon,
                starIntensity: starIntensity,
                slice: slice,
                weather: weather
            )
            mtkView.delegate = renderer
            window.contentView = mtkView

            mtkView.layer?.contentsScale = scale
            mtkView.drawableSize = pixelSize
            if let metalLayer = mtkView.layer as? CAMetalLayer {
                metalLayer.contentsScale = scale
                metalLayer.drawableSize = pixelSize
            }

            // Observe occlusion so covered displays stop rendering automatically
            let occObs = NotificationCenter.default.addObserver(
                forName: NSWindow.didChangeOcclusionStateNotification,
                object: window,
                queue: .main
            ) { [weak self, weak window] _ in
                Task { @MainActor in
                    guard let self = self, let win = window else { return }
                    self.handleOcclusionChange(for: win)
                }
            }
            observers.append(occObs)

            if isActive {
                window.orderBack(nil)
            }
            surfaces.append(ScreenSurface(
                screen: screen,
                window: window,
                mtkView: mtkView,
                renderer: renderer,
                pixelWidth: Int(pixelSize.width),
                pixelHeight: Int(pixelSize.height),
                isVisible: true
            ))
        }

        updateFramePacing()
        drawOnceAll()
    }

    private func handleOcclusionChange(for window: NSWindow) {
        guard let idx = surfaces.firstIndex(where: { $0.window === window }) else { return }
        let visible = window.occlusionState.contains(.visible)
        if surfaces[idx].isVisible != visible {
            surfaces[idx].isVisible = visible
            updateFramePacing()
            if visible && surfaces[idx].mtkView.isPaused && isActive && !isScreenAsleep {
                surfaces[idx].mtkView.draw()
            }
        }
    }

    func update(
        snapshot: SkySnapshot,
        style: SkyStyle,
        showStars: Bool,
        showMoon: Bool,
        starIntensity: Double,
        ambientMotion: Bool,
        spanAcrossDisplays: Bool,
        weather: WeatherState?,
        isActive: Bool,
        isAnimatingFast: Bool
    ) {
        self.latestSnapshot = snapshot
        self.style = style
        self.showStars = showStars
        self.showMoon = showMoon
        self.starIntensity = starIntensity
        self.ambientMotion = ambientMotion
        self.spanAcrossDisplays = spanAcrossDisplays
        self.weather = weather
        self.isAnimatingFast = isAnimatingFast

        let activeChanged = (self.isActive != isActive)
        self.isActive = isActive

        let slices = PanoramaLayout.computeSlices(
            frames: surfaces.map { $0.screen.frame },
            spanAcrossDisplays: spanAcrossDisplays
        )

        for (idx, surface) in surfaces.enumerated() {
            let slice = idx < slices.count ? slices[idx] : DisplaySlice.fullScreen(aspect: Double(surface.pixelWidth) / Double(max(1, surface.pixelHeight)))
            surface.renderer.update(
                snapshot: snapshot,
                style: style,
                showStars: showStars,
                showMoon: showMoon,
                starIntensity: starIntensity,
                slice: slice,
                weather: weather
            )
            if activeChanged {
                if isActive {
                    surface.window.orderBack(nil)
                } else {
                    surface.window.orderOut(nil)
                }
            }
        }

        updateFramePacing()
        if isActive && !isScreenAsleep {
            drawOnceAll()
        }
    }

    private func shouldAnimateContinuously() -> Bool {
        // Automatic battery protection: never burn continuous GPU frames on battery unless actively scrubbing/demoing
        if PowerMonitor.isOnBattery { return false }
        let hasPrecipitation = (weather?.rainIntensity ?? 0) > 0.05 || (weather?.snowIntensity ?? 0) > 0.05
        return ambientMotion || hasPrecipitation
    }

    private func updateFramePacing() {
        guard isActive && !isScreenAsleep else {
            for surface in surfaces {
                surface.mtkView.isPaused = true
            }
            return
        }

        let continuous = shouldAnimateContinuously()
        let hasPrecipitation = (weather?.rainIntensity ?? 0) > 0.05 || (weather?.snowIntensity ?? 0) > 0.05

        for surface in surfaces {
            if !surface.isVisible {
                surface.mtkView.isPaused = true
                continue
            }

            if isAnimatingFast {
                surface.mtkView.preferredFramesPerSecond = 60
                surface.mtkView.isPaused = false
            } else if hasPrecipitation && !PowerMonitor.isOnBattery {
                surface.mtkView.preferredFramesPerSecond = 24
                surface.mtkView.isPaused = false
            } else if continuous {
                surface.mtkView.preferredFramesPerSecond = 12
                surface.mtkView.isPaused = false
            } else {
                // Ultra-low-power mode (~0.0% CPU): render on demand every 30s tick or interaction
                surface.mtkView.isPaused = true
            }
        }
    }

    private func drawOnceAll() {
        for surface in surfaces where surface.mtkView.isPaused && surface.isVisible {
            surface.mtkView.draw()
        }
    }
}
