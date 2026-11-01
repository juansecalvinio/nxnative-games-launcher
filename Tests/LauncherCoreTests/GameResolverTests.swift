import Foundation
import Testing
@testable import LauncherCore

private func makeDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .resolvingSymlinksInPath()
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func addFolder(_ name: String, in directory: URL) throws {
    try FileManager.default.createDirectory(
        at: directory.appendingPathComponent(name),
        withIntermediateDirectories: true
    )
}

private func addFile(_ name: String, in directory: URL) throws {
    try Data().write(to: directory.appendingPathComponent(name))
}

@Test func findsAppInDirectory() throws {
    let dir = try makeDirectory()
    try addFolder("Juego.app", in: dir)
    let game = GameResolver.resolve(GameEntry(name: "J", path: dir.path))
    #expect(game.appURL?.lastPathComponent == "Juego.app")
    #expect(game.isLaunchable)
}

@Test func pathCanPointDirectlyToApp() throws {
    let dir = try makeDirectory()
    try addFolder("Juego.app", in: dir)
    let game = GameResolver.resolve(GameEntry(name: "J", path: dir.appendingPathComponent("Juego.app").path))
    #expect(game.appURL?.lastPathComponent == "Juego.app")
    #expect(game.directory.path == dir.path)
}

@Test func expandsTilde() {
    let game = GameResolver.resolve(GameEntry(name: "J", path: "~/no-existe-\(UUID().uuidString)"))
    #expect(game.directory.path.hasPrefix(NSHomeDirectory()))
}

@Test func trailingSlashWorks() throws {
    let dir = try makeDirectory()
    try addFolder("Juego.app", in: dir)
    let game = GameResolver.resolve(GameEntry(name: "J", path: dir.path + "/"))
    #expect(game.appURL?.lastPathComponent == "Juego.app")
}

@Test func ignoresKeyAndBuildSiblings() throws {
    let dir = try makeDirectory()
    try addFile("A.app.key", in: dir)
    try addFile("A.xci", in: dir)
    try addFolder("0100_build", in: dir)
    try addFolder("X.app", in: dir)
    let game = GameResolver.resolve(GameEntry(name: "J", path: dir.path))
    #expect(game.appURL?.lastPathComponent == "X.app")
}

@Test func apostropheAndSpacesInName() throws {
    let dir = try makeDirectory()
    let name = "The Legend of Zelda - Link's Awakening.app"
    try addFolder(name, in: dir)
    let game = GameResolver.resolve(GameEntry(name: "J", path: dir.path))
    #expect(game.appURL?.lastPathComponent == name)
}

@Test func onlyDirectChildrenAreSearched() throws {
    let dir = try makeDirectory()
    try addFolder("sub/Juego.app", in: dir)
    let game = GameResolver.resolve(GameEntry(name: "J", path: dir.path))
    #expect(game.appURL == nil)
}

@Test func multipleAppsPicksFirstAlphabetically() throws {
    let dir = try makeDirectory()
    try addFolder("B.app", in: dir)
    try addFolder("A.app", in: dir)
    let game = GameResolver.resolve(GameEntry(name: "J", path: dir.path))
    #expect(game.appURL?.lastPathComponent == "A.app")
}

@Test func keyFileAloneIsNotAnApp() throws {
    let dir = try makeDirectory()
    try addFile("X.app.key", in: dir)
    let game = GameResolver.resolve(GameEntry(name: "J", path: dir.path))
    #expect(game.appURL == nil)
    #expect(!game.isLaunchable)
}

@Test func noAppNoCommandIsUnavailable() throws {
    let dir = try makeDirectory()
    let game = GameResolver.resolve(GameEntry(name: "J", path: dir.path))
    #expect(game.unavailableReason == "No se encontró ningún .app en: \(dir.path)")
}

@Test func missingDirectoryIsUnavailable() {
    let path = "/nonexistent/\(UUID().uuidString)"
    let game = GameResolver.resolve(GameEntry(name: "J", path: path))
    #expect(game.unavailableReason == "No se encontró la carpeta: \(path)")
}

@Test func commandWithoutAppIsLaunchable() throws {
    let dir = try makeDirectory()
    let game = GameResolver.resolve(GameEntry(name: "J", path: dir.path, command: "./run"))
    #expect(game.appURL == nil)
    #expect(game.isLaunchable)
}

@Test func missingDirectoryWithCommandIsUnavailable() {
    let path = "/nonexistent/\(UUID().uuidString)"
    let game = GameResolver.resolve(GameEntry(name: "J", path: path, command: "./run"))
    #expect(!game.isLaunchable)
}
