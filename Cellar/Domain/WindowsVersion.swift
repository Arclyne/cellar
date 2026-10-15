import Foundation

enum WindowsVersion: String, Codable, CaseIterable, Identifiable {
    case windows11 = "win11"
    case windows10 = "win10"
    case windows81 = "win81"
    case windows7 = "win7"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .windows11: "Windows 11"
        case .windows10: "Windows 10"
        case .windows81: "Windows 8.1"
        case .windows7: "Windows 7"
        }
    }
}
