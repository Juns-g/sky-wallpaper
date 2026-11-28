import AppKit
import CoreGraphics

/// Describes one connected display for the per-display on/off list.
struct DisplayInfo: Identifiable, Equatable {
    let id: String          // stable display UUID
    let name: String        // NSScreen.localizedName
    let width: Int          // points
    let height: Int         // points
}

@MainActor
enum DisplayIdentity {
    /// Stable UUID for a screen (survives reboot / port change), falling back to the CGDirectDisplayID.
    static func uuid(for screen: NSScreen) -> String {
        guard let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return "unknown-\(screen.localizedName)"
        }
        let displayID = CGDirectDisplayID(num.uint32Value)
        if let cfUUID = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue(),
           let str = CFUUIDCreateString(nil, cfUUID) as String? {
            return str
        }
        return "display-\(displayID)"
    }

    static func info(for screen: NSScreen) -> DisplayInfo {
        DisplayInfo(
            id: uuid(for: screen),
            name: screen.localizedName,
            width: Int(screen.frame.width.rounded()),
            height: Int(screen.frame.height.rounded())
        )
    }

    static func allDisplays() -> [DisplayInfo] {
        NSScreen.screens.map(info(for:))
    }

    /// NSScreen.screens minus the displays the user switched off.
    static func enabledScreens(disabled: [String]) -> [NSScreen] {
        let excluded = Set(disabled)
        return NSScreen.screens.filter { !excluded.contains(uuid(for: $0)) }
    }

    static func disabledScreens(disabled: [String]) -> [NSScreen] {
        let excluded = Set(disabled)
        return NSScreen.screens.filter { excluded.contains(uuid(for: $0)) }
    }
}
