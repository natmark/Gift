//
//  CommitCommand.swift
//  Commandant
//
//  Created by AtsuyaSato on 2019/05/11.
//

import Foundation
import Result
import Commandant
import Curry
import GiftKit

struct CommitCommand: CommandProtocol {
    typealias Options = CommitOptions
    typealias ClientError = Options.ClientError

    let verb = "commit"
    let function = "Record changes to the repository"

    func run(_ options: CommitCommand.Options) -> Result<(), CommitCommand.ClientError> {
        let repository: Repository
        do {
            repository = try Repository.find()
            if let message = options.message {
                try repository.commit(message: message)
            }
        } catch let error as GiftKitError {
            return .failure(error)
        } catch let error {
            return .failure(.unknown(message: error.localizedDescription))
        }

        return .success(())
    }
}

struct CommitOptions: OptionsProtocol {
    typealias ClientError = GiftKitError
    let message: String?

    public static func evaluate(_ m: CommandMode) -> Result<CommitOptions, CommandantError<CommitOptions.ClientError>> {
        return curry(self.init)
            <*> m <| Option(key: "message", defaultValue: nil, usage: "Commit message")
    }
}
