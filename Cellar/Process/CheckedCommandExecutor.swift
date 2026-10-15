import Foundation

struct CheckedCommandExecutor {
    let commandRunner: CommandRunning

    func execute(_ invocation: CommandInvocation, acceptedExitCodes: Set<Int32> = [0]) async throws {
        let exitCode = try await commandRunner.runUntilExit(invocation)
        guard acceptedExitCodes.contains(exitCode) else {
            throw CellarError.commandFailed(
                commandName: invocation.displayName,
                exitCode: exitCode,
                logFile: invocation.logFile
            )
        }
    }
}
