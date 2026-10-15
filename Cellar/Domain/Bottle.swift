import Foundation

struct Bottle: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var windowsVersion: WindowsVersion
    var programs: [BottleProgram]
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        windowsVersion: WindowsVersion,
        programs: [BottleProgram] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.windowsVersion = windowsVersion
        self.programs = programs
        self.createdAt = createdAt
    }

    func addingProgram(_ program: BottleProgram) -> Bottle {
        guard !programs.contains(where: { $0.pointsToSameExecutable(as: program) }) else {
            return self
        }
        var updatedBottle = self
        updatedBottle.programs.append(program)
        return updatedBottle
    }

    func removingProgram(withID programID: BottleProgram.ID) -> Bottle {
        var updatedBottle = self
        updatedBottle.programs.removeAll { $0.id == programID }
        return updatedBottle
    }
}
