import Foundation
import Testing
@testable import LauncherCore

/// An app whose launcher.json offers these game languages (nil: no launcher.json at all).
private func makeApp(languages: [String]?, default fallback: String = "en-US") throws -> URL {
    let app = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("Juego.app")
    let dm = app.appendingPathComponent("Contents/Resources/dm")
    try FileManager.default.createDirectory(at: dm, withIntermediateDirectories: true)
    guard let languages else { return app }
    let json: [String: Any] = [
        "schema": 1,
        "settings": [
            ["env": "DM_FPS_TARGET", "default": "60", "options": [["30", "30 fps"], ["60", "60 fps"]]],
            ["env": "DM_LANG", "default": fallback, "options": languages.map { [$0, $0] }],
        ],
    ]
    try JSONSerialization.data(withJSONObject: json).write(to: dm.appendingPathComponent("launcher.json"))
    return app
}

private let command = #"open --env DM_LANG=es-419 --env DM_FULLSCREEN=1 "Juego.app""#

@Test func unsupportedRegionFallsBackToSameLanguage() throws {
    // DRAGON QUEST XI S: Spanish, but only Spain's
    let app = try makeApp(languages: ["en-US", "en-GB", "fr", "de", "es", "it", "ko", "zh-Hant", "zh-Hans"])
    #expect(GameLanguage.adjusted(command, app: app)
        == #"open --env DM_LANG=es --env DM_FULLSCREEN=1 "Juego.app""#)
}

@Test func supportedLanguageIsKept() throws {
    let app = try makeApp(languages: ["en-US", "es-419", "es"])
    #expect(GameLanguage.adjusted(command, app: app) == command)
}

@Test func missingLanguageUsesTheAppDefault() throws {
    let app = try makeApp(languages: ["ja", "en-US", "fr"], default: "en-US")
    #expect(GameLanguage.adjusted(command, app: app)
        == #"open --env DM_LANG=en-US --env DM_FULLSCREEN=1 "Juego.app""#)
}

@Test func appWithoutLauncherJSONKeepsCommand() throws {
    let app = try makeApp(languages: nil)
    #expect(GameLanguage.adjusted(command, app: app) == command)
}

@Test func commandWithoutLanguageIsUntouched() throws {
    let app = try makeApp(languages: ["es"])
    let plain = #"open "Juego.app""#
    #expect(GameLanguage.adjusted(plain, app: app) == plain)
}

@Test func noAppKeepsCommand() {
    #expect(GameLanguage.adjusted(command, app: nil) == command)
}

@Test func otherRegionsSwapBothWays() {
    #expect(GameLanguage.choose("es", options: ["es-419"], fallback: nil) == "es-419")
    #expect(GameLanguage.choose("fr-CA", options: ["fr"], fallback: nil) == "fr")
    #expect(GameLanguage.choose("pt-BR", options: ["en-US", "pt"], fallback: nil) == "pt")
    #expect(GameLanguage.choose("en-US", options: ["ja", "en-GB"], fallback: "ja") == "en-GB")
}

@Test func chineseScriptsAreNotMixed() {
    #expect(GameLanguage.choose("zh-TW", options: ["zh-Hans", "zh-Hant"], fallback: nil) == "zh-Hant")
    #expect(GameLanguage.choose("zh-Hant", options: ["en-US", "zh-Hans"], fallback: "en-US") == "en-US")
}
