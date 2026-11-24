import XCTest
@testable import MusicApp

final class CustomizationTests: XCTestCase {
    @MainActor func testCustomizationSurvivesRelaunchAndResetPreservesLyrics() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CustomizationStore(directory: directory)
        var style = AlbumCustomization()
        style.backgroundHex = "AABBCC"; style.logoAlignment = .trailing; style.logoScale = 0.42
        try store.saveAlbum(style, id: "album-A")
        try store.saveLyrics("My custom lyrics", id: "song-A")
        try store.togglePin("album-A")
        let restored = CustomizationStore(directory: directory)
        XCTAssertEqual(restored.album("album-A"), style)
        XCTAssertNil(restored.album("album-B").backgroundHex)
        XCTAssertTrue(restored.isPinned("album-A"))
        try restored.resetAlbum("album-A")
        XCTAssertEqual(restored.lyrics("song-A"), "My custom lyrics")
        XCTAssertEqual(restored.album("album-A"), AlbumCustomization())
    }
    @MainActor func testFailedSaveDoesNotReplaceInMemoryState() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CustomizationStore(directory: directory)
        try store.saveLyrics("Original", id: "A")
        try FileManager.default.removeItem(at: directory)
        try Data().write(to: directory) // A file now blocks the expected directory.
        XCTAssertThrowsError(try store.saveLyrics("Unsaved", id: "A"))
        XCTAssertEqual(store.lyrics("A"), "Original")
    }
    @MainActor func testRejectsInvalidArtwork() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CustomizationStore(directory: directory)
        XCTAssertThrowsError(try store.importImage(Data("not an image".utf8), preserveTransparency: true))
    }
    func testSyncedLyricsFallbackRemovesTimestampsButKeepsText() throws {
        let record = LyricsRecord(id: 1, trackName: "A", artistName: "B", albumName: "C", duration: 10, instrumental: false, plainLyrics: nil, syncedLyrics: "[00:01.25]First line\n[00:02.500]Second line")
        XCTAssertEqual(record.displayText, "First line\nSecond line")
    }
    func testBlankCommunityTextIsMissing() {
        let record = LyricsRecord(id: 1, trackName: "A", artistName: "B", albumName: nil, duration: nil, instrumental: false, plainLyrics: "  \n", syncedLyrics: nil)
        XCTAssertNil(record.displayText)
    }
    func testLyricsCacheSeparatesAlbumVersions() {
        let a = LyricsIdentity(title: "Song", artist: "Artist", album: "Original", duration: 120)
        let b = LyricsIdentity(title: "Song", artist: "Artist", album: "Live", duration: 120)
        XCTAssertNotEqual(a.cacheKey, b.cacheKey)
    }
}
