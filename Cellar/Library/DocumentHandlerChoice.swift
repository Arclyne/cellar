import Foundation

struct DocumentHandlerChoice: Identifiable {
    let id = UUID()
    let documentURL: URL
    let handlers: [DocumentHandler]
}
