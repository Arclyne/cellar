import Foundation

struct PortableExecutableIconReader {
    private static let dosSignature: UInt16 = 0x5A4D
    private static let portableExecutableSignature: UInt32 = 0x0000_4550
    private static let pe32Magic: UInt16 = 0x10B
    private static let pe32PlusMagic: UInt16 = 0x20B
    private static let resourceDataDirectoryIndex = 2
    private static let iconResourceType: UInt32 = 3
    private static let iconGroupResourceType: UInt32 = 14
    private static let subdirectoryFlag: UInt32 = 0x8000_0000
    private static let iconGroupEntrySize = 14
    private static let sectionHeaderSize = 40
    private static let iconFileHeaderSize = 6
    private static let iconFileEntrySize = 16

    private struct Section {
        let virtualAddress: Int
        let virtualExtent: Int
        let rawDataOffset: Int
    }

    private struct ResourceEntry {
        let numericID: UInt32?
        let target: UInt32

        var pointsToSubdirectory: Bool {
            target & PortableExecutableIconReader.subdirectoryFlag != 0
        }

        var targetOffset: Int {
            Int(target & ~PortableExecutableIconReader.subdirectoryFlag)
        }
    }

    private struct IconGroupMember {
        let entryOffset: Int
        let pixelWidth: Int
        let bitCount: Int
        let iconID: UInt32
    }

    private let imageData: Data

    init(imageData: Data) {
        self.imageData = imageData
    }

    func largestIconFileData() -> Data? {
        guard
            let sections = readSections(),
            let resourceRootOffset = resourceRootOffset(in: sections),
            let iconGroupDirectory = typeDirectory(Self.iconGroupResourceType, resourceRootOffset: resourceRootOffset),
            let iconDirectory = typeDirectory(Self.iconResourceType, resourceRootOffset: resourceRootOffset),
            let iconGroupLeaf = firstLeafOffset(inDirectoryAt: iconGroupDirectory, resourceRootOffset: resourceRootOffset),
            let iconGroupRange = dataRange(ofLeafAt: iconGroupLeaf, sections: sections),
            let largestMember = largestIconGroupMember(inGroupAt: iconGroupRange.lowerBound),
            let iconRange = iconDataRange(
                forIconID: largestMember.iconID,
                iconDirectory: iconDirectory,
                resourceRootOffset: resourceRootOffset,
                sections: sections
            )
        else {
            return nil
        }
        return iconFileData(describedBy: largestMember, imageRange: iconRange)
    }

    private func readSections() -> [Section]? {
        guard
            uint16(at: 0) == Self.dosSignature,
            let headerOffset = uint32(at: 0x3C).map(Int.init),
            uint32(at: headerOffset) == Self.portableExecutableSignature,
            let sectionCount = uint16(at: headerOffset + 6),
            let optionalHeaderSize = uint16(at: headerOffset + 20)
        else {
            return nil
        }
        let sectionTableOffset = headerOffset + 24 + Int(optionalHeaderSize)
        return (0..<Int(sectionCount)).compactMap { sectionIndex in
            let sectionHeaderOffset = sectionTableOffset + sectionIndex * Self.sectionHeaderSize
            guard
                let virtualSize = uint32(at: sectionHeaderOffset + 8),
                let virtualAddress = uint32(at: sectionHeaderOffset + 12),
                let rawDataSize = uint32(at: sectionHeaderOffset + 16),
                let rawDataOffset = uint32(at: sectionHeaderOffset + 20)
            else {
                return nil
            }
            return Section(
                virtualAddress: Int(virtualAddress),
                virtualExtent: Int(max(virtualSize, rawDataSize)),
                rawDataOffset: Int(rawDataOffset)
            )
        }
    }

    private func resourceRootOffset(in sections: [Section]) -> Int? {
        guard
            let headerOffset = uint32(at: 0x3C).map(Int.init),
            let optionalHeaderMagic = uint16(at: headerOffset + 24)
        else {
            return nil
        }
        let optionalHeaderOffset = headerOffset + 24
        let dataDirectoriesOffset: Int
        switch optionalHeaderMagic {
        case Self.pe32Magic:
            dataDirectoriesOffset = optionalHeaderOffset + 96
        case Self.pe32PlusMagic:
            dataDirectoriesOffset = optionalHeaderOffset + 112
        default:
            return nil
        }
        guard
            let resourceVirtualAddress = uint32(at: dataDirectoriesOffset + Self.resourceDataDirectoryIndex * 8),
            resourceVirtualAddress != 0
        else {
            return nil
        }
        return fileOffset(forVirtualAddress: Int(resourceVirtualAddress), sections: sections)
    }

    private func typeDirectory(_ resourceType: UInt32, resourceRootOffset: Int) -> Int? {
        resourceEntries(inDirectoryAt: resourceRootOffset)
            .first { $0.numericID == resourceType && $0.pointsToSubdirectory }
            .map { resourceRootOffset + $0.targetOffset }
    }

    private func firstLeafOffset(inDirectoryAt directoryOffset: Int, resourceRootOffset: Int) -> Int? {
        var currentDirectoryOffset = directoryOffset
        while let firstEntry = resourceEntries(inDirectoryAt: currentDirectoryOffset).first {
            guard firstEntry.pointsToSubdirectory else {
                return resourceRootOffset + firstEntry.targetOffset
            }
            currentDirectoryOffset = resourceRootOffset + firstEntry.targetOffset
        }
        return nil
    }

    private func iconDataRange(
        forIconID iconID: UInt32,
        iconDirectory: Int,
        resourceRootOffset: Int,
        sections: [Section]
    ) -> Range<Int>? {
        guard let iconEntry = resourceEntries(inDirectoryAt: iconDirectory).first(where: { $0.numericID == iconID }) else {
            return nil
        }
        let leafOffset = iconEntry.pointsToSubdirectory
            ? firstLeafOffset(inDirectoryAt: resourceRootOffset + iconEntry.targetOffset, resourceRootOffset: resourceRootOffset)
            : resourceRootOffset + iconEntry.targetOffset
        return leafOffset.flatMap { dataRange(ofLeafAt: $0, sections: sections) }
    }

    private func resourceEntries(inDirectoryAt directoryOffset: Int) -> [ResourceEntry] {
        guard
            let namedEntryCount = uint16(at: directoryOffset + 12),
            let numberedEntryCount = uint16(at: directoryOffset + 14)
        else {
            return []
        }
        let entryCount = Int(namedEntryCount) + Int(numberedEntryCount)
        return (0..<entryCount).compactMap { entryIndex in
            let entryOffset = directoryOffset + 16 + entryIndex * 8
            guard let name = uint32(at: entryOffset), let target = uint32(at: entryOffset + 4) else {
                return nil
            }
            let numericID = name & Self.subdirectoryFlag == 0 ? name : nil
            return ResourceEntry(numericID: numericID, target: target)
        }
    }

    private func dataRange(ofLeafAt leafOffset: Int, sections: [Section]) -> Range<Int>? {
        guard
            let dataVirtualAddress = uint32(at: leafOffset),
            let dataSize = uint32(at: leafOffset + 4),
            let dataOffset = fileOffset(forVirtualAddress: Int(dataVirtualAddress), sections: sections)
        else {
            return nil
        }
        let dataEnd = dataOffset + Int(dataSize)
        guard dataEnd <= imageData.count else { return nil }
        return dataOffset..<dataEnd
    }

    private func largestIconGroupMember(inGroupAt groupOffset: Int) -> IconGroupMember? {
        guard let memberCount = uint16(at: groupOffset + 4) else { return nil }
        let members: [IconGroupMember] = (0..<Int(memberCount)).compactMap { memberIndex in
            let entryOffset = groupOffset + 6 + memberIndex * Self.iconGroupEntrySize
            guard
                let declaredWidth = byte(at: entryOffset),
                let bitCount = uint16(at: entryOffset + 6),
                let iconID = uint16(at: entryOffset + 12)
            else {
                return nil
            }
            return IconGroupMember(
                entryOffset: entryOffset,
                pixelWidth: declaredWidth == 0 ? 256 : Int(declaredWidth),
                bitCount: Int(bitCount),
                iconID: UInt32(iconID)
            )
        }
        return members.max { first, second in
            (first.pixelWidth, first.bitCount) < (second.pixelWidth, second.bitCount)
        }
    }

    private func iconFileData(describedBy member: IconGroupMember, imageRange: Range<Int>) -> Data {
        var iconFile = Data()
        iconFile.append(littleEndianBytes(of: UInt16(0)))
        iconFile.append(littleEndianBytes(of: UInt16(1)))
        iconFile.append(littleEndianBytes(of: UInt16(1)))
        iconFile.append(imageData.subdata(in: member.entryOffset..<(member.entryOffset + 8)))
        iconFile.append(littleEndianBytes(of: UInt32(imageRange.count)))
        iconFile.append(littleEndianBytes(of: UInt32(Self.iconFileHeaderSize + Self.iconFileEntrySize)))
        iconFile.append(imageData.subdata(in: imageRange))
        return iconFile
    }

    private func fileOffset(forVirtualAddress virtualAddress: Int, sections: [Section]) -> Int? {
        sections
            .first { virtualAddress >= $0.virtualAddress && virtualAddress < $0.virtualAddress + $0.virtualExtent }
            .map { virtualAddress - $0.virtualAddress + $0.rawDataOffset }
    }

    private func byte(at offset: Int) -> UInt8? {
        guard offset >= 0, offset < imageData.count else { return nil }
        return imageData[imageData.startIndex + offset]
    }

    private func uint16(at offset: Int) -> UInt16? {
        guard offset >= 0, offset + 2 <= imageData.count else { return nil }
        return imageData.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt16.self) }.littleEndian
    }

    private func uint32(at offset: Int) -> UInt32? {
        guard offset >= 0, offset + 4 <= imageData.count else { return nil }
        return imageData.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self) }.littleEndian
    }

    private func littleEndianBytes<Integer: FixedWidthInteger>(of value: Integer) -> Data {
        withUnsafeBytes(of: value.littleEndian) { Data($0) }
    }
}
