import AppKit
import Foundation
import SkyCore

/// Synchronizes the live Metal sky to macOS system wallpaper so Lock Screen, Login Screen, and Mission Control match seamlessly.
@MainActor
final class WallpaperSyncManager {
    private let backupKey = "local.bian.SkyWallpaper.originalWallpapers.v1"
    private let storageDir: URL
    private var lastSyncedFiles: [URL] = []
    private var lockObserver: NSObjectProtocol?

    var onScreenLocked: (() -> Void)?

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        self.storageDir = appSupport.appendingPathComponent("SkyWallpaper/SyncedWallpapers", isDirectory: true)
        try? FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)

        lockObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.onScreenLocked?()
            }
        }
    }

    deinit {
        if let obs = lockObserver {
            DistributedNotificationCenter.default().removeObserver(obs)
        }
    }

    /// Save user's original wallpaper URLs once before overriding
    func backupOriginalWallpapersIfNeeded() {
        if UserDefaults.standard.dictionary(forKey: backupKey) != nil {
            return
        }
        var backup: [String: String] = [:]
        for (idx, screen) in NSScreen.screens.enumerated() {
            if let url = NSWorkspace.shared.desktopImageURL(for: screen) {
                // Never overwrite backup with one of our own generated files
                if !url.path.contains("SkyWallpaper/SyncedWallpapers") {
                    backup[screenIdentifier(screen, index: idx)] = url.path
                }
            }
        }
        if !backup.isEmpty {
            UserDefaults.standard.set(backup, forKey: backupKey)
        }
    }

    /// Render current sky for each screen and apply as system wallpaper (syncs Lock Screen & Mission Control)
    func syncNow(
        snapshot: SkySnapshot,
        style: SkyStyle,
        showStars: Bool,
        showMoon: Bool,
        starIntensity: Double,
        spanAcrossDisplays: Bool,
        weather: WeatherState?
    ) {
        guard let context = SkyMetalContext.shared else { return }
        backupOriginalWallpapersIfNeeded()

        let screens = NSScreen.screens
        let slices = PanoramaLayout.computeSlices(frames: screens.map(\.frame), spanAcrossDisplays: spanAcrossDisplays)
        let stamp = Int(Date().timeIntervalSince1970)
        var newlyWritten: [URL] = []

        for (idx, screen) in screens.enumerated() {
            let scale = max(1.0, screen.backingScaleFactor)
            let nativeW = Int((screen.frame.width * scale).rounded())
            let nativeH = Int((screen.frame.height * scale).rounded())
            // Cap longest edge at 2560px for fast ~25ms export while remaining tack-sharp on 4K lock screens
            let maxEdge = max(nativeW, nativeH)
            let ratio = maxEdge > 2560 ? (2560.0 / Double(maxEdge)) : 1.0
            let w = max(640, Int((Double(nativeW) * ratio).rounded()))
            let h = max(480, Int((Double(nativeH) * ratio).rounded()))

            let outURL = storageDir.appendingPathComponent("sky-\(idx)-\(stamp).jpg")
            let slice = idx < slices.count ? slices[idx] : DisplaySlice.fullScreen(aspect: Double(w) / Double(h))

            do {
                try context.renderWallpaperJPEG(
                    to: outURL,
                    snapshot: snapshot,
                    style: style,
                    showStars: showStars,
                    showMoon: showMoon,
                    starIntensity: starIntensity,
                    slice: slice,
                    weather: weather,
                    width: w,
                    height: h
                )
                try NSWorkspace.shared.setDesktopImageURL(
                    outURL,
                    for: screen,
                    options: [
                        .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
                        .allowClipping: true
                    ]
                )
                newlyWritten.append(outURL)
            } catch {
                continue
            }
        }

        // Remove previous generation files so disk stays tiny
        let oldFiles = lastSyncedFiles
        lastSyncedFiles = newlyWritten
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2.0) {
            for old in oldFiles where !newlyWritten.contains(old) {
                try? FileManager.default.removeItem(at: old)
            }
        }
    }

    /// Restore user's previously backed up macOS wallpapers
    func restoreOriginalWallpapers() {
        guard let backup = UserDefaults.standard.dictionary(forKey: backupKey) as? [String: String] else {
            return
        }
        for (idx, screen) in NSScreen.screens.enumerated() {
            let key = screenIdentifier(screen, index: idx)
            if let path = backup[key] ?? backup.values.first {
                let url = URL(fileURLWithPath: path)
                if FileManager.default.fileExists(atPath: url.path) {
                    try? NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [:])
                }
            }
        }
        UserDefaults.standard.removeObject(forKey: backupKey)
    }

    private func screenIdentifier(_ screen: NSScreen, index: Int) -> String {
        if let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            return "display-\(num.uint32Value)"
        }
        return "index-\(index)"
    }
}
