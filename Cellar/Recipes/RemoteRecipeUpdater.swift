import Foundation

protocol RecipeUpdating {
    func updateRecipes() async throws
}

struct RecipeIndex: Decodable {
    struct Entry: Decodable {
        let file: String
        let minimumAppVersion: String?
    }

    let recipes: [Entry]
}

struct RemoteRecipeUpdater: RecipeUpdating {
    private let indexURL: URL
    private let downloadedRecipesDirectory: URL
    private let appVersion: String
    private let session: URLSession
    private let fileManager: FileManager

    init(
        indexURL: URL,
        downloadedRecipesDirectory: URL,
        appVersion: String,
        session: URLSession = .shared,
        fileManager: FileManager = .default
    ) {
        self.indexURL = indexURL
        self.downloadedRecipesDirectory = downloadedRecipesDirectory
        self.appVersion = appVersion
        self.session = session
        self.fileManager = fileManager
    }

    func updateRecipes() async throws {
        let decoder = JSONDecoder()
        let index = try decoder.decode(RecipeIndex.self, from: try await download(indexURL))
        var recipeDataByFileName: [String: Data] = [:]
        for entry in index.recipes where isSafeRecipeFileName(entry.file) && isSupportedByThisApp(entry) {
            let recipeURL = indexURL.deletingLastPathComponent().appendingPathComponent(entry.file)
            let recipeData = try await download(recipeURL)
            guard (try? decoder.decode(InstallationRecipe.self, from: recipeData)) != nil else { continue }
            recipeDataByFileName[entry.file] = recipeData
        }
        try replaceDownloadedRecipes(with: recipeDataByFileName)
    }

    private func download(_ url: URL) async throws -> Data {
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    private func isSafeRecipeFileName(_ fileName: String) -> Bool {
        fileName == URL(fileURLWithPath: fileName).lastPathComponent
            && !fileName.hasPrefix(".")
            && fileName.hasSuffix(DirectoryRecipeCatalog.recipeFileSuffix)
    }

    private func isSupportedByThisApp(_ entry: RecipeIndex.Entry) -> Bool {
        guard let minimumAppVersion = entry.minimumAppVersion else { return true }
        return appVersion.compare(minimumAppVersion, options: .numeric) != .orderedAscending
    }

    private func replaceDownloadedRecipes(with recipeDataByFileName: [String: Data]) throws {
        let parentDirectory = downloadedRecipesDirectory.deletingLastPathComponent()
        let stagingDirectory = parentDirectory.appendingPathComponent(
            "\(downloadedRecipesDirectory.lastPathComponent)-\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
        do {
            for (fileName, recipeData) in recipeDataByFileName {
                try recipeData.write(to: stagingDirectory.appendingPathComponent(fileName), options: .atomic)
            }
            if fileManager.fileExists(atPath: downloadedRecipesDirectory.path) {
                _ = try fileManager.replaceItemAt(downloadedRecipesDirectory, withItemAt: stagingDirectory)
            } else {
                try fileManager.moveItem(at: stagingDirectory, to: downloadedRecipesDirectory)
            }
        } catch {
            try? fileManager.removeItem(at: stagingDirectory)
            throw error
        }
    }
}
