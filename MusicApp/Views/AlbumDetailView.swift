import SwiftUI
import MusicKit

struct AlbumDetailView: View {
    @EnvironmentObject private var music: MusicService
    @EnvironmentObject private var player: PlaybackService
    @EnvironmentObject private var custom: CustomizationStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let album: Album
    @State private var tracks: [Track] = []
    @State private var loading = true
    @State private var error: String?
    @State private var editing: AlbumEditorSection?
    @State private var confirmReset = false
    private var id: String { album.id.rawValue }
    private var style: AlbumCustomization { custom.album(id) }
    private var background: Color {
        if let hex = style.backgroundHex, let color = Color(hex: hex) { return color }
        if let cgColor = album.artwork?.backgroundColor { return Color(cgColor: cgColor) }
        return Color(.systemBackground)
    }
    private var foreground: Color {
        if let hex = style.accentHex, let color = Color(hex: hex) { return color }
        if let cgColor = album.artwork?.primaryTextColor { return Color(cgColor: cgColor) }
        return .primary
    }
    private var portrait: UIImage? { style.usePortraitArtwork ? custom.image(style.portraitArtwork) : nil }
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let portrait {
                    GeometryReader { geometry in
                        let offset = geometry.frame(in: .named("albumScroll")).minY
                        Image(uiImage: portrait).resizable().scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height + (reduceMotion ? 0 : max(0, offset)))
                            .clipped().offset(y: reduceMotion ? 0 : -max(0, offset))
                        LinearGradient(colors: [.clear, background.opacity(0.15), background], startPoint: .center, endPoint: .bottom)
                    }.frame(height: 460).overlay(alignment: .bottom) { albumIdentity.padding(.horizontal, 24).padding(.bottom, 16) }
                } else {
                    VStack(spacing: 22) {
                        CoverArt(artwork: album.artwork, albumID: id, size: 280, radius: 10)
                            .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
                        albumIdentity
                    }.frame(maxWidth: .infinity).padding(.top, 22).padding(.horizontal, 24)
                }
                HStack(spacing: 14) {
                    Button { Task { await player.play(tracks, albumID: id) } } label: { Label("Odtwórz", systemImage: "play.fill").frame(maxWidth: .infinity).frame(height: 48) }
                    Button { Task { await player.play(tracks, albumID: id, shuffle: true) } } label: { Label("Mieszaj", systemImage: "shuffle").frame(maxWidth: .infinity).frame(height: 48) }
                }
                .font(.headline).buttonStyle(.plain)
                .backgroundStyle(foreground.opacity(0.1))
                .padding(.horizontal, 20).padding(.top, 22)
                .disabled(tracks.isEmpty || player.isWorking)
                .modifier(AlbumPlayButtons())
                if loading { ProgressView().tint(foreground).padding(35) }
                if let error { InlineError(text: error) { Task { await load() } }.padding(20) }
                LazyVStack(spacing: 0) {
                    ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                        if index == 0 || tracks[index - 1].discNumber != track.discNumber {
                            if let disc = track.discNumber, disc > 1 || tracks.contains(where: { ($0.discNumber ?? 1) > 1 }) {
                                Text("Płyta \(disc)").font(.headline).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 20).padding(.bottom, 8)
                            }
                        }
                        Divider().overlay(foreground.opacity(0.12))
                        if case .song(let song) = track {
                            SongRow(song: song, showCover: false, number: track.trackNumber ?? index + 1, albumID: id) { Task { await player.play(tracks, startingAt: track, albumID: id) } }
                        } else {
                            Label(track.title, systemImage: "video").font(.body).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 14)
                        }
                    }
                    if !tracks.isEmpty { Divider().overlay(foreground.opacity(0.12)) }
                }.padding(.horizontal, 20).padding(.top, 24)
                VStack(alignment: .leading, spacing: 10) {
                    if let date = album.releaseDate { Text(date.formatted(date: .long, time: .omitted)) }
                    let seconds = tracks.compactMap(\.duration).reduce(0, +)
                    Text("\(album.trackCount) utworów • \(Int(seconds / 60)) min")
                    if let copyright = album.copyright { Text(copyright).font(.caption) }
                    if let notes = album.editorialNotes?.standard { Text(notes.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)).font(.subheadline).padding(.top, 14) }
                }.font(.footnote).opacity(0.7).frame(maxWidth: .infinity, alignment: .leading).padding(20).padding(.bottom, 30)
            }
        }
        .coordinateSpace(name: "albumScroll")
        .background(background.ignoresSafeArea())
        .foregroundStyle(foreground).tint(foreground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { Text(album.title).font(.subheadline.weight(.semibold)).lineLimit(1) }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Dodaj do biblioteki", systemImage: "plus") { Task { await music.addAlbum(album) } }
                    Button(custom.isPinned(id) ? "Odepnij album" : "Przypnij album", systemImage: custom.isPinned(id) ? "pin.slash" : "pin") {
                        do { try custom.togglePin(id) } catch { custom.errorMessage = error.localizedDescription }
                    }
                    Button("Odtwórz następny", systemImage: "text.line.first.and.arrowtriangle.forward") {
                        player.perform { try await player.engine.queue.insert(album, position: .afterCurrentEntry) }
                    }
                    Button("Odtwórz na końcu", systemImage: "text.line.last.and.arrowtriangle.forward") {
                        player.perform { try await player.engine.queue.insert(album, position: .tail) }
                    }
                    if let url = album.url { ShareLink(item: url) { Label("Udostępnij album", systemImage: "square.and.arrow.up") } }
                    Divider()
                    Menu("Dostosuj", systemImage: "paintbrush.pointed") {
                        Button("Okładka kwadratowa", systemImage: "square") { editing = .square }
                        Button("Okładka pionowa", systemImage: "rectangle.portrait") { editing = .portrait }
                        Button("Logo i jego położenie", systemImage: "textformat.size") { editing = .logo }
                        Button("Kolory albumu", systemImage: "paintpalette") { editing = .colors }
                        Button("Własne teksty utworów", systemImage: "quote.bubble") { editing = .lyrics }
                        Divider()
                        Button("Przywróć wygląd albumu", systemImage: "arrow.counterclockwise", role: .destructive) { confirmReset = true }
                    }
                } label: { Image(systemName: "ellipsis").font(.body.bold()).frame(width: 32, height: 32) }.accessibilityLabel("Opcje albumu")
            }
        }
        .sheet(item: $editing) { section in AlbumEditorView(album: album, tracks: tracks, initialSection: section) }
        .confirmationDialog("Przywrócić oryginalny wygląd tego albumu?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Przywróć wygląd", role: .destructive) { do { try custom.resetAlbum(id) } catch { custom.errorMessage = error.localizedDescription } }
        }
        .task(id: id) { await load() }
    }
    @ViewBuilder private var albumIdentity: some View {
        VStack(spacing: 6) {
            if let image = custom.image(style.logo) {
                GeometryReader { geometry in
                    Image(uiImage: image).resizable().scaledToFit()
                        .frame(width: geometry.size.width * style.logoScale, height: 90)
                        .frame(maxWidth: .infinity, alignment: style.logoAlignment.swiftUI)
                        .offset(x: style.logoOffsetX, y: style.logoOffsetY)
                }.frame(height: 90).accessibilityLabel(album.title)
            } else { Text(album.title).font(.system(size: 23, weight: .bold)).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true) }
            Text(album.artistName).font(.title3).multilineTextAlignment(.center)
            Text("\(album.genreNames.first ?? "ALBUM") • \(album.releaseDate.map { String(Calendar.current.component(.year, from: $0)) } ?? "")").font(.caption.weight(.medium)).textCase(.uppercase).opacity(0.65)
        }.frame(maxWidth: .infinity)
    }
    private func load() async {
        loading = true; error = nil
        defer { loading = false }
        do { tracks = try await music.albumTracks(album) }
        catch { self.error = error.localizedDescription }
    }
}

private struct AlbumPlayButtons: ViewModifier {
    func body(content: Content) -> some View { content.buttonBorderShape(.roundedRectangle(radius: 12)).buttonStyle(.bordered) }
}

struct PlaylistDetailView: View {
    @EnvironmentObject private var music: MusicService
    @EnvironmentObject private var player: PlaybackService
    let playlist: Playlist
    @State private var tracks: [Track] = []
    @State private var loading = true
    @State private var error: String?
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                CoverArt(artwork: playlist.artwork, size: 280, radius: 10).shadow(radius: 12, y: 6).padding(.top, 20)
                VStack(spacing: 5) { Text(playlist.name).font(.title2.bold()); Text(playlist.curatorName ?? "Apple Music").foregroundStyle(.secondary) }.multilineTextAlignment(.center)
                HStack(spacing: 14) {
                    Button { Task { await player.play(tracks) } } label: { Label("Odtwórz", systemImage: "play.fill").frame(maxWidth: .infinity) }
                    Button { Task { await player.play(tracks, shuffle: true) } } label: { Label("Mieszaj", systemImage: "shuffle").frame(maxWidth: .infinity) }
                }.buttonStyle(.bordered).controlSize(.large).disabled(tracks.isEmpty)
                if loading { ProgressView().padding() }
                if let error { InlineError(text: error) }
                LazyVStack(spacing: 0) {
                    ForEach(tracks) { track in
                        if case .song(let song) = track {
                            SongRow(song: song) { Task { await player.play(tracks, startingAt: track) } }
                            Divider().padding(.leading, 60)
                        }
                    }
                }
            }.padding(.horizontal, 20).padding(.bottom, 24)
        }
        .navigationTitle(playlist.name).navigationBarTitleDisplayMode(.inline)
        .toolbar { if let url = playlist.url { ToolbarItem(placement: .topBarTrailing) { ShareLink(item: url) } } }
        .task {
            do { tracks = try await music.playlistTracks(playlist) } catch { self.error = error.localizedDescription }
            loading = false
        }
    }
}
