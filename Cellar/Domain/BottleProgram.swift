import Foundation

struct BottleProgram: Identifiable, Codable, Hashable {
    let id: UUID
    var displayName: String
    var windowsPath: String

    init(id: UUID = UUID(), displayName: String, windowsPath: String) {
        self.id = id
        self.displayName = displayName
        self.windowsPath = windowsPath
    }

    func pointsToSameExecutable(as otherProgram: BottleProgram) -> Bool {
        windowsPath.caseInsensitiveCompare(otherProgram.windowsPath) == .orderedSame
    }
}
