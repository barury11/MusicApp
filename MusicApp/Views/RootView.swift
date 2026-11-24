import SwiftUI
import MusicKit

struct RootView: View {
    @EnvironmentObject private var music: MusicService
    @EnvironmentObject private var player: PlaybackService
    @EnvironmentObject private var custom: CustomizationStore
    @State private var tab = 0
    @State private var settings = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if music.authorization == .authorized {
                TabView(selection: $tab) {
                    Tab("Główna", systemImage: "house.fill", value: 0) { navigation { HomeView() } }
                    Tab("Nowości", systemImage: "square.grid.2x2.fill", value: 1) { navigation { DiscoverView() } }
                    Tab("Radio", systemImage: "dot.radiowaves.left.and.right", value: 2) { navigation { RadioView() } }
                    Tab("Biblioteka", systemImage: "music.note.house.fill", value: 3) { navigation { LibraryView() } }
                    Tab("Szukaj", systemImage: "magnifyingglass", value: 4, role: .search) { navigation { SearchView() } }
                }
                .tabViewBottomAccessory {
                    if player.hasItem { MiniPlayerView() }
                }
                .tabBarMinimizeBehavior(.onScrollDown)
            } else { WelcomeView(settings: $settings) }
        }
        .sheet(isPresented: $settings) { SettingsView() }
        .sheet(isPresented: $player.showPlayer) { NowPlayingView().presentationDragIndicator(.hidden).presentationCornerRadius(32) }
        .alert("MusicApp", isPresented: Binding(get: { alertText != nil }, set: { if !$0 { clearAlerts() } })) {
            Button("OK", role: .cancel) { clearAlerts() }
        } message: { Text(alertText ?? "") }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                let status = MusicAuthorization.currentStatus
                if status != music.authorization { Task { await music.restoreAuthorization() } }
            }
        }
    }
    private var alertText: String? { player.errorMessage ?? custom.errorMessage ?? music.message }
    private func clearAlerts() { player.errorMessage = nil; custom.errorMessage = nil; music.message = nil }
    private func navigation<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            content().toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { settings = true } label: { Image(systemName: "person.crop.circle").font(.title2) }.accessibilityLabel("Ustawienia")
                }
            }
        }
    }
}

struct WelcomeView: View {
    @EnvironmentObject private var music: MusicService
    @Binding var settings: Bool
    @State private var connecting = false
    @Environment(\.openURL) private var openURL
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "music.note").font(.system(size: 76, weight: .medium)).foregroundStyle(.musicRed).padding(30).glassEffect(in: .rect(cornerRadius: 32))
            VStack(spacing: 12) {
                Text("Twoja muzyka.\nTwój własny styl.").font(.system(size: 36, weight: .bold)).multilineTextAlignment(.center)
                Text("Biblioteka Apple Music i albumy, które możesz urządzić po swojemu.").font(.title3).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            Spacer()
            if music.authorization == .denied || music.authorization == .restricted {
                Text("Dostęp do multimediów jest wyłączony. Włącz go w Ustawieniach iOS → MusicApp → Multimedia i Apple Music.").font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("Otwórz Ustawienia iOS") { openURL(URL(string: UIApplication.openSettingsURLString)!) }.buttonStyle(.borderedProminent)
            } else {
                Button {
                    connecting = true
                    Task { await music.authorize(); connecting = false }
                } label: {
                    HStack { if connecting { ProgressView().tint(.white) }; Text("Połącz z Apple Music").font(.headline) }.frame(maxWidth: .infinity).padding(.vertical, 10)
                }.buttonStyle(.borderedProminent).disabled(connecting)
            }
            Button("Konfiguracja i informacje") { settings = true }.font(.subheadline)
            Text("Niezależny klient. Streaming wymaga aktywnej subskrypcji Apple Music.").font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.padding(28)
    }
}
