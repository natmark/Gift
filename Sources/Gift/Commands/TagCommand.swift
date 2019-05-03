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
        } catch let error as GiftKitError {
            return .failure(error)
        } catch let error {
            return .failure(.unknown(message: error.localizedDescription))
        }

        if !options.name.isEmpty {
            do {
                try repository.createTag(name: options.name, reference: options.object, withActuallyCreate: options.createTagObject)
            } catch let error as GiftKitError {
                return .failure(error)
            } catch let error {
                return .failure(.unknown(message: error.localizedDescription))
            }
        } else {
            do {
                let refs = try repository.getReferenceList()
                guard let tags = refs["tags"] as? [String: Any] else {
                    fatalError("Cannot load refs[\"tags\"]")
                }
                GitReference.show(references: tags, repository: repository)
            } catch let error as GiftKitError {
                return .failure(error)
            } catch let error {
                return .failure(.unknown(message: error.localizedDescription))
            }
        }
        return .success(())
    }
}

struct TagOptions: OptionsProtocol {
    typealias ClientError = GiftKitError
    let createTagObject: Bool
    let name: String
    let object: String

    public static func evaluate(_ m: CommandMode) -> Result<TagOptions, CommandantError<TagOptions.ClientError>> {
        return curry(self.init)
            <*> m <| Option(key: "a", defaultValue: false, usage: "Whether to create a tag object")
            <*> m <| Argument(defaultValue: "", usage: "The new tag's name", usageParameter: "tag")
            <*> m <| Argument(defaultValue: "HEAD", usage: "The object the new tag will point to", usageParameter: "object")
    }
}
