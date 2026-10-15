import Foundation

protocol ComponentInstalling {
    var canInstallComponents: Bool { get }
    func installComponent(_ componentVerb: String, in bottle: Bottle) async throws
}

struct WinetricksComponentInstaller: ComponentInstalling {
    let invocationFactory: WineInvocationFactory
    let winetricksLocator: WinetricksLocating
    let executor: CheckedCommandExecutor

    var canInstallComponents: Bool {
        winetricksLocator.locateWinetricks() != nil
    }

    func installComponent(_ componentVerb: String, in bottle: Bottle) async throws {
        let componentInstallation = try invocationFactory.winetricksInvocation(verbs: [componentVerb], for: bottle)
        try await executor.execute(componentInstallation)
    }
}
