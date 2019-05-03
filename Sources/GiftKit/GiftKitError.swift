//
//  GiftKitError.swift
//  Commandant
//
//  Created by AtsuyaSato on 2019/04/29.
//

import Foundation

public enum GiftKitError: Error {
    case notGitRepository(path: URL)
    case noGitDirectory
    case noObjectReference(name: String)
    case ambiguousObjectReference(message: String)
    case configFileMissing
    case unsupportedRepositoryFormatVersion(version: String)
    case isNotEmpty(url: URL)
    case isNotDirectory(url: URL)
    case failedWriteGitObject
    case failedReadGitObject
    case failedResolvingSubpathName(pathComponents: [String])
    case failedDecompressedObjectData
    case failedCompressedObjectData
    case failedDeserializeGitTreeObject
    case failedSerializeGitTreeObject
    case failedDeserializeGitCommitObject
    case failedSerializeGitCommitObject
    case failedKVLMTypeCast
    case failedGitObjectTypeCast
    case unknownFormatType(format: String, sha: String)
    case mulformedObject(sha: String)
    case unsupportedOSXVersion
    case unknown(message: String)
}

extension GiftKitError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notGitRepository(let path):
            return "Not a git repository \(path.path)."
        case .noGitDirectory:
            return "No git directory."
        case .noObjectReference(let name):
            return "No such reference \(name)."
        case .ambiguousObjectReference(let string):
            return string
        case .configFileMissing:
            return "Configuration file missing."
        case .unsupportedRepositoryFormatVersion(let version):
            return "Unsupported repositoryformatversion \(version)."
        case .isNotEmpty(let path):
            return "\(path.path) is not empty."
        case .isNotDirectory(let path):
            return "\(path.path) is not a directory."
        case .failedWriteGitObject:
            return "Failed write Git Object."
        case .failedReadGitObject:
            return "Failed read Git Object."
        case .failedResolvingSubpathName(let pathComponents):
            return "Failed resolving subpath:" + pathComponents.joined(separator: "/")
        case .failedDecompressedObjectData:
            return "Failed decompressed object data"
        case .failedCompressedObjectData:
            return "Failed compressed object data"
        case .failedDeserializeGitTreeObject:
            return "Failed Deserialize Git tree object"
        case .failedSerializeGitTreeObject:
            return "Failed Serialize Git tree object"
        case .failedDeserializeGitCommitObject:
            return "Failed Deserialize Git commit object"
        case .failedSerializeGitCommitObject:
            return "Failed Serialize Git commit object"
        case .failedKVLMTypeCast:
            return "Failed KVLM type cast"
        case .failedGitObjectTypeCast:
            return "Failed Git object type cast"
        case .unknownFormatType(let format, let sha):
            return "Unknown type \(format) for object \(sha)."
        case .mulformedObject(let sha):
            return "Malformed object \(sha): bad length."
        case .unsupportedOSXVersion:
            return "Available OS X 10.11 or newer."
        case .unknown(let string):
            return "Unknown Error: \(string)."
        }
    }
}
