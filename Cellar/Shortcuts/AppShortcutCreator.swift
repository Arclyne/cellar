import AppKit

protocol AppShortcutCreating {
    func createShortcut(named shortcutName: String, launching launchLink: ProgramLaunchLink, iconData: Data?) throws -> URL
}

struct ApplicationsFolderShortcutCreator: AppShortcutCreating {
    private static let launcherExecutableName = "launch"
    private static let bundleIdentifierPrefix = "com.arclyne.cellar.shortcut."
    private static let fallbackBundleName = "Windows Program"
    private static let disallowedNameCharacters = CharacterSet(charactersIn: "/:")

    private let fileManager: FileManager
    private let workspace: NSWorkspace
    private let candidateDestinationDirectories: [URL]

    init(fileManager: FileManager = .default, workspace: NSWorkspace = .shared) {
        self.fileManager = fileManager
        self.workspace = workspace
        candidateDestinationDirectories = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        ]
    }

    func createShortcut(named shortcutName: String, launching launchLink: ProgramLaunchLink, iconData: Data?) throws -> URL {
        guard let launchURL = launchLink.url else {
            throw CellarError.shortcutCouldNotBeCreated
        }
        let bundleName = sanitizedBundleName(from: shortcutName)
        let shortcutURL = try writableDestinationDirectory().appendingPathComponent(bundleName + ".app", isDirectory: true)
        if fileManager.fileExists(atPath: shortcutURL.path) {
            try fileManager.removeItem(at: shortcutURL)
        }

        let contentsDirectory = shortcutURL.appendingPathComponent("Contents", isDirectory: true)
        let executableDirectory = contentsDirectory.appendingPathComponent("MacOS", isDirectory: true)
        try fileManager.createDirectory(at: executableDirectory, withIntermediateDirectories: true)
        try writeInfoPropertyList(
            to: contentsDirectory.appendingPathComponent("Info.plist"),
            bundleName: bundleName,
            launchLink: launchLink
        )
        try writeLauncher(
            to: executableDirectory.appendingPathComponent(Self.launcherExecutableName),
            opening: launchURL
        )
        if let iconData, let icon = NSImage(data: iconData) {
            workspace.setIcon(icon, forFile: shortcutURL.path, options: [])
        }
        return shortcutURL
    }

    private func writableDestinationDirectory() throws -> URL {
        for destinationDirectory in candidateDestinationDirectories {
            if !fileManager.fileExists(atPath: destinationDirectory.path) {
                try? fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
            }
            if fileManager.isWritableFile(atPath: destinationDirectory.path) {
                return destinationDirectory
            }
        }
        throw CellarError.shortcutCouldNotBeCreated
    }

    private func writeInfoPropertyList(to propertyListURL: URL, bundleName: String, launchLink: ProgramLaunchLink) throws {
        let bundleProperties: [String: Any] = [
            "CFBundleExecutable": Self.launcherExecutableName,
            "CFBundleIdentifier": Self.bundleIdentifierPrefix + launchLink.programID.uuidString.lowercased(),
            "CFBundleName": bundleName,
            "CFBundleDisplayName": bundleName,
            "CFBundlePackageType": "APPL",
            "CFBundleInfoDictionaryVersion": "6.0",
            "CFBundleShortVersionString": "1.0",
            "CFBundleVersion": "1",
            "LSMinimumSystemVersion": "14.0",
            "LSUIElement": true
        ]
        let propertyListData = try PropertyListSerialization.data(fromPropertyList: bundleProperties, format: .xml, options: 0)
        try propertyListData.write(to: propertyListURL, options: .atomic)
    }

    private func writeLauncher(to launcherURL: URL, opening launchURL: URL) throws {
        let launcherScript = "#!/bin/sh\nexec /usr/bin/open -g \"\(launchURL.absoluteString)\"\n"
        try Data(launcherScript.utf8).write(to: launcherURL, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: launcherURL.path)
    }

    private func sanitizedBundleName(from requestedName: String) -> String {
        let sanitizedName = requestedName
            .components(separatedBy: Self.disallowedNameCharacters)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitizedName.isEmpty ? Self.fallbackBundleName : sanitizedName
    }
}
