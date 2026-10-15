import Foundation

struct LibraryDependencies {
    let layout: BottleDirectoryLayout
    let bottleStore: BottleStoring
    let wineRuntimeLocator: WineRuntimeLocating
    let prefixProvisioner: PrefixProvisioning
    let installerRunner: InstallerRunning
    let recipeInstaller: RecipeInstalling
    let programLauncher: ProgramLaunching
    let processTerminator: BottleProcessTerminating
    let recipes: [InstallationRecipe]
    let documentHandlerFinder: DocumentHandlerFinding
    let programIconProvider: ProgramIconProviding
    let programWindowLocator: ProgramWindowLocating
    let fileRevealer: FileRevealing
}

extension LibraryDependencies {
    static func live(fileManager: FileManager = .default) -> LibraryDependencies {
        let layout = BottleDirectoryLayout.inApplicationSupport(fileManager: fileManager)
        let commandRunner = ProcessCommandRunner(fileManager: fileManager)
        let executor = CheckedCommandExecutor(commandRunner: commandRunner)
        let wineRuntimeLocator = InstalledWineRuntimeLocator(fileManager: fileManager)
        let winetricksLocator = InstalledWinetricksLocator(fileManager: fileManager)
        let invocationFactory = WineInvocationFactory(
            runtimeLocator: wineRuntimeLocator,
            winetricksLocator: winetricksLocator,
            layout: layout
        )
        let bottleStore = FileSystemBottleStore(layout: layout, fileManager: fileManager)
        let prefixProvisioner = WinePrefixProvisioner(invocationFactory: invocationFactory, executor: executor)
        let installerRunner = WineInstallerRunner(invocationFactory: invocationFactory, executor: executor)
        let recipeInstaller = RecipeInstaller(
            bottleStore: bottleStore,
            prefixProvisioner: prefixProvisioner,
            componentInstaller: WinetricksComponentInstaller(
                invocationFactory: invocationFactory,
                winetricksLocator: winetricksLocator,
                executor: executor
            ),
            dllOverrideApplier: WineRegistryDllOverrideApplier(invocationFactory: invocationFactory, executor: executor),
            installerRunner: installerRunner,
            programResolver: DriveCProgramResolver(layout: layout, fileManager: fileManager)
        )
        let recipes = BundledRecipeCatalog().loadRecipes()

        return LibraryDependencies(
            layout: layout,
            bottleStore: bottleStore,
            wineRuntimeLocator: wineRuntimeLocator,
            prefixProvisioner: prefixProvisioner,
            installerRunner: installerRunner,
            recipeInstaller: recipeInstaller,
            programLauncher: WineProgramLauncher(invocationFactory: invocationFactory, commandRunner: commandRunner),
            processTerminator: WineserverProcessTerminator(invocationFactory: invocationFactory, commandRunner: commandRunner),
            recipes: recipes,
            documentHandlerFinder: RecipeDocumentHandlerFinder(recipes: recipes),
            programIconProvider: PortableExecutableIconProvider(),
            programWindowLocator: WindowServerProgramWindowLocator(),
            fileRevealer: WorkspaceFileRevealer()
        )
    }
}
