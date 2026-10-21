import Foundation

struct DocumentHandler: Identifiable {
    let bottle: Bottle
    let program: BottleProgram

    var id: BottleProgram.ID { program.id }
}

protocol DocumentHandlerFinding {
    func handlers(forDocumentAt documentURL: URL, among bottles: [Bottle]) -> [DocumentHandler]
}

struct RecipeDocumentHandlerFinder: DocumentHandlerFinding {
    let recipes: [InstallationRecipe]

    func handlers(forDocumentAt documentURL: URL, among bottles: [Bottle]) -> [DocumentHandler] {
        let openingRecipes = recipes.filter { $0.opensDocuments(withExtension: documentURL.pathExtension) }
        guard !openingRecipes.isEmpty else { return [] }

        return bottles.compactMap { bottle in
            // A bottle installed from a known recipe only opens that recipe's documents, so
            // Enterprise Architect 15 and 17 bottles never take each other's projects.
            let candidateRecipes = recipe(for: bottle).map { [$0] } ?? openingRecipes
            let handlingProgram = bottle.programs.first { program in
                candidateRecipes.contains { recipe in
                    recipe.opensDocuments(withExtension: documentURL.pathExtension)
                        && recipe.declaresExecutable(named: program.executableFileName)
                }
            }
            return handlingProgram.map { DocumentHandler(bottle: bottle, program: $0) }
        }
    }

    private func recipe(for bottle: Bottle) -> InstallationRecipe? {
        if let recipeID = bottle.recipeID {
            return recipes.first { $0.id == recipeID }
        }
        // Bottles created before Cellar recorded their recipe are matched by where their programs live.
        return recipes.first { recipe in
            bottle.programs.contains { recipe.declaresProgram(at: $0.windowsPath) }
        }
    }
}
