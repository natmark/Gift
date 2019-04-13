//
//  GitConfig.swift
//  Commandant
//
//  Created by AtsuyaSato on 2019/04/14.
//

import Foundation
import INI

class GitConfig {
    var sections: [Section]

    func write(to configURL: URL) throws {
        var fileObject = ""
        for section in sections {
            fileObject += "[\(section.name)]\n"
            for settings in section.settings {
                fileObject += "\t\(settings.key) = \(settings.value)\n"
            }
        }
        try fileObject.write(to: configURL, atomically: true, encoding: .utf8)
    }

    func set(sectionName: String, key: String, value: String) {
        if sections.filter({ $0.name == sectionName }).count == 0 {
            sections.append(Section(name: sectionName, settings: [key: value]))
            return
        }

        for section in sections {
            if section.name == sectionName {
                section.settings[key] = value
            }
        }

        //sections.append(section)
    }

    subscript(key: String) -> Section? {
        return sections.filter { $0.name == key }.first
    }

    init(from configURL: URL? = nil) {
        // Convert INI.Conft to Config
        guard let configURL = configURL, let iniConfig = try? parseINI(filename: configURL.path) else {
            self.sections = []
            return
        }

        var sections = [Section]()
        for section in iniConfig.sections {
            sections.append(Section(name: section.name, settings: section.settings))
        }

        self.sections = sections
    }
}

class Section {
    let name: String
    var settings: [String: String]

    init(name: String, settings: [String: String]) {
        self.name = name
        self.settings = settings
    }

    subscript(key: String) -> String? {
        return settings[key]
    }

    func bool(_ key: String) -> Bool {
        return ["1", "true", "yes"].contains(settings[key] ?? "")
    }
}
