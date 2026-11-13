import Foundation

/// Keeps a launch command's `DM_LANG` to a language the game actually ships.
///
/// nxnative passes `DM_LANG` to the game as the console's language, and a game handed one it lacks
/// can crash at boot (DRAGON QUEST XI S has `es` but not `es-419`). A console never does that: it
/// picks a language the game lists. Each nxnative Mac app lists its game's languages as the options
/// of the `DM_LANG` setting in `Contents/Resources/dm/launcher.json`, so the language is checked
/// against that list and, when it is missing, the same language for another region stands in
/// (`es-419` → `es`), else the app's default.
public enum GameLanguage {
    /// Same language, other region, in the order to try (the regions nxnative's NSP script also swaps).
    static let regional: [String: [String]] = [
        "es-419": ["es"], "es": ["es-419"],
        "fr-CA": ["fr"], "fr": ["fr-CA"],
        "pt-BR": ["pt"], "pt": ["pt-BR"],
        "en-US": ["en-GB"], "en-GB": ["en-US"],
        "zh-CN": ["zh-Hans"], "zh-Hans": ["zh-CN"],
        "zh-TW": ["zh-Hant"], "zh-Hant": ["zh-TW"],
    ]

    private static let pattern = try! NSRegularExpression(pattern: #"DM_LANG=([A-Za-z0-9-]+)"#)

    /// The command with its `DM_LANG` replaced by one the app's game supports; unchanged when the
    /// command sets no language, the app lists none, or the language is already supported.
    public static func adjusted(_ command: String, app: URL?, fileManager: FileManager = .default) -> String {
        guard let app, let range = languageRange(in: command) else { return command }
        guard let (options, fallback) = languages(of: app, fileManager) else { return command }
        let requested = String(command[range])
        guard let chosen = choose(requested, options: options, fallback: fallback), chosen != requested else {
            return command
        }
        return command.replacingCharacters(in: range, with: chosen)
    }

    /// The supported language to use for `requested`: itself, the same language for another region,
    /// another variant with the same language subtag (not across Chinese scripts), else `fallback`.
    static func choose(_ requested: String, options: [String], fallback: String?) -> String? {
        if options.contains(requested) { return requested }
        if let match = regional[requested]?.first(where: options.contains) { return match }
        let base = primary(requested)
        if base != "zh", let match = options.first(where: { primary($0) == base }) { return match }
        return fallback.flatMap { options.contains($0) ? $0 : nil } ?? options.first
    }

    /// The `DM_LANG` setting's options and default from the app's launcher.json, or nil when the app has none.
    static func languages(of app: URL, _ fileManager: FileManager) -> ([String], String?)? {
        let url = app.appendingPathComponent("Contents/Resources/dm/launcher.json")
        guard let data = fileManager.contents(atPath: url.path),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let settings = root["settings"] as? [[String: Any]],
              let setting = settings.first(where: { $0["env"] as? String == "DM_LANG" }),
              let raw = setting["options"] as? [[Any]] else { return nil }
        let options = raw.compactMap { $0.first as? String }
        return options.isEmpty ? nil : (options, setting["default"] as? String)
    }

    private static func languageRange(in command: String) -> Range<String.Index>? {
        let whole = NSRange(command.startIndex..., in: command)
        guard let match = pattern.firstMatch(in: command, range: whole) else { return nil }
        return Range(match.range(at: 1), in: command)
    }

    private static func primary(_ code: String) -> String {
        code.split(separator: "-").first.map { $0.lowercased() } ?? code.lowercased()
    }
}
