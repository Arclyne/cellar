import SwiftUI

@main
struct CellarApp: App {
    @NSApplicationDelegateAdaptor(CellarAppDelegate.self) private var appDelegate
    @State private var library = BottleLibrary(dependencies: .live())
    @State private var appUpdater = AppUpdater()

    var body: some Scene {
        Window("Cellar", id: "library") {
            ContentView()
                .environment(library)
                .frame(minWidth: 820, minHeight: 520)
                .onAppear {
                    appDelegate.connectURLHandler { openedURLs in
                        library.handleOpenedURLs(openedURLs)
                    }
                }
        }
        .windowToolbarStyle(.unified)
        .commands {
            CheckForUpdatesCommand(appUpdater: appUpdater)
        }
    }
}
