import Foundation

protocol ProgramIconProviding {
    func iconData(forExecutableAt executableURL: URL) async -> Data?
}

final class PortableExecutableIconProvider: ProgramIconProviding {
    private let extractedIcons = NSCache<NSURL, NSData>()

    func iconData(forExecutableAt executableURL: URL) async -> Data? {
        if let cachedIcon = extractedIcons.object(forKey: executableURL as NSURL) {
            return cachedIcon as Data
        }
        let extractedIcon = await Task.detached(priority: .utility) { () -> Data? in
            guard let imageData = try? Data(contentsOf: executableURL, options: .alwaysMapped) else {
                return nil
            }
            return PortableExecutableIconReader(imageData: imageData).largestIconFileData()
        }.value
        if let extractedIcon {
            extractedIcons.setObject(extractedIcon as NSData, forKey: executableURL as NSURL)
        }
        return extractedIcon
    }
}
