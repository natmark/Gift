//
//  URL+FileStatus.swift
//  Commandant
//
//  Created by AtsuyaSato on 2019/04/06.
//

import Foundation
extension URL {
    enum FileStatus {
        case file
        case directory
        case notExist
    }

    public var isDirectory: Bool {
        return fileStatus == .directory
    }

    public var isFile: Bool {
        return fileStatus == .file
    }

    public var isExist: Bool {
        return fileStatus != .notExist
    }

    var fileStatus: FileStatus {
        let fileStatus: FileStatus
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDir) {
            if isDir.boolValue {
                fileStatus = .directory
            }
            else {
                fileStatus = .file
            }
        }
        else {
            fileStatus = .notExist
        }
        return fileStatus
    }
}
