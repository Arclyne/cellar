import Foundation

protocol InstalledProgramResolving {
    func installedPrograms(among candidates: [ProgramCandidate], in bottle: Bottle) -> [BottleProgram]
}

struct DriveCProgramResolver: InstalledProgramResolving {
    private let layout: BottleDirectoryLayout
    private let fileManager: FileManager

    init(layout: BottleDirectoryLayout, fileManager: FileManager = .default) {
        self.layout = layout
        self.fileManager = fileManager
    }

    func installedPrograms(among candidates: [ProgramCandidate], in bottle: Bottle) -> [BottleProgram] {
        let pathConverter = layout.pathConverter(for: bottle.id)
        return candidates
            .filter { candidate in
                guard let executableURL = pathConverter.unixURL(forWindowsPath: candidate.windowsPath) else {
                    return false
                }
                return fileManager.fileExists(atPath: executableURL.path)
            }
            .map { BottleProgram(displayName: $0.displayName, windowsPath: $0.windowsPath) }
    }
}
