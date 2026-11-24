import SwiftUI
import MusicKit
import MediaPlayer
import UIKit

extension Color {
    static let musicRed = Color(red: 0.98, green: 0.18, blue: 0.30)
    init?(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else { return nil }
        self.init(.sRGB, red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255, opacity: 1)
    }
    var rgbHex: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int(max(0, min(1, r)) * 255), Int(max(0, min(1, g)) * 255), Int(max(0, min(1, b)) * 255))
    }
}

extension AlbumCustomization.LogoAlignment {
    var swiftUI: Alignment {
        switch self { case .leading: return .leading; case .center: return .center; case .trailing: return .trailing }
    }
}

func durationText(_ value: TimeInterval) -> String {
    guard value.isFinite, value > 0 else { return "0:00" }
    let seconds = Int(value)
    return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
}

struct CoverArt: View {
    @EnvironmentObject private var custom: CustomizationStore
    var artwork: Artwork?
    var albumID: String? = nil
    var size: CGFloat = 160
    var radius: CGFloat = 8
    var body: some View {
        Group {
            if let albumID, let image = custom.image(custom.album(albumID).squareArtwork) {
                Image(uiImage: image).resizable().scaledToFill()
            } else if let artwork {
                ArtworkImage(artwork, width: size, height: size)
            } else {
                ZStack { Color(.secondarySystemBackground); Image(systemName: "music.note").font(.system(size: size * 0.3)).foregroundStyle(.secondary) }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .accessibilityHidden(true)
    }
}

struct AlbumTile: View {
    let album: Album
    var size: CGFloat = 160
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            CoverArt(artwork: album.artwork, albumID: album.id.rawValue, size: size)
            Text(album.title).font(.subheadline).foregroundStyle(.primary).lineLimit(1)
            Text(album.artistName).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
        }.frame(width: size, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct PlaylistTile: View {
    let playlist: Playlist
    var size: CGFloat = 160
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            CoverArt(artwork: playlist.artwork, size: size)
            Text(playlist.name).font(.subheadline).foregroundStyle(.primary).lineLimit(1)
            Text(playlist.curatorName ?? "Apple Music").font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
        }.frame(width: size, alignment: .leading)
    }
}

struct AlbumShelf: View {
    let title: String
    let albums: [Album]
    @Namespace private var namespace
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.title2.bold()).padding(.horizontal, 20)
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(albums) { album in
                        NavigationLink {
                            AlbumDetailView(album: album).navigationTransition(.zoom(sourceID: album.id, in: namespace))
                        } label: {
                            AlbumTile(album: album).matchedTransitionSource(id: album.id, in: namespace)
                        }.buttonStyle(.plain)
                    }
                }.padding(.horizontal, 20)
            }.scrollIndicators(.hidden)
        }
    }
}

struct PlaylistShelf: View {
    let title: String
    let playlists: [Playlist]
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.title2.bold()).padding(.horizontal, 20)
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(playlists) { playlist in
                        NavigationLink { PlaylistDetailView(playlist: playlist) } label: { PlaylistTile(playlist: playlist) }.buttonStyle(.plain)
                    }
                }.padding(.horizontal, 20)
            }.scrollIndicators(.hidden)
        }
    }
}

struct SongRow: View {
    @EnvironmentObject private var player: PlaybackService
    @EnvironmentObject private var music: MusicService
    let song: Song
    var showCover = true
    var number: Int? = nil
    var albumID: String? = nil
    var action: () -> Void
    @State private var lyrics = false
    @State private var addToPlaylist = false
    var body: some View {
        HStack(spacing: 12) {
            Button(action: action) {
                HStack(spacing: 12) {
                    if showCover { CoverArt(artwork: song.artwork, albumID: albumID, size: 48, radius: 5) }
                    else if let number {
                        Group {
                            if player.currentSong?.id == song.id && player.isPlaying { Image(systemName: "waveform").symbolEffect(.variableColor.iterative) }
                            else { Text(String(number)).monospacedDigit() }
                        }.font(.subheadline).foregroundStyle(.secondary).frame(width: 24)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 5) {
                            Text(song.title).lineLimit(1)
                            if song.contentRating == .explicit { Image(systemName: "e.square.fill").font(.system(size: 10)).opacity(0.55) }
                        }
                        if showCover { Text(song.artistName).font(.subheadline).foregroundStyle(.secondary).lineLimit(1) }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).disabled(player.isWorking)
            Menu {
                Button("Odtwórz następny", systemImage: "text.line.first.and.arrowtriangle.forward") { player.enqueue(song, next: true) }
                Button("Odtwórz na końcu", systemImage: "text.line.last.and.arrowtriangle.forward") { player.enqueue(song, next: false) }
                Divider()
                Button("Dodaj do biblioteki", systemImage: "plus") { Task { await music.addSong(song) } }
                Button("Dodaj do playlisty…", systemImage: "text.badge.plus") { addToPlaylist = true }
                Button("Tekst utworu", systemImage: "quote.bubble") { lyrics = true }
                if let url = song.url { ShareLink(item: url) { Label("Udostępnij utwór", systemImage: "square.and.arrow.up") } }
            } label: { Image(systemName: "ellipsis").font(.body.weight(.semibold)).frame(width: 38, height: 44).contentShape(Rectangle()) }
                .tint(.primary).accessibilityLabel("Opcje: \(song.title)")
        }
        .frame(minHeight: showCover ? 62 : 48)
        .sheet(isPresented: $lyrics) { LyricsView(song: song) }
        .sheet(isPresented: $addToPlaylist) { AddToPlaylistView(song: song) }
    }
}

struct AddToPlaylistView: View {
    @EnvironmentObject private var music: MusicService
    @Environment(\.dismiss) private var dismiss
    let song: Song
    var body: some View {
        NavigationStack {
            List(music.playlists) { playlist in
                Button {
                    Task { await music.add(song, to: playlist); dismiss() }
                } label: {
                    HStack { CoverArt(artwork: playlist.artwork, size: 48); Text(playlist.name).foregroundStyle(.primary) }
                }
            }
            .overlay { if music.playlists.isEmpty { ContentUnavailableView("Brak playlist", systemImage: "music.note.list", description: Text("Utwórz playlistę w Bibliotece.")) } }
            .navigationTitle("Dodaj do playlisty").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Zamknij") { dismiss() } } }
        }
    }
}

struct InlineError: View {
    let text: String
    var retry: (() -> Void)? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(text, systemImage: "exclamationmark.circle").font(.callout).foregroundStyle(.secondary)
            if let retry { Button("Spróbuj ponownie", action: retry).font(.callout.bold()) }
        }.padding().frame(maxWidth: .infinity, alignment: .leading).background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: .zero)
        view.showsVolumeSlider = false
        view.tintColor = .white
        return view
    }
    func updateUIView(_ uiView: MPVolumeView, context: Context) { }
}

struct SystemVolumeSlider: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: .zero)
        view.showsRouteButton = false
        view.tintColor = .white.withAlphaComponent(0.8)
        return view
    }
    func updateUIView(_ uiView: MPVolumeView, context: Context) { }
}
