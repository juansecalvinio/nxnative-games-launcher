import AppKit

public protocol GameLaunching: Sendable {
    func launch(_ game: Game) async throws
}

public enum LaunchError: LocalizedError, Equatable {
    case commandFailed(code: Int32, output: String)
    case nothingToLaunch

    public var errorDescription: String? {
        switch self {
        case .commandFailed(let code, let output):
            let base = "El comando falló con código \(code)"
            return output.isEmpty ? base : "\(base): \(output)"
        case .nothingToLaunch:
            return "Este juego no tiene nada para ejecutar"
        }
    }
}

public struct SystemGameLauncher: GameLaunching {
    private let failureWindow: Duration

    public init(failureWindow: Duration = .seconds(2)) {
        self.failureWindow = failureWindow
    }

    public func launch(_ game: Game) async throws {
        if let command = game.command {
            try await run(GameLanguage.adjusted(command, app: game.appURL), in: game.directory)
        } else if let appURL = game.appURL {
            _ = try await NSWorkspace.shared.openApplication(at: appURL, configuration: .init())
        } else {
            throw LaunchError.nothingToLaunch
        }
    }

    private func run(_ command: String, in directory: URL) async throws {
        // stderr goes to a file, not a Pipe: a game that outlives the launch and
        // keeps logging would block once nobody reads a full pipe.
        let errorURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("gameslauncher-\(UUID().uuidString).log")
        FileManager.default.createFile(atPath: errorURL.path, contents: nil)
        defer { try? FileManager.default.removeItem(at: errorURL) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.currentDirectoryURL = directory
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = try FileHandle(forWritingTo: errorURL)

        let (exits, continuation) = AsyncStream.makeStream(of: Int32.self)
        process.terminationHandler = { finished in
            continuation.yield(finished.terminationStatus)
            continuation.finish()
        }
        try process.run()

        let window = failureWindow
        let status = await withTaskGroup(of: Int32?.self) { group in
            group.addTask { await exits.first { _ in true } }
            group.addTask {
                try? await Task.sleep(for: window)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }

        if let status, status != 0 {
            let output = (try? String(contentsOf: errorURL, encoding: .utf8)) ?? ""
            throw LaunchError.commandFailed(code: status, output: output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}
