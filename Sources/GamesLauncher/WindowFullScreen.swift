import AppKit

/// Full screen for the green button without macOS native full screen. A game opened with
/// DM_FULLSCREEN=1 from a native full screen Space only reaches 1280×752, so instead the
/// window covers the display with the Dock and menu bar hidden, and the button toggles back.
@MainActor
final class WindowFullScreen: NSObject {
    static let shared = WindowFullScreen()

    private weak var window: NSWindow?
    private var windowedFrame: NSRect?

    func attach(to window: NSWindow) {
        self.window = window
        window.collectionBehavior.insert(.fullScreenNone)
        guard let zoom = window.standardWindowButton(.zoomButton) else { return }
        zoom.target = self
        zoom.action = #selector(toggle)
    }

    @objc func toggle() {
        if windowedFrame == nil {
            enter(animated: true)
        } else {
            exit()
        }
    }

    func enter(animated: Bool) {
        guard let window, windowedFrame == nil, let screen = window.screen ?? NSScreen.main else { return }
        windowedFrame = window.frame
        NSApp.presentationOptions = [.hideDock, .hideMenuBar]
        window.isMovable = false
        window.setFrame(screen.frame, display: true, animate: animated)
    }

    private func exit() {
        guard let window, let frame = windowedFrame else { return }
        windowedFrame = nil
        NSApp.presentationOptions = []
        window.isMovable = true
        window.setFrame(frame, display: true, animate: true)
    }
}
