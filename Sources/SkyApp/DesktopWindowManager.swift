import AppKit
import MetalKit
import SkyCore

@MainActor
final class DesktopWindowManager {
    private struct ScreenSurface {
        let window: NSWindow
        let mtkView: MTKView
        let renderer: SkyRenderer
        let pixelWidth: Int
        let pixelHeight: Int
    }

    private var surfaces: [ScreenSurface] = []
    private var latestSnapshot: SkySnapshot
    private var style: SkyStyle = .pure
    private var showStars: Bool = true
    private var showMoon: Bool = false
    private var starIntensity: Double = 1.0
    private var isActive: Bool = true
    private var isAnimatingFast: Bool = false
    private var isScreenAsleep: Bool = false

    private var observers: [NSObjectProtocol] = []

    var primaryResolutionSummary: String {
        guard let first = surfaces.first else { return "Metal" }
        let countSuffix = surfaces.count > 1 ? " · \(surfaces.count) 屏" : ""
        return "Metal \(first.pixelWidth)×\(first.pixelHeight)\(countSuffix)"
    }

    init(initialSnapshot: SkySnapshot) {
        self.latestSnapshot = initialSnapshot
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

        let desktopLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))

        for screen in NSScreen.screens {
            let scale = max(1.0, screen.backingScaleFactor)
            let pixelSize = CGSize(
                width: (screen.frame.width * scale).rounded(),
                height: (screen.frame.height * scale).rounded()
            )

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
                metalLayer.colorspace = screen.colorSpace?.cgColorSpace ?? CGColorSpaceCreateDeviceRGB()
            }

            let aspect = Double(pixelSize.width / max(1.0, pixelSize.height))
            let renderer = SkyRenderer(context: context, initialSnapshot: latestSnapshot, initialAspect: aspect)
            renderer.update(
                snapshot: latestSnapshot,
                style: style,
                showStars: showStars,
                showMoon: showMoon,
                starIntensity: starIntensity
            )
            mtkView.delegate = renderer
            window.contentView = mtkView

            // Re-lock native HiDPI / 4K backing scale after attaching to window
            mtkView.layer?.contentsScale = scale
            mtkView.drawableSize = pixelSize
            if let metalLayer = mtkView.layer as? CAMetalLayer {
                metalLayer.contentsScale = scale
                metalLayer.drawableSize = pixelSize
            }

            if isActive {
                window.orderBack(nil)
            }
            surfaces.append(ScreenSurface(
                window: window,
                mtkView: mtkView,
                renderer: renderer,
                pixelWidth: Int(pixelSize.width),
                pixelHeight: Int(pixelSize.height)
            ))
        }

        updateFramePacing()
        drawOnceAll()
    }

    func update(
        snapshot: SkySnapshot,
        style: SkyStyle,
        showStars: Bool,
        showMoon: Bool,
        starIntensity: Double,
        isActive: Bool,
        isAnimatingFast: Bool
    ) {
        self.latestSnapshot = snapshot
        self.style = style
        self.showStars = showStars
        self.showMoon = showMoon
        self.starIntensity = starIntensity
        self.isAnimatingFast = isAnimatingFast

        let activeChanged = (self.isActive != isActive)
        self.isActive = isActive

        for surface in surfaces {
            surface.renderer.update(
                snapshot: snapshot,
                style: style,
                showStars: showStars,
                showMoon: showMoon,
                starIntensity: starIntensity
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

    private func updateFramePacing() {
        guard isActive && !isScreenAsleep else {
            for surface in surfaces {
                surface.mtkView.isPaused = true
            }
            return
        }

        let isNight = latestSnapshot.solar.elevationDegrees < -3.0
        for surface in surfaces {
            if isAnimatingFast {
                surface.mtkView.preferredFramesPerSecond = 60
                surface.mtkView.isPaused = false
            } else if style == .cirrus && !isNight {
                surface.mtkView.preferredFramesPerSecond = 15
                surface.mtkView.isPaused = false
            } else if isNight && showStars {
                surface.mtkView.preferredFramesPerSecond = 12
                surface.mtkView.isPaused = false
            } else {
                surface.mtkView.isPaused = true
            }
        }
    }

    private func drawOnceAll() {
        for surface in surfaces where surface.mtkView.isPaused {
            surface.mtkView.draw()
        }
    }
}
