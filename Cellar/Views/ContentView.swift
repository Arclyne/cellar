import SwiftUI

struct ContentView: View {
    @Environment(BottleLibrary.self) private var library
    @State private var isPresentingNewBottleSheet = false
    @State private var isPresentingInstallSheet = false

    var body: some View {
        NavigationSplitView {
            BottleSidebar()
                .navigationSplitViewColumnWidth(min: 200, ideal: 230)
        } detail: {
            if let selectedBottle = library.selectedBottle {
                BottleDetailView(bottle: selectedBottle)
            } else {
                WelcomeView(
                    onInstallSoftware: { isPresentingInstallSheet = true },
                    onCreateBottle: { isPresentingNewBottleSheet = true }
                )
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    isPresentingInstallSheet = true
                } label: {
                    Label("Install Software", systemImage: "square.and.arrow.down")
                }
                .help("Install Windows software with a recipe")
                .disabled(library.isBusy)

                Button {
                    isPresentingNewBottleSheet = true
                } label: {
                    Label("New Bottle", systemImage: "plus")
                }
                .help("Create an empty bottle")
                .disabled(library.isBusy)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            LibraryStatusBar()
        }
        .sheet(isPresented: $isPresentingNewBottleSheet) {
            NewBottleSheet()
                .environment(library)
        }
        .sheet(isPresented: $isPresentingInstallSheet) {
            InstallSoftwareSheet()
                .environment(library)
        }
        .alert(
            library.presentedNotice?.title ?? "",
            isPresented: isPresentingNotice,
            presenting: library.presentedNotice
        ) { _ in
            Button("OK", role: .cancel) {
                library.dismissNotice()
            }
        } message: { notice in
            Text(notice.message)
        }
        .task {
            library.refresh()
        }
    }

    private var isPresentingNotice: Binding<Bool> {
        Binding(
            get: { library.presentedNotice != nil },
            set: { isPresented in
                if !isPresented {
                    library.dismissNotice()
                }
            }
        )
    }
}
