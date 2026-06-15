# Platformówka — rdzeń ruchu i poziomu (002) — Design

## Kontekst

Drugi podsystem gry **exorcist** (po rdzeniu głosowym, plan 001). Cel: pierwszy
grywalny wycinek platformówki 2D left-to-right — postać, którą można przeprowadzić
przez testowy poziom. Mechanika głosowa, walka, księgi i progresja to osobne plany
(003–006) i NIE wchodzą w zakres 002.

Egzorcysta jest na tym etapie zakonnikiem — ruch jest skromny i ma być fundamentem,
który kolejne plany rozszerzą wraz z progresją zakonnik→papież.

## Cel

Solidny, dobrze „czujący się" rdzeń ruchu (bieg + skok) oraz jeden testowy poziom
z pełną pętlą traversalu: start → pokonanie platform i pułapek → marker końca.

## Wyróżnik architektoniczny: TDD mimo zależności od silnika

Platformówka z natury opiera się o fizykę silnika (`CharacterBody2D`,
`move_and_slide()`), która jest trudna do testów jednostkowych. Powtarzamy więc
strategię z rdzenia głosowego: **oddzielamy czystą logikę od integracji z silnikiem**.

- **Czyste funkcje GDScript** (kinematyka) — testowalne w GUT bez sceny i bez silnika.
- **Cienka warstwa integracyjna** — `CharacterBody2D`, sceny, kamera — weryfikowana
  manualnie w edytorze.

## Filary zakresu

### 1. Ruch postaci (czysta kinematyka + integracja)

- Bieg lewo/prawo: prędkość pozioma dąży do prędkości docelowej (przyspieszanie),
  a przy braku wejścia wytraca się tarciem do zera.
- Grawitacja z prędkością graniczną spadania.
- Skok pojedynczy z dwoma usprawnieniami feelu:
  - **Coyote time** — skok dozwolony przez krótkie okno po zejściu z krawędzi.
  - **Zmienna wysokość skoku** — puszczenie przycisku w trakcie wznoszenia przycina
    prędkość pionową (krótszy skok).
- Parametry strojenia (grawitacja, prędkość biegu, siła skoku, przyspieszenie,
  tarcie, prędkość graniczna, okno coyote, współczynnik przycięcia) są **argumentami
  czystych funkcji**. Testy podają konkretne wartości; gra trzyma wartości domyślne
  jako stałe. Te „pokrętła" są naturalnym kandydatem do wyniesienia do konfiguracji
  (jak `DEFAULT_TOLERANCE` w rdzeniu głosowym) — ale samo wyniesienie do konfiguracji
  jest poza zakresem 002.

### 2. Testowy poziom

- Pozioma sekwencja platform: `StaticBody2D` + `CollisionShape2D` (prostokąty),
  z `ColorRect` jako placeholderem wizualnym (zero zależności od grafiki/tilesetów).
- **Strefy-pułapki** (kolce/przepaście) jako `Area2D` — dotknięcie zabija gracza.
- **Kill-plane** pod poziomem (`Area2D` lub próg `y`) — spadek poza poziom zabija.
- **Punkt startu/respawnu** — pozycja, na którą wraca gracz po śmierci.
- **Marker końca** jako `Area2D` — wejście kończy poziom: sygnał + komunikat
  „Poziom ukończony".

### 3. Śmierć i respawn

- Śmierć (pułapka albo kill-plane) → respawn na punkcie startu. Bez żyć i HP —
  to należy do walki (plan 004). Pętla śmierć→respawn jest natychmiastowa i prosta.

### 4. Kamera

- `Camera2D` podążająca za graczem (płynne podążanie; ewentualne wyprzedzenie
  poziome to detal strojenia, nie wymóg).

## Architektura i pliki

```
res://player/movement.gd      # czysta kinematyka — statyczne funkcje (TDD)
res://player/player.gd        # integracja CharacterBody2D: Input → funkcje → move_and_slide (manual)
res://player/player.tscn      # CharacterBody2D + CollisionShape2D + ColorRect + Camera2D
res://levels/test_level.gd    # okablowanie poziomu: pułapki, kill-plane, marker końca, respawn (manual)
res://levels/test_level.tscn  # platformy, strefy Area2D, punkt startu, marker końca
tests/test_movement.gd        # testy GUT czystej kinematyki
```

**Granice odpowiedzialności:**

- `movement.gd` nie wie nic o scenie, węzłach ani `Input` — operuje na liczbach
  i `Vector2`. Jedyna jednostka pokryta testami jednostkowymi.
- `player.gd` zna silnik (czyta `Input`, woła `movement.gd`, aplikuje
  `move_and_slide()`, śledzi `is_on_floor()` i licznik coyote, emituje/obsługuje
  śmierć i respawn).
- `test_level.gd` łączy sygnały pułapek/markera końca z respawnem gracza i UI.

## Testowanie

### Automatyczne (GUT, czysta kinematyka)

- Grawitacja zwiększa prędkość spadania z każdą klatką, ale nie powyżej prędkości
  granicznej.
- Pozioma prędkość dąży do docelowej przy wejściu i wytraca się tarciem do zera
  przy jego braku (bez przeskoku poniżej zera / „dygotania").
- Skok ustawia prędkość pionową w górę tylko gdy można skoczyć (na ziemi lub w oknie
  coyote); w powietrzu poza oknem — nie.
- Przycięcie skoku przy puszczeniu zmniejsza prędkość wznoszenia (i nie wpływa na
  ruch w dół).
- Licznik coyote: ustawiany przy zejściu z ziemi, maleje z czasem, wygasa po oknie;
  skok go konsumuje.

### Manualne (edytor + uruchomienie gry)

- Bieg i skok „czują się" dobrze; coyote i zmienna wysokość działają zauważalnie.
- Kolizje z platformami (lądowanie, ściany) poprawne.
- Pułapka i spadek poza poziom → respawn na starcie.
- Marker końca → komunikat „Poziom ukończony".
- Kamera płynnie podąża za graczem.

## Definicja ukończenia

- [ ] Testy jednostkowe kinematyki przechodzą (GUT).
- [ ] Postać przechodzi testowy poziom od startu do markera końca.
- [ ] Śmierć (pułapka/kill-plane) respawnuje gracza na starcie.
- [ ] Marker końca wyzwala stan „ukończono".
- [ ] Kamera podąża za graczem.

## Świadomie poza zakresem (YAGNI / kolejne plany)

- Podwójny skok, dash, wspinaczka — kandydaci na nagrody progresji (003/006).
- Rzucanie zaklęć / głos w grze — plan 003+.
- Wrogowie, HP, żywioły walki — plan 004.
- Tileset/grafika, prawdziwe poziomy, parallax — później.
- Wyniesienie parametrów ruchu do konfiguracji (knoby już istnieją jako stałe).
- Bufor skoku (jump buffering) — opcjonalne usprawnienie feelu na później.
