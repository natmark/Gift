//
//  GitTree.swift
//  Commandant
//
//  Created by AtsuyaSato on 2019/04/28.
//

import Foundation

public struct GitTree: GitObject {
    public var leafs: [GitTreeLeaf] = []
    public var identifier: GitObjectType {
        return .tree
    }

    public var repository: Repository?

    public init(repository: Repository?, data: Data?) throws {
        self.repository = repository
        if let data = data {
            try deserialize(data: data)
        }
    }

    public func serialize() throws -> Data {
        var result = [UInt8]()
        for leaf in leafs {
            guard
                let modeData = leaf.mode.data(using: .utf8),
                let pathData = leaf.path.data(using: .utf8),
                let shaData = leaf.sha.data(using: .utf8)
            else {
                throw GiftKitError.failedSerializeGitTreeObject
            }
            result += [UInt8](modeData)
            result += [0x20]
            result += [UInt8](pathData)
            result += [0x00]
            result += [UInt8](shaData)
        }
        return Data(bytes: result)
    }

    private func parseTreeAndTakeOneLeaf(from data: Data, startAtIndex start: Int) throws -> (leaf: GitTreeLeaf, position: Int) {
        let dataBytes = [UInt8](data)

        guard
            let firstSpaceCharacterIndex = dataBytes.firstIndex(of: 0x20, skip: start),
            let firstNullStringIndex = dataBytes.firstIndex(of: 0x00, skip: firstSpaceCharacterIndex)
        else {
                throw GiftKitError.failedDeserializeGitTreeObject
        }
        if firstSpaceCharacterIndex - start < 5 || firstSpaceCharacterIndex - start > 6 {
            throw GiftKitError.failedDeserializeGitTreeObject
        }

        let sha = Array(dataBytes[firstNullStringIndex + 1..<firstNullStringIndex + 21]).map { String(format:"%02X", $0) }.joined().lowercased()

        guard
            let mode = String(data: Data(bytes: Array(dataBytes[start..<firstSpaceCharacterIndex])), encoding: .utf8),
            let path = String(data: Data(bytes:Array(dataBytes[firstSpaceCharacterIndex + 1..<firstNullStringIndex])), encoding: .utf8)
        else {
            throw GiftKitError.failedDeserializeGitTreeObject
        }

        return (leaf: GitTreeLeaf(mode: mode, path: path, sha: sha),position: firstNullStringIndex + 21)
    }

    public mutating func deserialize(data: Data) throws {
        let dataBytes = [UInt8](data)
        var leafs = [GitTreeLeaf]()
        var position = 0

        while position < dataBytes.count {
            let result = try parseTreeAndTakeOneLeaf(from: data, startAtIndex: position)
            position = result.position
            leafs.append(result.leaf)
        }

        self.leafs = leafs
    }
}
