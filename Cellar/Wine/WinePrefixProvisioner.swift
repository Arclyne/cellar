import Foundation

protocol PrefixProvisioning {
    func provisionPrefix(for bottle: Bottle) async throws
}

struct WinePrefixProvisioner: PrefixProvisioning {
    let invocationFactory: WineInvocationFactory
    let executor: CheckedCommandExecutor

    func provisionPrefix(for bottle: Bottle) async throws {
        let environmentInitialization = try invocationFactory.wineInvocation(
            arguments: ["wineboot", "--init"],
            displayName: "Windows environment setup",
            for: bottle
        )
        try await executor.execute(environmentInitialization)

        let windowsVersionSelection = try invocationFactory.wineInvocation(
            arguments: ["winecfg", "-v", bottle.windowsVersion.rawValue],
            displayName: "Windows version selection",
            for: bottle
        )
        try await executor.execute(windowsVersionSelection)
    }
}
