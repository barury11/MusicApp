import SwiftUI
import UIKit

@MainActor
final class CustomizationStore: ObservableObject {
    @Published private(set) var archive = CustomizationArchive()
    @Published var errorMessage: String?
    private let directory: URL
    private var imageCache: [String: UIImage] = [:]

    init(directory: URL? = nil) {
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
    func saveLyrics(_ text: String, id: String) throws {
        var next = archive
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { next.lyrics.removeValue(forKey: id) }
        else { next.lyrics[id] = text }
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
        guard data.count <= 30_000_000, let source = UIImage(data: data), source.size.width > 0, source.size.height > 0 else { throw StoreError.invalidImage }
        // Flatten orientation and cap decoded dimensions; PNG preserves a logo's alpha channel.
        let ratio = min(1, 2400 / max(source.size.width, source.size.height))
        let size = CGSize(width: source.size.width * ratio, height: source.size.height * ratio)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = !preserveTransparency
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { context in
            if !preserveTransparency { UIColor.black.setFill(); context.fill(CGRect(origin: .zero, size: size)) }
            source.draw(in: CGRect(origin: .zero, size: size))
        }
        let filename = UUID().uuidString + (preserveTransparency ? ".png" : ".jpg")
        guard let bytes = preserveTransparency ? rendered.pngData() : rendered.jpegData(compressionQuality: 0.9) else { throw StoreError.invalidImage }
        try bytes.write(to: directory.appendingPathComponent(filename), options: .atomic)
        return filename
    }
    func image(_ filename: String?) -> UIImage? {
        guard let filename, filename == URL(fileURLWithPath: filename).lastPathComponent else { return nil }
        if let cached = imageCache[filename] { return cached }
        guard let image = UIImage(contentsOfFile: directory.appendingPathComponent(filename).path) else { return nil }
        if imageCache.count > 24 { imageCache.removeAll() }
        imageCache[filename] = image
        return image
    }
    enum StoreError: LocalizedError {
        case invalidImage
        var errorDescription: String? { "Nie można odczytać obrazu. Wybierz PNG, JPEG lub HEIC do 30 MB." }
    }
}
