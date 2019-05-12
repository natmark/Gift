import Foundation
import DataCompression

public struct Repository {
    var workTreeURL: URL
    var gitDirectoryURL: URL
    var config: GitConfig?
    var globalConfig: GitConfig?
    var index: GitIndex

    private init(workTreeURL: URL, checkRepository: Bool = true) throws {
        let disableAllCheck = !checkRepository

        self.workTreeURL = workTreeURL
        self.gitDirectoryURL = workTreeURL.appendingPathComponent(".git")
        let indexURL = gitDirectoryURL.appendingPathComponent("index")
        self.index = try GitIndex(from: indexURL)

        if !disableAllCheck && !gitDirectoryURL.isDirectory {
            throw GiftKitError.notGitRepository(path: workTreeURL)
        }

        let configURL = gitDirectoryURL.appendingPathComponent("config")
        if configURL.isExist {
            self.config = GitConfig(from: configURL)
        } else if !disableAllCheck {
            throw GiftKitError.configFileMissing
        }

        let homeDirURL: URL
        if #available(OSX 10.12, *) {
            homeDirURL = FileManager.default.homeDirectoryForCurrentUser
        } else {
            homeDirURL = URL(fileURLWithPath: NSHomeDirectory())
        }

        let globalConfigURL = homeDirURL.appendingPathComponent(".gitconfig")
        if globalConfigURL.isExist {
            self.config = GitConfig(from: globalConfigURL)
        }

        if disableAllCheck { return }

        if let formatVersion = self.config?["core"]?["repositoryformatversion"], Int(formatVersion) != 0 {
            throw GiftKitError.unsupportedRepositoryFormatVersion(version: formatVersion)
        }
    }

    public static func find(with targetURL: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)) throws -> Repository {
        if targetURL.appendingPathComponent(".git").isDirectory {
            return try Repository(workTreeURL: targetURL)
        }

        let parentURL = targetURL.deletingLastPathComponent()
        if parentURL.standardizedFileURL == targetURL.standardizedFileURL {
            // Bottom case (targetURL is root path)
            throw GiftKitError.noGitDirectory
        }

        return try find(with: parentURL)
    }

    @discardableResult
    public static func create(with workTreeURL: URL) throws -> Repository {
        let repository = try Repository(workTreeURL: workTreeURL, checkRepository: false)

        if repository.workTreeURL.isExist {
            if !repository.workTreeURL.isDirectory {
                throw GiftKitError.isNotDirectory(url: repository.workTreeURL)
            }
            if let contents = try? repository.workTreeURL.contents(), !contents.isEmpty {
                throw GiftKitError.isNotEmpty(url: repository.workTreeURL)
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
}

extension Repository {
    private var author: GitUser? {
        var authorEmail: String?
        var authorName: String?

        if let email = self.config?["user"]?["email"] {
            authorEmail = email
        }
        if let email = self.globalConfig?["user"]?["email"] {
            authorEmail = email
        }
        if let name = self.config?["user"]?["name"] {
            authorName = name
        }
        if let name = self.globalConfig?["user"]?["name"] {
            authorName = name
        }
        return GitUser(email: authorEmail, name: authorName)
    }

    private static let timeZoneFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "Z"
        return dateFormatter
    }()

    public mutating func commit(message: String) throws {
        guard let author = author else {
            throw GiftKitError.gitAccountNotFound
        }

        var kvlm = [(key: String, value: Any)]()

        if index.cacheTrees.isEmpty {
            if self.index.cacheTrees.firstIndex(where: { $0.pathName == "" }) == nil {
                // Dummy
                self.index.cacheTrees.append(CacheTree(entryCount: 0, subtreeCount: 0, pathName: "", sha: nil))
            }
            let rootTree = try createTree(from: index.cacheEntries, pathComponents: [])
            let sha = try writeObject(rootTree)
            let subtreeCount = rootTree.leafs.filter ({
                if let object = try? readObject(sha: $0.sha) {
                    return object.identifier == .tree
                }
                return false
            }).count
            let subtreeCache = CacheTree(entryCount: rootTree.leafs.count, subtreeCount: subtreeCount, pathName: "", sha: sha)

            if let index = self.index.cacheTrees.firstIndex(where: { $0.pathName == ""}) {
                self.index.cacheTrees[index] = subtreeCache
            }

            kvlm.append((key: "tree", value: sha))
        } else {
            var currentPathComponents: [String] = []
            var cachedTreePath: [String] = []

            for cachedTree in self.index.cacheTrees {
                if workTreeURL.appendingPathComponents(pathComponents: currentPathComponents + [cachedTree.pathName]).isExist {
                    currentPathComponents.append(cachedTree.pathName)
                } else {
                    while workTreeURL.appendingPathComponents(pathComponents: currentPathComponents + [cachedTree.pathName]).isExist {
                        currentPathComponents.removeLast()
                    }
                    currentPathComponents.append(cachedTree.pathName)
                }
                cachedTreePath.append(currentPathComponents.dropFirst().joined(separator: "/"))
            }

            for (i, (cacheTree, path)) in zip(self.index.cacheTrees, cachedTreePath).reversed().enumerated() {
                let cachedTreeIndex = self.index.cacheTrees.count - i - 1
                if cacheTree.sha != nil {
                    continue
                }

                var leafs = [GitTreeLeaf]()
                // Entries
                let filteredEntries = self.index.cacheEntries.filter({ $0.pathName.hasPrefix(path) && !$0.pathName.replacingOccurrences(of: path, with: "").contains("/") })
                for filteredCacheEntry in filteredEntries {
                    let leaf = GitTreeLeaf(mode: filteredCacheEntry.mode, path: filteredCacheEntry.pathName.replacingOccurrences(of: path, with: ""), sha: filteredCacheEntry.sha)
                    leafs.append(leaf)
                }

                let filteredCacheTrees = zip(self.index.cacheTrees, cachedTreePath).filter({$0.1 != path && $0.1.hasPrefix(path) && !$0.1.replacingOccurrences(of: path, with: "").contains("/")}).map({$0.0})
                // Trees
                for filteredCacheTree in filteredCacheTrees {
                    guard let sha = filteredCacheTree.sha else {
                        throw GiftKitError.failedReadGitObject
                    }
                    // S_IFDIR    0040000   directory
                    let leaf = GitTreeLeaf(mode: "040000", path: filteredCacheTree.pathName, sha: sha)
                    leafs.append(leaf)
                }

                var tree = try GitTree(repository: self, data: nil)
                tree.leafs = leafs
                let sha = try writeObject(tree)

                let cacheTree = CacheTree(entryCount: filteredEntries.count, subtreeCount: filteredCacheTrees.count, pathName: cacheTree.pathName, sha: sha)
                self.index.cacheTrees[cachedTreeIndex] = cacheTree

                // rootObject
                if cacheTree.pathName == "" {
                    kvlm.append((key: "tree", value: sha))
                }
            }
        }

        if let parent = try? resolveReference(pathComponents: ["HEAD"]) {
            kvlm.append((key: "parent", value: parent))
        }

        let currentTime = "\(Int(Date().timeIntervalSince1970)) \(Repository.timeZoneFormatter.string(from: Date()))"
        let authorIdentity = "\(author.name) <\(author.email)> \(currentTime)"
        kvlm.append((key: "author", value: authorIdentity))
        kvlm.append((key: "committer", value: authorIdentity))
        kvlm.append((key: "", value: message))

        var commit = try GitCommit(repository: self, data: nil)
        commit.kvlm = kvlm
        let sha = try writeObject(commit)

        guard let fileURL = try computeSubFilePathFromPathComponents(["HEAD"]) else {
            throw GiftKitError.failedResolvingSubpathName(pathComponents: ["HEAD"])
        }
        let HEAD = try String(contentsOf: fileURL).replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "ref: ", with: "")

        try createReference(pathComponents: convertPathComponents(from: HEAD, baseComponents: ["refs"]), sha: sha)

        self.index.cacheEntries.sort { $0.pathName < $1.pathName }
        try self.index.write()
    }

    private mutating func createTree(from cacheEntries: [CacheEntry], pathComponents: [String]) throws -> GitTree {

        let fileEntries = cacheEntries.filter{ convertPathComponents(from: $0.pathName, baseComponents: pathComponents).count == 1 }
        let subtreeEntries = cacheEntries.filter { convertPathComponents(from: $0.pathName, baseComponents: pathComponents).count > 1 }

        var subtreeKeyValues = [(key: String, value: [CacheEntry])]()
        for subtreeEntry in subtreeEntries {
            let key = convertPathComponents(from: subtreeEntry.pathName, baseComponents: pathComponents).first!
            if let index = subtreeKeyValues.firstIndex(where: { $0.key == key }) {
                subtreeKeyValues[index] = (key: key, value: subtreeKeyValues[index].value + [subtreeEntry])
            } else {
                subtreeKeyValues.append((key: key, value: [subtreeEntry]))
            }
        }

        var tree = try GitTree(repository: self, data: nil)

        for (key, value) in subtreeKeyValues {
            if self.index.cacheTrees.firstIndex(where: { $0.pathName == key }) == nil {
                // Dummy
                self.index.cacheTrees.append(CacheTree(entryCount: 0, subtreeCount: 0, pathName: key, sha: nil))
            }

            let subtree = try createTree(from: value, pathComponents: pathComponents + [key])
            let sha = try writeObject(subtree)
            // S_IFDIR    0040000   directory
            let subtreeLeaf = GitTreeLeaf(mode: "040000", path: key, sha: sha)

            let subtreeCount = subtree.leafs.filter({
                if let object = try? readObject(sha: $0.sha) {
                    return object.identifier == .tree
                }
                return false
                }).count
            let subtreeCache = CacheTree(entryCount: subtree.leafs.count, subtreeCount: subtreeCount, pathName: key, sha: sha)
            if let index = self.index.cacheTrees.firstIndex(where: { $0.pathName == key}) {
                self.index.cacheTrees[index] = subtreeCache
            }
            tree.leafs.append(subtreeLeaf)
        }

        for fileEntry in fileEntries {
            let leaf = GitTreeLeaf(mode: fileEntry.mode, path: convertPathComponents(from: fileEntry.pathName, baseComponents: pathComponents).last!, sha: fileEntry.sha)
            tree.leafs.append(leaf)
        }

        return tree
    }

    public mutating func stageObject(fileURL: URL, sha: String) throws {
        let entryPathComponents = try self.computeSubPathComponents(from: fileURL, base: workTreeURL)
        let pathName = entryPathComponents.joined(separator: "/")

        let attr = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        guard
            let createdAt = attr[.creationDate] as? Date,
            let updatedAt = attr[.modificationDate] as? Date,
            let inode = attr[.systemNumber] as? Int,
            let dev = attr[.systemNumber] as? Int,
            let posixPermission = attr[.posixPermissions] as? Int,
            let gid = attr[.groupOwnerAccountID] as? Int,
            let uid = attr[.ownerAccountID] as? Int,
            let size = attr[.size] as? UInt64 else {
                throw GiftKitError.failedReadFileAttributes
        }
        // TODO: Support object type
        // https://github.com/gitster/git/blob/master/Documentation/technical/index-format.txt#L63
        // 1000 regular file
        // 1010 (symbolic link)
        // 1100 (git link)
        let mode = "100" + String(posixPermission, radix: 8)
        let assumeValidFlag = false
        let extendedFlag = false
        let stageFlag = 0

        let entry = CacheEntry(createdAt: createdAt,
                               caretedAtNanosecond: 0, // TODO: Fix nanosec
                               updatedAt: updatedAt,
                               updatedAtNanosecond: 0, // TODO: Fix nanosec
                               deviceID: dev,
                               inode: inode,
                               mode: mode,
                               uid: uid,
                               gid: gid,
                               size: size,
                               sha: sha,
                               assumeValidFlag: assumeValidFlag,
                               extendedFlag: extendedFlag,
                               stageFlag: stageFlag,
                               nameLength: pathName.count,
                               pathName: pathName)

        if let cachedEntryIndex = self.index.cacheEntries.firstIndex(where: { $0.pathName == entry.pathName }) {
            self.index.cacheEntries.remove(at: cachedEntryIndex)
            self.index.cacheEntries.append(entry)
            self.index.cacheEntries.sort { $0.pathName < $1.pathName }
            try self.updateCachedTree(entryPathComponents: [String](entryPathComponents))
        } else {
            self.index.cacheEntries.append(entry)
            self.index.cacheEntries.sort { $0.pathName < $1.pathName }
            try self.updateCachedTree(entryPathComponents: [String](entryPathComponents))
        }

        try self.index.write()
    }

    public func resolveObject(name: String) throws -> [String] {
        func isHash(string: String) -> Bool {
            let pattern = "^[0-9A-Fa-f]{1,40}$"
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
            let matches = regex.matches(in: string, range: NSRange(location: 0, length: string.count))
            return matches.count > 0
        }

        /*
        Resolve name to an object hash in repo.

        This function is aware of:

        - the HEAD literal
        - short and long hashes
        - tags
        - branches
        - remote branches
        */

        var candidates = [String]()
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            return []
        }

        if name == "HEAD" {
            return [try resolveReference(pathComponents: ["HEAD"])]
        }

        if isHash(string: name) {
            if name.count == 40 {
                // This is a complete hash
                return [name.lowercased()]
            } else if name.count >= 4 {
                /*
                This is a small hash 4 seems to be the minimal length
                for git to consider something a short hash.
                This limit is documented in man git-rev-parse
                */

                let minHash = name.lowercased()
                let prefix = String(minHash.prefix(2))
                if let path = try computeSubDirectoryPathFromPathComponents(["objects", prefix], withMakeDirectory: false) {
                    let suffix = name.dropFirst(2)

                    let files = try path.contents().map { $0.lastPathComponent }.filter { $0.starts(with: suffix)}.map { prefix + $0 }

                    candidates += files
                }
            }
        }

        return candidates
    }

    public func createTag(name: String, reference: String, withActuallyCreate createTagObject: Bool) throws {

        let sha = try findObject(name: reference)
        
        if createTagObject {
            var tag = try GitTag(repository: self, data: nil)
            var kvlm = [(key: String, value: Any)]()

            kvlm.append((key: "object", value: sha))
            kvlm.append((key: "type", value: "commit"))
            kvlm.append((key: "tag", value: name))

            guard let tagger = author else {
                throw GiftKitError.gitAccountNotFound
            }
            kvlm.append((key: "tagger", value: "\(tagger.name) <\(tagger.email)>"))
            kvlm.append((key: "", value: "This is the commit message that should have come from the user\n"))
            tag.kvlm = kvlm
            let tagSHA = try writeObject(tag)
            try createReference(pathComponents: ["tags", name], sha: tagSHA)
        } else {
            try createReference(pathComponents: ["tags", name], sha: sha)
        }
    }

    public func createReference(pathComponents: [String], sha: String) throws {
        guard let filePath = try computeSubFilePathFromPathComponents(["refs"] + pathComponents) else {
            throw GiftKitError.failedResolvingSubpathName(pathComponents: ["refs"] + pathComponents)
        }
        let fileObject = sha + "\n"
        try fileObject.write(to: filePath, atomically: true, encoding: .utf8)
    }

    public func getReferenceList(pathComponents: [String] = []) throws -> [String: Any] {
        let referencePath: URL
        if pathComponents.isEmpty {
            guard let refPath = try computeSubDirectoryPathFromPathComponents(["refs"]) else {
                throw GiftKitError.failedResolvingSubpathName(pathComponents: ["refs"])
            }
            referencePath = refPath
        } else {
            referencePath = self.gitDirectoryURL.appendingPathComponents(pathComponents: pathComponents)
        }

        var result = [String: Any]()

        for fileURL in try referencePath.contents().sorted(by: { $0.path < $1.path }) {
            let pathComponents = try computeSubPathComponents(from: fileURL, base: gitDirectoryURL)
            if fileURL.isDirectory {
                result[fileURL.lastPathComponent] = try getReferenceList(pathComponents: pathComponents)
            } else {
                result[fileURL.lastPathComponent] = try resolveReference(pathComponents: pathComponents)
            }
        }

        return result
    }

    public func resolveReference(pathComponents: [String]) throws -> String {
        guard let fileURL = try self.computeSubFilePathFromPathComponents(pathComponents) else {
            throw GiftKitError.failedResolvingSubpathName(pathComponents: pathComponents)
        }
        let refText = try String(contentsOf: fileURL).replacingOccurrences(of: "\n", with: "")

        if refText.starts(with: "ref: ") {
            return try resolveReference(pathComponents: [refText.replacingOccurrences(of: "ref: ", with: "")])
        } else {
            return refText
        }
    }

    public func hashObject(fileURL: URL, type: GitObjectType, withActuallyWrite actuallyWrite: Bool) throws -> String {

        var repository: Repository? = nil
        if actuallyWrite {
            repository = self
        }

        let fileData = try Data(contentsOf: fileURL, options: [])

        let object: GitObject
        switch type {
        case .commit:
            object = try GitCommit(repository: repository, data: fileData)
        case .tree:
            object = try GitTree(repository: repository, data: fileData)
        case .tag:
            object = try GitTag(repository: repository, data: fileData)
        case .blob:
            object = try GitBlob(repository: repository, data: fileData)
        }

        return try self.writeObject(object, withActuallyWrite: actuallyWrite)
    }

    public func writeObject(_ object: GitObject, withActuallyWrite actuallyWrite: Bool = true) throws -> String {
        // Serialize object data
        let data = try object.serialize()
        let byteArray = [UInt8](data)
        guard let objectFormatData = object.identifier.rawValue.data(using: .utf8), let dataSizeData = String(byteArray.count).data(using: .utf8) else {
            throw GiftKitError.failedWriteGitObject
        }

        let objectFormat = [UInt8](objectFormatData)
        let dataSize = [UInt8](dataSizeData)
        // Add header
        let result = Data(bytes: objectFormat + [0x20] + dataSize + [0x00] + byteArray)
        let sha = result.sha1()

        if actuallyWrite {
            guard let fileURL = try self.computeSubFilePathFromPathComponents(["objects", String(sha.prefix(2)), String(sha.suffix(sha.count - 2))], withMakeDirectory: true) else {
                throw GiftKitError.failedResolvingSubpathName(pathComponents: ["objects", String(sha.prefix(2)), String(sha.suffix(sha.count - 2))])
            }

            guard let fileObject = result.zip() else {
                throw GiftKitError.failedCompressedObjectData
            }
            try fileObject.write(to: fileURL, options: .atomicWrite)
        }

        return sha
    }

    public func readObject<T: GitObject>(type: T.Type, sha: String) throws -> T {
        guard let castedObject = try readObject(sha: sha) as? T else {
            throw GiftKitError.failedGitObjectTypeCast
        }
        return castedObject
    }

    public func readObject(sha: String) throws -> GitObject {
        // .git/objects/e5/e11e0360d9534b0d3f65085df7c62d8fb8a82b
        // take prefix(2) to make directory (e5)
        guard let fileURL = try self.computeSubFilePathFromPathComponents(["objects", String(sha.prefix(2)), String(sha.suffix(sha.count - 2))]) else {
            throw GiftKitError.failedResolvingSubpathName(pathComponents: ["objects", String(sha.prefix(2)), String(sha.suffix(sha.count - 2))])
        }

        let binaryData = try Data(contentsOf: fileURL, options: [])
        guard let data = binaryData.unzip() else {
            throw GiftKitError.failedDecompressedObjectData
        }

        // commit 176.tree
        // 636f 6d6d 6974 2031 3736 0074 7265 6520
        let dataBytes = [UInt8](data)

        // 0x00 NUL (Null string)
        // 0x20 Control character (space)
        guard let firstSpaceCharacterIndex = dataBytes.firstIndex(of: 0x20),
            let firstNullStringIndex = dataBytes.firstIndex(of: 0x00, skip: firstSpaceCharacterIndex),
            let format = String(bytes: Array(dataBytes.prefix(firstSpaceCharacterIndex)), encoding: .utf8),
            let sizeString = String(bytes: dataBytes[firstSpaceCharacterIndex + 1..<firstNullStringIndex], encoding: .utf8),
            let size = Int(sizeString)
            else {
            throw GiftKitError.failedDecompressedObjectData
        }

        if size != dataBytes.count - firstNullStringIndex - 1 {
            throw GiftKitError.mulformedObject(sha: sha)
        }

        guard let type = GitObjectType(rawValue: format) else {
            throw GiftKitError.unknownFormatType(format: format, sha: sha)
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
        let objectData = Data(bytes: dataBytes.dropFirst(firstNullStringIndex+1))
        let gitObject = try gitObjectMetaType.init(repository: self, data: objectData)

        return gitObject
    }

    public func findObject(name: String, type: GitObjectType? = nil, follow: Bool = true) throws -> String {
        let shaList = try resolveObject(name: name)

        if shaList.isEmpty {
            throw GiftKitError.noObjectReference(name: name)
        }
        if shaList.count > 1 {
            throw GiftKitError.ambiguousObjectReference(message: "Ambiguous reference \(name): Candidates are:\n - \(shaList.joined(separator: "\n - ")).")
        }

        var sha = shaList.first!

        guard let type = type else {
            return sha
        }

        while true {
            let object = try readObject(sha: sha)

            if object.identifier == type {
                return sha
            }

            if !follow {
                return ""
            }

            if let tag = object as? GitTag {
                guard let shaObject = tag.kvlm.first(where: { $0.key == "object" })?.value as? String else {
                    throw GiftKitError.failedKVLMTypeCast
                }
                sha = shaObject
            } else if let commit = object as? GitCommit, type == .tree {
                guard let shaObject = commit.kvlm.first(where: { $0.key == "tree" })?.value as? String else {
                    throw GiftKitError.failedKVLMTypeCast
                }
                sha = shaObject
            } else {
                return ""
            }
        }
    }

    private mutating func updateCachedTree(entryPathComponents: [String]) throws {
        var updatedSHAList = [String]()
        var components = [""] + [String](entryPathComponents)

        if let rootTreeSHA = self.index.cacheTrees.first?.sha {
            updatedSHAList.append(rootTreeSHA)
        }

        for cacheTree in index.cacheTrees {
            if components.count == 1 {
                components.removeAll()
            }
            if cacheTree.pathName == components.first {
                components = [String](components.dropFirst())
                if let sha = cacheTree.sha {
                    updatedSHAList.append(sha)
                }
            }
        }

        self.index.cacheTrees = self.index.cacheTrees.map { tree in
            if let sha = tree.sha {
                if updatedSHAList.contains(sha) {
                    return CacheTree(entryCount: tree.entryCount, subtreeCount: tree.subtreeCount, pathName: tree.pathName, sha: nil)
                } else {
                    return tree
                }
            } else {
                return tree
            }
        }
    }

    private func convertPathComponents(from pathName: String, baseComponents: [String]) -> [String] {
        var components = pathName.split(separator: "/").map { String($0) }
        for baseComponent in baseComponents {
            if let first = components.first, baseComponent == first {
                components = Array(components.dropFirst())
            }
        }
        return components
    }

    private func computeSubPathComponents(from subpath: URL, base: URL) throws -> [String] {
        let basePathComponents = base.pathComponents
        var subPathComponents = subpath.pathComponents

        for component in basePathComponents {
            if let first = subPathComponents.first, component == first {
                subPathComponents = Array(subPathComponents.dropFirst())
            } else {
                throw GiftKitError.failedResolvingSubpathName(pathComponents: subPathComponents)
            }
        }
        return subPathComponents
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
                throw GiftKitError.isNotDirectory(url: path)
            }
        }

        if withMakeDirectory {
            try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true, attributes: nil)
            return path
        }
        return nil
    }
    
}
