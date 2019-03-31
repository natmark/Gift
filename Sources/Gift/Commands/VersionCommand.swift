//
//  VersionCommand.swift
//  Commandant
//
//  Created by AtsuyaSato on 2019/03/31.
//

import Result
import Commandant

public struct Version {
    public let value: String
    public static let current = Version(value: "0.0.1")
}

struct VersionCommand: CommandProtocol {
    let verb = "version"
    let function = "Display the current version of Gift"

    func run(_ options: NoOptions<CommandantError<()>>) -> Result<(), CommandantError<()>> {
        print(Version.current.value)
        return .success(())
    }
}
