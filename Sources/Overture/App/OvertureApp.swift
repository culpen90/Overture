import SwiftUI

@main
struct OvertureApp: App {
    @StateObject private var preferences = BrowserPreferences()

    var body: some Scene {
        WindowGroup("Overture") {
            BrowserRootView(preferences: preferences)
        }
        .defaultSize(width: 1_280, height: 820)
        .windowStyle(.hiddenTitleBar)
        .commands {
            BrowserCommands()
        }

        Settings {
            BrowserSettingsView(preferences: preferences)
        }
    }
}
