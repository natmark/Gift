//
//  GiftKitError.swift
//  Commandant
//
//  Created by AtsuyaSato on 2019/04/29.
//

import Foundation

public enum GiftKitError: Error {
    case notGitRepository(String)
    case noGitDirectory
    case configFileMissing
    case unsupportedRepositoryFormatVersion(String)
    case isNotEmpty
    case isNotDirectory
    case failedResolvingSubpathName
    case failedDecompressedObjectData
    case failedCompressedObjectData
    case failedDeserializeGitTreeObject
    case failedSerializeGitTreeObject
    case failedDeserializeGitCommitObject
    case failedSerializeGitCommitObject
    case unknownFormatType(String)
    case mulformedObject(String)
    case unsupportedOSXVersion(String)
    case unknown(String)
}
