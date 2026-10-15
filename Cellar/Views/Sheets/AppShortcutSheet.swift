import SwiftUI

struct AppShortcutSheet: View {
    let program: BottleProgram
    let bottle: Bottle

    @Environment(BottleLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var shortcutName: String

    init(program: BottleProgram, bottle: Bottle) {
        self.program = program
        self.bottle = bottle
        _shortcutName = State(initialValue: program.displayName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create App Shortcut")
                .font(.title2.weight(.semibold))
            Text("Adds an app to your Applications folder that opens \(program.displayName) through Cellar.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Form {
                TextField("Name", text: $shortcutName, prompt: Text("Enterprise Architect"))
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("Create") {
                    createShortcut()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(trimmedShortcutName.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 440)
    }

    private var trimmedShortcutName: String {
        shortcutName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func createShortcut() {
        let requestedName = trimmedShortcutName
        dismiss()
        Task {
            await library.createAppShortcut(named: requestedName, for: program, in: bottle)
        }
    }
}
