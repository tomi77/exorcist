# Platformówka — rdzeń ruchu i poziomu (002) — Implementation Plan

> **For Claude:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Zbudować grywalny rdzeń platformówki 2D left-to-right — postać z biegiem i skokiem (coyote time, zmienna wysokość), testowy poziom z platformami, pułapkami i markerem końca, śmierć→respawn oraz podążającą kamerą.

**Architecture:** Powtórzenie wzorca z rdzenia głosowego — czysta kinematyka (`player/movement.gd`, statyczne funkcje nad liczbami) testowana jednostkowo w GUT bez silnika, oraz cienka warstwa integracyjna (`CharacterBody2D`, sceny, kamera) weryfikowana manualnie. Pułapki, kill-plane i marker końca to `Area2D`; śmierć i ukończenie poziomu komunikowane sygnałami.

**Tech Stack:** Godot 4.x, GDScript, GUT (Godot Unit Test). Scaffold i GUT już istnieją (plan 001).

**Spec:** `docs/superpowers/specs/002-platformer-design.md`

**Zakres:** Wyłącznie ruch + poziom + kolizje + kamera (jeden poziom testowy). Głos w grze (003), walka/demony (004), meta-zaklęcia (005), progresja (006) — osobne plany.

---

## Założenia techniczne (domyślne stałe feelu)

Wartości startowe do strojenia manualnego (Task 6). Trzymane jako `const` w `player/player.gd`, przekazywane do czystych funkcji jako argumenty:

- `RUN_SPEED = 300.0` (px/s — docelowa prędkość biegu)
- `ACCEL = 2000.0` (px/s² — przyspieszanie do prędkości docelowej)
- `FRICTION = 2500.0` (px/s² — wytracanie przy braku wejścia)
- `GRAVITY = 1200.0` (px/s²)
- `MAX_FALL = 1400.0` (px/s — prędkość graniczna spadania)
- `JUMP_SPEED = 520.0` (px/s — początkowa prędkość skoku w górę)
- `COYOTE_TIME = 0.1` (s — okno skoku po zejściu z krawędzi)
- `JUMP_CUT = 0.4` (mnożnik prędkości wznoszenia przy puszczeniu skoku)

Konwencja: oś Y rośnie w dół (Godot), więc skok to **ujemna** prędkość Y.

Wejście prototypu: wbudowane akcje Godota `ui_left`, `ui_right` (ruch) i `ui_accept`
(skok) — istnieją w każdym projekcie, więc nie ruszamy `[input]` w `project.godot`.
Dedykowana mapa wejścia (`move_left`/`move_right`/`jump`) to świadomy follow-up.

Pliki:

- `player/movement.gd` — czysta kinematyka (statyczne funkcje).
- `player/player.gd` — integracja `CharacterBody2D`.
- `player/player.tscn` — scena gracza (+ `Camera2D`).
- `levels/test_level.gd` — okablowanie poziomu (pułapki, kill-plane, marker, respawn, UI).
- `levels/test_level.tscn` — poziom testowy.
- `tests/test_movement.gd` — testy GUT kinematyki.

---

## Konwencje Godot (obowiązują, wnioski z 001 / church-manager)

- **Wcięcia: TABULATORY, nie spacje.** Bloki kodu w tym planie używają spacji dla
  czytelności — **przy zapisie skonwertuj na taby**.
- **Godot 4.6 — inferencja typów:** `:=` pada na elementach untyped `Array` oraz na
  zwrotach statycznych funkcji wołanych przez `const`-preload. Dawaj jawne adnotacje
  typów (`var x: float = ...`) tam, gdzie to potrzebne. (W tym planie kinematyka to
  skalary `float`/`bool`, więc problem jest minimalny, ale pamiętaj o nim w integracji.)
- **Preferuj `const X = preload("res://...")` zamiast `class_name`.**
- **Węzły sceny przez `%UniqueName`** (`unique_name_in_owner = true`), nigdy ścieżki
  stringowe.
- **Sygnały:** deklaracja `signal nazwa`, emisja `emit_signal("nazwa")`, podłączanie
  w kodzie przez `connect` w `_ready()` (nie w edytorze).
- **UI w hierarchii Control** (np. `Label` pod `CanvasLayer`), nigdy Control pod Node2D
  w sposób psujący routing.
- **Testy: ścieżki `res://` absolutne**, pełny zestaw z `-ginclude_subdirs`.

---

## Task 1: Kinematyka — grawitacja i ruch poziomy

**Files:**
- Create: `player/movement.gd`
- Test: `tests/test_movement.gd`

- [ ] **Step 1: Napisz failing test**

`tests/test_movement.gd`:

```gdscript
extends GutTest

const Movement = preload("res://player/movement.gd")

func test_gravity_increases_fall_speed():
    # vy=0, grawitacja 1000 px/s^2, krok 0.1 s -> 100 px/s w dół
    assert_almost_eq(Movement.apply_gravity(0.0, 1000.0, 2000.0, 0.1), 100.0, 0.0001)

func test_gravity_clamped_to_max_fall():
    # blisko limitu: 1950 + 1000*0.1 = 2050, ale limit 2000
    assert_almost_eq(Movement.apply_gravity(1950.0, 1000.0, 2000.0, 0.1), 2000.0, 0.0001)

func test_horizontal_accelerates_toward_target():
    # vx=0, kierunek +1, prędkość docelowa 300, accel 3000, krok 0.05 -> +150
    var vx := Movement.apply_horizontal(0.0, 1.0, 300.0, 3000.0, 3000.0, 0.05)
    assert_almost_eq(vx, 150.0, 0.0001)

func test_horizontal_does_not_overshoot_target():
    # już blisko docelowej: 290 + accel*dt by przekroczyło 300 -> clamp do 300
    var vx := Movement.apply_horizontal(290.0, 1.0, 300.0, 3000.0, 3000.0, 0.05)
    assert_almost_eq(vx, 300.0, 0.0001)

func test_horizontal_friction_stops_at_zero_without_overshoot():
    # brak wejścia (dir 0): tarcie sprowadza do 0 i nie przeskakuje poniżej
    var vx := Movement.apply_horizontal(150.0, 0.0, 300.0, 3000.0, 3000.0, 0.1)
    assert_almost_eq(vx, 0.0, 0.0001)
```

- [ ] **Step 2: Uruchom test — ma dać FAŁSZ (FAIL)**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/test_movement.gd -gexit`
Expected: FAIL — `player/movement.gd` nie istnieje.

- [ ] **Step 3: Zaimplementuj `player/movement.gd`**

```gdscript
extends RefCounted
## Czysta kinematyka platformówki — statyczne funkcje nad skalarami.
## Brak zależności od sceny, węzłów i Input. Oś Y rośnie w dół (skok = ujemne Y).

## Prędkość pionowa po jednym kroku grawitacji, ograniczona prędkością graniczną.
static func apply_gravity(vy: float, gravity: float, max_fall: float, delta: float) -> float:
    return min(vy + gravity * delta, max_fall)

## Prędkość pozioma po jednym kroku: przy wejściu dąży do prędkości docelowej
## (input_dir w [-1,1]) z przyspieszeniem accel; bez wejścia wytraca się tarciem
## do zera. move_toward gwarantuje brak przeskoku poza cel.
static func apply_horizontal(vx: float, input_dir: float, run_speed: float,
        accel: float, friction: float, delta: float) -> float:
    if input_dir != 0.0:
        var target := input_dir * run_speed
        return move_toward(vx, target, accel * delta)
    return move_toward(vx, 0.0, friction * delta)
```

- [ ] **Step 4: Uruchom test — ma PRZEJŚĆ**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/test_movement.gd -gexit`
Expected: 5 testów, 5 passing. Przy „Could not find type" odśwież cache: `godot --headless --path . --import`.

- [ ] **Step 5: Commit**

```bash
git add player/movement.gd tests/test_movement.gd
git commit -m "feat: add gravity and horizontal kinematics"
```

---

## Task 2: Kinematyka — skok (warunek, start, przycięcie)

**Files:**
- Modify: `player/movement.gd` (dopisz funkcje skoku)
- Test: `tests/test_movement.gd` (dopisz testy)

- [ ] **Step 1: Dopisz failing testy do `tests/test_movement.gd`**

```gdscript
func test_can_jump_on_floor():
    assert_true(Movement.can_jump(true, 0.0))

func test_can_jump_within_coyote_window():
    assert_true(Movement.can_jump(false, 0.05))

func test_cannot_jump_in_air_after_coyote():
    assert_false(Movement.can_jump(false, 0.0))

func test_start_jump_sets_upward_velocity():
    # skok = ujemna prędkość Y (w górę)
    assert_almost_eq(Movement.start_jump(600.0), -600.0, 0.0001)

func test_cut_jump_reduces_rising_velocity():
    # wznoszenie (ujemne Y) przycięte mnożnikiem
    assert_almost_eq(Movement.cut_jump(-600.0, 0.5), -300.0, 0.0001)

func test_cut_jump_ignores_falling():
    # opadanie (dodatnie Y) nietknięte
    assert_almost_eq(Movement.cut_jump(200.0, 0.5), 200.0, 0.0001)
```

- [ ] **Step 2: Uruchom test — ma dać FAŁSZ (FAIL)**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/test_movement.gd -gexit`
Expected: FAIL — `can_jump`/`start_jump`/`cut_jump` nie zdefiniowane.

- [ ] **Step 3: Dopisz funkcje do `player/movement.gd`**

```gdscript
## Czy skok jest dozwolony: na ziemi lub w aktywnym oknie coyote.
static func can_jump(on_floor: bool, coyote_timer: float) -> bool:
    return on_floor or coyote_timer > 0.0

## Prędkość pionowa nadawana przy starcie skoku (ujemna = w górę).
static func start_jump(jump_speed: float) -> float:
    return -jump_speed

## Przycięcie skoku przy puszczeniu przycisku: skraca tylko ruch w górę
## (ujemne Y); ruch w dół pozostaje bez zmian.
static func cut_jump(vy: float, cut_factor: float) -> float:
    if vy < 0.0:
        return vy * cut_factor
    return vy
```

- [ ] **Step 4: Uruchom test — ma PRZEJŚĆ**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/test_movement.gd -gexit`
Expected: 11 testów, 11 passing.

- [ ] **Step 5: Commit**

```bash
git add player/movement.gd tests/test_movement.gd
git commit -m "feat: add jump kinematics (coyote check, start, cut)"
```

---

## Task 3: Kinematyka — licznik coyote

**Files:**
- Modify: `player/movement.gd` (dopisz `tick_coyote`)
- Test: `tests/test_movement.gd` (dopisz testy)

- [ ] **Step 1: Dopisz failing testy do `tests/test_movement.gd`**

```gdscript
func test_coyote_refills_on_floor():
    # na ziemi licznik jest doładowany do pełnego okna
    assert_almost_eq(Movement.tick_coyote(0.0, true, 0.1, 0.016), 0.1, 0.0001)

func test_coyote_decrements_in_air():
    # w powietrzu maleje o delta
    assert_almost_eq(Movement.tick_coyote(0.1, false, 0.1, 0.04), 0.06, 0.0001)

func test_coyote_does_not_go_negative():
    # nie schodzi poniżej zera
    assert_almost_eq(Movement.tick_coyote(0.02, false, 0.1, 0.1), 0.0, 0.0001)
```

- [ ] **Step 2: Uruchom test — ma dać FAŁSZ (FAIL)**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/test_movement.gd -gexit`
Expected: FAIL — `tick_coyote` nie zdefiniowane.

- [ ] **Step 3: Dopisz funkcję do `player/movement.gd`**

```gdscript
## Aktualizacja licznika coyote: na ziemi doładowanie do pełnego okna,
## w powietrzu odliczanie do zera (bez wartości ujemnych).
static func tick_coyote(coyote_timer: float, on_floor: bool, coyote_time: float, delta: float) -> float:
    if on_floor:
        return coyote_time
    return max(coyote_timer - delta, 0.0)
```

- [ ] **Step 4: Uruchom test — ma PRZEJŚĆ**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/test_movement.gd -gexit`
Expected: 14 testów, 14 passing.

- [ ] **Step 5: Uruchom CAŁY zestaw (regresja z rdzeniem głosowym)**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: wszystkie testy passing (18 z rdzenia głosowego + 14 kinematyki = 32).

- [ ] **Step 6: Commit**

```bash
git add player/movement.gd tests/test_movement.gd
git commit -m "feat: add coyote timer kinematics"
```

---

## Task 4: Integracja gracza (`CharacterBody2D`)

Warstwa integracyjna — BRAK testu jednostkowego (zależność od silnika). Weryfikacja:
projekt + scena ładują się headless bez błędów; pełna weryfikacja feelu w Task 6.

**Files:**
- Create: `player/player.gd`
- Create: `player/player.tscn`

- [ ] **Step 1: Zaimplementuj `player/player.gd`**

```gdscript
extends CharacterBody2D
## Integracja: Input -> czyste funkcje kinematyki -> move_and_slide().
## Prototyp używa wbudowanych akcji ui_left / ui_right / ui_accept.

const Movement = preload("res://player/movement.gd")

const RUN_SPEED := 300.0
const ACCEL := 2000.0
const FRICTION := 2500.0
const GRAVITY := 1200.0
const MAX_FALL := 1400.0
const JUMP_SPEED := 520.0
const COYOTE_TIME := 0.1
const JUMP_CUT := 0.4

signal died

var _coyote_timer := 0.0

func _physics_process(delta: float) -> void:
    var on_floor := is_on_floor()
    _coyote_timer = Movement.tick_coyote(_coyote_timer, on_floor, COYOTE_TIME, delta)

    var input_dir := Input.get_axis("ui_left", "ui_right")
    velocity.x = Movement.apply_horizontal(velocity.x, input_dir, RUN_SPEED, ACCEL, FRICTION, delta)
    velocity.y = Movement.apply_gravity(velocity.y, GRAVITY, MAX_FALL, delta)

    if Input.is_action_just_pressed("ui_accept") and Movement.can_jump(on_floor, _coyote_timer):
        velocity.y = Movement.start_jump(JUMP_SPEED)
        _coyote_timer = 0.0
    if Input.is_action_just_released("ui_accept"):
        velocity.y = Movement.cut_jump(velocity.y, JUMP_CUT)

    move_and_slide()

## Wywoływane przez poziom przy kontakcie z pułapką / kill-plane.
func die() -> void:
    emit_signal("died")
```

- [ ] **Step 2: Zbuduj `player/player.tscn` (format tekstowy .tscn, format=3)**

Struktura:
- Korzeń `CharacterBody2D` o nazwie `Player`, skrypt `res://player/player.gd`.
- Dziecko `CollisionShape2D` z `RectangleShape2D` (np. 32×48).
- Dziecko `ColorRect` jako placeholder wizualny (np. 32×48, offset tak, by pokrywał
  kształt kolizji; dowolny wyrazisty kolor).
- Dziecko `Camera2D` (podąża automatycznie, bo jest dzieckiem gracza).

Wzór (zweryfikuj składnię .tscn dla Godot 4; `SubResource` dla kształtu):

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://player/player.gd" id="1"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_player"]
size = Vector2(32, 48)

[node name="Player" type="CharacterBody2D"]
script = ExtResource("1")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("RectangleShape2D_player")

[node name="ColorRect" type="ColorRect" parent="."]
offset_left = -16.0
offset_top = -24.0
offset_right = 16.0
offset_bottom = 24.0
color = Color(0.9, 0.85, 0.6, 1)

[node name="Camera2D" type="Camera2D" parent="."]
```

- [ ] **Step 3: Weryfikacja headless**

Run: `godot --headless --path . --import` a potem `godot --headless --path . --quit-after 2`
Expected: brak błędów PARSOWANIA `player.gd` ani `player.tscn`. (Scena gracza nie jest
jeszcze sceną główną, więc samo `--import` musi przejść czysto; brak SCRIPT ERROR.)
Pełny zestaw testów nadal: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` — 32 passing.

- [ ] **Step 4: Commit**

```bash
git add player/player.gd player/player.tscn
git commit -m "feat: add player CharacterBody2D integration"
```

---

## Task 5: Poziom testowy (platformy, pułapki, marker, respawn, kamera)

Warstwa integracyjna — BRAK testu jednostkowego. Weryfikacja: scena ładuje się
headless bez błędów; pełna walidacja grania w Task 6.

**Files:**
- Create: `levels/test_level.gd`
- Create: `levels/test_level.tscn`
- Modify: `project.godot` (scena główna → poziom testowy)

- [ ] **Step 1: Zaimplementuj `levels/test_level.gd`**

```gdscript
extends Node2D
## Okablowanie poziomu: respawn po śmierci, ukończenie na markerze.
## Pułapki i kill-plane są w grupie "hazard" (Area2D). Marker końca: %EndMarker.

@onready var _player: CharacterBody2D = %Player
@onready var _start: Marker2D = %StartPoint
@onready var _end_label: Label = %EndLabel

func _ready() -> void:
    _end_label.visible = false
    _player.global_position = _start.global_position
    _player.died.connect(_on_player_died)
    for hazard in get_tree().get_nodes_in_group("hazard"):
        hazard.body_entered.connect(_on_hazard_entered)
    %EndMarker.body_entered.connect(_on_end_entered)

func _on_hazard_entered(body: Node) -> void:
    if body == _player:
        _player.die()

func _on_player_died() -> void:
    _player.velocity = Vector2.ZERO
    _player.global_position = _start.global_position

func _on_end_entered(body: Node) -> void:
    if body == _player:
        _end_label.visible = true
```

- [ ] **Step 2: Zbuduj `levels/test_level.tscn` (format tekstowy .tscn)**

Struktura:
- Korzeń `Node2D` o nazwie `TestLevel`, skrypt `res://levels/test_level.gd`.
- Instancja `player.tscn` jako `Player` z `unique_name_in_owner = true`
  (`%Player`), umieszczona przy starcie.
- `Marker2D` o nazwie `StartPoint`, `%StartPoint` — pozycja respawnu (tam gdzie gracz).
- **Platformy** (kilka): każda `StaticBody2D` z `CollisionShape2D` (`RectangleShape2D`)
  + `ColorRect` placeholder. Ułóż poziomo left-to-right z przerwami (przepaście) i
  różnymi wysokościami, tak by dało się przejść biegiem i skokiem.
- **Pułapki** (przynajmniej jedna): `Area2D` w grupie `"hazard"` z `CollisionShape2D`
  + `ColorRect` (np. czerwony „kolec"). Ustaw grupę: w .tscn `groups = ["hazard"]`
  na węźle Area2D.
- **Kill-plane**: szeroki `Area2D` w grupie `"hazard"` poniżej całego poziomu
  (łapie spadek poza platformy).
- **Marker końca**: `Area2D` o nazwie `EndMarker`, `%EndMarker`, z `CollisionShape2D`
  + `ColorRect` (np. zielony „portal") na prawym końcu poziomu.
- **UI**: `CanvasLayer` > `Label` o nazwie `EndLabel`, `%EndLabel`,
  text = „Poziom ukończony" (widoczność sterowana z kodu, startowo ukryta).

Uwagi:
- `Area2D` wykrywa gracza przez `body_entered` — gracz to `CharacterBody2D` (a więc
  `PhysicsBody2D`), więc kolizja zadziała przy domyślnych maskach/warstwach. Upewnij
  się, że Area2D i Player mają zgodne `collision_layer`/`collision_mask` (domyślne 1
  wystarczą).
- Grupy w .tscn: dodaj `groups = PackedStringArray("hazard")` (lub `groups = ["hazard"]`
  zależnie od wersji formatu — zweryfikuj dla Godot 4) do węzłów pułapek i kill-plane.

- [ ] **Step 3: Ustaw scenę główną w `project.godot`**

Zmień `run/main_scene` w sekcji `[application]` na `"res://levels/test_level.tscn"`
(zastępuje scenę demo głosu jako scenę startową na czas prac nad platformówką;
scena demo głosu pozostaje dostępna jako plik). NIE usuwaj innych kluczy.

- [ ] **Step 4: Weryfikacja headless**

Run: `godot --headless --path . --import` a potem `godot --headless --path . --quit-after 2`
Expected: poziom ładuje się jako scena główna BEZ błędów skryptu/parsowania ani
„Node not found %Player/%StartPoint/%EndMarker/%EndLabel". (Headless nie renderuje
ani nie symuluje wejścia — KLUCZOWA jest czystość ładowania i podłączeń sygnałów.)
Pełny zestaw testów nadal: 32 passing.

- [ ] **Step 5: Commit**

```bash
git add levels/test_level.gd levels/test_level.tscn project.godot
git commit -m "feat: add test level with hazards, respawn and end marker"
```

---

## Task 6: Weryfikacja manualna i strojenie feelu

Cel: potwierdzić grywalność i dostroić feel ruchu (główne ryzyko 002, analogicznie do
strojenia tolerancji w 001). BRAK testów jednostkowych — to praca w edytorze.

- [ ] **Step 1: Uruchom grę i przejdź pętlę traversalu**

Uruchom `godot --path .` (F5). Sprawdź:
1. Bieg lewo/prawo (`←`/`→`), skok (`Spacja`/`Enter`). Postać porusza się i skacze.
2. Kolizje: lądowanie na platformach, brak przenikania, zatrzymanie o ściany.
3. **Coyote time:** skok tuż po zbiegnięciu z krawędzi nadal działa.
4. **Zmienna wysokość:** krótkie tknięcie skoku = niższy skok; przytrzymanie = pełny.
5. **Pułapka** i **spadek w przepaść/poza poziom** → respawn na starcie.
6. **Marker końca** → pojawia się „Poziom ukończony".
7. **Kamera** płynnie podąża za graczem.

- [ ] **Step 2: Strojenie stałych feelu**

W `player/player.gd` dostrój `RUN_SPEED`, `ACCEL`, `FRICTION`, `GRAVITY`, `MAX_FALL`,
`JUMP_SPEED`, `COYOTE_TIME`, `JUMP_CUT`, aż ruch „czuje się" dobrze (responsywny bieg,
satysfakcjonujący skok, wyczuwalne ale nie przesadne coyote). Po zmianach powtórz
Step 1. (Testy kinematyki nie zależą od tych stałych — pozostaną zielone.)

> Jeśli kolizje `Area2D`↔gracz nie działają (pułapka/marker nie reagują) — sprawdź
> `collision_layer`/`collision_mask` oraz że gracz wchodzi w obszar `Area2D` (a nie
> tylko go mija). Jeśli `is_on_floor()` jest niestabilne — sprawdź `up_direction`
> (domyślnie `Vector2.UP`) i czy platformy to `StaticBody2D` z kolizją.

- [ ] **Step 3: Commit strojenia (jeśli zmieniono wartości)**

```bash
git add player/player.gd
git commit -m "tune: calibrate platformer movement feel"
```

---

## Definicja ukończenia (Platformówka 002)

- [ ] Testy jednostkowe kinematyki przechodzą: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` (32 passing).
- [ ] Postać przechodzi testowy poziom od startu do markera końca.
- [ ] Śmierć (pułapka / kill-plane / spadek) respawnuje gracza na starcie.
- [ ] Marker końca wyświetla „Poziom ukończony".
- [ ] Kamera podąża za graczem; feel ruchu wstępnie skalibrowany.

---

## Dalsze plany (roadmapa — poza zakresem)

3. **003 — System ksiąg i znaków:** definicje znaków, zbieranie ksiąg, rytuał
   inskrypcji w grze, trwały zapis szablonów gracza, ograniczone odsłuchiwanie wzorca.
   (Tu spina się rdzeń głosowy z platformówką.)
4. **004 — Walka i demony:** wrogowie, słabości, rzucanie zaklęć jako broni, HP.
5. **005 — Meta-zaklęcia:** combosy dwóch brzmień po sobie.
6. **006 — Progresja zakonnik→papież:** rangi, gating ksiąg, sloty, pasywki; tu wracają
   podwójny skok / dash jako nagrody mobilności.

Follow-upy techniczne (z pamięci projektu): dedykowana mapa wejścia
(`move_left`/`move_right`/`jump`), wyniesienie stałych feelu i `DEFAULT_TOLERANCE` do
konfiguracji, dług testowy rdzenia głosowego (duplikacja stałych, asercje kontraktu).
