import AppKit

@MainActor
final class CellarAppDelegate: NSObject, NSApplicationDelegate {
    private var urlsAwaitingHandler: [URL] = []
    private var urlHandler: (([URL]) -> Void)?

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let urlHandler else {
            urlsAwaitingHandler.append(contentsOf: urls)
            return
        }
        urlHandler(urls)
    }

    func connectURLHandler(_ handler: @escaping ([URL]) -> Void) {
        urlHandler = handler
        let queuedURLs = urlsAwaitingHandler
        urlsAwaitingHandler.removeAll()
        if !queuedURLs.isEmpty {
            handler(queuedURLs)
        }
    }
}
