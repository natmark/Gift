//
//  LsTreeCommand.swift
//  Commandant
//
//  Created by AtsuyaSato on 2019/04/30.
//

import Foundation
import Result
import Commandant
import Curry
import GiftKit

struct LsTreeCommand: CommandProtocol {
    typealias Options = LsTreeOptions
    typealias ClientError = Options.ClientError

    let verb = "ls-tree"
    let function = "Pretty-print a tree object."

    func run(_ options: LsTreeCommand.Options) -> Result<(), LsTreeCommand.ClientError> {
        let repository: Repository
        let tree: GitTree
        do {
            repository = try Repository.find()
            tree = try repository.readObject(type: GitTree.self, sha: options.object)
        } catch let error {
            fatalError(error.localizedDescription)
        }

        for leaf in tree.leafs {
            let object: GitObject
            do {
                object = try repository.readObject(sha: leaf.sha)
            } catch let error {
                fatalError(error.localizedDescription)
            }
            print("\(leaf.mode) \(object.identifier.rawValue) \(leaf.sha)\t\(leaf.path)")
        }

        return .success(())
    }
}

struct LsTreeOptions: OptionsProtocol {
    typealias ClientError = CommandantError<()>
    let object: String

    public static func evaluate(_ m: CommandMode) -> Result<LsTreeOptions, CommandantError<LsTreeOptions.ClientError>> {
        return curry(self.init)
            <*> m <| Argument(usage: "The object to show.")
    }
}
