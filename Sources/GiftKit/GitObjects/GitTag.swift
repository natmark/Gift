//
//  GitTag.swift
//  Commandant
//
//  Created by AtsuyaSato on 2019/04/28.
//

import Foundation

public struct GitTag: GitObject {
    public static var identifier: GitObjectType {
        return .tag
    }

    public var repository: Repository

    public init(repository: Repository, data: Data?) {
        self.repository = repository
    }

    public func serialize() {
    }

    public func deserialize(data: Data) {
    }
}
