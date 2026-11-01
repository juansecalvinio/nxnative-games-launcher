import Foundation
import Testing
@testable import LauncherCore

private func writeConfig(_ json: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("json")
    try json.write(to: url, atomically: true, encoding: .utf8)
    return url
}

@Test func loadsGamesInFileOrder() throws {
    let url = try writeConfig("""
    {"games":[
      {"name":"B","path":"/b"},
      {"name":"A","path":"/a","command":"open x"}
    ]}
    """)
    #expect(ConfigStore.load(from: url) == .loaded([
        GameEntry(name: "B", path: "/b", command: nil),
        GameEntry(name: "A", path: "/a", command: "open x"),
    ]))
}

@Test func missingFileIsMissing() {
    let url = URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString).json")
    #expect(ConfigStore.load(from: url) == .missing)
}

@Test func malformedJsonIsInvalid() throws {
    let url = try writeConfig("{")
    guard case .invalid(let message) = ConfigStore.load(from: url) else {
        Issue.record("expected .invalid")
        return
    }
    #expect(!message.isEmpty)
}

@Test func entryWithoutPathIsInvalid() throws {
    let url = try writeConfig(#"{"games":[{"name":"x"}]}"#)
    guard case .invalid = ConfigStore.load(from: url) else {
        Issue.record("expected .invalid")
        return
    }
}

@Test func emptyGamesIsLoadedEmpty() throws {
    let url = try writeConfig(#"{"games":[]}"#)
    #expect(ConfigStore.load(from: url) == .loaded([]))
}

@Test func unknownFieldsAreIgnored() throws {
    let url = try writeConfig(#"{"games":[{"name":"x","path":"/x","cover":"y"}],"v":1}"#)
    #expect(ConfigStore.load(from: url) == .loaded([GameEntry(name: "x", path: "/x", command: nil)]))
}

@Test func defaultURLPoints() {
    #expect(ConfigStore.defaultURL.path.hasSuffix("GamesLauncher/games.json"))
}
