import Foundation

public struct GameEntry: Decodable, Equatable, Sendable {
    public let name: String
    public let path: String
    public let command: String?

    public init(name: String, path: String, command: String? = nil) {
        self.name = name
        self.path = path
        self.command = command
    }
}

public enum ConfigLoadResult: Equatable, Sendable {
    case loaded([GameEntry])
    case missing
    case invalid(String)
}

public enum ConfigStore {
    private struct File: Decodable {
        let games: [GameEntry]
    }

    public static var defaultURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GamesLauncher/games.json")
    }

    public static var defaultLibraryURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/gaming/roms/switch")
    }

    public static func load(from url: URL) -> ConfigLoadResult {
        guard FileManager.default.fileExists(atPath: url.path) else { return .missing }
        do {
            let data = try Data(contentsOf: url)
            return .loaded(try JSONDecoder().decode(File.self, from: data).games)
        } catch {
            return .invalid(describe(error))
        }
    }

    public static func save(_ games: [GameEntry], to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        func json(_ value: String) throws -> String {
            String(decoding: try encoder.encode(value), as: UTF8.self)
        }

        // Written by hand because JSONEncoder doesn't keep the field order of a hand-edited file.
        let blocks = try games.map { game in
            var fields = ["\"name\": \(try json(game.name))", "\"path\": \(try json(game.path))"]
            if let command = game.command {
                fields.append("\"command\": \(try json(command))")
            }
            let body = fields.map { "      \($0)" }.joined(separator: ",\n")
            return "    {\n\(body)\n    }"
        }
        let text = "{\n  \"games\": [\n\(blocks.joined(separator: ",\n"))\n  ]\n}\n"
        try Data(text.utf8).write(to: url, options: .atomic)
    }

    private static func describe(_ error: Error) -> String {
        guard let decoding = error as? DecodingError else { return error.localizedDescription }
        switch decoding {
        case .keyNotFound(let key, let context):
            return "Falta el campo \"\(key.stringValue)\" en \(location(context))"
        case .typeMismatch(_, let context), .valueNotFound(_, let context):
            return "Valor incorrecto en \(location(context))"
        case .dataCorrupted(let context):
            let detail = (context.underlyingError as NSError?)?.userInfo[NSDebugDescriptionErrorKey] as? String
            return "JSON mal formado: \(detail ?? context.debugDescription)"
        @unknown default:
            return decoding.localizedDescription
        }
    }

    private static func location(_ context: DecodingError.Context) -> String {
        let path = context.codingPath.map { $0.intValue.map(String.init) ?? $0.stringValue }
        return path.isEmpty ? "la raíz del archivo" : path.joined(separator: ".")
    }
}
