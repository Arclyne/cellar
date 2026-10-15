import Foundation

struct WindowsPathConverter {
    private static let driveCRoot = "C:\\"
    private static let hostDriveLetter = "Z:"

    let driveCDirectory: URL

    func windowsPath(for unixURL: URL) -> String {
        let resolvedPath = unixURL.resolvingSymlinksInPath().path
        let driveCPath = driveCDirectory.resolvingSymlinksInPath().path
        guard resolvedPath.hasPrefix(driveCPath + "/") else {
            return Self.hostDriveLetter + backslashed(resolvedPath)
        }
        let pathInsideDriveC = String(resolvedPath.dropFirst(driveCPath.count + 1))
        return Self.driveCRoot + backslashed(pathInsideDriveC)
    }

    func unixURL(forWindowsPath windowsPath: String) -> URL? {
        guard windowsPath.uppercased().hasPrefix(Self.driveCRoot) else { return nil }
        let pathComponents = windowsPath
            .dropFirst(Self.driveCRoot.count)
            .split(separator: "\\")
            .map(String.init)
        return pathComponents.reduce(driveCDirectory) { partialURL, pathComponent in
            partialURL.appendingPathComponent(pathComponent)
        }
    }

    private func backslashed(_ unixPath: String) -> String {
        unixPath.replacingOccurrences(of: "/", with: "\\")
    }
}
