import Foundation

protocol CommandRunning {
    func runUntilExit(_ invocation: CommandInvocation) async throws -> Int32
    func launch(_ invocation: CommandInvocation) throws
}
