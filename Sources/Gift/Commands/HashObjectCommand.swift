//
//  HashObjectCommand.swift
//  Commandant
//
//  Created by AtsuyaSato on 2019/04/29.
//

import Foundation
import Result
import Commandant
import Curry
import GiftKit

struct HashObjectCommand: CommandProtocol {
    typealias Options = HashObjectoptions
    typealias ClientError = Options.ClientError

    let verb = "hash-object"
    let function = "Compute object ID and optionally creates a blob from a file"

    func run(_ options: HashObjectCommand.Options) -> Result<(), HashObjectCommand.ClientError> {
        let fileURL = URL(fileURLWithPath: options.path)
        guard let type = options.type else {
            fatalError("Type argument is invalid")
        }

        let repository: Repository
        do {
            repository = try Repository.find()
        } catch let error {
            fatalError(error.localizedDescription)
        }

        do {
            let sha = try repository.hashObject(fileURL: fileURL, type: type, withActuallyWrite: options.write)
            print(sha)
        } catch let error {
            fatalError(error.localizedDescription)
        }
        return .success(())
    }
}

struct HashObjectoptions: OptionsProtocol {
    typealias ClientError = CommandantError<()>
    let type: GitObjectType?
    let write: Bool
    let path: String

    public static func evaluate(_ m: CommandMode) -> Result<HashObjectoptions, CommandantError<HashObjectoptions.ClientError>> {
        return curry(self.init)
            <*> m <| Option(key: "type", defaultValue: .blob, usage: "Specify the type [blob, commit, tag, tree], default blob")
            <*> m <| Option(key: "write", defaultValue: false, usage: "Actually write the object into the database")
            <*> m <| Argument(usage: "Read object from <file>")
    }
}
