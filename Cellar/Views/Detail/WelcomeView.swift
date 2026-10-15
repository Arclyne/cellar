import SwiftUI

struct WelcomeView: View {
    let onInstallSoftware: () -> Void
    let onCreateBottle: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Welcome to Cellar", systemImage: "wineglass")
        } description: {
            Text("Run Windows software on your Mac. Every bottle is its own isolated Windows environment.")
        } actions: {
            Button("Install Software…", action: onInstallSoftware)
                .buttonStyle(.borderedProminent)
            Button("New Empty Bottle…", action: onCreateBottle)
        }
    }
}
