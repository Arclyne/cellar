import Foundation
import Observation

@Observable
@MainActor
final class BottleLibrary {
    private(set) var bottles: [Bottle] = []
    var selectedBottleID: Bottle.ID?
    private(set) var activityMessage: String?
    private(set) var presentedNotice: LibraryNotice?
    private(set) var isWineRuntimeAvailable = false
    let recipes: [InstallationRecipe]

    private let layout: BottleDirectoryLayout
    private let bottleStore: BottleStoring
    private let wineRuntimeLocator: WineRuntimeLocating
    private let prefixProvisioner: PrefixProvisioning
    private let installerRunner: InstallerRunning
    private let recipeInstaller: RecipeInstalling
    private let programLauncher: ProgramLaunching
    private let processTerminator: BottleProcessTerminating
    private let fileRevealer: FileRevealing

    init(dependencies: LibraryDependencies) {
        layout = dependencies.layout
        bottleStore = dependencies.bottleStore
        wineRuntimeLocator = dependencies.wineRuntimeLocator
        prefixProvisioner = dependencies.prefixProvisioner
        installerRunner = dependencies.installerRunner
        recipeInstaller = dependencies.recipeInstaller
        programLauncher = dependencies.programLauncher
        processTerminator = dependencies.processTerminator
        fileRevealer = dependencies.fileRevealer
        recipes = dependencies.recipeCatalog.loadRecipes()
    }

    var selectedBottle: Bottle? {
        bottles.first { $0.id == selectedBottleID }
    }

    var isBusy: Bool {
        activityMessage != nil
    }

    func refresh() {
        isWineRuntimeAvailable = wineRuntimeLocator.locateWineRuntime() != nil
        reloadBottles(selecting: nil)
    }

    func createBottle(named requestedName: String, windowsVersion: WindowsVersion) async {
        let bottleName = requestedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bottleName.isEmpty else {
            presentedNotice = .failure(CellarError.bottleNameMissing)
            return
        }
        let newBottle = Bottle(name: bottleName, windowsVersion: windowsVersion)
        await performActivity("Creating \(bottleName)…") {
            try self.bottleStore.save(newBottle)
            try await self.prefixProvisioner.provisionPrefix(for: newBottle)
        }
        reloadBottles(selecting: newBottle.id)
    }

    func install(_ recipe: InstallationRecipe, from installerURL: URL, intoBottleNamed requestedName: String) async {
        let bottleName = requestedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bottleName.isEmpty else {
            presentedNotice = .failure(CellarError.bottleNameMissing)
            return
        }
        let request = InstallationRequest(recipe: recipe, installerURL: installerURL, bottleName: bottleName)
        var installedBottleID: Bottle.ID?
        await performActivity(InstallationStage.creatingBottle.statusMessage) {
            let report = try await self.recipeInstaller.install(request) { stage in
                Task { @MainActor in
                    self.updateActivityMessage(stage.statusMessage)
                }
            }
            installedBottleID = report.bottle.id
            if !report.failedComponents.isEmpty {
                self.presentedNotice = .componentsSkipped(
                    report.failedComponents,
                    logFile: self.layout.logFile(for: report.bottle.id)
                )
            }
        }
        reloadBottles(selecting: installedBottleID)
    }

    func runInstaller(at installerURL: URL, in bottle: Bottle) async {
        await performActivity("Running \(installerURL.lastPathComponent)…") {
            try await self.installerRunner.runInstaller(at: installerURL, in: bottle)
        }
    }

    func launch(_ program: BottleProgram, in bottle: Bottle) {
        do {
            try programLauncher.launch(program, in: bottle, opening: nil)
        } catch {
            presentedNotice = .failure(error)
        }
    }

    func addProgram(at executableURL: URL, to bottle: Bottle) {
        let windowsPath = layout.pathConverter(for: bottle.id).windowsPath(for: executableURL)
        let program = BottleProgram(
            displayName: executableURL.deletingPathExtension().lastPathComponent,
            windowsPath: windowsPath
        )
        updateBottle(withID: bottle.id) { $0.addingProgram(program) }
    }

    func removeProgram(_ program: BottleProgram, from bottle: Bottle) {
        updateBottle(withID: bottle.id) { $0.removingProgram(withID: program.id) }
    }

    func stopAllPrograms(in bottle: Bottle) async {
        await performActivity("Stopping programs in \(bottle.name)…") {
            try await self.processTerminator.terminateAllProcesses(in: bottle)
        }
    }

    func deleteBottle(_ bottle: Bottle) async {
        await performActivity("Moving \(bottle.name) to the Trash…") {
            try? await self.processTerminator.terminateAllProcesses(in: bottle)
            try self.bottleStore.remove(bottle)
        }
        reloadBottles(selecting: nil)
    }

    func driveCDirectory(of bottle: Bottle) -> URL {
        layout.driveCDirectory(for: bottle.id)
    }

    func openDriveC(of bottle: Bottle) {
        fileRevealer.open(layout.driveCDirectory(for: bottle.id))
    }

    func revealLog(of bottle: Bottle) {
        let logFile = layout.logFile(for: bottle.id)
        let revealedURL = FileManager.default.fileExists(atPath: logFile.path)
            ? logFile
            : layout.bottleDirectory(for: bottle.id)
        fileRevealer.revealInFinder(revealedURL)
    }

    func dismissNotice() {
        presentedNotice = nil
    }

    private func performActivity(_ initialMessage: String, operation: () async throws -> Void) async {
        activityMessage = initialMessage
        do {
            try await operation()
        } catch {
            presentedNotice = .failure(error)
        }
        activityMessage = nil
    }

    private func updateActivityMessage(_ message: String) {
        guard activityMessage != nil else { return }
        activityMessage = message
    }

    private func updateBottle(withID bottleID: Bottle.ID, transform: (Bottle) -> Bottle) {
        guard let currentBottle = bottles.first(where: { $0.id == bottleID }) else {
            presentedNotice = .failure(CellarError.bottleNotFound)
            return
        }
        let updatedBottle = transform(currentBottle)
        do {
            try bottleStore.save(updatedBottle)
            bottles = bottles.map { $0.id == bottleID ? updatedBottle : $0 }
        } catch {
            presentedNotice = .failure(error)
        }
    }

    private func reloadBottles(selecting preferredBottleID: Bottle.ID?) {
        do {
            bottles = try bottleStore.loadBottles()
        } catch {
            presentedNotice = .failure(error)
            return
        }
        let requestedSelection = preferredBottleID ?? selectedBottleID
        selectedBottleID = bottles.contains { $0.id == requestedSelection } ? requestedSelection : bottles.first?.id
    }
}
