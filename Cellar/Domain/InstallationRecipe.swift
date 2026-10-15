import Foundation

struct InstallationRecipe: Identifiable, Codable, Hashable {
    let id: String
    let displayName: String
    let summary: String
    let windowsVersion: WindowsVersion
    let winetricksVerbs: [String]
    let dllOverrides: [String: String]
    let installerFileExtensions: [String]
    let programCandidates: [ProgramCandidate]
    let documentFileExtensions: [String]

    func opensDocuments(withExtension fileExtension: String) -> Bool {
        documentFileExtensions.contains { $0.caseInsensitiveCompare(fileExtension) == .orderedSame }
    }
}

struct ProgramCandidate: Codable, Hashable {
    let displayName: String
    let windowsPath: String

    var executableFileName: String {
        WindowsPath.fileName(of: windowsPath)
    }
}
