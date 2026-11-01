import Foundation
import Observation

public enum LauncherState: Equatable, Sendable {
    case ready
    case configMissing(URL)
    case configInvalid(URL, String)
}

@MainActor @Observable
public final class LauncherModel {
    public private(set) var state: LauncherState = .ready
    public private(set) var games: [Game] = []
    public private(set) var selectedIndex = 0
    public var message: String?

    public var selectedGame: Game? {
        games.indices.contains(selectedIndex) ? games[selectedIndex] : nil
    }

    private let configURL: URL
    private let launcher: any GameLaunching
    private var isLaunching = false
    private var launchedApps: Set<String> = []

    public init(configURL: URL, launcher: any GameLaunching) {
        self.configURL = configURL
        self.launcher = launcher
        reload()
    }

    public func reload() {
        switch ConfigStore.load(from: configURL) {
        case .loaded(let entries):
            games = entries.map { GameResolver.resolve($0) }
            state = .ready
        case .missing:
            games = []
            state = .configMissing(configURL)
        case .invalid(let problem):
            games = []
            state = .configInvalid(configURL, problem)
        }
        selectedIndex = min(selectedIndex, max(games.count - 1, 0))
    }

    public func moveLeft() {
        selectedIndex = max(selectedIndex - 1, 0)
    }

    public func moveRight() {
        selectedIndex = min(selectedIndex + 1, max(games.count - 1, 0))
    }

    public func confirm() async {
        if message != nil {
            message = nil
            return
        }
        guard !isLaunching, let game = selectedGame else { return }
        if let reason = game.unavailableReason {
            message = reason
            return
        }

        isLaunching = true
        defer { isLaunching = false }
        do {
            try await launcher.launch(game)
            if let appURL = game.appURL {
                launchedApps.insert(appURL.standardizedFileURL.path)
            }
        } catch {
            message = error.localizedDescription
        }
    }

    public func didLaunchedGameTerminate(at appURL: URL) -> Bool {
        launchedApps.remove(appURL.standardizedFileURL.path) != nil
    }
}
