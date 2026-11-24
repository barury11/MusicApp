# MusicApp

Natywny, niezależny klient Apple Music na iPhone’a i iPada. SwiftUI, MusicKit i lokalna personalizacja albumów. Projekt jest przeznaczony do budowania niepodpisanego IPA i instalacji po podpisaniu własnym certyfikatem.

## Funkcje

- Główna z rekomendacjami, popularne albumy i playlisty, radio, biblioteka oraz wyszukiwanie w katalogu i bibliotece.
- Albumy, wykonawcy i playlisty z rzeczywistymi danymi MusicKit, pełne stronicowanie biblioteki i utworów albumu/playlisty.
- Odtwarzanie przez `ApplicationMusicPlayer`, kolejka, odtwarzanie następnego/na końcu, mieszanie, powtarzanie, przewijanie, Crossfade z regulacją 1–12 s i praca w tle.
- Minigrający pasek przy natywnym szklanym pasku kart, gesty następny/poprzedni, pełny odtwarzacz, AirPlay i systemowa głośność.
- Dodawanie do ulubionych przez API Apple Music, dodawanie do biblioteki, tworzenie playlist i dodawanie utworów do playlist.
- Odczyt treści pobranej wcześniej w systemowej Muzyce przez filtr „Pobrane”.
- Zwykłe teksty z darmowej otwartej bazy [LRCLIB](https://lrclib.net), lokalna pamięć podręczna oraz własne teksty wpisywane lub importowane z UTF-8 TXT.

## Dostosowanie albumu

Otwórz album → **⋯ → Dostosuj**. Sekcja zawiera:

1. Kwadratową okładkę — używaną na listach i w odtwarzaczu.
2. Pionową okładkę — pełny nagłówek strony albumu.
3. Przezroczyste logo zastępujące tytuł albumu, rozmiar, wyrównanie lewo/środek/prawo i przesunięcia X/Y.
4. Kolor tła albumu i wspólny kolor akcentów, tekstu oraz przycisków.
5. Własne teksty poszczególnych utworów, z pierwszeństwem przed LRCLIB.

Obrazy importujesz ze Zdjęć albo Plików. Zmiany wyglądu zatwierdzasz przyciskiem **Gotowe**; **Anuluj** nie zapisuje szkicu. Teksty zapisuje się osobno na ekranie edycji utworu. Reset wyglądu zachowuje własne teksty. Żadna z tych zmian nie edytuje metadanych w systemowej Muzyce.

Personalizacja wyglądu jest przypisana do identyfikatora albumu MusicKit. Ta sama płyta w katalogu i lokalnej bibliotece może mieć różne identyfikatory. Teksty są przypisane do ISRC, gdy jest dostępny, lub do identyfikatora utworu. Logo i okładki są kopiowane do Application Support; JSON jest zapisywany atomowo. Usunięcie aplikacji usuwa lokalną personalizację.

## Niepodpisane IPA w GitHub Actions

1. Otwórz **Actions → Build unsigned IPA → Run workflow**. Workflow uruchamia się też po pushu do `main`.
2. Po zakończeniu pobierz artefakt **MusicApp-unsigned**.
3. Rozpakuj ZIP artefaktu — w środku jest **MusicApp-unsigned.ipa**.
4. Podpisz i zainstaluj IPA wybranym narzędziem (AltStore, Sideloadly, iLoader).

Workflow wybiera najnowszy zainstalowany stabilny Xcode z SDK iOS 26+, generuje projekt przez XcodeGen, kompiluje urządzeniowy Release bez podpisu, sprawdza strukturę `Payload/MusicApp.app` i uprawnienie wykonywania pliku binarnego, a następnie uruchamia testy na dostępnym symulatorze iPhone’a. Logi i wyniki testów są dostępne w artefakcie **MusicApp-diagnostics**. IPA może być przesłane przed zakończeniem testów — sprawdź również zielony status całego workflow.

Minimalny system to **iOS/iPadOS 26.0**, więc aplikacja obejmuje również iOS 27. Kod korzysta z publicznych funkcji Liquid Glass dostępnych od iOS 26. Xcode 27 nie jest wymagany do samej kompilacji.

## MusicKit i podpis aplikacji

**Niepodpisane IPA i prawo do korzystania z usługi Apple Music to osobne kwestie.** Sideloading nie nadaje automatycznie uprawnień usługi Apple.

Standardowa konfiguracja dla dewelopera:

- Utwórz własny identyfikator aplikacji w Apple Developer i włącz dla niego usługę MusicKit.
- Zmień `PRODUCT_BUNDLE_IDENTIFIER` w `project.yml` na ten identyfikator.
- Przy instalacji użyj właściwego profilu i podpisu. Nie dodawaj wymyślonych entitlements — MusicKit jest konfigurowany jako usługa App ID.
- Zezwól aplikacji na dostęp do multimediów. Streaming katalogu wymaga subskrypcji Apple Music.

MusicKit domyślnie generuje token automatycznie. Jeśli to nie działa z użytym podpisem, w **Ustawienia → Zaawansowane · MusicKit** można podać własny developer token JWT. Jest przechowywany wyłącznie w Keychain. Nie wklejaj klucza prywatnego `.p8` do kodu ani aplikacji. Token nie gwarantuje obejścia ograniczeń podpisu, subskrypcji czy konfiguracji Apple. Po zmianie identyfikatora aplikacji przy ponownym podpisywaniu konfiguracja MusicKit może wymagać dostosowania.

## Zakres i ograniczenia

- Interfejs wzorowany na Apple Music: natywna nawigacja, menu, karty, szkło, zoom do albumu, sprężynowa animacja okładki. Nie jest to skopiowany kod Apple ani gwarantowana rekonstrukcja piksel w piksel. Referencje i decyzje wymiarów: [docs/DESIGN.md](docs/DESIGN.md).
- Brak publicznego pobierania tekstów Apple, Apple Music Sing, oficjalnych animowanych okładek Apple i zarządzania pobieraniem utworów z katalogu. Widoki nie udają tych funkcji.
- Dostępne formaty oraz faktyczny Lossless/Atmos są kontrolowane przez silnik Apple, sprzęt, subskrypcję i ustawienia systemowe. Znacznik jakości jest odczytywany z aktywnego wariantu odtwarzania, a nie zgadywany z albumu.
- LRCLIB nie gwarantuje pokrycia ani prawidłowości. Dopasowanie obejmuje tytuł, wykonawcę, album i długość — bez automatycznego podstawiania innej wersji. Gdy brak tekstu, można wpisać własny. Aplikacja nie zawiera skopiowanej bazy tekstów.
- Rzeczywiste odtwarzanie, autoryzację, sterowanie AirPods, działanie offline i zachowanie ekranu blokady należy sprawdzić na fizycznym iPhonie z kontem Apple Music. Testy CI nie logują się na konto i nie potwierdzają tych funkcji.
- Akcja dodania do ulubionych wysyła żądanie do API Apple; ta wersja nie odczytuje pełnego bieżącego stanu ulubionych i nie oferuje ich usuwania. Dla importów bez odpowiednika katalogowego Apple może nie udostępnić tej operacji.
- CarPlay, widgety, SharePlay, profile społecznościowe i pełne odtworzenie funkcji aplikacji systemowej nie są częścią tej wersji.

## Budowanie lokalnie na macOS

```sh
brew install xcodegen
xcodegen generate
xcodebuild -project MusicApp.xcodeproj -scheme MusicApp \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath build/device CODE_SIGNING_ALLOWED=NO build
python3 scripts/package_ipa.py \
  build/device/Build/Products/Release-iphoneos/MusicApp.app \
  build/MusicApp-unsigned.ipa
```

## Prywatność

Biblioteka i personalizacja nie są wysyłane na serwer twórcy aplikacji. MusicKit komunikuje się z Apple. Przy otwieraniu tekstu LRCLIB otrzymuje metadane piosenki; tę funkcję można wyłączyć w Ustawieniach. Własne teksty nie są wysyłane do LRCLIB. Brak analityki, reklam i zewnętrznych pakietów Swift.
