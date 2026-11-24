import SwiftUI
import MusicKit

struct SearchView: View {
    @EnvironmentObject private var player: PlaybackService
    @State private var query = ""
    @State private var libraryScope = false
    @State private var songs: [Song] = []
    @State private var albums: [Album] = []
    @State private var artists: [Artist] = []
    @State private var playlists: [Playlist] = []
    @State private var loading = false
    @State private var error: String?
    private var searchKey: String { "\(libraryScope):\(query)" }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                Picker("Źródło", selection: $libraryScope) { Text("Apple Music").tag(false); Text("Twoja biblioteka").tag(true) }.pickerStyle(.segmented).padding(.horizontal, 20)
                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Przeglądaj muzykę").font(.title2.bold())
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(Array(["Pop", "Hip-hop", "R&B", "Rock", "Dance", "Alternatywa", "Jazz", "Muzyka klasyczna"].enumerated()), id: \.offset) { index, genre in
                                Button { query = genre } label: {
                                    ZStack(alignment: .bottomLeading) {
                                        LinearGradient(colors: [Color(hue: Double(index) / 9, saturation: 0.7, brightness: 0.75), Color(hue: Double(index) / 9, saturation: 0.8, brightness: 0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                        Image(systemName: "music.note").font(.system(size: 70, weight: .bold)).rotationEffect(.degrees(-20)).offset(x: 100, y: -8).opacity(0.15)
                                        Text(genre).font(.title3.bold()).foregroundStyle(.white).padding(14)
                                    }.frame(height: 108).clipShape(RoundedRectangle(cornerRadius: 12))
                                }.buttonStyle(.plain)
                            }
                        }
                    }.padding(.horizontal, 20)
                } else {
                    if loading { ProgressView().frame(maxWidth: .infinity).padding() }
                    if let error { InlineError(text: error).padding(.horizontal, 20) }
                    if !songs.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Utwory").font(.title2.bold()).padding(.bottom, 8)
                            ForEach(songs) { song in
                                SongRow(song: song) { Task { await player.playSongs(songs, startingAt: song) } }
                                Divider().padding(.leading, 60)
                            }
                        }.padding(.horizontal, 20)
                    }
                    if !albums.isEmpty { AlbumShelf(title: "Albumy", albums: albums) }
                    if !playlists.isEmpty { PlaylistShelf(title: "Playlisty", playlists: playlists) }
                    if !artists.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Wykonawcy").font(.title2.bold())
                            ForEach(artists) { artist in
                                NavigationLink { ArtistDetailView(artist: artist) } label: {
                                    HStack(spacing: 14) { CoverArt(artwork: artist.artwork, size: 60, radius: 30); Text(artist.name).foregroundStyle(.primary); Spacer(); Image(systemName: "chevron.right").foregroundStyle(.tertiary) }
                                }.buttonStyle(.plain)
                            }
                        }.padding(.horizontal, 20)
                    }
                    if !loading && error == nil && songs.isEmpty && albums.isEmpty && artists.isEmpty && playlists.isEmpty {
                        ContentUnavailableView.search(text: query)
                    }
                }
            }.padding(.vertical, 12).padding(.bottom, 24)
        }
        .navigationTitle("Szukaj")
        .searchable(text: $query, prompt: "Wykonawcy, utwory, albumy")
        .task(id: searchKey) { await search() }
    }
    @MainActor private func search() async {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        songs = []; albums = []; artists = []; playlists = []; error = nil
        guard !term.isEmpty else { loading = false; return }
        loading = true
        do {
            try await Task.sleep(for: .milliseconds(350))
            if libraryScope {
                var request = MusicLibrarySearchRequest(term: term, types: [Song.self, Album.self, Artist.self, Playlist.self])
                request.limit = 25
                let response = try await request.response()
                try Task.checkCancellation()
                songs = Array(response.songs); albums = Array(response.albums); artists = Array(response.artists); playlists = Array(response.playlists)
            } else {
                var request = MusicCatalogSearchRequest(term: term, types: [Song.self, Album.self, Artist.self, Playlist.self])
                request.limit = 25
                let response = try await request.response()
                try Task.checkCancellation()
                songs = Array(response.songs); albums = Array(response.albums); artists = Array(response.artists); playlists = Array(response.playlists)
            }
            loading = false
        } catch is CancellationError { }
        catch { if !Task.isCancelled { self.error = error.localizedDescription; loading = false } }
    }
}
