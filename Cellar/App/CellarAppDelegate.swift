import AppKit

@MainActor
final class CellarAppDelegate: NSObject, NSApplicationDelegate {
    private var documentURLsAwaitingOpener: [URL] = []
    private var documentOpener: (([URL]) -> Void)?

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let documentOpener else {
            documentURLsAwaitingOpener.append(contentsOf: urls)
            return
        }
        documentOpener(urls)
    }

    func connectDocumentOpener(_ opener: @escaping ([URL]) -> Void) {
        documentOpener = opener
        let queuedDocumentURLs = documentURLsAwaitingOpener
        documentURLsAwaitingOpener.removeAll()
        if !queuedDocumentURLs.isEmpty {
            opener(queuedDocumentURLs)
        }
    }
}
