import Foundation

public enum GameDiscovery {
    public static func newEntries(
        in library: URL,
        existing: [GameEntry],
        fileManager: FileManager = .default
    ) -> [GameEntry] {
        let known = Set(existing.map(folderPath))
        let folders = (try? fileManager.contentsOfDirectory(
            at: library,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )) ?? []

        return folders
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .filter { !known.contains($0.standardizedFileURL.path) }
            .compactMap { folder in
                guard let app = GameResolver.firstApp(in: folder, fileManager) else { return nil }
                return GameEntry(
                    name: app.deletingPathExtension().lastPathComponent,
                    path: displayPath(folder.path),
                    command: command(forApp: app.lastPathComponent)
                )
            }
    }

    /// Only drops a game when the library was readable and its .app is confirmed gone,
    /// so a missing permission can't wipe the list. Games outside the library are kept.
    public static func removingDeleted(
        from entries: [GameEntry],
        in library: URL,
        fileManager: FileManager = .default
    ) -> [GameEntry] {
        guard isReadable(library, fileManager) else { return entries }
        let root = library.standardizedFileURL.path + "/"

        return entries.filter { entry in
            let url = location(of: entry)
            guard url.path.hasPrefix(root), fileManager.fileExists(atPath: url.path) else {
                return !url.path.hasPrefix(root)
            }
            guard url.pathExtension != "app", isReadable(url, fileManager) else { return true }
            return GameResolver.firstApp(in: url, fileManager) != nil
        }
    }

    static func command(forApp appName: String) -> String {
        var escaped = appName
        for character in ["\\", "\"", "$", "`"] {
            escaped = escaped.replacingOccurrences(of: character, with: "\\" + character)
        }
        return "open --env DM_LANG=es-419 --env DM_FULLSCREEN=1 \"\(escaped)\""
    }

    static func displayPath(_ path: String) -> String {
        NSString(string: path).abbreviatingWithTildeInPath
    }

    private static func folderPath(of entry: GameEntry) -> String {
        let url = location(of: entry)
        return url.pathExtension == "app" ? url.deletingLastPathComponent().path : url.path
    }

    private static func location(of entry: GameEntry) -> URL {
        URL(fileURLWithPath: NSString(string: entry.path).expandingTildeInPath).standardizedFileURL
    }

    private static func isReadable(_ url: URL, _ fileManager: FileManager) -> Bool {
        (try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) != nil
    }
}
