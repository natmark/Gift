//
//  GitObject.swift
//  Commandant
//
//  Created by AtsuyaSato on 2019/04/28.
//

import Foundation

public protocol GitObject {
    var identifier: GitObjectType { get }
    var repository: Repository { get }
    init(repository: Repository, data: Data?)
    func serialize() -> Data
    func deserialize(data: Data)
}

public enum GitObjectType: String {
    case blob
    case commit
    case tag
    case tree
}
