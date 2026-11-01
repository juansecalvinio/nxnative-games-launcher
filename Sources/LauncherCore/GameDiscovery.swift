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
        let url = URL(fileURLWithPath: NSString(string: entry.path).expandingTildeInPath).standardizedFileURL
        return url.pathExtension == "app" ? url.deletingLastPathComponent().path : url.path
    }
}
