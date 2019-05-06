//
//  Array+EachSlice.swift
//  Commandant
//
//  Created by AtsuyaSato on 2019/05/06.
//

import Foundation

extension Array {
    func eachSlice<S>(_ n: Int, _ body: ([Element]) -> S) -> [S] {
        var result = [S]()
        for from in stride(from: 0, to: self.count, by: n) {
            let to = Swift.min(from + n, self.endIndex)
            result.append(body(Array(self[from ..< to])))
        }
        return result
    }
}
