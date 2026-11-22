# Bezpieczna Przystań

Pierwsza wersja aplikacji Flutter na Androida i do przeglądarki dla osób doświadczających przemocy. Zawiera dziennik z załącznikami audio, plan bezpieczeństwa, rejestrator, materiały edukacyjne i informacje o pomocy w Polsce. PANIC, SOS, rozmowy ze wsparciem, zmiana ikony i PIN są w przygotowaniu. Tryb neutralny otwiera działający kalkulator. Przytrzymanie wyświetlacza lub skrót Ctrl + Shift + U otwiera okno potwierdzenia powrotu. Android zapamiętuje wybór lokalnie, a przeglądarka po odświeżeniu tej samej karty. Gest nie jest blokadą PIN, a nazwa i ikona aplikacji w systemie są nadal widoczne.

## Uruchomienie na Macu

Wersja Flutter używana w projekcie to 3.50.1. Do testów Web potrzebny jest Chrome, a do Androida JDK 17, Android SDK i telefon z włączonym debugowaniem USB lub emulator. Minimalna wersja aplikacji to Android 8 (API 26).

```sh
flutter doctor
flutter pub get
flutter analyze
flutter run -d chrome
flutter devices
flutter run -d IDENTYFIKATOR_ANDROID
```

Jeśli używasz SDK pobranego do katalogu tymczasowego podczas przygotowania projektu, polecenie Flutter to `/private/tmp/bezpieczna-flutter/bin/flutter`.

## Wersja demonstracyjna

Workflow „Wersja demonstracyjna” buduje i publikuje Flutter Web przez GitHub Pages. W ustawieniach **Pages → Build and deployment → Source** należy wybrać **GitHub Actions**. APK w wersji debug znajduje się w artefaktach zadania `android` po udanej kompilacji.

- Web wymaga HTTPS lub lokalnego adresu `localhost` oraz zgody na mikrofon. Do demo wprowadzaj wyłącznie dane testowe. Dźwięk i treść wpisów pozostają w pamięci karty i znikają po jej zamknięciu lub odświeżeniu. Blokada ekranu, zmiana urządzenia audio i ograniczenia przeglądarki mogą przerwać nagrywanie.
- Android wymaga zgody na mikrofon oraz włączonych powiadomień. Rozpocznij nagrywanie przy otwartej aplikacji. Mikrofon działa w usłudze pierwszoplanowej z powiadomieniem umożliwiającym zatrzymanie. Wymuszenie zatrzymania aplikacji lub przerwanie procesu przez system może spowodować utratę niezapisanego nagrania.
- Dźwięk, dziennik i plan pozostają na urządzeniu. Android zapisuje zakończone nagrania w prywatnym katalogu aplikacji i wyłącza kopię zapasową. Aplikacja jeszcze nie szyfruje danych. Używaj tej wersji do testów, a do przechowywania prawdziwych nagrań potrzebna jest osobna ocena bezpieczeństwa.

## Scenariusz testu mikrofonu

1. Otwórz rejestrator, naciśnij „Rozpocznij nagrywanie” i zaakceptuj uprawnienia.
2. Nagraj kilka sekund testowego dźwięku. Na Androidzie przejdź do ekranu głównego lub zablokuj telefon i sprawdź obecność powiadomienia.
3. Zatrzymaj nagranie w aplikacji lub z powiadomienia na Androidzie.
4. Odtwórz nagranie. Dodaj je do dziennika i sprawdź odtwarzanie z poziomu wpisu.
5. Usuń nagranie i sprawdź, że wpis pokazuje niedostępny załącznik.
6. Powtórz próbę po odmowie zgody na mikrofon. Na Web sprawdź, że odświeżenie strony usuwa dane sesji.

[Informacje o pomocy na Gov.pl](https://www.gov.pl/web/gov/skorzystaj-z-pomocy-dla-osob-dotknietych-przemoca-w-rodzinie)
