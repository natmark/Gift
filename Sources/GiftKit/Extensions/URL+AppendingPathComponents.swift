//
//  URL+AppendingPathComponents.swift
//  Commandant
//
//  Created by AtsuyaSato on 2019/04/13.
//

import Foundation

extension URL {
    func appendingPathComponents(pathComponents: [String]) -> URL {
        if pathComponents.count == 0 {
            return self
        }

        var path = self
        pathComponents.dropLast().forEach {
            path = path.appendingPathComponent($0, isDirectory: true)
        }
        return path.appendingPathComponent(pathComponents.last!)
    }
}
