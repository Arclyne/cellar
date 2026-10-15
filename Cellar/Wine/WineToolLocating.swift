import Foundation

protocol WineRuntimeLocating {
    func locateWineRuntime() -> WineRuntime?
}

protocol WinetricksLocating {
    func locateWinetricks() -> URL?
}

struct InstalledWineRuntimeLocator: WineRuntimeLocating {
    private static let launcherNamesInPreferenceOrder = ["wine64", "wine"]
    private static let applicationBundleNames = ["Wine Crossover", "Wine Stable", "Wine Devel", "Wine Staging"]
    private static let packageManagerBinDirectories = ["/opt/homebrew/bin", "/usr/local/bin"]

    static let defaultCandidateBinDirectories: [URL] = {
        let bundledBinDirectories = InstalledWineRuntimeLocator.applicationBundleNames.map { bundleName in
            "/Applications/\(bundleName).app/Contents/Resources/wine/bin"
        }
        let candidatePaths = bundledBinDirectories + InstalledWineRuntimeLocator.packageManagerBinDirectories
        return candidatePaths.map { URL(fileURLWithPath: $0, isDirectory: true) }
    }()

    private let candidateBinDirectories: [URL]
    private let fileManager: FileManager

    init(
        candidateBinDirectories: [URL] = InstalledWineRuntimeLocator.defaultCandidateBinDirectories,
        fileManager: FileManager = .default
    ) {
        self.candidateBinDirectories = candidateBinDirectories
        self.fileManager = fileManager
    }

    func locateWineRuntime() -> WineRuntime? {
        candidateBinDirectories.lazy.compactMap { runtime(in: $0) }.first
    }

    private func runtime(in binDirectory: URL) -> WineRuntime? {
        let launcherExecutable = Self.launcherNamesInPreferenceOrder
            .map { binDirectory.appendingPathComponent($0) }
            .first { fileManager.isExecutableFile(atPath: $0.path) }
        return launcherExecutable.map { WineRuntime(binDirectory: binDirectory, launcherExecutable: $0) }
    }
}

struct InstalledWinetricksLocator: WinetricksLocating {
    static let defaultCandidateExecutables: [URL] = [
        "/opt/homebrew/bin/winetricks",
        "/usr/local/bin/winetricks"
    ].map { URL(fileURLWithPath: $0) }

    private let candidateExecutables: [URL]
    private let fileManager: FileManager

    init(
        candidateExecutables: [URL] = InstalledWinetricksLocator.defaultCandidateExecutables,
        fileManager: FileManager = .default
    ) {
        self.candidateExecutables = candidateExecutables
        self.fileManager = fileManager
    }

    func locateWinetricks() -> URL? {
        candidateExecutables.first { fileManager.isExecutableFile(atPath: $0.path) }
    }
}
