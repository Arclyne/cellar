import Foundation

struct CommandInvocation {
    let executable: URL
    let arguments: [String]
    let environment: [String: String]
    let workingDirectory: URL?
    let logFile: URL?
    let displayName: String

    init(
        executable: URL,
        arguments: [String],
        environment: [String: String] = [:],
        workingDirectory: URL? = nil,
        logFile: URL? = nil,
        displayName: String
    ) {
        self.executable = executable
        self.arguments = arguments
        self.environment = environment
        self.workingDirectory = workingDirectory
        self.logFile = logFile
        self.displayName = displayName
    }

    var renderedCommandLine: String {
        ([executable.path] + arguments).joined(separator: " ")
    }
}
