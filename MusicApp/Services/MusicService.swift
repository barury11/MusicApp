import Foundation
import MusicKit
import SwiftUI

struct RecommendationShelf: Identifiable {
    let id: String
    let title: String
    let albums: [Album]
    let playlists: [Playlist]
}

@MainActor
final class MusicService: ObservableObject {
    @Published var authorization = MusicAuthorization.currentStatus
    @Published var canPlayCatalog = false
    @Published var albums: [Album] = []
    @Published var songs: [Song] = []
    @Published var playlists: [Playlist] = []
    @Published var artists: [Artist] = []
    @Published var chartAlbums: [Album] = []
    @Published var chartSongs: [Song] = []
    @Published var chartPlaylists: [Playlist] = []
    @Published var shelves: [RecommendationShelf] = []
    @Published var stations: [Station] = []
    @Published var loadingLibrary = false
    @Published var loadingCatalog = false
    @Published var libraryError: String?
    @Published var catalogError: String?
    @Published var message: String?
    private var downloadedOnly = false
    private let automaticTokenProvider = MusicDataRequest.tokenProvider

    init() { applyStoredToken() }

    func applyStoredToken() {
        if let token = TokenStore.read(), !token.isEmpty { MusicDataRequest.tokenProvider = ManualMusicTokenProvider(token: token) }
        else { MusicDataRequest.tokenProvider = automaticTokenProvider }
    }
    func restoreAuthorization() async {
        authorization = MusicAuthorization.currentStatus
        if authorization == .authorized { await refresh() }
    }
    func authorize() async {
        authorization = await MusicAuthorization.request()
        if authorization == .authorized { await refresh() }
    }
    func refresh() async {
        do { canPlayCatalog = try await MusicSubscription.current.canPlayCatalogContent }
        catch { canPlayCatalog = false }
        async let library: () = loadLibrary(downloadedOnly: downloadedOnly)
        async let catalog: () = loadCatalog()
        _ = await (library, catalog)
    }
    func loadLibrary(downloadedOnly: Bool = false) async {
        guard authorization == .authorized, !loadingLibrary else { return }
        self.downloadedOnly = downloadedOnly
        loadingLibrary = true
        libraryError = nil
        defer { loadingLibrary = false }
        do {
            var request = MusicLibraryRequest<Album>()
            request.sort(by: \.libraryAddedDate, ascending: false)
            request.includeOnlyDownloadedContent = downloadedOnly
            request.limit = 100
            var batch = try await request.response().items
            var loaded = Array(batch)
            albums = loaded
            while batch.hasNextBatch {
                try Task.checkCancellation()
                guard let next = try await batch.nextBatch() else { break }
                loaded.append(contentsOf: next); batch = next; albums = loaded
            }
            var songRequest = MusicLibraryRequest<Song>()
            songRequest.sort(by: \.title, ascending: true)
            songRequest.includeOnlyDownloadedContent = downloadedOnly
            songRequest.limit = 100
            var songBatch = try await songRequest.response().items
            songs = Array(songBatch)
            while songBatch.hasNextBatch {
                try Task.checkCancellation()
                guard let next = try await songBatch.nextBatch() else { break }
                songs.append(contentsOf: next); songBatch = next
            }
            var playlistRequest = MusicLibraryRequest<Playlist>()
            playlistRequest.includeOnlyDownloadedContent = downloadedOnly
            playlistRequest.limit = 100
            var playlistBatch = try await playlistRequest.response().items
            playlists = Array(playlistBatch)
            while playlistBatch.hasNextBatch {
                try Task.checkCancellation()
                guard let next = try await playlistBatch.nextBatch() else { break }
                playlists.append(contentsOf: next); playlistBatch = next
            }
            var artistRequest = MusicLibraryRequest<Artist>()
            artistRequest.includeOnlyDownloadedContent = downloadedOnly
            artistRequest.limit = 100
            var artistBatch = try await artistRequest.response().items
            artists = Array(artistBatch)
            while artistBatch.hasNextBatch {
                try Task.checkCancellation()
                guard let next = try await artistBatch.nextBatch() else { break }
                artists.append(contentsOf: next); artistBatch = next
            }
        } catch is CancellationError { }
        catch { libraryError = error.localizedDescription }
    }
    func loadCatalog() async {
        guard authorization == .authorized, !loadingCatalog else { return }
        loadingCatalog = true
        catalogError = nil
        defer { loadingCatalog = false }
        do {
            var request = MusicCatalogChartsRequest(types: [Album.self, Song.self, Playlist.self])
            request.limit = 30
            let response = try await request.response()
            chartAlbums = response.albumCharts.first.map { Array($0.items) } ?? []
            chartSongs = response.songCharts.first.map { Array($0.items) } ?? []
            chartPlaylists = response.playlistCharts.first.map { Array($0.items) } ?? []
        } catch { catalogError = "Katalog Apple Music: \(error.localizedDescription). Sprawdź dostęp MusicKit w Ustawieniach aplikacji." }
        do {
            let response = try await MusicPersonalRecommendationsRequest().response()
            shelves = response.recommendations.map {
                RecommendationShelf(id: $0.id.rawValue, title: $0.title ?? "Dla Ciebie", albums: Array($0.albums), playlists: Array($0.playlists))
            }
            var seen = Set<String>()
            stations = response.recommendations.flatMap { Array($0.stations) }.filter { seen.insert($0.id.rawValue).inserted }
        } catch {
            if catalogError == nil { catalogError = "Nie udało się pobrać rekomendacji: \(error.localizedDescription)" }
        }
    }
    func albumTracks(_ album: Album) async throws -> [Track] {
        let detailed = try await album.with(.tracks)
        guard var items = detailed.tracks else { return [] }
        var tracks = Array(items)
        while items.hasNextBatch {
            guard let next = try await items.nextBatch() else { break }
            tracks.append(contentsOf: next); items = next
        }
        return tracks
    }
    func playlistTracks(_ playlist: Playlist) async throws -> [Track] {
        let detailed = try await playlist.with(.tracks)
        guard var items = detailed.tracks else { return [] }
        var tracks = Array(items)
        while items.hasNextBatch {
            guard let next = try await items.nextBatch() else { break }
            tracks.append(contentsOf: next); items = next
        }
        return tracks
    }
    func addAlbum(_ album: Album) async {
        do { try await MusicLibrary.shared.add(album); message = "Dodano album do biblioteki"; await loadLibrary(downloadedOnly: downloadedOnly) }
        catch { message = error.localizedDescription }
    }
    func addSong(_ song: Song) async {
        do { try await MusicLibrary.shared.add(song); message = "Dodano utwór do biblioteki" }
        catch { message = error.localizedDescription }
    }
    func favorite(id: MusicItemID, url: URL?, type: String) async {
        var catalogID = id.rawValue
        if !catalogID.allSatisfy(\.isNumber) && type != "playlists", let url, url.host == "music.apple.com" {
            let queryID = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "i" })?.value
            catalogID = (type == "songs" ? queryID : nil) ?? url.lastPathComponent
        }
        guard (type == "playlists" && catalogID.hasPrefix("pl.")) || (!catalogID.isEmpty && catalogID.allSatisfy(\.isNumber)) else {
            message = "Nie znaleziono odpowiednika w katalogu. Otwórz tę pozycję w wyszukiwaniu Apple Music, aby dodać ją do ulubionych."
            return
        }
        do {
            var components = URLComponents(string: "https://api.music.apple.com/v1/me/favorites")!
            components.queryItems = [URLQueryItem(name: "ids[\(type)]", value: catalogID)]
            var request = URLRequest(url: components.url!)
            request.httpMethod = "POST"
            _ = try await MusicDataRequest(urlRequest: request).response()
            message = "Wysłano do Apple Music prośbę o dodanie do ulubionych."
        } catch { message = error.localizedDescription }
    }
    func createPlaylist(name: String) async {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do {
            let playlist = try await MusicLibrary.shared.createPlaylist(name: name)
            playlists.insert(playlist, at: 0)
            message = "Utworzono playlistę"
        } catch { message = error.localizedDescription }
    }
    func add(_ song: Song, to playlist: Playlist) async {
        do { try await MusicLibrary.shared.add(song, to: playlist); message = "Dodano do playlisty" }
        catch { message = error.localizedDescription }
    }
}
