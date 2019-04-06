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
    let verb = "version"
    let function = "Display the current version of Gift"

    func run(_ options: NoOptions<CommandantError<()>>) -> Result<(), CommandantError<()>> {
        print(GiftKitVersion.current.value)
        return .success(())
    }
}
