import Foundation

final class ProcessCommandRunner: CommandRunning {
    private let fileManager: FileManager
    private let inheritedEnvironment: [String: String]

    init(
        fileManager: FileManager = .default,
        inheritedEnvironment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.fileManager = fileManager
        self.inheritedEnvironment = inheritedEnvironment
    }

    func runUntilExit(_ invocation: CommandInvocation) async throws -> Int32 {
        let loggedProcess = try prepareProcess(for: invocation)
        return try await withCheckedThrowingContinuation { continuation in
            loggedProcess.process.terminationHandler = { finishedProcess in
                loggedProcess.closeLog()
                continuation.resume(returning: finishedProcess.terminationStatus)
            }
            do {
                try loggedProcess.process.run()
            } catch {
                loggedProcess.process.terminationHandler = nil
                loggedProcess.closeLog()
                continuation.resume(throwing: error)
            }
        }
    }

    func launch(_ invocation: CommandInvocation) throws {
        let loggedProcess = try prepareProcess(for: invocation)
        loggedProcess.process.terminationHandler = { _ in
            loggedProcess.closeLog()
        }
        do {
            try loggedProcess.process.run()
        } catch {
            loggedProcess.process.terminationHandler = nil
            loggedProcess.closeLog()
            throw error
        }
    }

    private func prepareProcess(for invocation: CommandInvocation) throws -> LoggedProcess {
        let process = Process()
        process.executableURL = invocation.executable
        process.arguments = invocation.arguments
        process.environment = inheritedEnvironment.merging(invocation.environment) { _, invocationValue in invocationValue }
        process.currentDirectoryURL = invocation.workingDirectory
        process.standardInput = FileHandle.nullDevice

        guard let logFile = invocation.logFile else {
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            return LoggedProcess(process: process, logHandle: nil)
        }

        let logHandle = try openLogHandle(at: logFile)
        try logHandle.write(contentsOf: Data(logHeader(for: invocation).utf8))
        process.standardOutput = logHandle
        process.standardError = logHandle
        return LoggedProcess(process: process, logHandle: logHandle)
    }

    private func openLogHandle(at logFile: URL) throws -> FileHandle {
        try fileManager.createDirectory(at: logFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !fileManager.fileExists(atPath: logFile.path) {
            fileManager.createFile(atPath: logFile.path, contents: nil)
        }
        let logHandle = try FileHandle(forWritingTo: logFile)
        try logHandle.seekToEnd()
        return logHandle
    }

    private func logHeader(for invocation: CommandInvocation) -> String {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        return "\n[\(timestamp)] \(invocation.displayName)\n$ \(invocation.renderedCommandLine)\n"
    }
}

private final class LoggedProcess {
    let process: Process
    private let logHandle: FileHandle?

    init(process: Process, logHandle: FileHandle?) {
        self.process = process
        self.logHandle = logHandle
    }

    func closeLog() {
        try? logHandle?.close()
    }
}
