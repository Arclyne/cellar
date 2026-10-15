import Foundation

struct ProcessExit {
    let processIdentifier: Int32
    let exitCode: Int32
}

protocol CommandRunning {
    func runUntilExit(_ invocation: CommandInvocation) async throws -> Int32
    func launch(_ invocation: CommandInvocation, onExit: @escaping @Sendable (ProcessExit) -> Void) throws -> Int32
}
