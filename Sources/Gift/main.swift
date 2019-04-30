import Foundation
import Commandant

let registry = CommandRegistry<CommandantError<()>>()
registry.register(VersionCommand())
registry.register(InitCommand())
registry.register(CatFileCommand())
registry.register(HashObjectCommand())
registry.register(LogCommand())
registry.register(LsTreeCommand())
registry.register(CheckoutCommand())
registry.register(ShowRefCommand())
registry.register(TagCommand())
registry.register(RevParseCommand())

let helpCommand = HelpCommand(registry: registry)
registry.register(helpCommand)

registry.main(defaultVerb: helpCommand.verb) { error in
    fputs(error.localizedDescription + "\n", stderr)
}
