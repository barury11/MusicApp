import Foundation
import MusicKit
import SwiftUI

@MainActor
final class PlaybackService: ObservableObject {
    let engine = ApplicationMusicPlayer.shared
    @Published var currentSong: Song?
    @Published var currentTitle: String = ""
    @Published var currentArtist: String = ""
    @Published var currentArtwork: Artwork?
    @Published var albumKey: String?
    @Published var position: Double = 0
    @Published var duration: Double = 0
    @Published var showPlayer = false
    @Published var errorMessage: String?
    @Published var isWorking = false
    private var songAlbumIDs: [String: String] = [:]
    private var poller: Task<Void, Never>?

    init() {
        poller = Task { [weak self] in
            while !Task.isCancelled {
                self?.synchronize()
                do { try await Task.sleep(for: .milliseconds(300)) } catch { break }
            }
        }
    }
    deinit { poller?.cancel() }
    var isPlaying: Bool { engine.state.playbackStatus == .playing }
    var hasItem: Bool { engine.queue.currentEntry != nil }
    var entries: [MusicPlayer.Queue.Entry] { Array(engine.queue.entries) }

    func perform(_ action: @escaping () async throws -> Void) {
        Task { do { try await action(); synchronize() } catch { errorMessage = error.localizedDescription } }
    }
    func play(_ tracks: [Track], startingAt track: Track? = nil, albumID: String? = nil, shuffle: Bool = false) async {
        guard !tracks.isEmpty, !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        if let albumID {
            for item in tracks { if case .song(let song) = item { songAlbumIDs[song.id.rawValue] = albumID } }
        }
        do {
            engine.state.shuffleMode = shuffle ? .songs : .off
            engine.queue = ApplicationMusicPlayer.Queue(for: tracks, startingAt: track ?? tracks.first)
            try await engine.play()
            synchronize()
        } catch { errorMessage = error.localizedDescription }
    }
    func playSongs(_ songs: [Song], startingAt song: Song? = nil, shuffle: Bool = false) async {
        await play(songs.map { Track.song($0) }, startingAt: song.map { Track.song($0) }, shuffle: shuffle)
    }
    func playStation(_ station: Station) async {
        do {
            engine.queue = ApplicationMusicPlayer.Queue(for: [station])
            try await engine.play(); synchronize()
        } catch { errorMessage = error.localizedDescription }
    }
    func toggle() {
        if isPlaying { engine.pause(); synchronize() }
        else { perform { try await self.engine.play() } }
    }
    func next() { perform { try await self.engine.skipToNextEntry() } }
    func previous() { perform { try await self.engine.skipToPreviousEntry() } }
    func seek(_ value: Double) {
        guard value.isFinite, duration > 0 else { return }
        engine.playbackTime = max(0, min(value, duration)); position = engine.playbackTime
    }
    func enqueue(_ song: Song, next: Bool) {
        perform { try await self.engine.queue.insert(song, position: next ? .afterCurrentEntry : .tail) }
    }
    func select(_ entry: MusicPlayer.Queue.Entry) {
        engine.queue.currentEntry = entry
        perform { try await self.engine.play() }
    }
    func toggleShuffle() { engine.state.shuffleMode = engine.state.shuffleMode == .off ? .songs : .off }
    func toggleRepeat() {
        switch engine.state.repeatMode {
        case .none: engine.state.repeatMode = .all
        case .all: engine.state.repeatMode = .one
        default: engine.state.repeatMode = .none
        }
    }
    private func synchronize() {
        let time = engine.playbackTime
        position = time.isFinite ? max(0, time) : 0
        if let entry = engine.queue.currentEntry {
            currentTitle = entry.title
            currentArtist = entry.subtitle ?? ""
            currentArtwork = entry.artwork
            if case .song(let song) = entry.item {
                currentSong = song
                duration = song.duration ?? 0
                albumKey = songAlbumIDs[song.id.rawValue] ?? song.albums?.first?.id.rawValue
            } else {
                currentSong = nil; duration = 0; albumKey = nil
            }
        } else {
            currentSong = nil; currentTitle = ""; currentArtist = ""; currentArtwork = nil; duration = 0; albumKey = nil
        }
    }
}
