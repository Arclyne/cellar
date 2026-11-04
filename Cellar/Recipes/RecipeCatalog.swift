import Foundation

protocol RecipeCataloging {
    func loadRecipes() -> [InstallationRecipe]
}

struct DirectoryRecipeCatalog: RecipeCataloging {
    static let recipeFileSuffix = ".recipe.json"

    private let directory: URL?
    private let fileManager: FileManager

    init(directory: URL?, fileManager: FileManager = .default) {
        self.directory = directory
        self.fileManager = fileManager
    }

    static func bundled(in bundle: Bundle = .main) -> DirectoryRecipeCatalog {
        DirectoryRecipeCatalog(directory: bundle.resourceURL)
    }

    func loadRecipes() -> [InstallationRecipe] {
        guard
            let directory,
            let fileURLs = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        else {
            return []
        }
        let decoder = JSONDecoder()
        return fileURLs
            .filter { $0.lastPathComponent.hasSuffix(Self.recipeFileSuffix) }
            .compactMap { try? decoder.decode(InstallationRecipe.self, from: Data(contentsOf: $0)) }
    }
}

struct LayeredRecipeCatalog: RecipeCataloging {
    private let layersByPrecedence: [RecipeCataloging]

    init(layersByPrecedence: [RecipeCataloging]) {
        self.layersByPrecedence = layersByPrecedence
    }

    func loadRecipes() -> [InstallationRecipe] {
        var recipesByID: [InstallationRecipe.ID: InstallationRecipe] = [:]
        for layer in layersByPrecedence.reversed() {
            for recipe in layer.loadRecipes() {
                recipesByID[recipe.id] = recipe
            }
        }
        return recipesByID.values
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
}
