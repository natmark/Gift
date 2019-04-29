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
            return .failure(CommandantError.usageError(description: "Type argument is invalid"))
        }

        let repository: Repository
        do {
            repository = try Repository.find()
        } catch let error {
            return .failure(CommandantError.usageError(description: error.localizedDescription))
        }

        let object: GitObject
        do {
            object = try repository.readObject(sha: repository.findObject(name: options.object, type: type))
            print(try object.serialize())
        } catch let error {
            return .failure(CommandantError.usageError(description: error.localizedDescription))
        }

        return .success(())
    }
}

struct CatFileOptions: OptionsProtocol {
    typealias ClientError = CommandantError<()>
    let type: GitObjectType?
    let object: String

    public static func evaluate(_ m: CommandMode) -> Result<CatFileOptions, CommandantError<CatFileOptions.ClientError>> {
        return curry(self.init)
            <*> m <| Argument(usage: "Specify the type [blob, commit, tag, tree]")
            <*> m <| Argument(usage: "The object to display")
    }
}
