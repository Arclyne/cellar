import SwiftUI

@main
struct CellarApp: App {
    @NSApplicationDelegateAdaptor(CellarAppDelegate.self) private var appDelegate
    @State private var library = BottleLibrary(dependencies: .live())

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(library)
                .frame(minWidth: 820, minHeight: 520)
                .onAppear {
                    appDelegate.connectDocumentOpener { documentURLs in
                        library.openDocuments(documentURLs)
                    }
                }
        }
        .windowToolbarStyle(.unified)
    }
}
