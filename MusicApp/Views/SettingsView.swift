import SwiftUI
import MusicKit

struct SettingsView: View {
    @EnvironmentObject private var music: MusicService
    @Environment(\.dismiss) private var dismiss
    @State private var token = ""
    @State private var error: String?
    @State private var saved = false
    @State private var applying = false
    @AppStorage("lyricsAutoFetch") private var autoLyrics = true
    var body: some View {
        NavigationStack {
            Form {
                Section("Apple Music") {
                    LabeledContent("Dostęp", value: music.authorization == .authorized ? "Przyznany" : "Nieprzyznany")
                    LabeledContent("Streaming katalogu", value: music.canPlayCatalog ? "Dostępny" : "Wymaga subskrypcji lub konfiguracji")
                    Button("Odśwież bibliotekę i katalog") { Task { await music.refresh() } }.disabled(music.authorization != .authorized)
                    Link("Ustawienia systemowe", destination: URL(string: UIApplication.openSettingsURLString)!)
                }
                Section {
                    Toggle("Pobieraj teksty z LRCLIB", isOn: $autoLyrics)
                    Link("O bazie LRCLIB", destination: URL(string: "https://lrclib.net")!)
                } header: { Text("Teksty") } footer: { Text("Podczas otwierania tekstu wysyłane są tytuł, wykonawca, album i długość utworu. Własne teksty pozostają na urządzeniu. Baza społecznościowa może nie zawierać wszystkich utworów lub wersji.") }
                Section {
                    SecureField("Developer token (JWT)", text: $token).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button {
                        applying = true
                        do {
                            try TokenStore.save(token.trimmingCharacters(in: .whitespacesAndNewlines))
                            music.applyStoredToken(); saved = true
                            Task { await music.refresh(); applying = false }
                        } catch { self.error = error.localizedDescription; applying = false }
                    } label: { HStack { Text("Zastosuj konfigurację"); if applying { ProgressView() } } }.disabled(applying)
                    if saved { Label("Konfiguracja zapisana", systemImage: "checkmark.circle").foregroundStyle(.green) }
                    Link("Dokumentacja MusicKit", destination: URL(string: "https://developer.apple.com/musickit/")!)
                } header: { Text("Zaawansowane · MusicKit") } footer: {
                    Text("Domyślnie używana jest autoryzacja MusicKit. Jeśli podpis aplikacji nie pozwala wygenerować tokenu automatycznie, możesz podać własny token deweloperski. Sam token nie gwarantuje dostępu do odtwarzania ani zastąpienia wymaganych uprawnień Apple. Klucz prywatny .p8 nie jest potrzebny w aplikacji. Puste pole przywraca konfigurację automatyczną.")
                }
                Section("Informacje") {
                    LabeledContent("Wersja", value: "0.1.0")
                    Text("MusicApp jest niezależnym klientem Apple Music. Personalizacja albumów działa lokalnie i nie zmienia systemowej biblioteki.").font(.footnote).foregroundStyle(.secondary)
                    Link("Kod źródłowy i instrukcja", destination: URL(string: "https://github.com/barury11/MusicApp")!)
                }
            }
            .navigationTitle("Ustawienia").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Gotowe") { dismiss() } } }
            .task { token = TokenStore.read() ?? "" }
            .alert("Nie udało się zapisać", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK", role: .cancel) { error = nil } } message: { Text(error ?? "") }
        }
    }
}
