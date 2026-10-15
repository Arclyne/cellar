import Foundation

struct LibraryNotice: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String

    static func failure(_ error: Error) -> LibraryNotice {
        LibraryNotice(title: "Something went wrong", message: error.localizedDescription)
    }

    static func componentsSkipped(_ failedComponents: [String], logFile: URL) -> LibraryNotice {
        LibraryNotice(
            title: "Installed with warnings",
            message: "These components could not be installed: \(failedComponents.joined(separator: ", ")). Details are in \(logFile.path)."
        )
    }
}
