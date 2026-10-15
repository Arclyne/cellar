import Foundation

protocol RecipeCataloging {
    func loadRecipes() -> [InstallationRecipe]
}

struct BundledRecipeCatalog: RecipeCataloging {
    private static let recipeFileSuffix = ".recipe.json"

    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func loadRecipes() -> [InstallationRecipe] {
        let decoder = JSONDecoder()
        let recipeFiles = (bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? [])
            .filter { $0.lastPathComponent.hasSuffix(Self.recipeFileSuffix) }
        return recipeFiles
            .compactMap { try? decoder.decode(InstallationRecipe.self, from: Data(contentsOf: $0)) }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
}
