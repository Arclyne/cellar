import SwiftUI

struct BottleSidebar: View {
    @Environment(BottleLibrary.self) private var library
    @State private var bottlePendingDeletion: Bottle?

    var body: some View {
        @Bindable var library = library
        List(selection: $library.selectedBottleID) {
            Section("Bottles") {
                ForEach(library.bottles) { bottle in
                    BottleRow(bottle: bottle)
                        .tag(bottle.id)
                        .contextMenu {
                            Button("Open C: Drive") {
                                library.openDriveC(of: bottle)
                            }
                            Button("Show Log in Finder") {
                                library.revealLog(of: bottle)
                            }
                            Divider()
                            Button("Move to Trash…", role: .destructive) {
                                bottlePendingDeletion = bottle
                            }
                        }
                }
            }
        }
        .listStyle(.sidebar)
        .overlay {
            if library.bottles.isEmpty {
                Text("No bottles yet")
                    .foregroundStyle(.secondary)
            }
        }
        .confirmationDialog(
            "Move “\(bottlePendingDeletion?.name ?? "")” to the Trash?",
            isPresented: isConfirmingDeletion,
            presenting: bottlePendingDeletion
        ) { bottle in
            Button("Move to Trash", role: .destructive) {
                Task { await library.deleteBottle(bottle) }
            }
        } message: { _ in
            Text("Every program installed in this bottle goes with it.")
        }
    }

    private var isConfirmingDeletion: Binding<Bool> {
        Binding(
            get: { bottlePendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    bottlePendingDeletion = nil
                }
            }
        )
    }
}

struct BottleRow: View {
    let bottle: Bottle

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(bottle.name)
                Text(bottle.windowsVersion.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "wineglass")
        }
    }
}
