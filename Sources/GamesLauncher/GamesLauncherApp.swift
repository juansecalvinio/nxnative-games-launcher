import LauncherCore
import SwiftUI

@main
struct GamesLauncherApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var model = LauncherModel(
        configURL: ConfigStore.defaultURL,
        libraryURL: ConfigStore.defaultLibraryURL,
        launcher: SystemGameLauncher()
    )

    var body: some Scene {
        Window("Games Launcher", id: "home") {
            HomeView(model: model)
                .frame(minWidth: 960, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
