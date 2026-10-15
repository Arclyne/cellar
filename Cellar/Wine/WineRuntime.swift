import Foundation

struct WineRuntime: Equatable {
    let binDirectory: URL
    let launcherExecutable: URL

    var genericWineExecutable: URL {
        binDirectory.appendingPathComponent("wine")
    }

    var wineserverExecutable: URL {
        binDirectory.appendingPathComponent("wineserver")
    }
}
