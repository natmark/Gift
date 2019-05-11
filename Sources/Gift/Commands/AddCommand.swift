//
//  AddCommand.swift
//  Commandant
//
//  Created by AtsuyaSato on 2019/05/04.
//

import Foundation
import Result
import Commandant
import Curry
import GiftKit

struct AddCommand: CommandProtocol {
    typealias Options = AddOptions
    typealias ClientError = Options.ClientError

    let verb = "add"
    let function = "Add file contents to the index"

    func run(_ options: AddCommand.Options) -> Result<(), AddCommand.ClientError> {
        let repository: Repository
        do {
            repository = try Repository.find()
        } catch let error as GiftKitError {
            return .failure(error)
        } catch let error {
            return .failure(.unknown(message: error.localizedDescription))
        }

        let fileURL = URL(fileURLWithPath: options.path)
        do {
            let binaryData = try Data(contentsOf: fileURL, options: [])
            let object = try GitBlob(repository: repository, data: binaryData)
            let sha = try repository.writeObject(object, withActuallyWrite: true)
            try repository.stageObject(fileURL: fileURL, sha: sha)
        }  catch let error as GiftKitError {
            return .failure(error)
        } catch let error {
            return .failure(.unknown(message: error.localizedDescription))
        }

        return .success(())
    }
}

struct AddOptions: OptionsProtocol {
    typealias ClientError = GiftKitError
    let path: String

    public static func evaluate(_ m: CommandMode) -> Result<AddOptions, CommandantError<AddOptions.ClientError>> {
        return curry(self.init)
            <*> m <| Argument(usage: "Files to add content from.")
    }
}
