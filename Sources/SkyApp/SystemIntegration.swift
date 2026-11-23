import AppKit
import Foundation
import IOKit.ps

enum PowerMonitor {
    /// Returns true if Mac is currently running on battery power
    static var isOnBattery: Bool {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return false
        }
        for ps in list {
            if let desc = IOPSGetPowerSourceDescription(snapshot, ps)?.takeUnretainedValue() as? [String: Any],
               let state = desc[kIOPSPowerSourceStateKey as String] as? String {
                if state == kIOPSBatteryPowerValue as String {
                    return true
                }
            }
        }
        return false
    }
}

@MainActor
final class AppearanceSync {
    private var lastAppliedDark: Bool?

    /// Optionally align macOS Light/Dark mode with true astronomical sunrise/sunset (elevation < -1° => Dark)
    func applyIfNeeded(sunElevationDegrees: Double, enabled: Bool) {
        guard enabled else {
            lastAppliedDark = nil
            return
        }
        let shouldBeDark = sunElevationDegrees < -1.0
        guard lastAppliedDark != shouldBeDark else { return }
        lastAppliedDark = shouldBeDark

        let currentlyDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        guard currentlyDark != shouldBeDark else { return }

        let target = shouldBeDark ? "true" : "false"
        let script = "tell application \"System Events\" to tell appearance preferences to set dark mode to \(target)"
        DispatchQueue.global(qos: .utility).async {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            proc.arguments = ["-e", script]
            try? proc.run()
            proc.waitUntilExit()
        }
    }

    func reset() {
        lastAppliedDark = nil
    }
}
