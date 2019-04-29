//
//  LogCommand.swift
//  Commandant
//
//  Created by AtsuyaSato on 2019/04/29.
//

import Foundation
import Result
import Commandant
import Curry
import GiftKit

struct LogCommand: CommandProtocol {
    typealias Options = LogOptions
    typealias ClientError = Options.ClientError

    let verb = "log"
    let function = "Display history of a given commit."

    func run(_ options: LogCommand.Options) -> Result<(), LogCommand.ClientError> {
        let repository: Repository
        do {
            repository = try Repository.find()
        } catch let error {
            return .failure(CommandantError.usageError(description: error.localizedDescription))
        }
        
        printLog(repository: repository, sha: repository.findObject(name: options.commit), loadedSHAList: [])
        return .success(())
    }

    func printLog(repository: Repository, sha: String, loadedSHAList: [String]) {
        var loadedSHAList = loadedSHAList
        if loadedSHAList.contains(sha) {
            return
        }
        loadedSHAList.append(sha)

        guard let object = try? repository.readObject(sha: sha), let commit = object as? GitCommit else {
            return
        }
        if !commit.kvlm.keys.contains("parent") {
            // Base case: the initial commit
            return
        }

        var parents = [String]()
        if let value = commit.kvlm["parent"] as? [String] {
            parents = value
        } else if let value = commit.kvlm["parent"] as? String {
            parents = [value]
        }

        for parent in parents {
            print("c_\(sha) -> c_\(parent)")
            printLog(repository: repository, sha: parent, loadedSHAList: loadedSHAList)
        }
    }
}

struct LogOptions: OptionsProtocol {
    typealias ClientError = CommandantError<()>
    let commit: String

    public static func evaluate(_ m: CommandMode) -> Result<LogOptions, CommandantError<LogOptions.ClientError>> {
        return curry(self.init)
            <*> m <| Option(key: "commit", defaultValue: "HEAD", usage: "Commit to start at.")
    }
}