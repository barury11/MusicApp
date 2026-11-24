import Foundation

struct AlbumCustomization: Codable, Equatable {
    enum LogoAlignment: String, Codable, CaseIterable, Identifiable {
        case leading, center, trailing
        var id: String { rawValue }
        var title: String {
            switch self { case .leading: return "Lewo"; case .center: return "Środek"; case .trailing: return "Prawo" }
        }
    }
    var squareArtwork: String?
    var portraitArtwork: String?
    var logo: String?
    var backgroundHex: String?
    var accentHex: String?
    var logoAlignment: LogoAlignment = .center
    var logoScale: Double = 0.75
    var logoOffsetX: Double = 0
    var logoOffsetY: Double = 0
    var usePortraitArtwork = true
}

struct CustomizationArchive: Codable {
    var version = 1
    var albums: [String: AlbumCustomization] = [:]
    var lyrics: [String: String] = [:]
    var pinnedAlbums: Set<String> = []
}

struct LyricsRecord: Codable, Equatable {
    let id: Int
    let trackName: String
    let artistName: String
    let albumName: String?
    let duration: Double?
    let instrumental: Bool?
    let plainLyrics: String?
    let syncedLyrics: String?

    var displayText: String? {
        if let plainLyrics, !plainLyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return plainLyrics }
        guard let syncedLyrics else { return nil }
        let text = syncedLyrics.components(separatedBy: .newlines).map {
            $0.replacingOccurrences(of: #"\[\d+:\d+(?:\.\d+)?\]"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
        }.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}

struct LyricsIdentity: Hashable, Codable {
    var title: String
    var artist: String
    var album: String
    var duration: Double
    var cacheKey: String {
        [title, artist, album, String(Int(duration.rounded()))].map { $0.lowercased() }.joined(separator: "\u{1F}")
    }
}
