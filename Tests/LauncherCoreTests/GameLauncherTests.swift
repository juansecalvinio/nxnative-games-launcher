import Foundation
import Testing
@testable import LauncherCore

private func makeGame(command: String?) throws -> Game {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .resolvingSymlinksInPath()
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return Game(name: "J", directory: dir, appURL: nil, command: command, unavailableReason: nil)
}

@Test func commandRunsInGameDirectory() async throws {
    let game = try makeGame(command: "pwd > out.txt")
    try await SystemGameLauncher().launch(game)
    let output = try String(contentsOf: game.directory.appendingPathComponent("out.txt"), encoding: .utf8)
    let reported = URL(fileURLWithPath: output.trimmingCharacters(in: .whitespacesAndNewlines))
    #expect(reported.resolvingSymlinksInPath().path == game.directory.path)
}

@Test func commandKeepsShellQuoting() async throws {
    let game = try makeGame(command: #"touch "con espacios's.txt""#)
    try await SystemGameLauncher().launch(game)
    #expect(FileManager.default.fileExists(atPath: game.directory.appendingPathComponent("con espacios's.txt").path))
}

@Test func failingCommandThrows() async throws {
    let game = try makeGame(command: "echo no >&2; exit 3")
    await #expect(throws: LaunchError.commandFailed(code: 3, output: "no")) {
        try await SystemGameLauncher().launch(game)
    }
}

@Test func longRunningCommandReturns() async throws {
    let game = try makeGame(command: "sleep 30")
    let start = ContinuousClock.now
    try await SystemGameLauncher(failureWindow: .milliseconds(200)).launch(game)
    #expect(ContinuousClock.now - start < .seconds(2))
}

@Test func noAppNoCommandThrows() async throws {
    let game = try makeGame(command: nil)
    await #expect(throws: LaunchError.nothingToLaunch) {
        try await SystemGameLauncher().launch(game)
    }
}
