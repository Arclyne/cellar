import Foundation
import Observation

@Observable
@MainActor
final class BottleLibrary {
    private static let windowWatchInterval: Duration = .milliseconds(500)
    private static let windowWatchAttempts = 90

    private(set) var bottles: [Bottle] = []
    var selectedBottleID: Bottle.ID?
    private(set) var activityMessage: String?
    private(set) var presentedNotice: LibraryNotice?
    private(set) var isWineRuntimeAvailable = false
    private(set) var programActivities: [BottleProgram.ID: ProgramActivity] = [:]
    let recipes: [InstallationRecipe]

    private let layout: BottleDirectoryLayout
    private let bottleStore: BottleStoring
    private let wineRuntimeLocator: WineRuntimeLocating
    private let prefixProvisioner: PrefixProvisioning
    private let installerRunner: InstallerRunning
    private let recipeInstaller: RecipeInstalling
    private let programLauncher: ProgramLaunching
    private let processTerminator: BottleProcessTerminating
    private let documentHandlerFinder: DocumentHandlerFinding
    private let programIconProvider: ProgramIconProviding
    private let programWindowLocator: ProgramWindowLocating
    private let appShortcutCreator: AppShortcutCreating
    private let fileRevealer: FileRevealing
    private var launchedProcessIdentifiers: [BottleProgram.ID: Int32] = [:]

    init(dependencies: LibraryDependencies) {
        layout = dependencies.layout
        bottleStore = dependencies.bottleStore
        wineRuntimeLocator = dependencies.wineRuntimeLocator
        prefixProvisioner = dependencies.prefixProvisioner
        installerRunner = dependencies.installerRunner
        recipeInstaller = dependencies.recipeInstaller
        programLauncher = dependencies.programLauncher
        processTerminator = dependencies.processTerminator
        documentHandlerFinder = dependencies.documentHandlerFinder
        programIconProvider = dependencies.programIconProvider
        programWindowLocator = dependencies.programWindowLocator
        appShortcutCreator = dependencies.appShortcutCreator
        fileRevealer = dependencies.fileRevealer
        recipes = dependencies.recipes
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
            if report.bottle.programs.isEmpty {
                self.presentedNotice = .noProgramsFound(inBottleNamed: report.bottle.name)
            } else if !report.failedComponents.isEmpty {
                self.presentedNotice = .componentsSkipped(
                    report.failedComponents,
                    logFile: self.layout.logFile(for: report.bottle.id)
                )
            }
        }
        reloadBottles(selecting: installedBottleID)
    }

    func applyComponents(of recipe: InstallationRecipe, to bottle: Bottle) async {
        await performActivity("Preparing \(bottle.name)…") {
            let report = try await self.recipeInstaller.applyComponents(of: recipe, to: bottle) { stage in
                Task { @MainActor in
                    self.updateActivityMessage(stage.statusMessage)
                }
            }
            if !report.failedComponents.isEmpty {
                self.presentedNotice = .componentsSkipped(
                    report.failedComponents,
                    logFile: self.layout.logFile(for: report.bottle.id)
                )
            }
        }
        reloadBottles(selecting: bottle.id)
    }

    func runInstaller(at installerURL: URL, in bottle: Bottle) async {
        await performActivity("Running \(installerURL.lastPathComponent)…") {
            try await self.installerRunner.runInstaller(at: installerURL, in: bottle)
        }
    }

    func launch(_ program: BottleProgram, in bottle: Bottle, opening documentURL: URL? = nil) {
        if documentURL == nil, let currentActivity = programActivities[program.id] {
            if currentActivity == .running, let processIdentifier = launchedProcessIdentifiers[program.id] {
                programWindowLocator.bringToFront(processIdentifier: processIdentifier)
            }
            return
        }
        do {
            let processIdentifier = try programLauncher.launch(program, in: bottle, opening: documentURL) { processExit in
                Task { @MainActor in
                    self.programDidExit(program, in: bottle, with: processExit)
                }
            }
            launchedProcessIdentifiers[program.id] = processIdentifier
            programActivities[program.id] = .opening
            watchForFirstWindow(of: program, processIdentifier: processIdentifier)
        } catch {
            presentedNotice = .failure(error)
        }
    }

    func activity(of program: BottleProgram) -> ProgramActivity? {
        programActivities[program.id]
    }

    func handleOpenedURLs(_ openedURLs: [URL]) {
        for launchLink in openedURLs.compactMap(ProgramLaunchLink.init(url:)) {
            launchProgram(linkedBy: launchLink)
        }
        let documentURLs = openedURLs.filter(\.isFileURL)
        if !documentURLs.isEmpty {
            openDocuments(documentURLs)
        }
    }

    func createAppShortcut(named shortcutName: String, for program: BottleProgram, in bottle: Bottle) async {
        let programIcon = await iconData(for: program, in: bottle)
        do {
            let shortcutURL = try appShortcutCreator.createShortcut(
                named: shortcutName,
                launching: ProgramLaunchLink(bottleID: bottle.id, programID: program.id),
                iconData: programIcon
            )
            fileRevealer.revealInFinder(shortcutURL)
        } catch {
            presentedNotice = .failure(error)
        }
    }

    func openDocuments(_ documentURLs: [URL]) {
        if bottles.isEmpty {
            refresh()
        }
        for documentURL in documentURLs {
            guard let documentHandler = documentHandlerFinder.handler(forDocumentAt: documentURL, among: bottles) else {
                presentedNotice = .noHandler(forDocumentNamed: documentURL.lastPathComponent)
                continue
            }
            selectedBottleID = documentHandler.bottle.id
            launch(documentHandler.program, in: documentHandler.bottle, opening: documentURL)
        }
    }

    func iconData(for program: BottleProgram, in bottle: Bottle) async -> Data? {
        guard let executableURL = layout.pathConverter(for: bottle.id).unixURL(forWindowsPath: program.windowsPath) else {
            return nil
        }
        return await programIconProvider.iconData(forExecutableAt: executableURL)
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
        forgetLaunchedPrograms(of: bottle)
        await performActivity("Stopping programs in \(bottle.name)…") {
            try await self.processTerminator.terminateAllProcesses(in: bottle)
        }
    }

    func deleteBottle(_ bottle: Bottle) async {
        forgetLaunchedPrograms(of: bottle)
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

    private func launchProgram(linkedBy launchLink: ProgramLaunchLink) {
        if bottles.isEmpty {
            refresh()
        }
        guard
            let linkedBottle = bottles.first(where: { $0.id == launchLink.bottleID }),
            let linkedProgram = linkedBottle.programs.first(where: { $0.id == launchLink.programID })
        else {
            presentedNotice = .shortcutTargetMissing
            return
        }
        selectedBottleID = linkedBottle.id
        launch(linkedProgram, in: linkedBottle)
    }

    private func watchForFirstWindow(of program: BottleProgram, processIdentifier: Int32) {
        Task { @MainActor in
            for _ in 0..<Self.windowWatchAttempts {
                try? await Task.sleep(for: Self.windowWatchInterval)
                guard self.launchedProcessIdentifiers[program.id] == processIdentifier else { return }
                if self.programWindowLocator.hasOnscreenWindow(ownedBy: processIdentifier) { break }
            }
            guard self.launchedProcessIdentifiers[program.id] == processIdentifier else { return }
            self.programActivities[program.id] = .running
        }
    }

    private func programDidExit(_ program: BottleProgram, in bottle: Bottle, with processExit: ProcessExit) {
        guard launchedProcessIdentifiers[program.id] == processExit.processIdentifier else { return }
        launchedProcessIdentifiers[program.id] = nil
        programActivities[program.id] = nil
        if processExit.exitCode != 0 {
            presentedNotice = .programClosedUnexpectedly(
                program.displayName,
                exitCode: processExit.exitCode,
                logFile: layout.logFile(for: bottle.id)
            )
        }
    }

    private func forgetLaunchedPrograms(of bottle: Bottle) {
        for program in bottle.programs {
            launchedProcessIdentifiers[program.id] = nil
            programActivities[program.id] = nil
        }
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
