//
//  GitBlob.swift
//  Commandant
//
//  Created by AtsuyaSato on 2019/04/28.
//

import Foundation

public struct GitBlob: GitObject {
    public var identifier: GitObjectType {
        return .blob
    }

    public var repository: Repository?

    public init(repository: Repository?, data: Data?) throws {
        self.repository = repository
    }

    public func serialize() throws -> Data {
        fatalError()
    }

    public mutating func deserialize(data: Data) throws {
    }
}
