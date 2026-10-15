import Foundation

struct WineInvocationFactory {
    private static let fallbackSearchPath = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"]

    private let runtimeLocator: WineRuntimeLocating
    private let winetricksLocator: WinetricksLocating
    private let layout: BottleDirectoryLayout

    init(runtimeLocator: WineRuntimeLocating, winetricksLocator: WinetricksLocating, layout: BottleDirectoryLayout) {
        self.runtimeLocator = runtimeLocator
        self.winetricksLocator = winetricksLocator
        self.layout = layout
    }

    func wineInvocation(
        arguments: [String],
        displayName: String,
        workingDirectory: URL? = nil,
        for bottle: Bottle
    ) throws -> CommandInvocation {
        let runtime = try requireRuntime()
        return CommandInvocation(
            executable: runtime.launcherExecutable,
            arguments: arguments,
            environment: environment(for: bottle, runtime: runtime),
            workingDirectory: workingDirectory,
            logFile: layout.logFile(for: bottle.id),
            displayName: displayName
        )
    }

    func wineserverInvocation(arguments: [String], displayName: String, for bottle: Bottle) throws -> CommandInvocation {
        let runtime = try requireRuntime()
        return CommandInvocation(
            executable: runtime.wineserverExecutable,
            arguments: arguments,
            environment: environment(for: bottle, runtime: runtime),
            logFile: layout.logFile(for: bottle.id),
            displayName: displayName
        )
    }

    func winetricksInvocation(verbs: [String], for bottle: Bottle) throws -> CommandInvocation {
        let runtime = try requireRuntime()
        guard let winetricksExecutable = winetricksLocator.locateWinetricks() else {
            throw CellarError.winetricksNotFound
        }
        return CommandInvocation(
            executable: winetricksExecutable,
            arguments: ["--unattended"] + verbs,
            environment: environment(for: bottle, runtime: runtime),
            logFile: layout.logFile(for: bottle.id),
            displayName: "Winetricks \(verbs.joined(separator: " "))"
        )
    }

    func pathConverter(for bottle: Bottle) -> WindowsPathConverter {
        layout.pathConverter(for: bottle.id)
    }

    private func requireRuntime() throws -> WineRuntime {
        guard let runtime = runtimeLocator.locateWineRuntime() else {
            throw CellarError.wineRuntimeNotFound
        }
        return runtime
    }

    private func environment(for bottle: Bottle, runtime: WineRuntime) -> [String: String] {
        let searchPath = ([runtime.binDirectory.path] + Self.fallbackSearchPath).joined(separator: ":")
        return [
            "WINEPREFIX": layout.bottleDirectory(for: bottle.id).path,
            "WINE": runtime.genericWineExecutable.path,
            "WINESERVER": runtime.wineserverExecutable.path,
            "WINEDEBUG": "-all",
            "PATH": searchPath
        ]
    }
}
