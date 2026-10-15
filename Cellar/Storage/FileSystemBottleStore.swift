import Foundation

struct FileSystemBottleStore: BottleStoring {
    private let layout: BottleDirectoryLayout
    private let fileManager: FileManager

    init(layout: BottleDirectoryLayout, fileManager: FileManager = .default) {
        self.layout = layout
        self.fileManager = fileManager
    }

    func loadBottles() throws -> [Bottle] {
        try fileManager.createDirectory(at: layout.bottlesRootDirectory, withIntermediateDirectories: true)
        let bottleDirectories = try fileManager.contentsOfDirectory(
            at: layout.bottlesRootDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        return bottleDirectories
            .map { layout.metadataFile(inBottleDirectory: $0) }
            .filter { fileManager.fileExists(atPath: $0.path) }
            .compactMap { try? decodeBottle(at: $0) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func save(_ bottle: Bottle) throws {
        try fileManager.createDirectory(at: layout.bottleDirectory(for: bottle.id), withIntermediateDirectories: true)
        let encodedBottle = try Self.makeEncoder().encode(bottle)
        try encodedBottle.write(to: layout.metadataFile(for: bottle.id), options: .atomic)
    }

    func remove(_ bottle: Bottle) throws {
        let bottleDirectory = layout.bottleDirectory(for: bottle.id)
        guard fileManager.fileExists(atPath: bottleDirectory.path) else { return }
        try fileManager.trashItem(at: bottleDirectory, resultingItemURL: nil)
    }

    private func decodeBottle(at metadataFile: URL) throws -> Bottle {
        let encodedBottle = try Data(contentsOf: metadataFile)
        return try Self.makeDecoder().decode(Bottle.self, from: encodedBottle)
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
