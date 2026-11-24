# Referencje i odwzorowanie interfejsu

Źródła przeglądane 24 listopada 2026:

- [Apple Music — oficjalna strona Apple](https://www.apple.com/apple-music/).
- [Oficjalny widok albumu na iPhonie](https://www.apple.com/v/apple-music/ah/images/overview/boc_spatial_audio__di7hdk4tooqe_large.jpg): pełna pionowa okładka, nakładany tytuł, wykonawca, opis, lista na barwnym tle, szklana nawigacja.
- [Apple — nowy wygląd systemu](https://www.apple.com/newsroom/2025/06/apple-introduces-a-delightful-and-elegant-new-software-design/): materiały Liquid Glass i adaptacyjna nawigacja.
- [Zrzuty biblioteki i odtwarzacza iOS 26](https://images.iphone-ticker.de/wp-content/uploads/2025/06/apple-music-ios-26-1-scaled.png): duży nagłówek, podział kategorii, dwukolumnowe albumy, pływający miniodtwarzacz, oddzielona karta wyszukiwania.

To referencje wizualne, nie zasoby dystrybuowane z aplikacją. Okładki pochodzą z MusicKit lub importu użytkownika. SwiftUI korzysta z systemowych fontów, SF Symbols, menu i animacji — wygląd materiałów może zmieniać się wraz z iOS.

## Wymiary w punktach

| Element | Implementacja |
| --- | --- |
| Zewnętrzny margines listy | 20 pt |
| Odstęp albumów | 14 pt na półce, 18 pt w siatce |
| Okładka półki | 160 × 160 pt |
| Okładka albumu w standardowym widoku | 280 × 280 pt |
| Okładka na liście utworów | 48 × 48 pt |
| Rząd utworu | co najmniej 48 pt, z okładką 62 pt |
| Obszar przycisku menu | 38 × 44 pt |
| Przycisk odtwarzania albumu | 48 pt wysokości |
| Pełny odtwarzacz | margines 32 pt, okładka dopasowana do wysokości ekranu |
| Logo albumu | szerokość 20–100% obszaru, X ±80 pt, Y ±60 pt |

## Ruch

- Przejście do albumu: natywne `navigationTransition(.zoom)` i `matchedTransitionSource`.
- Pasek kart i miniodtwarzacz: `TabView`, `tabViewBottomAccessory`, `tabBarMinimizeBehavior(.onScrollDown)`; układ i szkło obsługuje system.
- Pełny odtwarzacz: systemowy arkusz z gestem zamknięcia, sprężynowe zmniejszenie okładki podczas pauzy, płynna zamiana symbolu play/pause.
- Pionowy nagłówek: rozciąganie podczas pociągnięcia w dół, z uwzględnieniem Reduce Motion.
- Edytor: lokalny szkic, podgląd logo, zapis dopiero po potwierdzeniu.

## Weryfikacja

Przegląd referencji nie jest testem wizualnym działającej aplikacji. Do porównania pikselowego z konkretną wersją Muzyki potrzebne są zrzuty z identycznego urządzenia, skali tekstu i iOS, z tą samą zawartością konta. Nie są dostępne w automatycznych testach tego repozytorium.
