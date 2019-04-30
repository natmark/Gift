//
//  CheckoutCommand.swift
//  Commandant
//
//  Created by AtsuyaSato on 2019/04/30.
//

import Foundation
import Result
import Commandant
import Curry
import GiftKit

struct CheckoutCommand: CommandProtocol {
    typealias Options = CheckoutOptions
    typealias ClientError = Options.ClientError

    let verb = "checkout"
    let function = "Checkout a commit inside of a directory."

    func run(_ options: CheckoutCommand.Options) -> Result<(), CheckoutCommand.ClientError> {
        let repository: Repository
        var object: GitObject
        do {
            repository = try Repository.find()
            object = try repository.readObject(sha: options.commit)
            if object.identifier == .commit {
                object = try repository.readObject(sha: (object as! GitCommit).kvlm["tree"] as! String)
            }
        } catch let error {
            fatalError(error.localizedDescription)
        }

        let path = URL(fileURLWithPath: options.path)
        if path.isExist {
            if !path.isDirectory {
                fatalError("Not a directory \(path.path)")
            }
            if let contents = try? path.contents(), !contents.isEmpty {
                fatalError("Not empty \(path.path)")
            }
        } else {
            do {
                try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true, attributes: nil)
            } catch let error {
                fatalError(error.localizedDescription)
            }
        }

        guard let tree = object as? GitTree else {
            fatalError("\(object.identifier.rawValue) cannot cast to GitTree.")
        }

        do {
            try checkoutTree(tree, repository: repository, path: path)
        } catch let error {
            fatalError(error.localizedDescription)
        }

        return .success(())
    }

    func checkoutTree(_ tree: GitTree, repository: Repository, path: URL) throws {
        for leaf in tree.leafs {
            let object = try repository.readObject(sha: leaf.sha)
            let destinationPath = path.appendingPathComponent(leaf.path)

            if let tree = object as? GitTree {
                try FileManager.default.createDirectory(at: destinationPath, withIntermediateDirectories: true, attributes: nil)
                try checkoutTree(tree, repository: repository, path: destinationPath)
            } else if let blob = object as? GitBlob {
                try blob.blobData.write(to: destinationPath, options: .atomicWrite)
            }
        }
    }
}

struct CheckoutOptions: OptionsProtocol {
    typealias ClientError = CommandantError<()>
    let commit: String
    let path: String

    public static func evaluate(_ m: CommandMode) -> Result<CheckoutOptions, CommandantError<CheckoutOptions.ClientError>> {
        return curry(self.init)
            <*> m <| Argument(usage: "The commit or tree to checkout.")
            <*> m <| Argument(usage: "The EMPTY directory to checkout on.")
    }
}
