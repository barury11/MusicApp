# Weryfikacja na fizycznym urządzeniu

Po pobraniu IPA i podpisaniu:

1. Zezwól na multimedia; sprawdź rzeczywistą bibliotekę i wyszukiwanie katalogu. Przy odmowie sprawdź Ustawienia iOS i konfigurację MusicKit.
2. Odtwórz album, zmień utwór, przewiń, włącz mieszanie i trzy stany powtarzania. Sprawdź odtwarzanie w tle, ekran blokady oraz przyciski słuchawek.
3. Przeciągnij po miniodtwarzaczu, otwórz kolejkę, przesuń i usuń utwór. Sprawdź, czy bieżący utwór nadal odpowiada wyświetlanej pozycji.
4. W albumie wybierz ⋯ → Dostosuj. Importuj kwadrat, pionową grafikę i logo PNG. Zapisz, wyjdź z albumu, wróć i ponownie uruchom aplikację.
5. Ustaw rozmiar i wszystkie wyrównania logo, kolory, następnie anuluj kolejną zmianę — zapisany wygląd powinien zostać zachowany.
6. Dodaj własny tekst; porównaj z LRCLIB po jego usunięciu. Wyłącz pobieranie LRCLIB i sprawdź brak automatycznego połączenia.
7. Przełącz tryb samolotowy przy wcześniej pobranym albumie i otwórz filtr Pobrane. Test zależy od systemowego pobrania utworów i licencji Apple Music.
8. Sprawdź jasny/ciemny wygląd, większy rozmiar tekstu, VoiceOver i Reduce Motion.

Testy jednostkowe w Actions obejmują trwałość personalizacji, izolację albumów, reset bez utraty tekstu, brak nadpisania stanu po błędzie zapisu, walidację obrazu oraz przetwarzanie odpowiedzi tekstów. Nie zastępują testu konta Apple Music na urządzeniu.
