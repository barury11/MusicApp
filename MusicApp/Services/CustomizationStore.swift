import SwiftUI
import UIKit
import ImageIO

@MainActor
final class CustomizationStore: ObservableObject {
    @Published private(set) var archive = CustomizationArchive()
    @Published var errorMessage: String?
    private let directory: URL
    private let imageCache = NSCache<NSString, UIImage>()

    init(directory: URL? = nil) {
        imageCache.totalCostLimit = 64 * 1024 * 1024
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("AlbumStudio", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
            let url = self.directory.appendingPathComponent("customizations.json")
            if FileManager.default.fileExists(atPath: url.path) {
                archive = try JSONDecoder().decode(CustomizationArchive.self, from: Data(contentsOf: url))
            }
        } catch { errorMessage = "Nie udało się odczytać personalizacji: \(error.localizedDescription). Plik pozostawiono do odzyskania." }
    }

    func album(_ id: String) -> AlbumCustomization { archive.albums[id] ?? AlbumCustomization() }
    func lyrics(_ id: String) -> String? { archive.lyrics[id] }
    func isPinned(_ id: String) -> Bool { archive.pinnedAlbums.contains(id) }

    func saveAlbum(_ value: AlbumCustomization, id: String) throws {
        var next = archive
        next.albums[id] = value
        try persist(next)
    }
    func saveLyrics(_ text: String, id: String) throws { try saveLyrics(text, ids: [id]) }
    func saveLyrics(_ text: String, ids: [String]) throws {
        var next = archive
        for id in ids {
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { next.lyrics.removeValue(forKey: id) }
            else { next.lyrics[id] = text }
        }
        try persist(next)
    }
    func togglePin(_ id: String) throws {
        var next = archive
        if next.pinnedAlbums.contains(id) { next.pinnedAlbums.remove(id) }
        else { next.pinnedAlbums.insert(id) }
        try persist(next)
    }
    func resetAlbum(_ id: String) throws {
        var next = archive
        next.albums.removeValue(forKey: id)
        try persist(next)
    }
    private func persist(_ next: CustomizationArchive) throws {
        let data = try JSONEncoder().encode(next)
        try data.write(to: directory.appendingPathComponent("customizations.json"), options: .atomic)
        archive = next
        // Do not delete previous artwork here: a draft editor can still reference it.
    }
    func importImage(_ data: Data, preserveTransparency: Bool) throws -> String {
        guard data.count <= 30_000_000,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 2400,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { throw StoreError.invalidImage }
        let rendered = UIImage(cgImage: thumbnail)
        let filename = UUID().uuidString + (preserveTransparency ? ".png" : ".jpg")
        guard let bytes = preserveTransparency ? rendered.pngData() : rendered.jpegData(compressionQuality: 0.9) else { throw StoreError.invalidImage }
        try bytes.write(to: directory.appendingPathComponent(filename), options: .atomic)
        return filename
    }
    func image(_ filename: String?) -> UIImage? {
        guard let filename, filename == URL(fileURLWithPath: filename).lastPathComponent else { return nil }
        if let cached = imageCache.object(forKey: filename as NSString) { return cached }
        guard let image = UIImage(contentsOfFile: directory.appendingPathComponent(filename).path) else { return nil }
        let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
        imageCache.setObject(image, forKey: filename as NSString, cost: cost)
        return image
    }
    enum StoreError: LocalizedError {
        case invalidImage
        var errorDescription: String? { "Nie można odczytać obrazu. Wybierz PNG, JPEG lub HEIC do 30 MB." }
    }
}
