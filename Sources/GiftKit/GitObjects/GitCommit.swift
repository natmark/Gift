//
//  GitCommit.swift
//  Commandant
//
//  Created by AtsuyaSato on 2019/04/28.
//

import Foundation

public protocol KVLMContract {
    // Key-Value List with Message
    var kvlm: [(key: String, value: Any)] { set get }
}

public struct GitCommit: GitObject, KVLMContract {
    public var kvlm: [(key: String, value: Any)] = []
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
        return try KVLMSerializer.serialize(kvlm: self.kvlm)
    }

    public mutating func deserialize(data: Data) throws {
        self.kvlm = try KVLMSerializer.deserialize(data: data)
    }
}
