//
//  GitUser.swift
//  Commandant
//
//  Created by AtsuyaSato on 2019/05/11.
//

import Foundation

struct GitUser {
    var email: String
    var name: String

    init?(email: String?, name: String?) {
        guard let email = email, let name = name else {
            return nil
        }

        self.email = email
        self.name = name
    }
}
