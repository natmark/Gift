import Foundation

public enum RepositoryError: Error {
    case notGitRepository(String)
    case noGitDirectory
    case configFileMissing
    case unsupportedRepositoryFormatVersion(String)
    case isNotEmpty
    case isNotDirectory
    case failedResolvingSubpathName
    case failedDecompressedObjectData
    case failedCompressedObjectData
    case unknownFormatType(String)
    case mulformedObject(String)
    case unsupportedOSXVersion(String)
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

    public func writeObject(_ object: GitObject, withActuallyWrite actuallyWrite: Bool = true) throws -> String {
        // Serialize object data
        let data = object.serialize()
        let byteArray = [UInt8](data)
        guard let objectFormatData = object.identifier.rawValue.data(using: .utf8), let dataSizeData = String(byteArray.count).data(using: .utf8) else {
            throw RepositoryError.unknown("Failed to convert string to data")
        }

        let objectFormat = [UInt8](objectFormatData)
        let dataSize = [UInt8](dataSizeData)
        // Add header
        let result = Data(bytes: objectFormat + [20] + dataSize + [0] + byteArray)
        let sha = result.sha1()


        if actuallyWrite {
            guard let fileURL = try self.computeSubFilePathFromPathComponents(["objects", String(sha.prefix(2)), String(sha.suffix(sha.count - 2))], withMakeDirectory: true) else {
                throw RepositoryError.failedResolvingSubpathName
            }

            let compressedData: Data?
            if #available(OSX 10.11, *) {
                compressedData = try result.compress()
            } else {
                throw RepositoryError.unsupportedOSXVersion("Available OS X 10.11 or newer")
            }
            guard let data = compressedData, let fileObject = String(data: data, encoding: .utf8) else {
                throw RepositoryError.failedCompressedObjectData
            }

            try fileObject.write(to: fileURL, atomically: true, encoding: .utf8)
        }

        return sha
    }

    public func readObject(sha: String) throws -> GitObject {
        // .git/objects/e5/e11e0360d9534b0d3f65085df7c62d8fb8a82b
        // take prefix(2) to make directory (e5)
        guard let fileURL = try self.computeSubFilePathFromPathComponents(["objects", String(sha.prefix(2)), String(sha.suffix(sha.count - 2))]) else {
            throw RepositoryError.failedResolvingSubpathName
        }

        let binaryData = try Data(contentsOf: fileURL, options: [])
        let decompressedData: Data?
        if #available(OSX 10.11, *) {
            decompressedData = try binaryData.decompress(algorithm: .zlib)
        } else {
            throw RepositoryError.unsupportedOSXVersion("Available OS X 10.11 or newer")
        }
        guard let data = decompressedData else {
            throw RepositoryError.failedDecompressedObjectData
        }

        // commit 176.tree
        // 636f 6d6d 6974 2031 3736 0074 7265 6520
        let dataBytes = [UInt8](data)

        // 0x00 NUL (Null string)
        // 0x20 Control character
        guard let firstControlCharacterIndex = dataBytes.firstIndex(of: 20),
            let firstNullStringIndex = dataBytes.firstIndex(of: 0),
            let format = String(bytes: Array(dataBytes.prefix(firstControlCharacterIndex)), encoding: .utf8),
            let sizeString = String(bytes: dataBytes[firstControlCharacterIndex..<firstNullStringIndex], encoding: .utf8),
            let size = Int(sizeString)
            else {
            throw RepositoryError.failedDecompressedObjectData
        }

        if size != dataBytes.count - firstNullStringIndex - 1 {
            throw RepositoryError.mulformedObject("Malformed object \(sha): bad length")
        }

        guard let type = GitObjectType(rawValue: format) else {
            throw RepositoryError.unknownFormatType("Unknown type \(format) for object \(sha)")
        }

        let gitObjectMetaType: GitObject.Type

        switch type {
        case .commit:
            gitObjectMetaType = GitCommit.self
        case .tree:
            gitObjectMetaType = GitTree.self
        case .tag:
            gitObjectMetaType = GitTag.self
        case .blob:
            gitObjectMetaType = GitBlob.self
        }

        return gitObjectMetaType.init(repository: self, data: Data(bytes: dataBytes.prefix(firstNullStringIndex+1)))
    }

    public func findObject(name: String, format: String? = nil, follow: Bool = true) -> String {
        return name
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
