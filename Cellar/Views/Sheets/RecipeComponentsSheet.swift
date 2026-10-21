import SwiftUI

struct RecipeComponentsSheet: View {
    let bottle: Bottle

    @Environment(BottleLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRecipeID: InstallationRecipe.ID?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Install Recipe Components")
                .font(.title2.weight(.semibold))
            if library.recipes.isEmpty {
                Text("No recipes are available.")
                    .foregroundStyle(.secondary)
            } else {
                componentsForm
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
        .onAppear(perform: selectInitialRecipe)
    }

    private var componentsForm: some View {
        Form {
            Picker("Software", selection: $selectedRecipeID) {
                ForEach(library.recipes) { recipe in
                    Text(recipe.displayName).tag(Optional(recipe.id))
                }
            }
            if let recipe = selectedRecipe {
                LabeledContent("Components", value: componentsDescription(of: recipe))
                LabeledContent("Library overrides", value: libraryOverridesDescription(of: recipe))
                Text("No installer runs. Copy the program into this bottle's C: drive; Cellar opens \(recipe.displayName) documents with it.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
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

    private var canStartInstallation: Bool {
        selectedRecipe != nil && library.isWineRuntimeAvailable && !library.isBusy
    }

    private func componentsDescription(of recipe: InstallationRecipe) -> String {
        recipe.winetricksVerbs.isEmpty ? "None" : recipe.winetricksVerbs.joined(separator: ", ")
    }

    private func libraryOverridesDescription(of recipe: InstallationRecipe) -> String {
        guard !recipe.dllOverrides.isEmpty else { return "None" }
        return recipe.dllOverrides
            .sorted { $0.key < $1.key }
            .map { "\($0.key) = \($0.value)" }
            .joined(separator: ", ")
    }

    private func selectInitialRecipe() {
        guard selectedRecipeID == nil else { return }
        selectedRecipeID = library.recipes.first { $0.id == bottle.recipeID }?.id ?? library.recipes.first?.id
    }

    private func startInstallation() {
        guard let recipe = selectedRecipe else { return }
        let targetBottle = bottle
        dismiss()
        Task { await library.applyComponents(of: recipe, to: targetBottle) }
    }
}
