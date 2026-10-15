import AppKit

protocol FileRevealing {
    func revealInFinder(_ url: URL)
    func open(_ url: URL)
}

struct WorkspaceFileRevealer: FileRevealing {
    func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
