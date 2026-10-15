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

    static func noProgramsFound(inBottleNamed bottleName: String) -> LibraryNotice {
        LibraryNotice(
            title: "Installed, but no program was found",
            message: "Cellar could not find the installed program in “\(bottleName)”. Use Add Program… in the bottle actions to pick its .exe."
        )
    }

    static func programClosedUnexpectedly(_ programName: String, exitCode: Int32, logFile: URL) -> LibraryNotice {
        let windowsExitCode = String(format: "0x%08X", UInt32(bitPattern: exitCode))
        return LibraryNotice(
            title: "\(programName) closed unexpectedly",
            message: "It stopped with exit code \(windowsExitCode). Details are in \(logFile.path)."
        )
    }

    static let shortcutTargetMissing = LibraryNotice(
        title: "This shortcut no longer works",
        message: "The program it opens was removed from Cellar. Create the shortcut again from the program in its bottle."
    )

    static func noHandler(forDocumentNamed documentName: String) -> LibraryNotice {
        LibraryNotice(
            title: "No program can open this file",
            message: "None of your bottles has a program that opens “\(documentName)”."
        )
    }
}
