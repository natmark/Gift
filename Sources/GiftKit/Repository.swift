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

    init(workTreeURL: URL, checkRepository: Bool = true) throws {
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
}
