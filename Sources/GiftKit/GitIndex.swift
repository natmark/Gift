//
//  GitIndex.swift
//  Commandant
//
//  Created by AtsuyaSato on 2019/05/04.
//

import Foundation
/*
   | 0           | 4            | 8           | C              |
   |-------------|--------------|-------------|----------------|
 0 | DIRC        | Version      | File count  | ctime       ...| 0
   | ...         | mtime                      | device         |
 2 | inode       | mode         | UID         | GID            | 2
   | File size   | Entry SHA-1                              ...|
 4 | ...                        | Flags       | Index SHA-1 ...| 4
   | ...                                                       |
 */

struct CacheEntry {
    var createdAt: Date
    var caretedAtNanosecond: Int
    var updatedAt: Date
    var updatedAtNanosecond: Int
    var deviceID: Int
    var inode: Int
    var mode: String
    var uid: Int
    var gid: Int
    var size: UInt64
    var sha: String
    var assumeValidFlag: Bool
    var extendedFlag: Bool
    var stageFlag: Int
    var nameLength: Int
    var pathName: String
}

struct CacheTree {
    var entryCount: Int
    var subtreeCount: Int
    var pathName: String
    var sha: String?
}

struct GitIndex {
    var headerVersion: Int?
    var cacheEntries = [CacheEntry]()
    var cacheTrees = [CacheTree]()
    var indexURL: URL

    init(from indexURL: URL) throws {
        self.indexURL = indexURL
        if !indexURL.isExist {
            return
        }

        let fileData = try Data(contentsOf: indexURL, options: [])
        let dataBytes = [UInt8](fileData)

        guard let signature = String(bytes: dataBytes[0..<4], encoding: .ascii) else {
            throw GiftKitError.indexFileFormatError(message: "binary read error.")
        }
        if signature != "DIRC" {
            throw GiftKitError.indexFileFormatError(message: "binary read error.")
        }

        guard let version = Int(dataBytes[4..<8].map{String(format:"%02X", $0)}.joined(), radix: 16) else {
            throw GiftKitError.indexFileFormatError(message: "binary read error.")
        }
        headerVersion = version

        guard let entrySize = Int(dataBytes[8..<12].map{String(format:"%02X", $0)}.joined(), radix: 16) else {
            throw GiftKitError.indexFileFormatError(message: "binary read error.")
        }

        if dataBytes.count < 32 {
            throw GiftKitError.indexFileFormatError(message: "data is too short.")
        }

        let hashedData = Data(bytes: Array(dataBytes.dropLast(20))).sha1()
        let checksum = Array(dataBytes.suffix(20)).map { String(format:"%02X", $0) }.joined().lowercased()

        if hashedData != checksum {
            throw GiftKitError.indexFileFormatError(message: "checksum mismatch.")
        }

        var currentIndex = 12
        var size = entrySize
        let endIndex = dataBytes.count - 20

        while currentIndex < endIndex {
            if size > 0 {
                currentIndex = try parseEntry(dataBytes: dataBytes, index: currentIndex)
                size -= 1
            } else {
                currentIndex = try parseExtension(dataBytes: dataBytes, index: currentIndex)
            }
        }
    }

    func write() throws {
        var dataBytes = [UInt8]()
        dataBytes += [0x44, 0x49, 0x52, 0x43] // DIRC
        dataBytes += [0x00, 0x00, 0x00, 0x02] // Version 2
        dataBytes += hexaToBytes(hexString: String(format: "%08X", self.cacheEntries.count)) // Entry Size
        var entryBegin = 0

        // Entries
        for cacheEntry in cacheEntries {
            entryBegin = dataBytes.count
            dataBytes += hexaToBytes(hexString: String(format: "%08X", cacheEntry.createdAt.timeIntervalSince1970)) // createdAtUnixTime
            dataBytes += hexaToBytes(hexString: String(format: "%08X", cacheEntry.caretedAtNanosecond)) // createdAtNanosec
            dataBytes += hexaToBytes(hexString: String(format: "%08X", cacheEntry.updatedAt.timeIntervalSince1970)) // updatedAtUnixTime
            dataBytes += hexaToBytes(hexString: String(format: "%08X", cacheEntry.updatedAtNanosecond)) // updatedAtNanosec
            dataBytes += hexaToBytes(hexString: String(format: "%08X", cacheEntry.deviceID)) // deviceID
            dataBytes += hexaToBytes(hexString: String(format: "%08X", cacheEntry.inode)) // inode
            guard let decimalEntryMode = Int(cacheEntry.mode, radix: 8) else {
                throw GiftKitError.failedCachedObjectFieldsTypeCast
            }
            dataBytes += hexaToBytes(hexString: String(format: "%08X", decimalEntryMode)) // mode
            dataBytes += hexaToBytes(hexString: String(format: "%08X", cacheEntry.uid)) // uid
            dataBytes += hexaToBytes(hexString: String(format: "%08X", cacheEntry.gid)) // gid
            dataBytes += hexaToBytes(hexString: String(format: "%08X", cacheEntry.size)) // size
            dataBytes += try Array(cacheEntry.sha).eachSlice(2) { "\($0[0])\($0[1])"}.map {
                if let decimal = UInt8($0, radix: 16) {
                    return decimal
                } else {
                    throw GiftKitError.failedCachedObjectFieldsTypeCast
                }
            }
            var binaryString = ""
            binaryString += cacheEntry.assumeValidFlag == true ? "1": "0"
            binaryString += cacheEntry.extendedFlag == true ? "1": "0"
            let stageFlag = String(cacheEntry.stageFlag, radix: 2)
            binaryString += String(Array(repeating: "0", count: 2 - stageFlag.count).joined() + stageFlag)

            let nameLength = String(cacheEntry.nameLength, radix: 2)
            binaryString += String(Array(repeating: "0", count: 12 - nameLength.count).joined() + nameLength)
            guard let flag1 = UInt8(binaryString.prefix(8), radix: 2), let flag2 = UInt8(binaryString.suffix(8), radix: 2) else {
                throw GiftKitError.failedCachedObjectFieldsTypeCast
            }
            dataBytes += [flag1, flag2]

            guard let pathNameBytes = cacheEntry.pathName.data(using: .ascii) else {
                throw GiftKitError.failedCachedObjectFieldsTypeCast
            }

            dataBytes += pathNameBytes
            dataBytes += Array(repeating: 0x00, count: 8 - (dataBytes.count - entryBegin) % 8)
        }
        dataBytes += [0x54, 0x52, 0x45, 0x45] // TREE

        var treeBytes = [UInt8]()
        // Extensions
        for cacheTree in cacheTrees {
            // pathName(ascii) | 0x00 | (if sha? 0x2d) | entryCount(.ascii) | 0x20 | subtreeCount(.ascii) | 0x0a | sha(20byte)
            if let pathNameByte = cacheTree.pathName.data(using: .ascii) {
                treeBytes += [UInt8](pathNameByte)
            }
            treeBytes += [0x00]

            if cacheTree.sha == nil {
                treeBytes += [0x2d]
            }

            if let entryCount = String(cacheTree.entryCount).data(using: .ascii) {
                treeBytes += [UInt8](entryCount)
            }

            treeBytes += [0x20]

            if let subtreeCount = String(cacheTree.subtreeCount).data(using: .ascii) {
                treeBytes += [UInt8](subtreeCount)
            }

            treeBytes += [0x0a]

            if let sha = cacheTree.sha {
                treeBytes += try Array(sha).eachSlice(2) { "\($0[0])\($0[1])"}.map {
                    if let decimal = UInt8($0, radix: 16) {
                        return decimal
                    } else {
                        throw GiftKitError.failedCachedObjectFieldsTypeCast
                    }
                }
            }
        }
        dataBytes += hexaToBytes(hexString: String(format: "%08X", treeBytes.count))
        dataBytes += treeBytes

        // TODO: REUC
        // TODO: link

        // checksum
        dataBytes += try Array(Data(bytes: dataBytes).sha1()).eachSlice(2) { "\($0[0])\($0[1])"}.map {
            if let decimal = UInt8($0, radix: 16) {
                return decimal
            } else {
                throw GiftKitError.failedCachedObjectFieldsTypeCast
            }
        }

        try Data(bytes: dataBytes).write(to: indexURL, options: .atomicWrite)
    }

    private func hexaToBytes(hexString: String) -> [UInt8] {
        let hexa = Array(hexString)
        return stride(from: 0, to: hexString.count, by: 2).compactMap { UInt8(String(hexa[$0...$0.advanced(by: 1)]), radix: 16) }
    }

    private mutating func parseEntry(dataBytes: [UInt8], index: Int) throws -> Int {
        let entryBegin = index
        var index = index

        guard let createdAtUnixTime = Int(dataBytes[index..<index+4].map{String(format:"%02X", $0)}.joined(), radix: 16) else {
            throw GiftKitError.indexFileFormatError(message: "binary read error.")
        }
        index += 4

        guard let createdAtMilisecond = Int(dataBytes[index..<index+4].map{String(format:"%02X", $0)}.joined(), radix: 16) else {
            throw GiftKitError.indexFileFormatError(message: "binary read error.")
        }
        index += 4

        guard let updatedAtUnixTime = Int(dataBytes[index..<index+4].map{String(format:"%02X", $0)}.joined(), radix: 16) else {
            throw GiftKitError.indexFileFormatError(message: "binary read error.")
        }
        index += 4

        guard let updatedAtMilisecond = Int(dataBytes[index..<index+4].map{String(format:"%02X", $0)}.joined(), radix: 16) else {
            throw GiftKitError.indexFileFormatError(message: "binary read error.")
        }
        index += 4

        guard let deviceID = Int(dataBytes[index..<index+4].map { String(format:"%02X", $0) }.joined(), radix: 16) else {
            throw GiftKitError.indexFileFormatError(message: "binary read error.")
        }
        index += 4

        guard let inode = Int(([0x02] + dataBytes[index..<index+4]).map { String(format:"%02X", $0) }.joined(), radix: 16) else {
            throw GiftKitError.indexFileFormatError(message: "binary read error.")
        }
        index += 4

        guard let hexMode = Int(dataBytes[index..<index+4].map { String(format:"%02X", $0) }.joined(), radix: 16) else {
            throw GiftKitError.indexFileFormatError(message: "binary read error.")
        }
        let mode = String(hexMode, radix: 8)
        index += 4

        guard let uid = Int(dataBytes[index..<index+4].map { String(format:"%02X", $0) }.joined(), radix: 16) else {
            throw GiftKitError.indexFileFormatError(message: "binary read error.")
        }
        index += 4

        guard let gid = Int(dataBytes[index..<index+4].map { String(format:"%02X", $0) }.joined(), radix: 16) else {
            throw GiftKitError.indexFileFormatError(message: "binary read error.")
        }
        index += 4

        guard let size = UInt64(dataBytes[index..<index+4].map { String(format:"%02X", $0) }.joined(), radix: 16) else {
            throw GiftKitError.indexFileFormatError(message: "binary read error.")
        }
        index += 4


        let sha = dataBytes[index..<index+20].map { String(format:"%02X", $0) }.joined().lowercased()
        index += 20

        guard let flags = Int((dataBytes[index..<index+2]).map { String(format:"%02X", $0) }.joined(), radix: 16) else {
            throw GiftKitError.indexFileFormatError(message: "binary read error.")
        }
        let bin = String(flags, radix: 2)
        let binaryString = Array(Array(repeating: "0", count: 16 - bin.count).joined() + bin)

        let assumeValidFlag = binaryString[0] == "1"
        let extendedFlag = binaryString[1] == "1"

        guard let stageFlag = Int(String(binaryString[2..<4]), radix: 2), let nameLength = Int(String(binaryString.suffix(12)), radix: 2) else {
            throw GiftKitError.indexFileFormatError(message: "binary read error.")
        }
        index += 2

        guard let filePath = String(bytes: dataBytes[index..<index+nameLength], encoding: .ascii) else {
            throw GiftKitError.indexFileFormatError(message: "binary read error.")
        }
        index += nameLength

        index += 8 - (index - entryBegin) % 8

        let entry = CacheEntry(createdAt: Date(timeIntervalSince1970: TimeInterval(createdAtUnixTime)),
                               caretedAtNanosecond: createdAtMilisecond,
                               updatedAt: Date(timeIntervalSince1970: TimeInterval(updatedAtUnixTime)),
                               updatedAtNanosecond: updatedAtMilisecond,
                               deviceID: deviceID,
                               inode: inode,
                               mode: mode,
                               uid: uid,
                               gid: gid,
                               size: size,
                               sha: sha,
                               assumeValidFlag: assumeValidFlag,
                               extendedFlag: extendedFlag,
                               stageFlag: stageFlag,
                               nameLength: nameLength,
                               pathName: filePath)

        self.cacheEntries.append(entry)

        return index
    }

    private mutating func parseExtension(dataBytes: [UInt8], index: Int) throws -> Int {
        var index = index
        guard let signature = String(bytes: dataBytes[index..<index+4], encoding: .ascii) else {
            throw GiftKitError.indexFileFormatError(message: "binary read error.")
        }
        index += 4

        guard let size = Int((dataBytes[index..<index+4]).map { String(format:"%02X", $0) }.joined(), radix: 16) else {
            throw GiftKitError.indexFileFormatError(message: "binary read error.")
        }
        index += 4

        if signature == "TREE" {
            try parseExtensionTree(dataBytes: dataBytes, index: index, size: size)
        } else if signature == "REUC" {
            try parseExtensionReuc(dataBytes: dataBytes, index: index, size: size)
        } else if signature == "link" {
            try parseExtensionLink(dataBytes: dataBytes, index: index, size: size)
        } else {
            throw GiftKitError.indexFileFormatError(message: "unknown signature \(signature).")
        }

        return index + size
    }
    private mutating func parseExtensionTree(dataBytes: [UInt8], index: Int, size: Int) throws {
        // Parse payload of cached tree extension
        let endIndex = index + size
        var index = index
        while index < endIndex {
            guard let pathEndIndex = Array(dataBytes[0..<endIndex]).firstIndex(of: 0x00, skip: index) else {
                throw GiftKitError.indexFileFormatError(message: "binary read error.")
            }
            guard let pathName = String(bytes: dataBytes[index..<pathEndIndex], encoding: .ascii) else {
                throw GiftKitError.indexFileFormatError(message: "binary read error.")
            }
            index = pathEndIndex + 1

            guard let entryCountEnd = Array(dataBytes[0..<endIndex]).firstIndex(of: 0x20, skip: index) else {
                throw GiftKitError.indexFileFormatError(message: "binary read error.")
            }

            let entryCount = dataBytes[index..<entryCountEnd]
            guard let entryCountString = String(bytes: entryCount, encoding: .ascii), let entryCountSize = Int(entryCountString) else {
                throw GiftKitError.indexFileFormatError(message: "binary read error.")
            }
            index = entryCountEnd + 1

            guard let subtreesEnd = Array(dataBytes[0..<endIndex]).firstIndex(of: 0x0a, skip: index) else {
                throw GiftKitError.indexFileFormatError(message: "binary read error.")
            }

            let subtrees = dataBytes[index..<subtreesEnd]
            guard let subtreesString = String(bytes: subtrees, encoding: .ascii), let subtreeCountSize = Int(subtreesString) else {
                throw GiftKitError.indexFileFormatError(message: "binary read error.")
            }
            index = subtreesEnd + 1

            var sha1: String?
            // 0x2d: hyphen (-)
            if entryCount.first == 0x2d {
            } else {
                if index + 20 > endIndex {
                    throw GiftKitError.indexFileFormatError(message: "binary read error.")
                }
                sha1 = dataBytes[index..<index+20].map { String(format:"%02X", $0) }.joined().lowercased()
                index += 20
            }

            let cacheTree = CacheTree(entryCount: entryCountSize, subtreeCount: subtreeCountSize, pathName: pathName, sha: sha1)
            self.cacheTrees.append(cacheTree)
        }
    }
    // REUC: resolve undo conflict
    private func parseExtensionReuc(dataBytes: [UInt8], index: Int, size: Int) throws {
        // Parse payload of resolve undo extension
        fatalError("not impremented")
    }
    private func parseExtensionLink(dataBytes: [UInt8], index: Int, size: Int) throws {
        // Parse payload of split index extension
        fatalError("not impremented")
    }
}
