import Foundation

actor LyricsService {
    static let shared = LyricsService()
    private struct Cached: Codable { var date: Date; var record: LyricsRecord }
    private let session: URLSession
    private let directory: URL

    init(session: URLSession = .shared, directory: URL? = nil) {
        self.session = session
        self.directory = directory ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("Lyrics", isDirectory: true)
    }

    func fetch(_ song: LyricsIdentity) async throws -> LyricsRecord? {
        let filename = song.cacheKey.data(using: .utf8)!.base64EncodedString().replacingOccurrences(of: "/", with: "_")
        // Metadata can exceed the filesystem filename limit: use a stable digest.
        let url = directory.appendingPathComponent(Self.digest(filename) + ".json")
        if let data = try? Data(contentsOf: url), let cached = try? JSONDecoder().decode(Cached.self, from: data), Date().timeIntervalSince(cached.date) < 7 * 86400 {
            return cached.record
        }
        var components = URLComponents(string: "https://lrclib.net/api/get")!
        components.queryItems = [URLQueryItem(name: "track_name", value: song.title), URLQueryItem(name: "artist_name", value: song.artist), URLQueryItem(name: "album_name", value: song.album), URLQueryItem(name: "duration", value: String(Int(song.duration.rounded())))]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 18
        request.setValue("MusicApp/0.1 (https://github.com/barury11/MusicApp)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if http.statusCode == 404 { return nil }
        guard http.statusCode == 200 else { throw URLError(.badServerResponse) }
        let record = try JSONDecoder().decode(LyricsRecord.self, from: data)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let bytes = try? JSONEncoder().encode(Cached(date: Date(), record: record)) { try? bytes.write(to: url, options: .atomic) }
        return record
    }
    private static func digest(_ string: String) -> String {
        // FNV-1a is only a cache filename; no security decisions depend on it.
        var hash: UInt64 = 14695981039346656037
        for byte in string.utf8 { hash = (hash ^ UInt64(byte)) &* 1099511628211 }
        return String(hash, radix: 16)
    }
}
