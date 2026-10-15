import AppKit
import CoreGraphics

protocol ProgramWindowLocating {
    func hasOnscreenWindow(ownedBy processIdentifier: Int32) -> Bool
    func bringToFront(processIdentifier: Int32)
}

struct WindowServerProgramWindowLocator: ProgramWindowLocating {
    private static let normalWindowLayer = 0

    func hasOnscreenWindow(ownedBy processIdentifier: Int32) -> Bool {
        let windowOptions: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowDescriptions = CGWindowListCopyWindowInfo(windowOptions, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        return windowDescriptions.contains { windowDescription in
            let ownerProcessIdentifier = (windowDescription[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value
            let windowLayer = (windowDescription[kCGWindowLayer as String] as? NSNumber)?.intValue
            return ownerProcessIdentifier == processIdentifier && windowLayer == Self.normalWindowLayer
        }
    }

    func bringToFront(processIdentifier: Int32) {
        NSRunningApplication(processIdentifier: processIdentifier)?.activate()
    }
}
