import Foundation

protocol InstallerRunning {
    func runInstaller(at installerURL: URL, in bottle: Bottle) async throws
}

struct WineInstallerRunner: InstallerRunning {
    private static let successfulInstallerExitCodes: Set<Int32> = [0, 3010]

    let invocationFactory: WineInvocationFactory
    let executor: CheckedCommandExecutor

    func runInstaller(at installerURL: URL, in bottle: Bottle) async throws {
        let installerArguments = try arguments(forInstallerAt: installerURL, in: bottle)
        let installation = try invocationFactory.wineInvocation(
            arguments: installerArguments,
            displayName: installerURL.lastPathComponent,
            workingDirectory: installerURL.deletingLastPathComponent(),
            for: bottle
        )
        try await executor.execute(installation, acceptedExitCodes: Self.successfulInstallerExitCodes)
    }

    private func arguments(forInstallerAt installerURL: URL, in bottle: Bottle) throws -> [String] {
        let installerWindowsPath = invocationFactory.pathConverter(for: bottle).windowsPath(for: installerURL)
        switch installerURL.pathExtension.lowercased() {
        case "msi":
            return ["msiexec", "/i", installerWindowsPath]
        case "exe":
            return [installerWindowsPath]
        default:
            throw CellarError.installerTypeNotSupported(installerURL.pathExtension)
        }
    }
}
