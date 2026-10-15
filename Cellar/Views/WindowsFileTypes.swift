import UniformTypeIdentifiers

enum WindowsFileTypes {
    static let installers = contentTypes(forFileExtensions: ["msi", "exe"])
    static let executables = contentTypes(forFileExtensions: ["exe"])

    static func contentTypes(forFileExtensions fileExtensions: [String]) -> [UTType] {
        let resolvedContentTypes = fileExtensions.compactMap { UTType(filenameExtension: $0) }
        return resolvedContentTypes.isEmpty ? [.item] : resolvedContentTypes
    }
}
