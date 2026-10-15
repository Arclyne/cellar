import Foundation

enum CellarError: LocalizedError {
    case wineRuntimeNotFound
    case winetricksNotFound
    case commandFailed(commandName: String, exitCode: Int32, logFile: URL?)
    case bottleNameMissing
    case bottleNotFound
    case installerTypeNotSupported(String)

    var errorDescription: String? {
        switch self {
        case .wineRuntimeNotFound:
            "Wine was not found. Install it with Homebrew: brew install --cask gcenx/wine/wine-crossover"
        case .winetricksNotFound:
            "Winetricks was not found. Install it with Homebrew: brew install winetricks cabextract"
        case .commandFailed(let commandName, let exitCode, let logFile):
            failureDescription(commandName: commandName, exitCode: exitCode, logFile: logFile)
        case .bottleNameMissing:
            "Give the bottle a name."
        case .bottleNotFound:
            "The bottle no longer exists."
        case .installerTypeNotSupported(let fileExtension):
            "Installers of type “.\(fileExtension)” are not supported. Use an .msi or .exe file."
        }
    }

    private func failureDescription(commandName: String, exitCode: Int32, logFile: URL?) -> String {
        let summary = "\(commandName) finished with exit code \(exitCode)."
        guard let logFile else { return summary }
        return "\(summary) Details are in \(logFile.path)."
    }
}
