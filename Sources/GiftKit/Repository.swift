import Foundation

public enum RepositoryError: Error {
    case notGitRepository(String)
    case noGitDirectory
    case configFileMissing
    case unsupportedRepositoryFormatVersion(String)
    case isNotEmpty
    case isNotDirectory
    case unknown(String)
}

public struct Repository {
    var workTreeURL: URL
    var gitDirectoryURL: URL
    var config: GitConfig?

    private init(workTreeURL: URL, checkRepository: Bool = true) throws {
        let disableAllCheck = !checkRepository

        self.workTreeURL = workTreeURL
        self.gitDirectoryURL = workTreeURL.appendingPathComponent(".git")

        if !disableAllCheck && !gitDirectoryURL.isDirectory {
            throw RepositoryError.notGitRepository(workTreeURL.path)
        }

        let configURL = gitDirectoryURL.appendingPathComponent("config")
        if configURL.isExist {
            self.config = GitConfig(from: configURL)
        } else if !disableAllCheck {
            throw RepositoryError.configFileMissing
        }

        if disableAllCheck { return }

        if let formatVersion = self.config?["core"]?["repositoryformatversion"], Int(formatVersion) != 0 {
            throw RepositoryError.unsupportedRepositoryFormatVersion(formatVersion)
        }
    }

    public static func find(with targetURL: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)) throws -> Repository {
        if targetURL.appendingPathComponent(".git").isDirectory {
            return try Repository(workTreeURL: targetURL)
        }

        let parentURL = targetURL.deletingLastPathComponent()
        if parentURL.standardizedFileURL == targetURL.standardizedFileURL {
            // Bottom case (targetURL is root path)
            throw RepositoryError.noGitDirectory
        }

        return try find(with: parentURL)
    }

    @discardableResult
    public static func create(with workTreeURL: URL) throws -> Repository {
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
        try repository.computeSubDirectoryPathFromPathComponents(["branches"], withMakeDirectory: true)
        // .git/objects
        try repository.computeSubDirectoryPathFromPathComponents(["objects"], withMakeDirectory: true)
        // .git/refs/tags
        try repository.computeSubDirectoryPathFromPathComponents(["refs", "tags"], withMakeDirectory: true)
        // .git/refs/heads
        try repository.computeSubDirectoryPathFromPathComponents(["refs", "heads"], withMakeDirectory: true)

        // .git/description
        if let descriptionURL = try repository.computeSubFilePathFromPathComponents(["description"]) {
            let fileObject = "Unnamed repository; edit this file 'description' to name the repository.\n"
            try fileObject.write(to: descriptionURL, atomically: true, encoding: .utf8)
        }

        // .git/HEAD
        if let headURL = try repository.computeSubFilePathFromPathComponents(["HEAD"]) {
            let fileObject = "ref: refs/heads/master\n"
            try fileObject.write(to: headURL, atomically: true, encoding: .utf8)
        }

        // .git/config
        if let configURL = try repository.computeSubFilePathFromPathComponents(["config"]) {
            var gitConfig = GitConfig()
            gitConfig.set(sectionName: "core", key: "repositoryformatversion", value: "0")
            gitConfig.set(sectionName: "core", key: "filemode", value: "false")
            gitConfig.set(sectionName: "core", key: "bare", value: "false")
            try gitConfig.write(to: configURL)
        }

        return repository
    }

    @discardableResult
    private func computeSubFilePathFromPathComponents(_ pathComponents: [String], withMakeDirectory: Bool = false) throws -> URL? {

        if pathComponents.count == 0 {
            return self.gitDirectoryURL
        }

        if let _ = try self.computeSubDirectoryPathFromPathComponents(Array(pathComponents.dropLast()), withMakeDirectory: withMakeDirectory) {
            return self.gitDirectoryURL.appendingPathComponents(pathComponents: pathComponents)
        }
        return nil
    }

    @discardableResult
    private func computeSubDirectoryPathFromPathComponents(_ pathComponents: [String], withMakeDirectory: Bool = false) throws -> URL? {
        let path = self.gitDirectoryURL.appendingPathComponents(pathComponents: pathComponents)

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
