//
//  URL+ContentList.swift
//  Commandant
//
//  Created by AtsuyaSato on 2019/04/06.
//

import Foundation

extension URL {
    func contents() throws -> [URL] {
        let files: [URL]
        do {
            files = try FileManager.default.contentsOfDirectory(at: self, includingPropertiesForKeys: nil, options: [])
        }
        return files
    }
}
