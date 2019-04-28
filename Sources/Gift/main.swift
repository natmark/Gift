import Foundation
import Commandant

let registry = CommandRegistry<CommandantError<()>>()
registry.register(VersionCommand())
registry.register(InitCommand())
registry.register(CatFileCommand())

let helpCommand = HelpCommand(registry: registry)
registry.register(helpCommand)

registry.main(defaultVerb: helpCommand.verb) { error in
    fputs(error.localizedDescription + "\n", stderr)
}
