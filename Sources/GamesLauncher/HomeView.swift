import LauncherCore
import SwiftUI

struct HomeView: View {
    let model: LauncherModel

    @State private var controllerInput: ControllerInput?
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            GameBackground(game: model.selectedGame)
            VStack(spacing: 0) {
                TopBar()
                content
                FooterBar(showsPlay: model.selectedGame?.isLaunchable == true)
            }
            if let message = model.message {
                MessagePanel(message: message)
            }
        }
        .foregroundStyle(.white)
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onKeyPress(.leftArrow) {
            model.moveLeft()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            model.moveRight()
            return .handled
        }
        .onKeyPress(.return) {
            Task { await model.confirm() }
            return .handled
        }
        .onAppear {
            isFocused = true
            controllerInput = ControllerInput(model: model)
            controllerInput?.start()
            coverScreen()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.reload()
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didTerminateApplicationNotification)) { notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            if let url = app?.bundleURL, model.didLaunchedGameTerminate(at: url) {
                NSApp.activate()
            }
        }
    }

    // Native full screen would put the launcher in its own Space, and a game opened
    // from there can't enter full screen itself, so the window just covers the display.
    private func coverScreen() {
        guard let window = NSApp.windows.first, let screen = window.screen ?? NSScreen.main else { return }
        NSApp.presentationOptions = [.hideDock, .hideMenuBar]
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            window.standardWindowButton(button)?.isHidden = true
        }
        window.isMovable = false
        window.setFrame(screen.frame, display: true)
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .configMissing(let url):
            ConfigMissingView(url: url)
        case .configInvalid(let url, let problem):
            ConfigInvalidView(url: url, problem: problem)
        case .ready where model.games.isEmpty:
            NoticeText(title: "No hay juegos en games.json")
        case .ready:
            VStack(alignment: .leading, spacing: 28) {
                Spacer()
                Text(model.selectedGame?.name ?? "")
                    .font(.system(size: 52, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .shadow(radius: 12)
                GameRow(games: model.games, selectedIndex: model.selectedIndex)
            }
            .padding(.horizontal, 64)
            .padding(.bottom, 36)
        }
    }
}

private struct TopBar: View {
    var body: some View {
        HStack {
            Circle()
                .fill(.white.opacity(0.9))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "person.fill")
                        .foregroundStyle(.black.opacity(0.65))
                }
            Spacer()
            TimelineView(.everyMinute) { context in
                Text(context.date, format: .dateTime.hour().minute())
                    .font(.title2.weight(.medium))
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 64)
        .padding(.top, 36)
    }
}

private struct GameRow: View {
    let games: [Game]
    let selectedIndex: Int

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 20) {
                    ForEach(games.indices, id: \.self) { index in
                        GameTile(game: games[index], isSelected: index == selectedIndex)
                            .id(index)
                    }
                }
                .padding(12)
            }
            .scrollIndicators(.never)
            .scrollDisabled(true)
            .onChange(of: selectedIndex) { _, index in
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo(index, anchor: .center)
                }
            }
        }
    }
}

private struct GameTile: View {
    let game: Game
    let isSelected: Bool

    var body: some View {
        GameIcon(game: game)
            .frame(width: 168, height: 168)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .opacity(game.isLaunchable ? 1 : 0.4)
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .inset(by: -6)
                    .stroke(Color.selection, lineWidth: isSelected ? 4 : 0)
            }
            .scaleEffect(isSelected ? 1.04 : 1)
            .animation(.easeOut(duration: 0.12), value: isSelected)
    }
}

private struct FooterBar: View {
    let showsPlay: Bool

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(.white.opacity(0.35)).frame(height: 1)
            HStack {
                Spacer()
                Text("✕ Jugar").opacity(showsPlay ? 1 : 0)
            }
            .font(.title3.weight(.medium))
            .padding(.vertical, 18)
        }
        .padding(.horizontal, 64)
        .padding(.bottom, 8)
    }
}

extension Color {
    static let selection = Color(red: 0.18, green: 0.84, blue: 0.88)
}
