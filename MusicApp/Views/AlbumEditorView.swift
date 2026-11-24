import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import MusicKit

enum AlbumEditorSection: String, CaseIterable, Identifiable {
    case square = "Okładka kwadratowa", portrait = "Okładka pionowa", logo = "Logo i położenie", colors = "Kolory", lyrics = "Teksty"
    var id: String { rawValue }
}

struct AlbumEditorView: View {
    @EnvironmentObject private var custom: CustomizationStore
    @Environment(\.dismiss) private var dismiss
    let album: Album
    let tracks: [Track]
    let initialSection: AlbumEditorSection
    @State private var draft = AlbumCustomization()
    @State private var section = AlbumEditorSection.square
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showFileImporter = false
    @State private var fileTarget = AlbumEditorSection.square
    @State private var background: Color = .black
    @State private var accent: Color = .white
    @State private var error: String?
    @State private var importBusy = false
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            editorForm
            .navigationTitle("Dostosuj album").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Anuluj") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Gotowe") { save() }.fontWeight(.semibold).disabled(importBusy) }
            }
            .overlay { if importBusy { ProgressView("Importowanie…").padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18)) } }
            .alert("Nie udało się zapisać", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK", role: .cancel) { error = nil } } message: { Text(error ?? "") }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.image], onCompletion: importFile)
            .task { await loadDraft() }
            .onChange(of: selectedPhoto) { _, item in selectPhoto(item) }

        }.interactiveDismissDisabled(importBusy)
    }
    private var editorForm: some View {
        Form {
                Section {
                    preview.frame(height: draft.usePortraitArtwork && custom.image(draft.portraitArtwork) != nil ? 340 : 280).listRowInsets(EdgeInsets()).clipped()
                } header: { Text("Podgląd albumu") }
                Section {
                    Picker("Dostosuj", selection: $section) { ForEach(AlbumEditorSection.allCases) { Text($0.rawValue).tag($0) } }
                }
                selectedSection
                Section { Text("Wszystkie zmiany wyglądu dotyczą wyłącznie tego albumu w MusicApp.").font(.footnote).foregroundStyle(.secondary) }
            }
    }
    @ViewBuilder private var selectedSection: some View {
                switch section {
                case .square: artworkSection(.square, filename: draft.squareArtwork)
                case .portrait:
                    artworkSection(.portrait, filename: draft.portraitArtwork)
                    Section { Toggle("Pionowa okładka w pełnym widoku", isOn: $draft.usePortraitArtwork) } footer: { Text("Pionowa okładka wypełnia nagłówek albumu. Kwadratowa pozostaje na listach i w odtwarzaczu.") }
                case .logo:
                    artworkSection(.logo, filename: draft.logo)
                    Section("Położenie logo") {
                        Picker("Wyrównanie", selection: $draft.logoAlignment) { ForEach(AlbumCustomization.LogoAlignment.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
                        slider("Rozmiar", value: $draft.logoScale, range: 0.2...1, suffix: "%", multiplier: 100)
                        slider("Przesunięcie poziome", value: $draft.logoOffsetX, range: -80...80)
                        slider("Przesunięcie pionowe", value: $draft.logoOffsetY, range: -60...60)
                        Button("Wyśrodkuj logo") { draft.logoAlignment = .center; draft.logoOffsetX = 0; draft.logoOffsetY = 0; draft.logoScale = 0.75 }
                    }.disabled(draft.logo == nil)
                case .colors:
                    Section {
                        ColorPicker("Kolor tła", selection: $background, supportsOpacity: false).onChange(of: background) { _, color in if loaded { draft.backgroundHex = color.rgbHex } }
                        ColorPicker("Tekst i przyciski", selection: $accent, supportsOpacity: false).onChange(of: accent) { _, color in if loaded { draft.accentHex = color.rgbHex } }
                        Button("Przywróć kolory z okładki") {
                            resetColors()
                        }
                    } header: { Text("Kolory strony albumu") } footer: { Text("Wybierz kontrastowe kolory, aby nazwy i przyciski były czytelne.") }
                case .lyrics:
                    Section {
                        ForEach(tracks) { track in
                            if case .song(let song) = track {
                                NavigationLink { LyricsEditorView(song: song) } label: {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(song.title)
                                        Text(custom.lyrics(for: song) == nil ? "Dodaj własny tekst" : "Własny tekst zapisany").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        if tracks.isEmpty { Text("Wczytaj utwory albumu przed edycją tekstów.").foregroundStyle(.secondary) }
                    } header: { Text("Teksty utworów") } footer: { Text("Teksty zapisujesz osobno na ekranie utworu. Mają pierwszeństwo przed LRCLIB i są dostępne wyłącznie w MusicApp.") }
                }
    }
    private var originalBackground: Color {
        if let cgColor = album.artwork?.backgroundColor { return Color(cgColor: cgColor) }
        return .black
    }
    private var originalAccent: Color {
        if let cgColor = album.artwork?.primaryTextColor { return Color(cgColor: cgColor) }
        return .white
    }
    private func resetColors() {
        loaded = false
        draft.backgroundHex = nil; draft.accentHex = nil
        background = originalBackground; accent = originalAccent
        Task { @MainActor in await Task.yield(); loaded = true }
    }
    private func loadDraft() async {
        guard !loaded else { return }
        draft = custom.album(album.id.rawValue); section = initialSection
        background = draft.backgroundHex.flatMap { Color(hex: $0) } ?? originalBackground
        accent = draft.accentHex.flatMap { Color(hex: $0) } ?? originalAccent
        await Task.yield(); loaded = true
    }
    private func importFile(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            try importData(Data(contentsOf: url), target: fileTarget)
        } catch { self.error = error.localizedDescription }
    }
    private func selectPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        let target = section
        importBusy = true
        Task {
            defer { importBusy = false; selectedPhoto = nil }
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { throw CustomizationStore.StoreError.invalidImage }
                try importData(data, target: target)
            } catch { self.error = error.localizedDescription }
        }
    }
    @ViewBuilder private func artworkSection(_ target: AlbumEditorSection, filename: String?) -> some View {
        Section {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label("Wybierz ze Zdjęć", systemImage: "photo.on.rectangle")
            }
            Button { fileTarget = target; showFileImporter = true } label: { Label("Importuj z Plików", systemImage: "folder") }
            if filename != nil { Button("Usuń obraz", role: .destructive) { setImage(nil, target: target) } }
        } header: { Text(target.rawValue) } footer: {
            Text(target == .logo ? "PNG z przezroczystym tłem daje najlepszy efekt. Logo zastępuje nazwę albumu w pełnym widoku." : "JPEG, PNG lub HEIC, maksymalnie 30 MB. Obraz zostanie skopiowany do aplikacji.")
        }
    }
    private var preview: some View {
        ZStack(alignment: .bottom) {
            (draft.backgroundHex.flatMap(Color.init(hex:)) ?? background)
            if draft.usePortraitArtwork, let image = custom.image(draft.portraitArtwork) {
                GeometryReader { geometry in Image(uiImage: image).resizable().scaledToFill().frame(width: geometry.size.width, height: geometry.size.height).clipped() }
                LinearGradient(colors: [.clear, background.opacity(0.9)], startPoint: .center, endPoint: .bottom)
            }
            VStack(spacing: 14) {
                if !draft.usePortraitArtwork || custom.image(draft.portraitArtwork) == nil {
                    if let image = custom.image(draft.squareArtwork) { Image(uiImage: image).resizable().scaledToFill().frame(width: 154, height: 154).clipShape(RoundedRectangle(cornerRadius: 8)) }
                    else { CoverArt(artwork: album.artwork, size: 154) }
                }
                if let image = custom.image(draft.logo) {
                    GeometryReader { geometry in
                        Image(uiImage: image).resizable().scaledToFit().frame(width: geometry.size.width * draft.logoScale, height: 50).frame(maxWidth: .infinity, alignment: draft.logoAlignment.swiftUI).offset(x: draft.logoOffsetX, y: draft.logoOffsetY)
                    }.frame(height: 50)
                } else { Text(album.title).font(.headline).multilineTextAlignment(.center) }
                Text(album.artistName).font(.subheadline)
            }.padding(20).foregroundStyle(draft.accentHex.flatMap(Color.init(hex:)) ?? accent)
        }.animation(.smooth(duration: 0.2), value: draft.logoScale)
    }
    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, suffix: String = " pt", multiplier: Double = 1) -> some View {
        VStack(alignment: .leading) { HStack { Text(title); Spacer(); Text("\(Int(value.wrappedValue * multiplier))\(suffix)").foregroundStyle(.secondary).monospacedDigit() }; Slider(value: value, in: range) }
    }
    private func setImage(_ filename: String?, target: AlbumEditorSection) {
        switch target { case .square: draft.squareArtwork = filename; case .portrait: draft.portraitArtwork = filename; case .logo: draft.logo = filename; default: break }
    }
    private func importData(_ data: Data, target: AlbumEditorSection) throws { setImage(try custom.importImage(data, preserveTransparency: target == .logo), target: target) }
    private func save() {
        do { try custom.saveAlbum(draft, id: album.id.rawValue); dismiss() }
        catch { self.error = error.localizedDescription }
    }
}
