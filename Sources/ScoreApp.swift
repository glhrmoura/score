import AppKit
import SwiftUI

@main
struct ScoreApp: App {
    @State private var hub = LeagueHub()
    @State private var catalog = Catalog()

    init() {
        UserDefaults.standard.set("WhenScrolling", forKey: "AppleShowScrollBars")
        Typeface.register()
        URLCache.shared = URLCache(memoryCapacity: 32 * 1024 * 1024, diskCapacity: 256 * 1024 * 1024)
    }

    var body: some Scene {
        Window("Score", id: "main") {
            ContentView()
                .environment(hub)
                .environment(catalog)
                .frame(minWidth: 1080, minHeight: 640)
                .task { await catalog.loadCountries() }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1300, height: 840)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .toolbar) {
                Button("Atualizar") { hub.refresh() }
                    .keyboardShortcut("r")
            }
        }
    }
}
