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
        guard let type = options.type else {
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

        let object: GitObject
        do {
            object = try repository.readObject(sha: repository.findObject(name: options.object, type: type))

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
        } catch let error as GiftKitError {
            return .failure(error)
        } catch let error {
            return .failure(.unknown(message: error.localizedDescription))
        }

        return .success(())
    }

    private func printKVLM(kvlm: [String: Any]) {
        for key in kvlm.keys {
            if key == "" {
                continue
            }

            var values: [String] = kvlm[key] as? [String]
                ?? []

            if values.isEmpty {
                if let value = kvlm[key] as? String {
                    values = [value]
                }
            }

            print(key, values.joined(separator: " "))
        }

        print()
        if let message = kvlm[""] as? String {
            print(message)
        }
    }
}

struct CatFileOptions: OptionsProtocol {
    typealias ClientError = GiftKitError
    let type: GitObjectType?
    let object: String

    public static func evaluate(_ m: CommandMode) -> Result<CatFileOptions, CommandantError<CatFileOptions.ClientError>> {
        return curry(self.init)
            <*> m <| Argument(usage: "Specify the type [blob, commit, tag, tree]")
            <*> m <| Argument(usage: "The object to display")
    }
}
