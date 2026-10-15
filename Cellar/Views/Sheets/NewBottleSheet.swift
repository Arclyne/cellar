import SwiftUI

struct NewBottleSheet: View {
    @Environment(BottleLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var bottleName = ""
    @State private var windowsVersion = WindowsVersion.windows10

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Bottle")
                .font(.title2.weight(.semibold))
            Form {
                TextField("Name", text: $bottleName, prompt: Text("My Windows Apps"))
                Picker("Windows version", selection: $windowsVersion) {
                    ForEach(WindowsVersion.allCases) { version in
                        Text(version.displayName).tag(version)
                    }
                }
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("Create") {
                    createBottle()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(trimmedBottleName.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private var trimmedBottleName: String {
        bottleName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func createBottle() {
        let requestedName = trimmedBottleName
        let requestedVersion = windowsVersion
        dismiss()
        Task { await library.createBottle(named: requestedName, windowsVersion: requestedVersion) }
    }
}
