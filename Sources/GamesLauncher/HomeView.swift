import LauncherCore
import SwiftUI

struct HomeView: View {
    let model: LauncherModel

    @State private var controllerInput: ControllerInput?
    @State private var status = SystemStatus()
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            VStack(spacing: 0) {
                TopBar(status: status)
                content
                FooterBar(
                    showsPlay: model.selectedGame?.isLaunchable == true,
                    isControllerConnected: status.isControllerConnected
                )
            }
            if let message = model.message {
                MessagePanel(message: message)
            }
            if model.isLoading {
                LoadingView()
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
            status.start()
            setUpWindow()
        }
        .task {
            await model.start()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            if !model.isLoading {
                model.reload()
            }
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didTerminateApplicationNotification)) { notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            if let url = app?.bundleURL, model.didLaunchedGameTerminate(at: url) {
                NSApp.activate()
            }
        }
    }

    // Opens in full screen; the green button switches to a window filling the visible screen.
    private func setUpWindow() {
        guard let window = NSApp.windows.first, let screen = window.screen ?? NSScreen.main else { return }
        window.setFrame(screen.visibleFrame, display: true)
        WindowFullScreen.shared.attach(to: window)
        WindowFullScreen.shared.enter(animated: false)
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
            GameRow(games: model.games, selectedIndex: model.selectedIndex)
        }
    }
}

private let sideMargin: CGFloat = 64

private struct TopBar: View {
    let status: SystemStatus

    var body: some View {
        HStack(spacing: 22) {
            Circle()
                .fill(.white.opacity(0.9))
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.title2)
                        .foregroundStyle(.black.opacity(0.65))
                }
            Spacer()
            TimelineView(.everyMinute) { context in
                Text(context.date, format: .dateTime.hour().minute())
                    .font(.system(size: 30, weight: .medium))
                    .monospacedDigit()
            }
            WiFiIcon(isConnected: status.isWiFiConnected)
            if let battery = status.battery {
                BatteryIcon(level: battery)
            }
        }
        .padding(.horizontal, sideMargin)
        .padding(.top, 40)
    }
}

/// The Switch home row: big square covers from the left, the selected one outlined
/// with its name above it, and the row scrolling only when the selection leaves the screen.
private struct GameRow: View {
    let games: [Game]
    let selectedIndex: Int

    var body: some View {
        GeometryReader { geometry in
            let tile = min(geometry.size.width * 0.2, geometry.size.height * 0.62)
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: tile * 0.05) {
                        ForEach(games.indices, id: \.self) { index in
                            GameTile(game: games[index], size: tile, isSelected: index == selectedIndex)
                                .id(index)
                        }
                    }
                    .padding(.top, 64)
                    .padding(.bottom, 16)
                }
                .contentMargins(.horizontal, sideMargin + 8, for: .scrollContent)
                .scrollIndicators(.never)
                .scrollDisabled(true)
                .frame(maxHeight: .infinity)
                .onChange(of: selectedIndex) { _, index in
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(index)
                    }
                }
            }
        }
    }
}

private struct GameTile: View {
    let game: Game
    let size: CGFloat
    let isSelected: Bool

    var body: some View {
        GameIcon(game: game)
            .frame(width: size, height: size)
            .clipped()
            .opacity(game.isLaunchable ? 1 : 0.4)
            .overlay {
                Rectangle()
                    .inset(by: -7)
                    .stroke(Color.selection, lineWidth: isSelected ? 5 : 0)
            }
            .overlay(alignment: .topLeading) {
                if isSelected {
                    Text(game.name)
                        .font(.system(size: 34, weight: .regular))
                        .foregroundStyle(Color.selection)
                        .lineLimit(1)
                        .fixedSize()
                        .offset(y: -58)
                }
            }
            .animation(.easeOut(duration: 0.12), value: isSelected)
    }
}

private struct FooterBar: View {
    let showsPlay: Bool
    let isControllerConnected: Bool

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(.white.opacity(0.45)).frame(height: 1)
            HStack(spacing: 12) {
                ControllerIcon(isConnected: isControllerConnected)
                Spacer()
                Group {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 28))
                    Text("Jugar").font(.system(size: 26))
                }
                .opacity(showsPlay ? 1 : 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 22)
        }
        .padding(.horizontal, sideMargin - 16)
        .padding(.bottom, 4)
    }
}

extension Color {
    static let selection = Color(red: 0.24, green: 0.62, blue: 1.0)
    static let background = Color(white: 0.18)
}
