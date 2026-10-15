import Foundation

protocol RecipeInstalling {
    func install(
        _ request: InstallationRequest,
        onStageChange: @escaping @Sendable (InstallationStage) -> Void
    ) async throws -> InstallationReport
}

struct RecipeInstaller: RecipeInstalling {
    let bottleStore: BottleStoring
    let prefixProvisioner: PrefixProvisioning
    let componentInstaller: ComponentInstalling
    let dllOverrideApplier: DllOverrideApplying
    let installerRunner: InstallerRunning
    let programResolver: InstalledProgramResolving

    func install(
        _ request: InstallationRequest,
        onStageChange: @escaping @Sendable (InstallationStage) -> Void
    ) async throws -> InstallationReport {
        let recipe = request.recipe
        guard recipe.winetricksVerbs.isEmpty || componentInstaller.canInstallComponents else {
            throw CellarError.winetricksNotFound
        }

        onStageChange(.creatingBottle)
        let newBottle = Bottle(name: request.bottleName, windowsVersion: recipe.windowsVersion)
        try bottleStore.save(newBottle)

        onStageChange(.preparingWindowsEnvironment)
        try await prefixProvisioner.provisionPrefix(for: newBottle)

        let failedComponents = await installComponents(recipe.winetricksVerbs, in: newBottle, onStageChange: onStageChange)

        onStageChange(.configuringLibraries)
        try await dllOverrideApplier.applyDllOverrides(recipe.dllOverrides, in: newBottle)

        onStageChange(.runningInstaller(request.installerURL.lastPathComponent))
        try await installerRunner.runInstaller(at: request.installerURL, in: newBottle)

        onStageChange(.registeringPrograms)
        let installedPrograms = programResolver.installedPrograms(among: recipe.programCandidates, in: newBottle)
        let installedBottle = installedPrograms.reduce(newBottle) { bottle, program in bottle.addingProgram(program) }
        try bottleStore.save(installedBottle)

        return InstallationReport(bottle: installedBottle, failedComponents: failedComponents)
    }

    private func installComponents(
        _ componentVerbs: [String],
        in bottle: Bottle,
        onStageChange: @escaping @Sendable (InstallationStage) -> Void
    ) async -> [String] {
        var failedComponents: [String] = []
        for componentVerb in componentVerbs {
            onStageChange(.installingComponent(componentVerb))
            do {
                try await componentInstaller.installComponent(componentVerb, in: bottle)
            } catch {
                failedComponents.append(componentVerb)
            }
        }
        return failedComponents
    }
}
