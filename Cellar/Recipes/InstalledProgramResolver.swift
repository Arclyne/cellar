import Foundation

protocol InstalledProgramResolving {
    func installedPrograms(among candidates: [ProgramCandidate], in bottle: Bottle) -> [BottleProgram]
}

struct DriveCProgramResolver: InstalledProgramResolving {
    private static let searchedProgramDirectories = ["Program Files", "Program Files (x86)"]
    private static let maximumSearchDepth = 4

    private let layout: BottleDirectoryLayout
    private let fileManager: FileManager

    init(layout: BottleDirectoryLayout, fileManager: FileManager = .default) {
        self.layout = layout
        self.fileManager = fileManager
    }

    func installedPrograms(among candidates: [ProgramCandidate], in bottle: Bottle) -> [BottleProgram] {
        let programsAtDeclaredPaths = programsAtDeclaredPaths(among: candidates, in: bottle)
        guard programsAtDeclaredPaths.isEmpty else { return programsAtDeclaredPaths }
        return programsFoundBySearching(for: candidates, in: bottle)
    }

    private func programsAtDeclaredPaths(among candidates: [ProgramCandidate], in bottle: Bottle) -> [BottleProgram] {
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

    private func programsFoundBySearching(for candidates: [ProgramCandidate], in bottle: Bottle) -> [BottleProgram] {
        let displayNamesByExecutableName = Dictionary(
            candidates.map { ($0.executableFileName.lowercased(), $0.displayName) },
            uniquingKeysWith: { firstDisplayName, _ in firstDisplayName }
        )
        guard !displayNamesByExecutableName.isEmpty else { return [] }

        let pathConverter = layout.pathConverter(for: bottle.id)
        let driveCDirectory = layout.driveCDirectory(for: bottle.id)
        return Self.searchedProgramDirectories
            .map { driveCDirectory.appendingPathComponent($0, isDirectory: true) }
            .flatMap { executables(in: $0, named: Set(displayNamesByExecutableName.keys)) }
            .compactMap { executableURL in
                displayNamesByExecutableName[executableURL.lastPathComponent.lowercased()].map { displayName in
                    BottleProgram(displayName: displayName, windowsPath: pathConverter.windowsPath(for: executableURL))
                }
            }
    }

    private func executables(in searchRoot: URL, named lowercasedExecutableNames: Set<String>) -> [URL] {
        guard let directoryEnumerator = fileManager.enumerator(
            at: searchRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }
        var matchingExecutables: [URL] = []
        for case let fileURL as URL in directoryEnumerator {
            if directoryEnumerator.level > Self.maximumSearchDepth {
                directoryEnumerator.skipDescendants()
                continue
            }
            if lowercasedExecutableNames.contains(fileURL.lastPathComponent.lowercased()) {
                matchingExecutables.append(fileURL)
            }
        }
        return matchingExecutables
    }
}
