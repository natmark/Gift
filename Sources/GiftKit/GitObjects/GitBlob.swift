//
//  GitBlob.swift
//  Commandant
//
//  Created by AtsuyaSato on 2019/04/28.
//

import Foundation

public struct GitBlob: GitObject {
    public var blobData: Data = Data()
    public var identifier: GitObjectType {
        return .blob
    }

    public var repository: Repository?

    public init(repository: Repository?, data: Data?) throws {
        self.repository = repository
        if let data = data {
            try deserialize(data: data)
        }
    }

    public func serialize() throws -> Data {
        return self.blobData
    }

    public mutating func deserialize(data: Data) throws {
        self.blobData = data
    }
}
