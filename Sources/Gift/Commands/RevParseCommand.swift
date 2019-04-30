//
//  RevParseCommand.swift
//  Commandant
//
//  Created by AtsuyaSato on 2019/04/30.
//

import Foundation
import Result
import Commandant
import Curry
import GiftKit

struct RevParseCommand: CommandProtocol {
    typealias Options = RevParseOptions
    typealias ClientError = Options.ClientError

    let verb = "rev-parse"
    let function = "Parse revision (or other objects )identifiers"

    func run(_ options: RevParseCommand.Options) -> Result<(), RevParseCommand.ClientError> {

        let repository: Repository
        do {
            repository = try Repository.find()
            print(try repository.findObject(name: options.name, type: options.type))
        } catch let error {
            return .failure(CommandantError.usageError(description: error.localizedDescription))
        }
        return .success(())
    }
}

struct RevParseOptions: OptionsProtocol {
    typealias ClientError = CommandantError<()>
    let type: GitObjectType?
    let name: String

    public static func evaluate(_ m: CommandMode) -> Result<RevParseOptions, CommandantError<RevParseOptions.ClientError>> {
        return curry(self.init)
            <*> m <| Option(key: "type", defaultValue: nil, usage: "Specify the expected type")
            <*> m <| Argument(usage: "The name to parse")
    }
}
