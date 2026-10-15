import Foundation

struct WindowsPathConverter {
    private static let driveCRoot = "C:\\"
    private static let hostDriveRoot = "Z:\\"
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
        let uppercasedPath = windowsPath.uppercased()
        if uppercasedPath.hasPrefix(Self.driveCRoot) {
            return appendingComponents(of: windowsPath.dropFirst(Self.driveCRoot.count), to: driveCDirectory)
        }
        if uppercasedPath.hasPrefix(Self.hostDriveRoot) {
            let hostRoot = URL(fileURLWithPath: "/", isDirectory: true)
            return appendingComponents(of: windowsPath.dropFirst(Self.hostDriveRoot.count), to: hostRoot)
        }
        return nil
    }

    private func appendingComponents(of relativeWindowsPath: Substring, to baseURL: URL) -> URL {
        relativeWindowsPath
            .split(separator: "\\")
            .map(String.init)
            .reduce(baseURL) { partialURL, pathComponent in
                partialURL.appendingPathComponent(pathComponent)
            }
    }

    private func backslashed(_ unixPath: String) -> String {
        unixPath.replacingOccurrences(of: "/", with: "\\")
    }
}
