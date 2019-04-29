//
//  Data+SHA1.swift
//  Commandant
//
//  Created by AtsuyaSato on 2019/04/29.
//

import Foundation
import CommonCrypto

extension Data {
    public func sha1() -> String {
        let length = Int(CC_SHA1_DIGEST_LENGTH)
        var digest = [UInt8](repeating: 0, count: length)
        _ = self.withUnsafeBytes { CC_SHA1($0, CC_LONG(self.count), &digest) }
        let crypt = digest.map { String(format: "%02x", $0) }.joined(separator: "")
        return crypt
    }
}
