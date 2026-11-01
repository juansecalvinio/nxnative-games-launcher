import Foundation
import Observation

public enum LauncherState: Equatable, Sendable {
    case ready
    case configMissing(URL)
    case configInvalid(URL, String)
}

@MainActor @Observable
public final class LauncherModel {
    public private(set) var isLoading = true
    public private(set) var state: LauncherState = .ready
    public private(set) var games: [Game] = []
    public private(set) var selectedIndex = 0
    public var message: String?

    public var selectedGame: Game? {
        games.indices.contains(selectedIndex) ? games[selectedIndex] : nil
    }

    private let configURL: URL
    private let libraryURL: URL?
    private let launcher: any GameLaunching
    private var isLaunching = false
    private var launchedApps: Set<String> = []

    public init(configURL: URL, libraryURL: URL? = nil, launcher: any GameLaunching) {
        self.configURL = configURL
        self.libraryURL = libraryURL
        self.launcher = launcher
    }

    public func start(minimumDuration: Duration = .seconds(1)) async {
        let (configURL, libraryURL) = (configURL, libraryURL)
        let scan = Task.detached {
            Self.loadLibrary(configURL: configURL, libraryURL: libraryURL)
        }
        try? await Task.sleep(for: minimumDuration)
        apply(await scan.value)
    }

    public func reload() {
        apply(Self.loadLibrary(configURL: configURL, libraryURL: libraryURL))
    }

    private nonisolated static func loadLibrary(configURL: URL, libraryURL: URL?) -> ConfigLoadResult {
        let result = ConfigStore.load(from: configURL)
        guard case .loaded(let entries) = result, let libraryURL else { return result }

        let discovered = GameDiscovery.newEntries(in: libraryURL, existing: entries)
        guard !discovered.isEmpty else { return result }

        let all = entries + discovered
        // If this fails the games still show, and the next scan tries to save them again.
        try? ConfigStore.save(all, to: configURL)
        return .loaded(all)
    }

    private func apply(_ result: ConfigLoadResult) {
        switch result {
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
        isLoading = false
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
