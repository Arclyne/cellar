import AppKit

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
            guard
                let imageData = try? Data(contentsOf: executableURL, options: .alwaysMapped),
                let iconFileData = PortableExecutableIconReader(imageData: imageData).largestIconFileData()
            else {
                return nil
            }
            return IconFileConverter.pngData(fromIconFile: iconFileData)
        }.value
        if let extractedIcon {
            extractedIcons.setObject(extractedIcon as NSData, forKey: executableURL as NSURL)
        }
        return extractedIcon
    }
}

enum IconFileConverter {
    private static let iconFileImageOffset = 22
    private static let pngSignature = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])

    static func pngData(fromIconFile iconFileData: Data) -> Data? {
        guard iconFileData.count > iconFileImageOffset else { return nil }
        let embeddedImage = iconFileData.subdata(in: iconFileImageOffset..<iconFileData.count)
        if embeddedImage.starts(with: pngSignature) {
            return embeddedImage
        }
        guard
            let decodedIcon = NSImage(data: iconFileData),
            let tiffData = decodedIcon.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData)
        else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
}
