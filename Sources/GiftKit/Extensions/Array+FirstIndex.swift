//
//  Array+firstIndex.swift
//  Commandant
//
//  Created by AtsuyaSato on 2019/04/29.
//

import Foundation

extension Array where Element == UInt8 {
    public func firstIndex(of element: UInt8, skip: Int) -> Int? {
        if let index = Array(self.dropFirst(skip)).firstIndex(of: element) {
            return skip + index
        }
        return nil
    }
}
