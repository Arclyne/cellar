import Foundation

protocol ProgramLaunching {
    func launch(
        _ program: BottleProgram,
        in bottle: Bottle,
        opening documentURL: URL?,
        onExit: @escaping @Sendable (ProcessExit) -> Void
    ) throws -> Int32
}

struct WineProgramLauncher: ProgramLaunching {
    let invocationFactory: WineInvocationFactory
    let commandRunner: CommandRunning

    func launch(
        _ program: BottleProgram,
        in bottle: Bottle,
        opening documentURL: URL?,
        onExit: @escaping @Sendable (ProcessExit) -> Void
    ) throws -> Int32 {
        let pathConverter = invocationFactory.pathConverter(for: bottle)
        let documentArguments = documentURL.map { [pathConverter.windowsPath(for: $0)] } ?? []
        let programDirectory = pathConverter.unixURL(forWindowsPath: program.windowsPath)?.deletingLastPathComponent()
        let programLaunch = try invocationFactory.wineInvocation(
            arguments: [program.windowsPath] + documentArguments,
            displayName: program.displayName,
            workingDirectory: programDirectory,
            for: bottle
        )
        return try commandRunner.launch(programLaunch, onExit: onExit)
    }
}
