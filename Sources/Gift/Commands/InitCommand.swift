//
//  InitCommand.swift
//  Commandant
//
//  Created by AtsuyaSato on 2019/04/06.
//

import Foundation
import Result
import Commandant
import Curry
import GiftKit

struct InitCommand: CommandProtocol {
    typealias Options = InitOptions
    typealias ClientError = Options.ClientError

    let verb = "init"
    let function = "Create an empty Git repository or reinitialize an existing one"

    func run(_ options: InitCommand.Options) -> Result<(), InitCommand.ClientError> {
        let worktreeURL = URL(fileURLWithPath: options.path)
        do {
            let repository = try RepositoryOperation.createRepository(workTreeURL: worktreeURL)
            print(repository)
        } catch {
            print("Directory is not empty")
        }

        return .success(())
    }
}

struct InitOptions: OptionsProtocol {
    typealias ClientError = CommandantError<()>
    let path: String

    public static func evaluate(_ m: CommandMode) -> Result<InitOptions, CommandantError<InitOptions.ClientError>> {
        return curry(self.init)
            <*> m <| Option(key: "path", defaultValue: FileManager.default.currentDirectoryPath, usage: "Where to create the repository.")
    }
}
