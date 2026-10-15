import Foundation

enum InstallationStage: Equatable {
    case creatingBottle
    case preparingWindowsEnvironment
    case installingComponent(String)
    case configuringLibraries
    case runningInstaller(String)
    case registeringPrograms

    var statusMessage: String {
        switch self {
        case .creatingBottle:
            "Creating bottle…"
        case .preparingWindowsEnvironment:
            "Preparing the Windows environment…"
        case .installingComponent(let componentName):
            "Installing \(componentName)…"
        case .configuringLibraries:
            "Configuring libraries…"
        case .runningInstaller(let installerName):
            "Running \(installerName)…"
        case .registeringPrograms:
            "Registering programs…"
        }
    }
}

struct InstallationRequest {
    let recipe: InstallationRecipe
    let installerURL: URL
    let bottleName: String
}

struct InstallationReport {
    let bottle: Bottle
    let failedComponents: [String]
}
