//
//  GitReference.swift
//  Commandant
//
//  Created by AtsuyaSato on 2019/04/30.
//

import Foundation
import GiftKit

struct GitReference {
    static func show(references: [String: Any], repository: Repository, withHash: Bool = true, prefix: String = "") {
        for (key, value) in references {
            var spacer = ""
            if withHash {
                spacer = " "
            }
            var separator = ""
            if !prefix.isEmpty {
                separator = "/"
            }

            if let string = value as? String {
                print("\(string)\(spacer)\(prefix)\(separator)\(key)")
            } else {
                if let refs = value as? [String: Any] {
                    GitReference.show(references: refs, repository: repository, withHash: withHash, prefix: "\(prefix)\(separator)\(key)")
                }
            }
        }
    }
}
