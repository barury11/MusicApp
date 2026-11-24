import SwiftUI

@main
struct MusicApp: App {
    @StateObject private var music = MusicService()
    @StateObject private var player = PlaybackService()
    @StateObject private var custom = CustomizationStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(music)
                .environmentObject(player)
                .environmentObject(custom)
                .tint(Color.musicRed)
                .task { await music.restoreAuthorization() }
        }
    }
}
