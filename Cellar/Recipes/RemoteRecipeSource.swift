import Foundation

struct RemoteRecipeSource {
    private static let indexURLInfoKey = "CellarRecipeIndexURL"
    private static let fallbackIndexURL = URL(
        string: "https://raw.githubusercontent.com/Arclyne/cellar/main/Cellar/Recipes/Definitions/index.json"
    )!

    let indexURL: URL
    let downloadedRecipesDirectory: URL
    let appVersion: String

    static func live(bundle: Bundle = .main, fileManager: FileManager = .default) -> RemoteRecipeSource {
        let configuredIndexURL = (bundle.object(forInfoDictionaryKey: indexURLInfoKey) as? String)
            .flatMap(URL.init(string:))
        let applicationSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let downloadedRecipesDirectory = applicationSupportDirectory
            .appendingPathComponent("Cellar", isDirectory: true)
            .appendingPathComponent("Recipes", isDirectory: true)
        let appVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        return RemoteRecipeSource(
            indexURL: configuredIndexURL ?? fallbackIndexURL,
            downloadedRecipesDirectory: downloadedRecipesDirectory,
            appVersion: appVersion
        )
    }
}
