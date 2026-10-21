import Foundation

protocol RecipeInstalling {
    func install(
        _ request: InstallationRequest,
        onStageChange: @escaping @Sendable (InstallationStage) -> Void
    ) async throws -> InstallationReport

    func applyComponents(
        of recipe: InstallationRecipe,
        to bottle: Bottle,
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
        try requireComponentInstaller(for: recipe)

        onStageChange(.creatingBottle)
        let newBottle = Bottle(name: request.bottleName, windowsVersion: recipe.windowsVersion, recipeID: recipe.id)
        try bottleStore.save(newBottle)

        onStageChange(.preparingWindowsEnvironment)
        try await prefixProvisioner.provisionPrefix(for: newBottle)

        let failedComponents = try await installComponentsAndLibraries(of: recipe, in: newBottle, onStageChange: onStageChange)

        onStageChange(.runningInstaller(request.installerURL.lastPathComponent))
        try await installerRunner.runInstaller(at: request.installerURL, in: newBottle)

        let installedBottle = try registerInstalledPrograms(of: recipe, in: newBottle, onStageChange: onStageChange)
        return InstallationReport(bottle: installedBottle, failedComponents: failedComponents)
    }

    func applyComponents(
        of recipe: InstallationRecipe,
        to bottle: Bottle,
        onStageChange: @escaping @Sendable (InstallationStage) -> Void
    ) async throws -> InstallationReport {
        try requireComponentInstaller(for: recipe)

        let failedComponents = try await installComponentsAndLibraries(of: recipe, in: bottle, onStageChange: onStageChange)

        var recipeBottle = bottle
        recipeBottle.recipeID = recipe.id
        // Programs copied into the bottle by hand are registered when they sit where the recipe expects them.
        let updatedBottle = try registerInstalledPrograms(of: recipe, in: recipeBottle, onStageChange: onStageChange)
        return InstallationReport(bottle: updatedBottle, failedComponents: failedComponents)
    }

    private func requireComponentInstaller(for recipe: InstallationRecipe) throws {
        guard recipe.winetricksVerbs.isEmpty || componentInstaller.canInstallComponents else {
            throw CellarError.winetricksNotFound
        }
    }

    private func installComponentsAndLibraries(
        of recipe: InstallationRecipe,
        in bottle: Bottle,
        onStageChange: @escaping @Sendable (InstallationStage) -> Void
    ) async throws -> [String] {
        let failedComponents = await installComponents(recipe.winetricksVerbs, in: bottle, onStageChange: onStageChange)

        onStageChange(.configuringLibraries)
        try await dllOverrideApplier.applyDllOverrides(recipe.dllOverrides, in: bottle)
        return failedComponents
    }

    private func registerInstalledPrograms(
        of recipe: InstallationRecipe,
        in bottle: Bottle,
        onStageChange: @escaping @Sendable (InstallationStage) -> Void
    ) throws -> Bottle {
        onStageChange(.registeringPrograms)
        let installedPrograms = programResolver.installedPrograms(among: recipe.programCandidates, in: bottle)
        let installedBottle = installedPrograms.reduce(bottle) { bottle, program in bottle.addingProgram(program) }
        try bottleStore.save(installedBottle)
        return installedBottle
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
