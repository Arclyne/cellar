import SwiftUI
import UniformTypeIdentifiers

struct InstallSoftwareSheet: View {
    @Environment(BottleLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRecipeID: InstallationRecipe.ID?
    @State private var bottleName = ""
    @State private var installerURL: URL?
    @State private var isSelectingInstaller = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Install Software")
                .font(.title2.weight(.semibold))
            if library.recipes.isEmpty {
                Text("No recipes are available.")
                    .foregroundStyle(.secondary)
            } else {
                installationForm
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("Install") {
                    startInstallation()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canStartInstallation)
            }
        }
        .padding(20)
        .frame(width: 500)
        .fileImporter(
            isPresented: $isSelectingInstaller,
            allowedContentTypes: installerContentTypes
        ) { selection in
            if case .success(let selectedURL) = selection {
                installerURL = selectedURL
            }
        }
        .onAppear(perform: selectFirstRecipeIfNeeded)
        .onChange(of: selectedRecipeID) { _, _ in
            bottleName = selectedRecipe?.displayName ?? bottleName
        }
    }

    private var installationForm: some View {
        Form {
            Picker("Software", selection: $selectedRecipeID) {
                ForEach(library.recipes) { recipe in
                    Text(recipe.displayName).tag(Optional(recipe.id))
                }
            }
            if let recipe = selectedRecipe {
                Text(recipe.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            TextField("Bottle name", text: $bottleName)
            LabeledContent("Installer") {
                HStack {
                    Text(installerURL?.lastPathComponent ?? "None selected")
                        .foregroundStyle(installerURL == nil ? Color.secondary : Color.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button("Choose…") {
                        isSelectingInstaller = true
                    }
                }
            }
            if !library.isWineRuntimeAvailable {
                Label("Install Wine before continuing.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        }
        .formStyle(.grouped)
    }

    private var selectedRecipe: InstallationRecipe? {
        library.recipes.first { $0.id == selectedRecipeID }
    }

    private var installerContentTypes: [UTType] {
        WindowsFileTypes.contentTypes(forFileExtensions: selectedRecipe?.installerFileExtensions ?? ["msi", "exe"])
    }

    private var canStartInstallation: Bool {
        selectedRecipe != nil
            && installerURL != nil
            && library.isWineRuntimeAvailable
            && !library.isBusy
            && !bottleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func selectFirstRecipeIfNeeded() {
        guard selectedRecipeID == nil, let firstRecipe = library.recipes.first else { return }
        selectedRecipeID = firstRecipe.id
        bottleName = firstRecipe.displayName
    }

    private func startInstallation() {
        guard let recipe = selectedRecipe, let chosenInstallerURL = installerURL else { return }
        let requestedBottleName = bottleName
        dismiss()
        Task {
            await library.install(recipe, from: chosenInstallerURL, intoBottleNamed: requestedBottleName)
        }
    }
}
