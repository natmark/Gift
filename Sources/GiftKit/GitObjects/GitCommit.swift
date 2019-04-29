//
//  GitCommit.swift
//  Commandant
//
//  Created by AtsuyaSato on 2019/04/28.
//

import Foundation

public struct GitCommit: GitObject {
    // Key-Value List with Message
    private var kvlm: [String: Any] = [:]
    public var identifier: GitObjectType {
        return .commit
    }

    public var repository: Repository?

    public init(repository: Repository?, data: Data?) throws {
        self.repository = repository
        if let data = data {
            try deserialize(data: data)
        }
    }

    public func serialize() throws -> Data {
        var dataBytes = [UInt8]()
        for key in kvlm.keys {
            if key == "" {
                continue
            }

            var values: [String] = kvlm[key] as? [String]
                ?? []

            if values.isEmpty {
                if let value = kvlm[key] as? String {
                    values = [value]
                } else {
                    
                }
            }

            for value in values {
                // 0x20 Space
                guard let valueData = value.replacingOccurrences(of: "\n", with: "\n ").data(using: .utf8), let keyData = key.data(using: .utf8) else {
                    throw GiftKitError.failedSerializeGitCommitObject
                }
                dataBytes += [UInt8](keyData) + [0x20] + [UInt8](valueData) + [0x0a]
            }
        }

        guard let message = kvlm[""] as? String, let messageData = message.data(using: .utf8) else {
            throw GiftKitError.failedSerializeGitCommitObject
        }
        dataBytes += [0x0a] + [UInt8](messageData)

        return Data(bytes: dataBytes)
    }

    public mutating func deserialize(data: Data) throws {
        self.kvlm = try parseKeyValueListWithMessage(data: data)
    }

    private func parseKeyValueListWithMessage(data: Data, startIndex: Int = 0, dictionary: [String: Any]? = nil) throws -> [String: Any] {
        var dict: [String: Any]
        if let dictionary = dictionary {
            dict = dictionary
        } else {
            dict = [String: Any]()
        }

        let dataBytes = [UInt8](data)
        
        // 0x00 NUL (null string)
        // 0x20 Space
        guard let firstSpaceCharacterIndex = dataBytes.firstIndex(of: 0x20),
            let firstNullStringIndex = dataBytes.firstIndex(of: 0x00)
            else {
                throw GiftKitError.failedDeserializeGitCommitObject
        }

        if firstSpaceCharacterIndex < 0 || firstNullStringIndex < firstSpaceCharacterIndex {
            assert(firstNullStringIndex == startIndex)
            guard let string = String(bytes: Data(bytes: Array(dataBytes.dropFirst(startIndex + 1))), encoding: .utf8) else {
                throw GiftKitError.unknown("Failed to convert string to data")
            }

            dict[""] = string
            return dict
        }

        guard let key = String(bytes: dataBytes[startIndex..<firstSpaceCharacterIndex], encoding: .utf8) else {
            throw GiftKitError.unknown("Failed to convert string to data")
        }

        var endIndex = startIndex
        while true {
            // 0x0a LF (line break)
            guard let index = dataBytes.firstIndex(of: 0x0a, skip: endIndex + 1)
                else {
                    throw GiftKitError.failedDeserializeGitCommitObject
            }
            endIndex = index
            if dataBytes[endIndex + 1] != 0x20 {
                break
            }
        }

        guard let value = String(bytes: dataBytes[firstSpaceCharacterIndex+1..<endIndex], encoding: .utf8)?.replacingOccurrences(of: "\n ", with: "\n") else {
            throw GiftKitError.failedDeserializeGitCommitObject
        }

        if dict.keys.contains(key) {
            if ((dict[key] as? [String]) != nil) {
                var array = dict[key] as? [String] ?? []
                array.append(value)
                dict[key] = array
            } else {
                dict[key] = [dict[key], value]
            }
        } else {
            dict[key] = value
        }

        return try parseKeyValueListWithMessage(data: data, startIndex: endIndex + 1, dictionary:dict)
    }
}
