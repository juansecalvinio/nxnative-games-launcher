import AppKit
import LauncherCore
import SwiftUI

private func artwork(for game: Game?) -> NSImage? {
    guard let appURL = game?.appURL else { return nil }
    let image = NSWorkspace.shared.icon(forFile: appURL.path)
    image.size = NSSize(width: 1024, height: 1024)
    return image
}

struct GameIcon: View {
    let game: Game

    var body: some View {
        if let image = artwork(for: game) {
            Image(nsImage: image).resizable().scaledToFit()
        } else {
            ZStack {
                Color.gray
                Image(systemName: "gamecontroller.fill").font(.system(size: 56))
            }
        }
    }
}

struct GameBackground: View {
    // App icons carry transparent margins, so the image is zoomed past them.
    private let backgroundZoom = 1.35

    let game: Game?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(white: 0.16)
                if let image = artwork(for: game) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .scaleEffect(backgroundZoom)
                        .blur(radius: 48)
                        .clipped()
                        .transition(.opacity)
                        .id(game?.appURL)
                }
                LinearGradient(
                    colors: [.black.opacity(0.85), .black.opacity(0.1)],
                    startPoint: .bottom,
                    endPoint: .center
                )
            }
            .animation(.easeOut(duration: 0.25), value: game?.appURL)
        }
        .ignoresSafeArea()
    }
}
