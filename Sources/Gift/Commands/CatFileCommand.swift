//
//  CatFileCommand.swift
//  Commandant
//
//  Created by AtsuyaSato on 2019/04/28.
//

import Foundation
import Result
import Commandant
import Curry
import GiftKit

struct CatFileCommand: CommandProtocol {
    typealias Options = CatFileOptions
    typealias ClientError = Options.ClientError

    let verb = "cat-file"
    let function = "Provide content of repository objects"

    func run(_ options: CatFileCommand.Options) -> Result<(), CatFileCommand.ClientError> {

        guard let catOperationType = CatOperationType(rawValue: options.operation) else {
            fatalError("Type argument is invalid")
        }

        let repository: Repository
        do {
            repository = try Repository.find()
        } catch let error as GiftKitError {
            return .failure(error)
        } catch let error {
            return .failure(.unknown(message: error.localizedDescription))
        }

        let type = catOperationType.gitObjectType

        do {
            let object = try repository.readObject(sha: repository.findObject(name: options.object, type: type))

            if catOperationType == .size {
                print(try object.serialize().count)
            } else if catOperationType == .type {
                print(object.identifier)
            } else if catOperationType == .preview {
                switch  object.identifier {
                case .blob:
                    print(String(data: (object as! GitBlob).blobData, encoding: .utf8) ?? "")
                case .tag, .commit:
                    printKVLM(kvlm: (object as! KVLMContract).kvlm)
                case .tree:
                    for tree in (object as! GitTree).leafs {
                        print(tree.mode, tree.sha, tree.path)
                    }
                }
            } else {
                switch  object.identifier {
                case .blob:
                    print(String(data: (object as! GitBlob).blobData, encoding: .utf8) ?? "")
                case .tag, .commit:
                    printKVLM(kvlm: (object as! KVLMContract).kvlm)
                case .tree:
                    print(String(data: try object.serialize(), encoding: .ascii) ?? "")
                }
            }
        } catch let error as GiftKitError {
            return .failure(error)
        } catch let error {
            return .failure(.unknown(message: error.localizedDescription))
        }

        return .success(())
    }

    private func printKVLM(kvlm: [(key: String, value: Any)]) {
        for key in kvlm.map({ $0.key }) {
            if key == "" {
                continue
            }

            var values: [String] = kvlm.first(where: { $0.key == key})?.value as? [String]
                ?? []

            if values.isEmpty {
                if let value = kvlm.first(where: { $0.key == key})?.value as? String {
                    values = [value]
                }
            }

            print(key, values.joined(separator: " "))
        }

        print()
        if let message = kvlm.first(where: { $0.key == ""})?.value as? String {
            print(message)
        }
    }
}

enum CatOperationType: String {
    case blob
    case commit
    case tree
    case tag
    case type
    case size
    case preview

    var gitObjectType: GitObjectType? {
        switch self {
        case .blob:
            return .blob
        case .commit:
            return .commit
        case .tree:
            return .tree
        case .tag:
            return .tag
        case .type, .size, .preview:
            return nil
        }
    }
}

struct CatFileOptions: OptionsProtocol {
    typealias ClientError = GiftKitError
    let operation: String
    let object: String

    public static func evaluate(_ m: CommandMode) -> Result<CatFileOptions, CommandantError<CatFileOptions.ClientError>> {
        return curry(self.init)
            <*> m <| Argument(usage: "Specify the type [blob, commit, tag, tree] or option [type, size, preview]")
            <*> m <| Argument(usage: "The object to display")
    }
}
