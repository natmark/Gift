//
//  VersionCommand.swift
//  Commandant
//
//  Created by AtsuyaSato on 2019/03/31.
//

import Result
import Commandant
import GiftKit

struct VersionCommand: CommandProtocol {
    typealias Options = NoOptions<CommandantError<()>>
    typealias ClientError = CommandantError<()>

    let verb = "version"
    let function = "Display the current version of Gift"

    func run(_ options: VersionCommand.Options) -> Result<(), VersionCommand.ClientError> {
        print(GiftKitVersion.current.value)
        return .success(())
    }
}
