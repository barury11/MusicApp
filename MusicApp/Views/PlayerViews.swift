import SwiftUI
import MusicKit

struct MiniPlayerView: View {
    @EnvironmentObject private var player: PlaybackService
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    @ObservedObject private var state = ApplicationMusicPlayer.shared.state
    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                CoverArt(artwork: player.currentArtwork, albumID: player.albumKey, size: placement == .inline ? 28 : 40, radius: 6)
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.currentTitle).font(.subheadline.weight(.medium)).lineLimit(1)
                    if placement != .inline { Text(player.currentArtist).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.contentShape(Rectangle()).onTapGesture { player.showPlayer = true }
                .accessibilityElement(children: .combine).accessibilityAddTraits(.isButton).accessibilityAction { player.showPlayer = true }
            Button { player.toggle() } label: { Image(systemName: state.playbackStatus == .playing ? "pause.fill" : "play.fill").font(.title3).contentTransition(.symbolEffect(.replace)).frame(width: 38, height: 44) }.buttonStyle(.plain).accessibilityLabel(state.playbackStatus == .playing ? "Pauza" : "Odtwórz")
            if placement != .inline {
                Button { player.next() } label: { Image(systemName: "forward.fill").font(.title3).frame(width: 38, height: 44) }.buttonStyle(.plain).accessibilityLabel("Następny utwór")
            }
        }.padding(.horizontal, 12)
        .gesture(DragGesture(minimumDistance: 28).onEnded { value in
            if abs(value.translation.width) > abs(value.translation.height) {
                if value.translation.width < -40 { player.next() }
                else if value.translation.width > 40 { player.previous() }
            }
        })
    }
}

struct NowPlayingView: View {
    @EnvironmentObject private var player: PlaybackService
    @EnvironmentObject private var music: MusicService
    @EnvironmentObject private var custom: CustomizationStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var state = ApplicationMusicPlayer.shared.state
    @State private var scrubbing = false
    @State private var scrubPosition: Double = 0
    @State private var showQueue = false
    @State private var lyricsSong: Song?
    @State private var playlistSong: Song?
    private var isPlaying: Bool { state.playbackStatus == .playing }
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width - 64, max(180, geometry.size.height * 0.43), 430)
            ZStack {
                playerBackground
                ScrollView {
                    VStack(spacing: 0) {
                        Capsule().fill(.white.opacity(0.45)).frame(width: 38, height: 5).padding(.top, 10)
                            .onTapGesture { dismiss() }.accessibilityLabel("Zamknij odtwarzacz").accessibilityAddTraits(.isButton)
                        CoverArt(artwork: player.currentArtwork, albumID: player.albumKey, size: size, radius: 12)
                            .scaleEffect(isPlaying ? 1 : 0.86)
                            .shadow(color: .black.opacity(0.35), radius: isPlaying ? 22 : 10, y: 16)
                            .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.82), value: isPlaying)
                            .padding(.top, 38).padding(.bottom, 38)
                        HStack(alignment: .center, spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(player.currentTitle).font(.system(size: 24, weight: .bold)).lineLimit(2)
                                Text(player.currentArtist).font(.title3).foregroundStyle(.white.opacity(0.65)).lineLimit(1)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            Menu {
                                if let song = player.currentSong {
                                    Button("Dodaj do ulubionych", systemImage: "star") { Task { await music.favorite(id: song.id, url: song.url, type: "songs") } }
                                    Button("Dodaj do biblioteki", systemImage: "plus") { Task { await music.addSong(song) } }
                                    Button("Dodaj do playlisty…", systemImage: "text.badge.plus") { playlistSong = song }
                                    Button("Tekst utworu", systemImage: "quote.bubble") { lyricsSong = song }
                                    if let url = song.url { ShareLink(item: url) { Label("Udostępnij utwór", systemImage: "square.and.arrow.up") } }
                                }
                            } label: { Image(systemName: "ellipsis").font(.title3.weight(.semibold)).frame(width: 40, height: 40).glassEffect(.regular.tint(.white.opacity(0.06)), in: .circle) }.tint(.white).accessibilityLabel("Opcje utworu")
                        }
                        VStack(spacing: 0) {
                            Slider(value: Binding(get: { scrubbing ? scrubPosition : min(player.position, max(1, player.duration)) }, set: { scrubPosition = $0 }), in: 0...max(1, player.duration), onEditingChanged: { editing in
                                if editing { scrubPosition = player.position; scrubbing = true }
                                else { player.seek(scrubPosition); scrubbing = false }
                            }).tint(.white.opacity(0.8)).disabled(player.duration <= 0).accessibilityLabel("Pozycja utworu")
                            HStack {
                                Text(durationText(scrubbing ? scrubPosition : player.position))
                                Spacer()
                                Text("−" + durationText(max(0, player.duration - (scrubbing ? scrubPosition : player.position))))
                            }.font(.caption.monospacedDigit()).foregroundStyle(.white.opacity(0.55))
                        }.padding(.top, 20)
                        HStack {
                            Button { player.previous() } label: { Image(systemName: "backward.fill").font(.system(size: 30)).frame(width: 70, height: 76) }.accessibilityLabel("Poprzedni utwór")
                            Spacer()
                            Button { player.toggle() } label: { Image(systemName: isPlaying ? "pause.fill" : "play.fill").font(.system(size: 46)).contentTransition(.symbolEffect(.replace)).frame(width: 90, height: 86) }.accessibilityLabel(isPlaying ? "Pauza" : "Odtwórz")
                            Spacer()
                            Button { player.next() } label: { Image(systemName: "forward.fill").font(.system(size: 30)).frame(width: 70, height: 76) }.accessibilityLabel("Następny utwór")
                        }.buttonStyle(.plain).padding(.top, 8)
                        if let variant = state.audioVariant {
                            Text(variantLabel(variant)).font(.caption.weight(.medium)).foregroundStyle(.white.opacity(0.65)).padding(.bottom, 12)
                        }
                        HStack(spacing: 14) {
                            Image(systemName: "speaker.fill").font(.caption)
                            SystemVolumeSlider().frame(height: 28)
                            Image(systemName: "speaker.wave.3.fill").font(.caption)
                        }.foregroundStyle(.white.opacity(0.6)).padding(.vertical, 12)
                        HStack {
                            Button { lyricsSong = player.currentSong } label: { Image(systemName: "quote.bubble").font(.title2).frame(width: 50, height: 50) }.disabled(player.currentSong == nil).accessibilityLabel("Tekst utworu")
                            Spacer()
                            AirPlayButton().frame(width: 44, height: 44).accessibilityLabel("AirPlay")
                            Spacer()
                            Button { showQueue = true } label: { Image(systemName: "list.bullet").font(.title2).frame(width: 50, height: 50) }.accessibilityLabel("Kolejka odtwarzania")
                        }.buttonStyle(.plain).padding(.top, 8)
                    }.padding(.horizontal, 32).padding(.bottom, 24).frame(minHeight: geometry.size.height, alignment: .top)
                }.scrollIndicators(.hidden)
            }.foregroundStyle(.white)
        }
        .sheet(isPresented: $showQueue) { QueueView().foregroundStyle(Color.primary).tint(Color.musicRed) }
        .sheet(item: $lyricsSong) { song in LyricsView(song: song).foregroundStyle(Color.primary).tint(Color.musicRed) }
        .sheet(item: $playlistSong) { song in AddToPlaylistView(song: song).foregroundStyle(Color.primary).tint(Color.musicRed) }
        .presentationBackground(.black)
    }
    private var playerBackground: some View {
        ZStack {
            Color.black
            if let artwork = player.currentArtwork {
                ArtworkImage(artwork, width: 600, height: 900).scaledToFill().blur(radius: 80).opacity(0.65)
            }
            if let id = player.albumKey, let hex = custom.album(id).backgroundHex, let color = Color(hex: hex) { color.opacity(0.6) }
            LinearGradient(colors: [.black.opacity(0.05), .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
        }.ignoresSafeArea().allowsHitTesting(false)
    }
    private func variantLabel(_ variant: AudioVariant) -> String {
        switch variant {
        case .dolbyAtmos: return "Dolby Atmos"
        case .dolbyAudio: return "Dolby Audio"
        case .highResolutionLossless: return "Hi-Res Lossless"
        case .lossless: return "Lossless"
        case .spatialAudio: return "Spatial Audio"
        default: return ""
        }
    }
}

struct QueueView: View {
    @EnvironmentObject private var player: PlaybackService
    @ObservedObject private var queue = ApplicationMusicPlayer.shared.queue
    @ObservedObject private var state = ApplicationMusicPlayer.shared.state
    @Environment(\.dismiss) private var dismiss
    private var repeatMode: MusicPlayer.RepeatMode { state.repeatMode ?? MusicPlayer.RepeatMode.none }
    private var queueControls: some View {
        HStack {
            Text("Odtwarzane dalej").font(.headline)
            Spacer()
            Button { player.toggleShuffle() } label: {
                Image(systemName: "shuffle").frame(width: 40, height: 40)
                    .background(state.shuffleMode == .songs ? Color.musicRed.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
            }.accessibilityLabel("Mieszaj").accessibilityValue(state.shuffleMode == .songs ? "Włączone" : "Wyłączone")
            Button { player.toggleRepeat() } label: {
                Image(systemName: repeatMode == .one ? "repeat.1" : "repeat").frame(width: 40, height: 40)
                    .background(repeatMode != .none ? Color.musicRed.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
            }.accessibilityLabel("Powtarzanie").accessibilityValue(repeatMode == .none ? "Wyłączone" : repeatMode == .one ? "Jeden utwór" : "Wszystko")
        }.buttonStyle(.plain).tint(Color.musicRed)
    }
    var body: some View {
        NavigationStack {
            List {
                Section { queueControls }
                Section {
                    ForEach(Array(queue.entries)) { entry in
                        Button { player.select(entry) } label: {
                            HStack(spacing: 12) {
                                CoverArt(artwork: entry.artwork, size: 48)
                                VStack(alignment: .leading, spacing: 3) { Text(entry.title).foregroundStyle(queue.currentEntry?.id == entry.id ? Color.musicRed : .primary); Text(entry.subtitle ?? "").font(.caption).foregroundStyle(.secondary) }
                                Spacer()
                                if queue.currentEntry?.id == entry.id { Image(systemName: "speaker.wave.2.fill").foregroundStyle(Color.musicRed) }
                            }
                        }
                    }
                    .onDelete { indices in queue.entries.remove(atOffsets: indices) }
                    .onMove { indices, destination in queue.entries.move(fromOffsets: indices, toOffset: destination) }
                }
            }
            .navigationTitle("Kolejka").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Zamknij") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { EditButton() }
            }
        }
    }
}
