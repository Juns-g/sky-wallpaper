import AppKit
import SkyCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var viewModel: SkyViewModel!

    func applicationDidFinishLaunching(_ notification: Notification) {
        viewModel = SkyViewModel()
        viewModel.onPhaseChanged = { [weak self] phase in
            self?.updateStatusIcon(for: phase)
        }

        setupStatusItem()
        setupPopover()
        updateStatusIcon(for: viewModel.snapshot.phase)
    }

    func applicationWillTerminate(_ notification: Notification) {
        viewModel?.shutdown()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleStatusItemClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "Sky 实时天空壁纸"
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        let hostingController = NSHostingController(
            rootView: MenuBarPopoverView(viewModel: viewModel) { [weak self] in
                self?.quitApp()
            }
        )
        hostingController.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hostingController
    }

    private func updateStatusIcon(for phase: DayPhase) {
        guard let button = statusItem.button else { return }
        // Subtle phase-tinted hierarchical menu bar symbol (matches native macOS Weather/Sky feel)
        let tintColor: NSColor
        switch phase {
        case .dawn:
            tintColor = NSColor(srgbRed: 0.96, green: 0.68, blue: 0.56, alpha: 1.0)
        case .sunrise:
            tintColor = NSColor(srgbRed: 1.00, green: 0.72, blue: 0.36, alpha: 1.0)
        case .day:
            tintColor = NSColor(srgbRed: 0.99, green: 0.80, blue: 0.32, alpha: 1.0)
        case .sunset:
            tintColor = NSColor(srgbRed: 0.98, green: 0.56, blue: 0.42, alpha: 1.0)
        case .dusk:
            tintColor = NSColor(srgbRed: 0.72, green: 0.66, blue: 0.98, alpha: 1.0)
        case .night:
            tintColor = NSColor(srgbRed: 0.68, green: 0.80, blue: 1.00, alpha: 1.0)
        }

        if let image = NSImage(systemSymbolName: phase.symbolName, accessibilityDescription: phase.chineseTitle) {
            let sizeConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            let colorConfig = NSImage.SymbolConfiguration(paletteColors: [tintColor])
            let combined = sizeConfig.applying(colorConfig)
            let configured = image.withSymbolConfiguration(combined) ?? image
            configured.isTemplate = false
            button.image = configured
        } else {
            button.title = "☀"
        }
    }

    @objc private func handleStatusItemClick(_ sender: AnyObject?) {
        guard let event = NSApp.currentEvent else {
            togglePopover()
            return
        }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        let activeTitle = viewModel.settings.isWallpaperActive ? "暂停天空桌面" : "恢复天空桌面"
        let toggleItem = NSMenuItem(title: activeTitle, action: #selector(toggleActive), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        let demoTitle = viewModel.isDemoPlaying ? "停止演示全天" : "演示全天 24 小时"
        let demoItem = NSMenuItem(title: demoTitle, action: #selector(toggleDemo), keyEquivalent: "")
        demoItem.target = self
        menu.addItem(demoItem)

        if viewModel.isPreviewing {
            let nowItem = NSMenuItem(title: "回到当前时间", action: #selector(resetToNow), keyEquivalent: "")
            nowItem.target = self
            menu.addItem(nowItem)
        }

        let syncItem = NSMenuItem(title: "同步当前天色到锁屏", action: #selector(syncLockScreen), keyEquivalent: "")
        syncItem.target = self
        menu.addItem(syncItem)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "退出 Sky", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func toggleActive() {
        viewModel.setWallpaperActive(!viewModel.settings.isWallpaperActive)
    }

    @objc private func toggleDemo() {
        viewModel.toggleDemoTour()
    }

    @objc private func resetToNow() {
        viewModel.returnToNow()
    }

    @objc private func syncLockScreen() {
        viewModel.syncLockScreenWallpaperNow(showToast: true)
    }

    @objc private func quitApp() {
        viewModel.shutdown()
        NSApp.terminate(nil)
    }
}
