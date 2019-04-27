//
//  GitConfig.swift
//  Commandant
//
//  Created by AtsuyaSato on 2019/04/14.
//

import Foundation
import INI

struct GitConfig {
    var sections: [ConfigSection]

    subscript(key: String) -> ConfigSection? {
        return sections.filter { $0.name == key }.first
    }

    init(from configURL: URL? = nil) {
        // Convert INI.Conft to Config
        guard let configURL = configURL, let iniConfig = try? parseINI(filename: configURL.path) else {
            self.sections = []
            return
        }

        self.sections = iniConfig.sections.map { ConfigSection(name: $0.name, settings: $0.settings) }
    }

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

    mutating func set(sectionName: String, key: String, value: String) {
        if sections.filter({ $0.name == sectionName }).count == 0 {
            sections.append(ConfigSection(name: sectionName, settings: [key: value]))
            return
        }

        sections = sections.map({ section -> ConfigSection in
            if(section.name != sectionName) {
                return section
            } else {
                var settings = section.settings
                settings[key] = value
                return ConfigSection(name: section.name, settings: settings)
            }
        })
    }
}

struct ConfigSection {
    let name: String
    var settings: [String: String]

    subscript(key: String) -> String? {
        return settings[key]
    }

    func bool(_ key: String) -> Bool {
        return ["1", "true", "yes"].contains(settings[key] ?? "")
    }
}
