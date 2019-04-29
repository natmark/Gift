//
//  GitObject.swift
//  Commandant
//
//  Created by AtsuyaSato on 2019/04/28.
//

import Foundation

public enum GitObjectError: Error {
    case failedDeserialize
}

public protocol GitObject {
    var identifier: GitObjectType { get }
    var repository: Repository? { get }
    init(repository: Repository?, data: Data?) throws
    func serialize() throws -> Data
    mutating func deserialize(data: Data) throws
}

public enum GitObjectType: String {
    case blob
    case commit
    case tag
    case tree
}
