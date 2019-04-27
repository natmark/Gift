//
//  GitObject.swift
//  Commandant
//
//  Created by AtsuyaSato on 2019/04/28.
//

import Foundation

typealias GitObject = GitObjectProtocol & Codable

public protocol GitObjectProtocol {
    static var identifier: String { get }
    init(repo: Repository)
}
