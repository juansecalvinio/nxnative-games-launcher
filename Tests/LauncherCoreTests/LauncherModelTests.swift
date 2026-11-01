import Foundation
import Testing
@testable import LauncherCore

private actor FakeLauncher: GameLaunching {
    private(set) var launched: [String] = []
    private let error: LaunchError?
    private let delay: Duration

    init(error: LaunchError? = nil, delay: Duration = .zero) {
        self.error = error
        self.delay = delay
    }

    func launch(_ game: Game) async throws {
        launched.append(game.name)
        try await Task.sleep(for: delay)
        if let error { throw error }
    }
}

private func writeConfig(_ games: [(name: String, command: String?)], to url: URL? = nil) throws -> URL {
    let url = url ?? FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("json")
    let entries = games.map { game -> [String: String] in
        var entry = ["name": game.name, "path": NSTemporaryDirectory()]
        entry["command"] = game.command
        return entry
    }
    try JSONSerialization.data(withJSONObject: ["games": entries]).write(to: url)
    return url
}

private func threeGames() throws -> URL {
    try writeConfig([("A", "true"), ("B", "true"), ("C", "true")])
}

@MainActor @Test func moveStopsAtEdges() throws {
    let model = LauncherModel(configURL: try threeGames(), launcher: FakeLauncher())
    model.moveLeft()
    #expect(model.selectedIndex == 0)
    model.moveRight()
    model.moveRight()
    model.moveRight()
    #expect(model.selectedIndex == 2)
}

@MainActor @Test func moveWithNoGamesDoesNotCrash() throws {
    let model = LauncherModel(configURL: try writeConfig([]), launcher: FakeLauncher())
    model.moveRight()
    model.moveLeft()
    #expect(model.selectedGame == nil)
    #expect(model.state == .ready)
}

@MainActor @Test func confirmLaunchesSelected() async throws {
    let launcher = FakeLauncher()
    let model = LauncherModel(configURL: try threeGames(), launcher: launcher)
    model.moveRight()
    await model.confirm()
    #expect(await launcher.launched == ["B"])
}

@MainActor @Test func confirmOnUnavailableShowsReason() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try #"{"games":[{"name":"X","path":"/nonexistent/x"}]}"#.write(to: url, atomically: true, encoding: .utf8)
    let launcher = FakeLauncher()
    let model = LauncherModel(configURL: url, launcher: launcher)
    await model.confirm()
    #expect(model.message == "No se encontró la carpeta: /nonexistent/x")
    #expect(await launcher.launched.isEmpty)
}

@MainActor @Test func launchFailureShowsMessage() async throws {
    let error = LaunchError.commandFailed(code: 1, output: "x")
    let model = LauncherModel(configURL: try threeGames(), launcher: FakeLauncher(error: error))
    await model.confirm()
    #expect(model.message == error.errorDescription)
    #expect(model.state == .ready)
}

@MainActor @Test func doubleConfirmLaunchesOnce() async throws {
    let launcher = FakeLauncher(delay: .milliseconds(100))
    let model = LauncherModel(configURL: try threeGames(), launcher: launcher)
    async let first: Void = model.confirm()
    async let second: Void = model.confirm()
    _ = await (first, second)
    #expect(await launcher.launched.count == 1)
}

@MainActor @Test func confirmWhileMessageDismisses() async throws {
    let launcher = FakeLauncher()
    let model = LauncherModel(configURL: try threeGames(), launcher: launcher)
    model.message = "aviso"
    await model.confirm()
    #expect(model.message == nil)
    #expect(await launcher.launched.isEmpty)
}

@MainActor @Test func reloadClampsSelection() throws {
    let url = try threeGames()
    let model = LauncherModel(configURL: url, launcher: FakeLauncher())
    model.moveRight()
    model.moveRight()
    _ = try writeConfig([("A", "true")], to: url)
    model.reload()
    #expect(model.selectedIndex == 0)
    #expect(model.games.count == 1)
}

@MainActor @Test func reloadKeepsSelectionInRange() throws {
    let model = LauncherModel(configURL: try threeGames(), launcher: FakeLauncher())
    model.moveRight()
    model.reload()
    #expect(model.selectedIndex == 1)
}

@MainActor @Test func missingConfigState() {
    let url = URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString).json")
    let model = LauncherModel(configURL: url, launcher: FakeLauncher())
    #expect(model.state == .configMissing(url))
}

@MainActor @Test func invalidConfigState() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try "{".write(to: url, atomically: true, encoding: .utf8)
    let model = LauncherModel(configURL: url, launcher: FakeLauncher())
    guard case .configInvalid(let reported, let message) = model.state else {
        Issue.record("expected .configInvalid")
        return
    }
    #expect(reported == url)
    #expect(!message.isEmpty)
}

private func writeAppConfig() throws -> (config: URL, app: URL) {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .resolvingSymlinksInPath()
    let app = dir.appendingPathComponent("Link's Game.app")
    try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
    let config = dir.appendingPathComponent("games.json")
    let entry = ["name": "G", "path": dir.path]
    try JSONSerialization.data(withJSONObject: ["games": [entry]]).write(to: config)
    return (config, app)
}

@MainActor @Test func launchedGameTerminationIsReported() async throws {
    let (config, app) = try writeAppConfig()
    let model = LauncherModel(configURL: config, launcher: FakeLauncher())
    await model.confirm()
    #expect(model.didLaunchedGameTerminate(at: app))
}

@MainActor @Test func terminationIsReportedOnce() async throws {
    let (config, app) = try writeAppConfig()
    let model = LauncherModel(configURL: config, launcher: FakeLauncher())
    await model.confirm()
    _ = model.didLaunchedGameTerminate(at: app)
    #expect(!model.didLaunchedGameTerminate(at: app))
}

@MainActor @Test func unrelatedAppTerminationIsIgnored() async throws {
    let (config, _) = try writeAppConfig()
    let model = LauncherModel(configURL: config, launcher: FakeLauncher())
    await model.confirm()
    #expect(!model.didLaunchedGameTerminate(at: URL(fileURLWithPath: "/Applications/Safari.app")))
}

@MainActor @Test func gameNeverLaunchedIsIgnored() throws {
    let (config, app) = try writeAppConfig()
    let model = LauncherModel(configURL: config, launcher: FakeLauncher())
    #expect(!model.didLaunchedGameTerminate(at: app))
}

@MainActor @Test func failedLaunchIsNotTracked() async throws {
    let (config, app) = try writeAppConfig()
    let model = LauncherModel(configURL: config, launcher: FakeLauncher(error: .nothingToLaunch))
    await model.confirm()
    #expect(!model.didLaunchedGameTerminate(at: app))
}
