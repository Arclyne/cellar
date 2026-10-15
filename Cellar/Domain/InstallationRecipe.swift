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
}

struct ProgramCandidate: Codable, Hashable {
    let displayName: String
    let windowsPath: String
}
