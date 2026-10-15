import SwiftUI

@main
struct CellarApp: App {
    @State private var library = BottleLibrary(dependencies: .live())

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(library)
                .frame(minWidth: 820, minHeight: 520)
        }
        .windowToolbarStyle(.unified)
    }
}
