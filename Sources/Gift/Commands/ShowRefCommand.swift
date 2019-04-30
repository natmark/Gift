//
//  ShowRefCommand.swift
//  Commandant
//
//  Created by AtsuyaSato on 2019/04/30.
//

import Foundation
import Result
import Commandant
import Curry
import GiftKit

struct ShowRefCommand: CommandProtocol {
    typealias Options = NoOptions<CommandantError<()>>
    typealias ClientError = Options.ClientError

    let verb = "show-ref"
    let function = "List references."

    func run(_ options: ShowRefCommand.Options) -> Result<(), ShowRefCommand.ClientError> {
        let repository: Repository
        let refs: [String: Any]

        do {
            repository = try Repository.find()
            refs = try repository.getReferenceList()
        } catch let error {
            fatalError(error.localizedDescription)
        }

        GitReference.show(references: refs, repository: repository, prefix:"refs")

        return .success(())
    }
}


