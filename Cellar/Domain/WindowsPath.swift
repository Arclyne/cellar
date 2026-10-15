import Foundation

enum WindowsPath {
    static func fileName(of windowsPath: String) -> String {
        windowsPath.split(separator: "\\").last.map(String.init) ?? windowsPath
    }
}
