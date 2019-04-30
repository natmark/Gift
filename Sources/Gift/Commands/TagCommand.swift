//
//  TagCommand.swift
//  Commandant
//
//  Created by AtsuyaSato on 2019/04/30.
//

import Foundation
import Result
import Commandant
import Curry
import GiftKit

struct TagCommand: CommandProtocol {
    typealias Options = TagOptions
    typealias ClientError = Options.ClientError

    let verb = "tag"
    let function = "List and create tags."

    func run(_ options: TagCommand.Options) -> Result<(), TagCommand.ClientError> {
        let repository: Repository
        do {
            repository = try Repository.find()
        } catch let error {
            return .failure(CommandantError.usageError(description: error.localizedDescription))
        }

        if let name = options.name {
            do {
                try repository.createTag(name: name, reference: options.object, withActuallyCreate: options.createTagObject)
            } catch let error {
                return .failure(CommandantError.usageError(description: error.localizedDescription))
            }
        } else {
            do {
                let refs = try repository.getReferenceList()
                GitReference.show(references: refs, repository: repository, withHash: false)
            } catch let error {
                return .failure(CommandantError.usageError(description: error.localizedDescription))
            }
        }
        return .success(())
    }
}

struct TagOptions: OptionsProtocol {
    typealias ClientError = CommandantError<()>
    let createTagObject: Bool
    let name: String?
    let object: String

    public static func evaluate(_ m: CommandMode) -> Result<TagOptions, CommandantError<TagOptions.ClientError>> {
        return curry(self.init)
            <*> m <| Option(key: "a", defaultValue: false, usage: "Whether to create a tag object")
            <*> m <| Argument(defaultValue: nil, usage: "The new tag's name", usageParameter: "tag name")
            <*> m <| Argument(defaultValue: "HEAD", usage: "The object the new tag will point to", usageParameter: "object")
    }
}
