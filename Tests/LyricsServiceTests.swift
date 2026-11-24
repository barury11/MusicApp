import XCTest
@testable import MusicApp

private final class LyricsStub: URLProtocol {
    static var responseCode = 200
    static var payload = Data()
    static var requests: [URLRequest] = []
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.requests.append(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.responseCode, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.payload)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { }
}

final class LyricsServiceTests: XCTestCase {
    private var directory: URL!
    private var session: URLSession!
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LyricsStub.self]
        session = URLSession(configuration: configuration)
        LyricsStub.requests = []
        LyricsStub.responseCode = 200
        LyricsStub.payload = try JSONEncoder().encode(LyricsRecord(id: 10, trackName: "A & B", artistName: "Artist", albumName: "Deluxe", duration: 120, instrumental: false, plainLyrics: "Test fixture", syncedLyrics: nil))
    }
    override func tearDownWithError() throws {
        session.invalidateAndCancel()
        try? FileManager.default.removeItem(at: directory)
    }
    func testEncodesMetadataAndCachesExactVersion() async throws {
        let service = LyricsService(session: session, directory: directory)
        let identity = LyricsIdentity(title: "A & B", artist: "Artist", album: "Deluxe", duration: 120)
        let first = try await service.fetch(identity)
        let second = try await service.fetch(identity)
        XCTAssertEqual(first, second)
        XCTAssertEqual(LyricsStub.requests.count, 1)
        let items = URLComponents(url: LyricsStub.requests[0].url!, resolvingAgainstBaseURL: false)!.queryItems!
        XCTAssertEqual(items.first(where: { $0.name == "track_name" })?.value, "A & B")
        XCTAssertEqual(items.first(where: { $0.name == "album_name" })?.value, "Deluxe")
        XCTAssertNotNil(LyricsStub.requests[0].value(forHTTPHeaderField: "User-Agent"))
    }
    func testMissingLyricsReturnsNilInsteadOfUnrelatedResult() async throws {
        LyricsStub.responseCode = 404
        let service = LyricsService(session: session, directory: directory)
        let result = try await service.fetch(LyricsIdentity(title: "Missing", artist: "Artist", album: "Album", duration: 90))
        XCTAssertNil(result)
        XCTAssertEqual(LyricsStub.requests.count, 1)
    }
    func testRateLimitIsReportedAsFailure() async throws {
        LyricsStub.responseCode = 429
        let service = LyricsService(session: session, directory: directory)
        do {
            _ = try await service.fetch(LyricsIdentity(title: "A", artist: "B", album: "C", duration: 10))
            XCTFail("Rate-limit response must not become a valid lyrics result")
        } catch { XCTAssertEqual((error as? URLError)?.code, .badServerResponse) }
    }
}
