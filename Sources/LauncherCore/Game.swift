import Foundation

public struct Game: Equatable, Sendable {
    public let name: String
    public let directory: URL
    public let appURL: URL?
    public let command: String?
    public let unavailableReason: String?

    public var isLaunchable: Bool { unavailableReason == nil }

    public init(name: String, directory: URL, appURL: URL?, command: String?, unavailableReason: String?) {
        self.name = name
        self.directory = directory
        self.appURL = appURL
        self.command = command
        self.unavailableReason = unavailableReason
    }
}

public enum GameResolver {
    public static func resolve(_ entry: GameEntry, fileManager: FileManager = .default) -> Game {
        let url = URL(fileURLWithPath: NSString(string: entry.path).expandingTildeInPath).standardizedFileURL
        let path = url.path

        func game(directory: URL, appURL: URL?, reason: String?) -> Game {
            Game(name: entry.name, directory: directory, appURL: appURL, command: entry.command, unavailableReason: reason)
        }

        if isPermissionDenied(url, fileManager) {
            let reason = "Sin permiso para leer: \(path). Activalo en Ajustes del Sistema > Privacidad y seguridad > Archivos y carpetas."
            return game(directory: url, appURL: nil, reason: reason)
        }
        guard isDirectory(url, fileManager) else {
            return game(directory: url, appURL: nil, reason: "No se encontró la carpeta: \(path)")
        }
        if url.pathExtension == "app" {
            return game(directory: url.deletingLastPathComponent(), appURL: url, reason: nil)
        }

        let appURL = firstApp(in: url, fileManager)
        let reason = appURL == nil && entry.command == nil ? "No se encontró ningún .app en: \(path)" : nil
        return game(directory: url, appURL: appURL, reason: reason)
    }

    private static func isPermissionDenied(_ url: URL, _ fileManager: FileManager) -> Bool {
        do {
            _ = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            return false
        } catch let error as CocoaError {
            return error.code == .fileReadNoPermission
        } catch {
            return false
        }
    }

    private static func firstApp(in directory: URL, _ fileManager: FileManager) -> URL? {
        let contents = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return contents
            .filter { $0.pathExtension == "app" && isDirectory($0, fileManager) }
            .min { $0.lastPathComponent < $1.lastPathComponent }
    }

    private static func isDirectory(_ url: URL, _ fileManager: FileManager) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
