import XCTest
import class Foundation.Bundle
@testable import GiftKit

final class GitConfigTests: XCTestCase {
    func testReadConfig() throws {
        let testTargetPath = URL(fileURLWithPath: #file).deletingLastPathComponent()
        let configURL = testTargetPath.appendingPathComponent("SampleConfig")

        let config = GitConfig(from: configURL)
        XCTAssertEqual(config.sections.count, 3)
        XCTAssertEqual(config["core"]?.settings.keys.count, 6)
        XCTAssertEqual(config["core"]?["repositoryformatversion"], "0")
    }

    func testWriteConfig() throws {
        let resourceURL = Bundle(for: type(of: self)).resourceURL!
        var writeURL = resourceURL.appendingPathComponent("TestConfig", isDirectory: false)
        let config = GitConfig()

        config.set(sectionName: "core", key: "repositoryformatversion", value: "0")
        config.set(sectionName: "core", key: "filemode", value: "false")
        config.set(sectionName: "core", key: "bare", value: "false")
        config.set(sectionName: "branch \"master\"", key: "remote", value: "origin")
        config.set(sectionName: "branch \"master\"", key: "merge", value: "refs/heads/master")

        do {
            try config.write(to: writeURL)
        } catch {
            // For Bitrise CI
            writeURL = URL(fileURLWithPath: #file).deletingLastPathComponent().appendingPathComponent("TestConfig")
            try config.write(to: writeURL)
        }

        let loadedConfig = GitConfig(from: writeURL)

        XCTAssertEqual(loadedConfig["core"]?["repositoryformatversion"], "0")
        XCTAssertEqual(loadedConfig["core"]?["filemode"], "false")
        XCTAssertEqual(loadedConfig["core"]?["bare"], "false")
        XCTAssertEqual(loadedConfig["branch \"master\""]?["remote"], "origin")
        XCTAssertEqual(loadedConfig["branch \"master\""]?["merge"], "refs/heads/master")
    }
}
