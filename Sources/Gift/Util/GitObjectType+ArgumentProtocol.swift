//
//  GitObjectType+ArgumentProtocol.swift
//  Commandant
//
//  Created by AtsuyaSato on 2019/04/29.
//

import Foundation
import Commandant
import GiftKit

extension GitObjectType: ArgumentProtocol {
    public static let name = "type"

    public static func from(string: String) -> GitObjectType? {
        return GitObjectType(rawValue: string)
    }
}
