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
            return .failure(CommandantError.usageError(description: error.localizedDescription))
        }

        showReference(refs, repository: repository, prefix:"refs")

        return .success(())
    }

    func showReference(_ refs: [String: Any], repository: Repository, withHash: Bool = true, prefix: String = "") {
        for (key, value) in refs {
            var spacer = ""
            if withHash {
                spacer = " "
            }
            var separator = ""
            if !prefix.isEmpty {
                separator = "/"
            }

            if let string = value as? String {
                print("\(string)\(spacer)\(prefix)\(separator)\(key)")
            } else {
                if let refs = value as? [String: Any] {
                    showReference(refs, repository: repository, withHash: withHash, prefix: "\(prefix)\(separator)\(key)")
                }
            }
        }
    }
}


