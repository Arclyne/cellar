import Foundation

struct DocumentHandler {
    let bottle: Bottle
    let program: BottleProgram
}

protocol DocumentHandlerFinding {
    func handler(forDocumentAt documentURL: URL, among bottles: [Bottle]) -> DocumentHandler?
}

struct RecipeDocumentHandlerFinder: DocumentHandlerFinding {
    let recipes: [InstallationRecipe]

    func handler(forDocumentAt documentURL: URL, among bottles: [Bottle]) -> DocumentHandler? {
        let handlingExecutableNames = Set(
            recipes
                .filter { $0.opensDocuments(withExtension: documentURL.pathExtension) }
                .flatMap { $0.programCandidates }
                .map { $0.executableFileName.lowercased() }
        )
        guard !handlingExecutableNames.isEmpty else { return nil }

        for bottle in bottles {
            let handlingProgram = bottle.programs.first { program in
                handlingExecutableNames.contains(program.executableFileName.lowercased())
            }
            if let handlingProgram {
                return DocumentHandler(bottle: bottle, program: handlingProgram)
            }
        }
        return nil
    }
}
