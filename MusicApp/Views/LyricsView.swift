import SwiftUI
import MusicKit
import UniformTypeIdentifiers

extension Song {
    var lyricsKey: String { isrc.map { "isrc:" + $0 } ?? "song:" + id.rawValue }
    var lyricsKeys: [String] { Array(Set([lyricsKey, "song:" + id.rawValue])) }
    var lyricsIdentity: LyricsIdentity { LyricsIdentity(title: title, artist: artistName, album: albumTitle ?? "", duration: duration ?? 0) }
}

extension CustomizationStore {
    func lyrics(for song: Song) -> String? { lyrics(song.lyricsKey) ?? lyrics("song:" + song.id.rawValue) }
}

struct LyricsView: View {
    @EnvironmentObject private var custom: CustomizationStore
    @Environment(\.dismiss) private var dismiss
    let song: Song
    @State private var record: LyricsRecord?
    @State private var loading = true
    @State private var error: String?
    @State private var editing = false
    @AppStorage("lyricsAutoFetch") private var autoFetch = true
    private var override: String? { custom.lyrics(for: song) }
    private var requestKey: String { "\(song.id.rawValue)|\(override == nil)|\(autoFetch)" }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 14) {
                        CoverArt(artwork: song.artwork, size: 64)
                        VStack(alignment: .leading, spacing: 4) { Text(song.title).font(.headline); Text(song.artistName).foregroundStyle(.secondary) }
                    }
                    if let text = override ?? record?.displayText {
                        Text(text).font(.system(size: 27, weight: .bold)).lineSpacing(9).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                        Text(override == nil ? "Źródło: LRCLIB • tekst społeczności" : "Twój tekst • tylko w MusicApp").font(.footnote).foregroundStyle(.secondary)
                    } else if loading { ProgressView("Szukanie tekstu…").frame(maxWidth: .infinity).padding(.vertical, 50) }
                    else {
                        ContentUnavailableView(record?.instrumental == true ? "Utwór instrumentalny" : "Brak tekstu", systemImage: "quote.bubble", description: Text(error ?? "Nie znaleziono dopasowania w LRCLIB. Możesz dodać własny tekst."))
                        Button("Dodaj własny tekst") { editing = true }.buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
                    }
                }.padding(24)
            }
            .navigationTitle("Tekst utworu").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Zamknij") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { Button("Edytuj", systemImage: "square.and.pencil") { editing = true } }
            }
            .sheet(isPresented: $editing) { NavigationStack { LyricsEditorView(song: song) } }
            .task(id: requestKey) {
                error = nil; record = nil; loading = true
                defer { loading = false }
                guard override == nil, autoFetch else { loading = false; return }
                do { record = try await LyricsService.shared.fetch(song.lyricsIdentity) }
                catch is CancellationError { }
                catch { self.error = "Nie udało się pobrać tekstu: \(error.localizedDescription)" }
            }
        }
    }
}

struct LyricsEditorView: View {
    @EnvironmentObject private var custom: CustomizationStore
    @Environment(\.dismiss) private var dismiss
    let song: Song
    @State private var text = ""
    @State private var showImporter = false
    @State private var error: String?
    @State private var initialized = false
    @State private var confirmRemove = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(song.title).font(.headline)
            Text("Zwykły tekst, bez znaczników czasu. Zapis dotyczy tylko MusicApp.").font(.footnote).foregroundStyle(.secondary)
            TextEditor(text: $text).font(.body).scrollContentBackground(.hidden).padding(8).background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12)).accessibilityLabel("Tekst utworu")
            HStack {
                Button("Importuj TXT", systemImage: "doc") { showImporter = true }
                Spacer()
                Button("Usuń własny tekst", role: .destructive) { confirmRemove = true }.disabled(custom.lyrics(for: song) == nil)
            }.font(.subheadline)
        }.padding(20)
        .navigationTitle("Własny tekst").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Zapisz") { save(text) }.fontWeight(.semibold) } }
        .task { if !initialized { text = custom.lyrics(for: song) ?? ""; initialized = true } }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.plainText]) { result in
            do {
                let url = try result.get(); let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                guard data.count < 500_000, let decoded = String(data: data, encoding: .utf8) else { throw CocoaError(.fileReadInapplicableStringEncoding) }
                text = decoded
            } catch { self.error = error.localizedDescription }
        }
        .confirmationDialog("Usunąć własny tekst?", isPresented: $confirmRemove, titleVisibility: .visible) { Button("Usuń", role: .destructive) { save("") } }
        .alert("Błąd zapisu", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK", role: .cancel) { error = nil } } message: { Text(error ?? "") }
    }
    private func save(_ value: String) {
        do { try custom.saveLyrics(value, ids: song.lyricsKeys); dismiss() }
        catch { self.error = error.localizedDescription }
    }
}
