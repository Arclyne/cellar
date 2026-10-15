import Foundation

struct BottleDirectoryLayout {
    private static let metadataFileName = "cellar-bottle.json"
    private static let logFileName = "cellar.log"
    private static let driveCDirectoryName = "drive_c"

    let bottlesRootDirectory: URL

    func bottleDirectory(for bottleID: Bottle.ID) -> URL {
        bottlesRootDirectory.appendingPathComponent(bottleID.uuidString, isDirectory: true)
    }

    func metadataFile(for bottleID: Bottle.ID) -> URL {
        bottleDirectory(for: bottleID).appendingPathComponent(Self.metadataFileName)
    }

    func metadataFile(inBottleDirectory bottleDirectory: URL) -> URL {
        bottleDirectory.appendingPathComponent(Self.metadataFileName)
    }

    func logFile(for bottleID: Bottle.ID) -> URL {
        bottleDirectory(for: bottleID).appendingPathComponent(Self.logFileName)
    }

    func driveCDirectory(for bottleID: Bottle.ID) -> URL {
        bottleDirectory(for: bottleID).appendingPathComponent(Self.driveCDirectoryName, isDirectory: true)
    }

    func pathConverter(for bottleID: Bottle.ID) -> WindowsPathConverter {
        WindowsPathConverter(driveCDirectory: driveCDirectory(for: bottleID))
    }

    static func inApplicationSupport(fileManager: FileManager = .default) -> BottleDirectoryLayout {
        let applicationSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let bottlesRootDirectory = applicationSupportDirectory
            .appendingPathComponent("Cellar", isDirectory: true)
            .appendingPathComponent("Bottles", isDirectory: true)
        return BottleDirectoryLayout(bottlesRootDirectory: bottlesRootDirectory)
    }
}
