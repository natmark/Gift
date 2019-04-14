//
//  RepositoryOperation.swift
//  Commandant
//
//  Created by AtsuyaSato on 2019/04/13.
//

import Foundation

public struct RepositoryOperation {
    @discardableResult
    public static func createRepository(workTreeURL: URL) throws -> Repository {
        let repository = try Repository(workTreeURL: workTreeURL, checkRepository: false)

        if repository.workTreeURL.isExist {
            if !repository.workTreeURL.isDirectory {
                throw RepositoryError.isNotDirectory
            }
            if let contents = try? repository.workTreeURL.contents(), !contents.isEmpty {
                throw RepositoryError.isNotEmpty
            }
        } else {
            try FileManager.default.createDirectory(at: workTreeURL, withIntermediateDirectories: true, attributes: nil)
        }

        // .git/branches
        try convertToRepositoryDirectoryPath(base: repository, pathComponents: ["branches"], withMakeDirectory: true)
        // .git/objects
        try convertToRepositoryDirectoryPath(base: repository, pathComponents: ["objects"], withMakeDirectory: true)
        // .git/refs/tags
        try convertToRepositoryDirectoryPath(base: repository, pathComponents: ["refs", "tags"], withMakeDirectory: true)
        // .git/refs/heads
        try convertToRepositoryDirectoryPath(base: repository, pathComponents: ["refs", "heads"], withMakeDirectory: true)

        // .git/description
        if let descriptionURL = try convertToRepositoryFilePath(base: repository, pathComponents: ["description"]) {
            let fileObject = "Unnamed repository; edit this file 'description' to name the repository.\n"
            try fileObject.write(to: descriptionURL, atomically: true, encoding: .utf8)
        }

        // .git/HEAD
        if let headURL = try convertToRepositoryFilePath(base: repository, pathComponents: ["HEAD"]) {
            let fileObject = "ref: refs/heads/master\n"
            try fileObject.write(to: headURL, atomically: true, encoding: .utf8)
        }

        // .git/config
        if let configURL = try convertToRepositoryFilePath(base: repository, pathComponents: ["config"]) {
            let gitConfig = GitConfig()
            gitConfig.set(sectionName: "core", key: "repositoryformatversion", value: "0")
            gitConfig.set(sectionName: "core", key: "filemode", value: "false")
            gitConfig.set(sectionName: "core", key: "bare", value: "false")
            try gitConfig.write(to: configURL)
        }

        return repository
    }

    @discardableResult
    static func convertToRepositoryFilePath(base repository: Repository, pathComponents: [String], withMakeDirectory: Bool = false) throws -> URL? {

        if pathComponents.count == 0 {
            return repository.gitDirectoryURL
        }

        if let _ = try convertToRepositoryDirectoryPath(base: repository, pathComponents: Array(pathComponents.dropLast()), withMakeDirectory: withMakeDirectory) {
            return repository.gitDirectoryURL.appendingPathComponents(pathComponents: pathComponents)
        }
        return nil
    }

    @discardableResult
    static func convertToRepositoryDirectoryPath(base repository: Repository, pathComponents: [String], withMakeDirectory: Bool = false) throws -> URL? {
        let path = repository.gitDirectoryURL.appendingPathComponents(pathComponents: pathComponents)

        if path.isExist {
            if path.isDirectory {
                return path
            } else {
                throw RepositoryError.isNotDirectory
            }
        }

        if withMakeDirectory {
            try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true, attributes: nil)
            return path
        }
        return nil
    }
}
