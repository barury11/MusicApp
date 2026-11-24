import SwiftUI
import MusicKit

struct HomeView: View {
    @EnvironmentObject private var music: MusicService
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 30) {
                if music.loadingCatalog && music.shelves.isEmpty { ProgressView().frame(maxWidth: .infinity).padding(.vertical, 40) }
                ForEach(music.shelves) { shelf in
                    if !shelf.albums.isEmpty { AlbumShelf(title: shelf.title, albums: shelf.albums) }
                    if !shelf.playlists.isEmpty { PlaylistShelf(title: shelf.albums.isEmpty ? shelf.title : "Playlisty dla Ciebie", playlists: shelf.playlists) }
                }
                if !music.albums.isEmpty { AlbumShelf(title: "Ostatnio dodane", albums: Array(music.albums.prefix(16))) }
                if !music.chartAlbums.isEmpty { AlbumShelf(title: "Popularne albumy", albums: music.chartAlbums) }
                if let error = music.catalogError { InlineError(text: error) { Task { await music.loadCatalog() } }.padding(.horizontal, 20) }
                if !music.loadingCatalog && music.albums.isEmpty && music.chartAlbums.isEmpty && music.shelves.isEmpty {
                    ContentUnavailableView("Twoja muzyka czeka", systemImage: "music.note", description: Text("Dodaj muzykę do biblioteki lub sprawdź konfigurację MusicKit w Ustawieniach."))
                }
            }.padding(.vertical, 12).padding(.bottom, 24)
        }.navigationTitle("Główna").refreshable { await music.refresh() }
    }
}

struct DiscoverView: View {
    @EnvironmentObject private var music: MusicService
    @EnvironmentObject private var player: PlaybackService
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 30) {
                if !music.chartPlaylists.isEmpty { PlaylistShelf(title: "Najpopularniejsze playlisty", playlists: music.chartPlaylists) }
                if !music.chartAlbums.isEmpty { AlbumShelf(title: "Na szczycie", albums: music.chartAlbums) }
                if !music.chartSongs.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Najpopularniejsze utwory").font(.title2.bold())
                        ForEach(music.chartSongs.prefix(20)) { song in
                            SongRow(song: song) { Task { await player.playSongs(music.chartSongs, startingAt: song) } }
                            Divider().padding(.leading, 60)
                        }
                    }.padding(.horizontal, 20)
                }
                if music.loadingCatalog { ProgressView().frame(maxWidth: .infinity).padding() }
                if let error = music.catalogError { InlineError(text: error) { Task { await music.loadCatalog() } }.padding(.horizontal, 20) }
            }.padding(.vertical, 12).padding(.bottom, 24)
        }.navigationTitle("Nowości").refreshable { await music.loadCatalog() }
    }
}

struct RadioView: View {
    @EnvironmentObject private var music: MusicService
    @EnvironmentObject private var player: PlaybackService
    @State private var catalogStations: [Station] = []
    @State private var error: String?
    @State private var loading = false
    private var stations: [Station] {
        var seen = Set<String>()
        return (music.stations + catalogStations).filter { seen.insert($0.id.rawValue).inserted }
    }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                Text("Odkryj coś nowego").font(.title2.bold())
                ForEach(stations, id: \.id) { station in StationRow(station: station) }
                if loading { ProgressView().frame(maxWidth: .infinity).padding() }
                if let error { InlineError(text: error) { Task { await load() } } }
                if !loading && stations.isEmpty && error == nil { ContentUnavailableView("Brak stacji", systemImage: "radio", description: Text("Stacje pojawią się po połączeniu z katalogiem Apple Music.")) }
            }.padding(20)
        }.navigationTitle("Radio").task { if catalogStations.isEmpty { await load() } }.refreshable { await load() }
    }
    private func load() async {
        loading = true; error = nil
        defer { loading = false }
        do {
            var request = MusicCatalogSearchRequest(term: "Apple Music", types: [Station.self])
            request.limit = 25
            catalogStations = Array(try await request.response().stations)
        } catch { self.error = error.localizedDescription }
    }
}

private struct StationRow: View {
    @EnvironmentObject private var player: PlaybackService
    let station: Station
    var body: some View {
        Button { Task { await player.playStation(station) } } label: {
            HStack(spacing: 16) {
                CoverArt(artwork: station.artwork, size: 92, radius: 12)
                VStack(alignment: .leading, spacing: 7) {
                    Text(station.name).font(.headline).foregroundStyle(.primary)
                    Label("Odtwórz stację", systemImage: "dot.radiowaves.left.and.right").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "play.fill").foregroundStyle(Color.musicRed)
            }
        }.buttonStyle(.plain)
    }
}

private enum LibraryDestination: String, CaseIterable, Identifiable {
    case playlists = "Playlisty", artists = "Wykonawcy", albums = "Albumy", songs = "Utwory"
    var id: String { rawValue }
    var icon: String {
        switch self { case .playlists: return "music.note.list"; case .artists: return "music.mic"; case .albums: return "square.stack"; case .songs: return "music.note" }
    }
}

struct LibraryView: View {
    @EnvironmentObject private var music: MusicService
    @EnvironmentObject private var custom: CustomizationStore
    @State private var downloaded = false
    @State private var creating = false
    @State private var playlistName = ""
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                categories
                Toggle(isOn: $downloaded) { Label("Pobrane", systemImage: "arrow.down.circle").font(.title3) }.tint(Color.musicRed).padding(.vertical, 14)
                if music.loadingLibrary { ProgressView("Wczytywanie biblioteki…").font(.footnote).padding(.vertical) }
                if let error = music.libraryError { InlineError(text: error) { Task { await music.loadLibrary(downloadedOnly: downloaded) } }.padding(.vertical, 12) }
                if !pinnedAlbums.isEmpty {
                    Text("Przypięte").font(.title2.bold()).padding(.top, 20).padding(.bottom, 14)
                    AlbumGrid(albums: pinnedAlbums)
                }
                Text("Ostatnio dodane").font(.title2.bold()).padding(.top, 24).padding(.bottom, 16)
                AlbumGrid(albums: music.albums)
                if music.albums.isEmpty && !music.loadingLibrary {
                    ContentUnavailableView("Brak albumów", systemImage: "square.stack", description: Text(downloaded ? "Nie znaleziono pobranych albumów." : "Albumy dodane do biblioteki Apple Music pojawią się tutaj."))
                }
            }.padding(.horizontal, 20).padding(.bottom, 24)
        }
        .navigationTitle("Biblioteka")
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Nowa playlista", systemImage: "plus") { creating = true } } }
        .alert("Nowa playlista", isPresented: $creating) {
            TextField("Nazwa", text: $playlistName)
            Button("Utwórz") { let name = playlistName; playlistName = ""; Task { await music.createPlaylist(name: name) } }
            Button("Anuluj", role: .cancel) { }
        }
        .onChange(of: downloaded) { _, value in Task { await music.loadLibrary(downloadedOnly: value) } }
        .refreshable { await music.loadLibrary(downloadedOnly: downloaded) }
    }
    private var pinnedAlbums: [Album] { music.albums.filter { custom.isPinned($0.id.rawValue) } }
    private var categories: some View {
        ForEach(LibraryDestination.allCases) { destination in
            NavigationLink { LibraryCollectionView(kind: destination.rawValue) } label: {
                HStack(spacing: 16) {
                    Image(systemName: destination.icon).foregroundStyle(Color.musicRed).font(.title2).frame(width: 28)
                    Text(destination.rawValue).font(.title3).foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.tertiary).font(.subheadline.weight(.semibold))
                }.padding(.vertical, 13)
            }.buttonStyle(.plain)
            Divider().padding(.leading, 44)
        }
    }

}

struct AlbumGrid: View {
    let albums: [Album]
    @Namespace private var namespace
    var body: some View {
        GeometryReader { geometry in
            let size = max(100, (geometry.size.width - 18) / 2)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 18), GridItem(.flexible())], alignment: .leading, spacing: 22) {
                ForEach(albums) { album in
                    NavigationLink {
                        AlbumDetailView(album: album).navigationTransition(.zoom(sourceID: album.id, in: namespace))
                    } label: { AlbumTile(album: album, size: size).matchedTransitionSource(id: album.id, in: namespace) }.buttonStyle(.plain)
                }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { measuredHeight = $0 }
        }
        .frame(height: max(1, measuredHeight))
    }
    @State private var measuredHeight: CGFloat = 1
}

struct LibraryCollectionView: View {
    @EnvironmentObject private var music: MusicService
    @EnvironmentObject private var player: PlaybackService
    let kind: String
    @State private var sortByName = false
    var body: some View {
        Group {
            if kind == "Albumy" {
                ScrollView { AlbumGrid(albums: sortByName ? music.albums.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending } : music.albums).padding(20) }
            } else if kind == "Playlisty" {
                List(music.playlists) { playlist in
                    NavigationLink { PlaylistDetailView(playlist: playlist) } label: {
                        HStack(spacing: 14) { CoverArt(artwork: playlist.artwork, size: 60); Text(playlist.name) }
                    }
                }.listStyle(.plain)
            } else if kind == "Wykonawcy" {
                List(music.artists) { artist in
                    NavigationLink { ArtistDetailView(artist: artist) } label: {
                        HStack(spacing: 14) { CoverArt(artwork: artist.artwork, size: 56, radius: 28); Text(artist.name) }
                    }
                }.listStyle(.plain)
            } else {
                List(music.songs) { song in SongRow(song: song) { Task { await player.playSongs(music.songs, startingAt: song) } }.listRowSeparator(.hidden) }.listStyle(.plain)
            }
        }
        .navigationTitle(kind)
        .toolbar { if kind == "Albumy" { ToolbarItem(placement: .topBarTrailing) { Menu("Sortuj", systemImage: "arrow.up.arrow.down") { Toggle("Według nazwy", isOn: $sortByName) } } } }
    }
}

struct ArtistDetailView: View {
    let artist: Artist
    @State private var albums: [Album] = []
    @State private var error: String?
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                CoverArt(artwork: artist.artwork, size: 220, radius: 110).padding(.top)
                Text(artist.name).font(.largeTitle.bold()).multilineTextAlignment(.center)
                if let error { InlineError(text: error) }
                AlbumGrid(albums: albums)
            }.padding(20)
        }.navigationTitle(artist.name).navigationBarTitleDisplayMode(.inline)
        .task {
            do { albums = Array(try await artist.with(.albums).albums ?? []) }
            catch { self.error = error.localizedDescription }
        }
    }
}
