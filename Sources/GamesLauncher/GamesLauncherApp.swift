import LauncherCore
import SwiftUI

@main
struct GamesLauncherApp: App {
    @State private var model = LauncherModel(
        configURL: ConfigStore.defaultURL,
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
