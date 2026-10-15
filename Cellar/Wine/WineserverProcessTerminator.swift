import Foundation

protocol BottleProcessTerminating {
    func terminateAllProcesses(in bottle: Bottle) async throws
}

struct WineserverProcessTerminator: BottleProcessTerminating {
    let invocationFactory: WineInvocationFactory
    let commandRunner: CommandRunning

    func terminateAllProcesses(in bottle: Bottle) async throws {
        let shutdown = try invocationFactory.wineserverInvocation(
            arguments: ["-k"],
            displayName: "Stop all programs",
            for: bottle
        )
        _ = try await commandRunner.runUntilExit(shutdown)
    }
}
