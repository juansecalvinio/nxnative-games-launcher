import Foundation
import Testing
@testable import LauncherCore

private actor NoLauncher: GameLaunching {
    func launch(_ game: Game) async throws {}
}

private func makeLibrary(_ apps: [String: String]) throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .resolvingSymlinksInPath()
    for (folder, app) in apps {
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent(folder).appendingPathComponent(app),
            withIntermediateDirectories: true
        )
    }
    return root
}

private func makeConfig(_ json: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("json")
    try Data(json.utf8).write(to: url)
    return url
}

// MARK: GameDiscovery

@Test func discoversFolderWithAppAsReadyToPlayEntry() throws {
    let library = try makeLibrary(["DK": "Donkey Kong.app"])
    let entries = GameDiscovery.newEntries(in: library, existing: [])
    let entry = try #require(entries.first)
    #expect(entries.count == 1)
    #expect(entry.name == "Donkey Kong")
    #expect(entry.path.hasSuffix(library.lastPathComponent + "/DK"))
    #expect(entry.command == "open --env DM_LANG=es-419 --env DM_FULLSCREEN=1 --env DM_LAUNCHER=0 \"Donkey Kong.app\"")
}

@Test func ignoresFolderWithoutApp() throws {
    let library = try makeLibrary(["COMPILANDO": "juego.nsp"])
    #expect(GameDiscovery.newEntries(in: library, existing: []).isEmpty)
}

@Test func ignoresFolderAlreadyInConfig() throws {
    let library = try makeLibrary(["DK": "Donkey Kong.app"])
    let existing = GameEntry(name: "Mi DK", path: library.appendingPathComponent("DK").path + "/")
    #expect(GameDiscovery.newEntries(in: library, existing: [existing]).isEmpty)
}

@Test func ignoresFolderWhoseAppIsAlreadyInConfig() throws {
    let library = try makeLibrary(["DK": "Donkey Kong.app"])
    let path = library.appendingPathComponent("DK/Donkey Kong.app").path
    let existing = GameEntry(name: "Mi DK", path: path)
    #expect(GameDiscovery.newEntries(in: library, existing: [existing]).isEmpty)
}

@Test func discoveredGamesAreSortedByFolder() throws {
    let library = try makeLibrary(["B": "Beta.app", "A": "Alfa.app"])
    #expect(GameDiscovery.newEntries(in: library, existing: []).map(\.name) == ["Alfa", "Beta"])
}

@Test func missingLibraryFindsNothing() {
    let library = URL(fileURLWithPath: "/no/existe/\(UUID().uuidString)")
    #expect(GameDiscovery.newEntries(in: library, existing: []).isEmpty)
}

@Test func discoveredPathUnderHomeUsesTilde() {
    let path = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("x").path
    #expect(GameDiscovery.displayPath(path) == "~/x")
}

@Test func commandEscapesShellCharactersInAppName() {
    #expect(GameDiscovery.command(forApp: "Say \"Hi\" $5.app")
        == "open --env DM_LANG=es-419 --env DM_FULLSCREEN=1 --env DM_LAUNCHER=0 \"Say \\\"Hi\\\" \\$5.app\"")
}

// MARK: ConfigStore.save

@Test func saveKeepsFieldOrderAndReadableSlashes() throws {
    let url = try makeConfig("{}")
    try ConfigStore.save([GameEntry(name: "N", path: "~/a/b", command: "c")], to: url)
    let text = try String(contentsOf: url, encoding: .utf8)
    #expect(text.contains("~/a/b"))
    let name = try #require(text.range(of: "\"name\""))
    let path = try #require(text.range(of: "\"path\""))
    let command = try #require(text.range(of: "\"command\""))
    #expect(name.lowerBound < path.lowerBound && path.lowerBound < command.lowerBound)
}

@Test func saveOmitsMissingCommand() throws {
    let url = try makeConfig("{}")
    let entry = GameEntry(name: "N", path: "/p")
    try ConfigStore.save([entry], to: url)
    #expect(ConfigStore.load(from: url) == .loaded([entry]))
    #expect(try !String(contentsOf: url, encoding: .utf8).contains("command"))
}

// MARK: LauncherModel

@MainActor @Test func newGameIsAppendedToRowAndConfig() throws {
    let library = try makeLibrary(["DK": "Donkey Kong.app"])
    let config = try makeConfig(#"{"games":[{"name":"Viejo","path":"/viejo","command":"true"}]}"#)
    let model = LauncherModel(configURL: config, libraryURL: library, launcher: NoLauncher())
    model.reload()
    #expect(model.games.map(\.name) == ["Viejo", "Donkey Kong"])
    #expect(model.games[1].isLaunchable)
    guard case .loaded(let saved) = ConfigStore.load(from: config) else {
        Issue.record("config no quedó legible")
        return
    }
    #expect(saved.map(\.name) == ["Viejo", "Donkey Kong"])
}

@MainActor @Test func reloadingTwiceDoesNotDuplicateGame() throws {
    let library = try makeLibrary(["DK": "Donkey Kong.app"])
    let config = try makeConfig(#"{"games":[]}"#)
    let model = LauncherModel(configURL: config, libraryURL: library, launcher: NoLauncher())
    model.reload()
    model.reload()
    #expect(model.games.count == 1)
}

@MainActor @Test func invalidConfigIsNotOverwritten() throws {
    let library = try makeLibrary(["DK": "Donkey Kong.app"])
    let broken = "{ esto no es json"
    let config = try makeConfig(broken)
    let model = LauncherModel(configURL: config, libraryURL: library, launcher: NoLauncher())
    model.reload()
    #expect(try String(contentsOf: config, encoding: .utf8) == broken)
    if case .configInvalid = model.state {} else { Issue.record("debería mostrar el error") }
}

@MainActor @Test func missingConfigIsNotCreated() throws {
    let library = try makeLibrary(["DK": "Donkey Kong.app"])
    let config = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let model = LauncherModel(configURL: config, libraryURL: library, launcher: NoLauncher())
    model.reload()
    #expect(!FileManager.default.fileExists(atPath: config.path))
}

@MainActor @Test func modelStartsLoadingAndStopsAfterStart() async throws {
    let library = try makeLibrary(["DK": "Donkey Kong.app"])
    let config = try makeConfig(#"{"games":[]}"#)
    let model = LauncherModel(configURL: config, libraryURL: library, launcher: NoLauncher())
    #expect(model.isLoading)
    #expect(model.games.isEmpty)
    await model.start(minimumDuration: .zero)
    #expect(!model.isLoading)
    #expect(model.games.map(\.name) == ["Donkey Kong"])
}

@MainActor @Test func startWaitsMinimumDuration() async throws {
    let config = try makeConfig(#"{"games":[]}"#)
    let model = LauncherModel(configURL: config, launcher: NoLauncher())
    let clock = ContinuousClock()
    let elapsed = await clock.measure { await model.start(minimumDuration: .milliseconds(200)) }
    #expect(elapsed >= .milliseconds(200))
}

// MARK: Deleted games

@Test func dropsEntryWhoseFolderWasDeleted() throws {
    let library = try makeLibrary(["ZELDA": "Zelda.app"])
    let kept = GameEntry(name: "Zelda", path: library.appendingPathComponent("ZELDA").path)
    let deleted = GameEntry(name: "DK", path: library.appendingPathComponent("DK").path, command: "open x.app")
    #expect(GameDiscovery.removingDeleted(from: [kept, deleted], in: library) == [kept])
}

@Test func dropsEntryWhoseAppWasDeletedFromItsFolder() throws {
    let library = try makeLibrary(["DK": "juego.nsp"])
    let entry = GameEntry(name: "DK", path: library.appendingPathComponent("DK").path, command: "open x.app")
    #expect(GameDiscovery.removingDeleted(from: [entry], in: library).isEmpty)
}

@Test func dropsEntryPointingAtDeletedApp() throws {
    let library = try makeLibrary(["DK": "juego.nsp"])
    let entry = GameEntry(name: "DK", path: library.appendingPathComponent("DK/DK.app").path)
    #expect(GameDiscovery.removingDeleted(from: [entry], in: library).isEmpty)
}

@Test func keepsEntryOutsideLibrary() throws {
    let library = try makeLibrary(["ZELDA": "Zelda.app"])
    let entry = GameEntry(name: "Externo", path: "/Volumes/Disco/Juego", command: "./correr")
    #expect(GameDiscovery.removingDeleted(from: [entry], in: library) == [entry])
}

@Test func keepsEverythingWhenLibraryCannotBeRead() {
    let library = URL(fileURLWithPath: "/no/existe/\(UUID().uuidString)")
    let entry = GameEntry(name: "Zelda", path: library.appendingPathComponent("ZELDA").path)
    #expect(GameDiscovery.removingDeleted(from: [entry], in: library) == [entry])
}

@Test func keepsEntryWhoseFolderCannotBeRead() throws {
    let library = try makeLibrary(["ZELDA": "Zelda.app"])
    let folder = library.appendingPathComponent("ZELDA")
    try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: folder.path)
    defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder.path) }
    let entry = GameEntry(name: "Zelda", path: folder.path)
    #expect(GameDiscovery.removingDeleted(from: [entry], in: library) == [entry])
}

@MainActor @Test func deletedGameLeavesRowAndConfig() throws {
    let library = try makeLibrary(["ZELDA": "Zelda.app"])
    let zelda = library.appendingPathComponent("ZELDA").path
    let gone = library.appendingPathComponent("DK").path
    let config = try makeConfig(#"{"games":[{"name":"DK","path":"\#(gone)","command":"open x.app"},{"name":"Zelda","path":"\#(zelda)"}]}"#)
    let model = LauncherModel(configURL: config, libraryURL: library, launcher: NoLauncher())
    model.reload()
    #expect(model.games.map(\.name) == ["Zelda"])
    #expect(ConfigStore.load(from: config) == .loaded([GameEntry(name: "Zelda", path: zelda)]))
}
