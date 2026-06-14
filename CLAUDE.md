# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**exorcist** — platformówka 2D (left-to-right) o egzorcyście awansującym od zakonnika do papieża. Wyróżnik: **gracz tworzy własny język zaklęć głosem** — patrzy na znak z księgi, sam wymyśla jego wymowę, gra nagrywa to brzmienie i później rozpoznaje powtórzenie przez dopasowanie podobieństwa audio (NIE transkrypcję mowy). Każda rozgrywka brzmi inaczej.

Pełna wizja: `docs/superpowers/specs/001-exorcist-design.md`.

**Stan: etap projektowy.** Repozytorium nie zawiera jeszcze kodu ani projektu Godota — tylko GDD i pierwszy plan implementacji. Pierwsza praca to wykonanie planu `docs/superpowers/plans/001-exorcist-voice-core.md`, którego Task 0 tworzy projekt Godota i instaluje GUT.

**Stack docelowy:** Godot 4.x, GDScript, GUT (Godot Unit Test) do testów.

## Język

Tekst dla użytkownika, komentarze, commit messages, specy i plany — **po polsku**. Identyfikatory w kodzie (nazwy klas, plików, zmiennych, sygnałów) — **po angielsku**.

## Workflow: spec → plan → TDD

`docs/superpowers/specs/` zawiera dokumenty projektowe (GDD), `docs/superpowers/plans/` — plany implementacji TDD rozbijające specy na drobne taski. Numeracja sekwencyjna `NNN-` (nie daty) w nazwach plików.

Każdy task planu to jeden cykl TDD: failing test → minimalna implementacja → weryfikacja → commit. Realizacja przez skille **superpowers:writing-plans** i **superpowers:subagent-driven-development**. Nie pisz implementacji przed testem i nie mieszaj wielu tasków w jednym commicie.

Roadmapa (na końcu planu 001): 001 rdzeń głosowy → 002 platformówka → 003 księgi i znaki → 004 walka i demony → 005 meta-zaklęcia → 006 progresja zakonnik→papież. Każdy podsystem to osobny plan dający samodzielnie działające, testowalne oprogramowanie.

## Commands

Działają dopiero po scaffoldzie (plan 001, Task 0). Test runner — GUT:

```bash
# Pełny zestaw
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit

# Pojedynczy plik testu (używaj absolutnej ścieżki res:// — względne bywają pomijane)
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/test_dtw.gd -gexit
```

Brak kroku budowania — Godot ładuje ze źródeł. Edytor: `godot --path .` (gdy sceny wymagają re-importu).

## Architektura rdzenia głosowego (planowana — patrz plan 001)

Cała matematyka dopasowania to **czyste, statyczne funkcje GDScript na tablicach próbek** — testowalne TDD bez silnika i bez mikrofonu. Potok:

```
PCM → ramki + okno Hanna → FFT → log-mel (filtrbank mel) → sekwencja wektorów cech → DTW → znormalizowana odległość → próg tolerancji
```

Moduły pod `res://voice/`: `fft.gd`, `features.gd`, `dtw.gd`, `spell_matcher.gd` (API: `inscribe()` zamienia nagranie na szablon, `match_sample()` porównuje powtórzenie wg tolerancji). Mikrofon (`mic_recorder.gd`, Godot `AudioEffectCapture`) i scena demo to warstwa integracyjna na końcu — weryfikowana manualnie, nie testem jednostkowym.

**Kluczowe ryzyko projektu:** strojenie tolerancji dopasowania (rozdział „to samo brzmienie" vs „inne"). Walidowane na żywym głosie w scenie demo; `SpellMatcher.DEFAULT_TOLERANCE` to knob do kalibracji.

## Konwencje Godota (wnioski z siostrzanego projektu church-manager)

Stosować od początku, żeby nie powtórzyć znanych pułapek:

- **Wcięcia: TABULATORY, nie spacje** — mieszanie powoduje przeformatowania edytora i szum w diffach.
- **Preferuj `const X = preload("res://...")` zamiast `class_name`** — Godot rozwiązuje `class_name` przez gitignorowany cache (`.godot/global_script_class_cache.cfg`); po dodaniu nowego `class_name` testy headless padają z „Could not find type X" do odświeżenia. Obejście: `godot --headless --path . --quit` lub otwórz projekt w edytorze.
- **Węzły sceny przez `%UniqueName`** (`unique_name_in_owner = true`), nigdy ścieżki stringowe typu `$VBox/.../Label`.
- **Settery chroń `is_inside_tree()`** zanim dotkniesz zmiennych `@onready`.
- **Sygnały w formie stringowej:** `emit_signal("nazwa", args)`.
- **UI:** trzymaj węzły Control w hierarchii Control — Control wewnątrz Node2D psuje routing inputu.
