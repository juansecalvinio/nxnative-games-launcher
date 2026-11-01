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

    public static func load(from url: URL) -> ConfigLoadResult {
        guard FileManager.default.fileExists(atPath: url.path) else { return .missing }
        do {
            let data = try Data(contentsOf: url)
            return .loaded(try JSONDecoder().decode(File.self, from: data).games)
        } catch {
            return .invalid(describe(error))
        }
    }

    private static func describe(_ error: Error) -> String {
        guard let decoding = error as? DecodingError else { return error.localizedDescription }
        switch decoding {
        case .keyNotFound(let key, let context):
            return "Falta el campo \"\(key.stringValue)\" en \(location(context))"
        case .typeMismatch(_, let context), .valueNotFound(_, let context):
            return "Valor incorrecto en \(location(context))"
        case .dataCorrupted(let context):
            return "JSON mal formado: \(context.underlyingError?.localizedDescription ?? context.debugDescription)"
        @unknown default:
            return decoding.localizedDescription
        }
    }

    private static func location(_ context: DecodingError.Context) -> String {
        let path = context.codingPath.map { $0.intValue.map(String.init) ?? $0.stringValue }
        return path.isEmpty ? "la raíz del archivo" : path.joined(separator: ".")
    }
}
