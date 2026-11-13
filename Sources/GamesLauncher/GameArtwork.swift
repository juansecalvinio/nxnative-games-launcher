import AppKit
import LauncherCore
import SwiftUI

/// The game's cover: its .app icon cropped to a square. App icons sit in a rounded square
/// with transparent margins, so the image is zoomed until the corners are filled.
struct GameIcon: View {
    private let cropZoom = 1.5

    let game: Game

    var body: some View {
        if let appURL = game.appURL {
            Image(nsImage: icon(at: appURL))
                .resizable()
                .scaledToFill()
                .scaleEffect(cropZoom)
        } else {
            ZStack {
                Color(white: 0.3)
                Image(systemName: "gamecontroller.fill").font(.system(size: 56))
            }
        }
    }

    private func icon(at url: URL) -> NSImage {
        let image = NSWorkspace.shared.icon(forFile: url.path)
        image.size = NSSize(width: 1024, height: 1024)
        return image
    }
}
