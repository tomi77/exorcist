# Rdzeń głosowy (Voice Core) — Implementation Plan

> **For Claude:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Zbudować i zwalidować rdzeń mechaniki głosowej — gracz nagrywa własne brzmienie znaku („inskrypcja"), a później gra rozpoznaje powtórzenie tego brzmienia przez dopasowanie podobieństwa audio (bez transkrypcji mowy).

**Architecture:** Cała matematyka dopasowania to czyste, statyczne funkcje GDScript operujące na tablicach próbek — testowalne TDD bez silnika i bez mikrofonu. Potok: PCM → ramki + okno Hanna → FFT → log-mel → sekwencja wektorów cech → DTW → znormalizowana odległość → próg tolerancji. Mikrofon (Godot `AudioEffectCapture`) podłączamy dopiero na końcu jako warstwę integracyjną, a na wierzchu stawiamy minimalną scenę demo do testu manualnego „na żywo".

**Tech Stack:** Godot 4.x, GDScript, GUT (Godot Unit Test) do testów jednostkowych.

**Zakres:** To pierwszy z kilku planów. Tu powstaje WYŁĄCZNIE rdzeń głosowy jako samodzielny, działający i grywalny prototyp (inskrypcja + rozpoznanie). Platformówka, walka, księgi i progresja to osobne plany (patrz „Dalsze plany" na końcu).

---

## Założenia techniczne (stałe prototypu)

Zdefiniowane raz, używane w całym planie:

- `SAMPLE_RATE = 44100` (zgodne z domyślnym miksem audio Godota)
- `FRAME_SIZE = 2048` (~46 ms okna analizy; potęga dwójki wymagana przez FFT)
- `HOP = 512` (~12 ms przeskoku między ramkami)
- `N_MELS = 20` (liczba pasm mel = długość wektora cech ramki)
- `FMIN = 80.0`, `FMAX = 8000.0` (zakres częstotliwości głosu)

Pliki źródłowe (wszystkie pod `res://`):

- `voice/fft.gd` — FFT (radix-2, in-place).
- `voice/features.gd` — okno Hanna, ramkowanie, filtrbank mel, log-mel, ekstrakcja cech.
- `voice/dtw.gd` — Dynamic Time Warping między dwiema sekwencjami cech.
- `voice/spell_matcher.gd` — API rdzenia: `inscribe()` i `match_sample()`.
- `voice/mic_recorder.gd` — integracja z mikrofonem (Godot `AudioEffectCapture`).
- `demo/voice_demo.tscn` + `demo/voice_demo.gd` — scena demo do testu manualnego.
- `test/` — testy GUT (jeden plik na moduł).

---

## Task 0: Scaffold projektu Godot + GUT

**Files:**
- Create: `project.godot`
- Create: `.gitignore`
- Create: `addons/gut/` (wtyczka GUT)
- Create: `test/.gdignore` (puste — żeby Godot nie importował testów jako zasobów gry)

- [ ] **Step 1: Utwórz projekt Godot**

Utwórz minimalny `project.godot` (Godot 4.x). Najprościej: otwórz Godota, „New Project" w katalogu repo, nazwa `exorcist`, renderer „Compatibility" (lekki, wystarcza do 2D). Zatwierdź — Godot wygeneruje `project.godot` i `icon.svg`.

- [ ] **Step 2: Dodaj GUT**

Zainstaluj GUT (AssetLib w edytorze: „Gut - Godot Unit Test", wersja dla Godota 4) — wypakuje się do `addons/gut/`. Włącz wtyczkę: Project → Project Settings → Plugins → GUT → Enable.

- [ ] **Step 3: Dodaj `.gitignore`**

```gitignore
# Godot 4
.godot/
*.import
export_presets.cfg
.DS_Store
```

- [ ] **Step 4: Zablokuj import testów jako zasobów**

Utwórz pusty plik `test/.gdignore` (sama obecność pliku wystarcza).

- [ ] **Step 5: Zweryfikuj, że GUT działa**

Utwórz tymczasowy `test/test_smoke.gd`:

```gdscript
extends GutTest

func test_smoke():
    assert_eq(1 + 1, 2, "matematyka działa")
```

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://test -gexit`
Expected: 1 test, 1 passing, exit code 0.

- [ ] **Step 6: Usuń smoke test i commit**

```bash
rm test/test_smoke.gd
git add project.godot .gitignore addons/gut test/.gdignore icon.svg
git commit -m "chore: scaffold Godot project with GUT test runner"
```

---

## Task 1: FFT (radix-2, in-place)

**Files:**
- Create: `voice/fft.gd`
- Test: `test/test_fft.gd`

- [ ] **Step 1: Napisz failing test**

`test/test_fft.gd`:

```gdscript
extends GutTest

const FFT = preload("res://voice/fft.gd")

func _magnitudes(re: Array, im: Array) -> Array:
    var out := []
    for i in range(re.size()):
        out.append(sqrt(re[i] * re[i] + im[i] * im[i]))
    return out

func test_impulse_has_flat_spectrum():
    # FFT impulsu [1,0,0,0] -> wszystkie biny o module 1
    var re := [1.0, 0.0, 0.0, 0.0]
    var im := [0.0, 0.0, 0.0, 0.0]
    FFT.fft(re, im)
    for m in _magnitudes(re, im):
        assert_almost_eq(m, 1.0, 0.0001)

func test_dc_signal_has_energy_in_bin_zero():
    # Sygnał stały [1,1,1,1] -> cała energia w binie 0 (=4), reszta 0
    var re := [1.0, 1.0, 1.0, 1.0]
    var im := [0.0, 0.0, 0.0, 0.0]
    FFT.fft(re, im)
    assert_almost_eq(re[0], 4.0, 0.0001)
    assert_almost_eq(im[0], 0.0, 0.0001)
    for i in range(1, 4):
        assert_almost_eq(re[i], 0.0, 0.0001)
        assert_almost_eq(im[i], 0.0, 0.0001)
```

- [ ] **Step 2: Uruchom test — ma dać FAŁSZ (FAIL)**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/test_fft.gd -gexit`
Expected: FAIL — `voice/fft.gd` nie istnieje / `fft` nie zdefiniowane.

- [ ] **Step 3: Zaimplementuj FFT**

`voice/fft.gd`:

```gdscript
extends RefCounted
## Iteracyjna FFT radix-2 (Cooley-Tukey), modyfikuje tablice w miejscu.
## re, im: tablice float tej samej długości będącej potęgą dwójki.

static func fft(re: Array, im: Array) -> void:
    var n := re.size()
    if n <= 1:
        return

    # Permutacja bit-reversal
    var j := 0
    for i in range(1, n):
        var bit := n >> 1
        while j & bit:
            j ^= bit
            bit >>= 1
        j ^= bit
        if i < j:
            var tr = re[i]; re[i] = re[j]; re[j] = tr
            var ti = im[i]; im[i] = im[j]; im[j] = ti

    # Danielson-Lanczos
    var seg := 2
    while seg <= n:
        var ang := -2.0 * PI / seg
        var wre := cos(ang)
        var wim := sin(ang)
        var half := seg >> 1
        var start := 0
        while start < n:
            var cur_re := 1.0
            var cur_im := 0.0
            for k in range(half):
                var a := start + k
                var b := start + k + half
                var tr := cur_re * re[b] - cur_im * im[b]
                var ti := cur_re * im[b] + cur_im * re[b]
                re[b] = re[a] - tr
                im[b] = im[a] - ti
                re[a] = re[a] + tr
                im[a] = im[a] + ti
                var n_re := cur_re * wre - cur_im * wim
                cur_im = cur_re * wim + cur_im * wre
                cur_re = n_re
            start += seg
        seg <<= 1
```

- [ ] **Step 4: Uruchom test — ma PRZEJŚĆ**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/test_fft.gd -gexit`
Expected: 2 testy, 2 passing.

- [ ] **Step 5: Commit**

```bash
git add voice/fft.gd test/test_fft.gd
git commit -m "feat: add radix-2 FFT for voice feature extraction"
```

---

## Task 2: Okno Hanna i ramkowanie sygnału

**Files:**
- Create: `voice/features.gd`
- Test: `test/test_features_framing.gd`

- [ ] **Step 1: Napisz failing test**

`test/test_features_framing.gd`:

```gdscript
extends GutTest

const Features = preload("res://voice/features.gd")

func test_hann_window_endpoints_are_zero_and_center_is_one():
    var w := Features.hann_window(5)
    assert_eq(w.size(), 5)
    assert_almost_eq(w[0], 0.0, 0.0001)
    assert_almost_eq(w[4], 0.0, 0.0001)
    assert_almost_eq(w[2], 1.0, 0.0001)

func test_framing_splits_with_correct_count_and_size():
    # 10 próbek, ramka 4, hop 2 -> ramki startują na 0,2,4,6 = 4 ramki
    var samples := PackedFloat32Array()
    for i in range(10):
        samples.append(float(i))
    var frames := Features.frame_signal(samples, 4, 2)
    assert_eq(frames.size(), 4)
    assert_eq(frames[0].size(), 4)
    assert_eq(frames[1][0], 2.0)  # druga ramka zaczyna się od próbki nr 2

func test_framing_drops_incomplete_tail():
    # 5 próbek, ramka 4, hop 2 -> tylko 1 pełna ramka (start 0); start 2 dałby [2,3,4,?] -> odrzucone
    var samples := PackedFloat32Array([0.0, 1.0, 2.0, 3.0, 4.0])
    var frames := Features.frame_signal(samples, 4, 2)
    assert_eq(frames.size(), 1)
```

- [ ] **Step 2: Uruchom test — ma dać FAŁSZ (FAIL)**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/test_features_framing.gd -gexit`
Expected: FAIL — `voice/features.gd` nie istnieje.

- [ ] **Step 3: Zaimplementuj okno i ramkowanie**

`voice/features.gd` (pierwsza część — kolejne taski dopisują do tego pliku):

```gdscript
extends RefCounted
## Ekstrakcja cech audio: okno, ramkowanie, filtrbank mel, log-mel.

const FFT = preload("res://voice/fft.gd")

static func hann_window(size: int) -> PackedFloat32Array:
    var w := PackedFloat32Array()
    w.resize(size)
    if size == 1:
        w[0] = 1.0
        return w
    for i in range(size):
        w[i] = 0.5 - 0.5 * cos(2.0 * PI * i / (size - 1))
    return w

## Dzieli sygnał na nakładające się ramki. Niepełną końcówkę odrzuca.
## Zwraca Array of PackedFloat32Array.
static func frame_signal(samples: PackedFloat32Array, frame_size: int, hop: int) -> Array:
    var frames := []
    var i := 0
    while i + frame_size <= samples.size():
        var frame := PackedFloat32Array()
        frame.resize(frame_size)
        for k in range(frame_size):
            frame[k] = samples[i + k]
        frames.append(frame)
        i += hop
    return frames
```

- [ ] **Step 4: Uruchom test — ma PRZEJŚĆ**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/test_features_framing.gd -gexit`
Expected: 3 testy, 3 passing.

- [ ] **Step 5: Commit**

```bash
git add voice/features.gd test/test_features_framing.gd
git commit -m "feat: add Hann window and signal framing"
```

---

## Task 3: Filtrbank mel

**Files:**
- Modify: `voice/features.gd` (dopisz funkcje mel)
- Test: `test/test_features_mel.gd`

- [ ] **Step 1: Napisz failing test**

`test/test_features_mel.gd`:

```gdscript
extends GutTest

const Features = preload("res://voice/features.gd")

func test_mel_hz_roundtrip():
    # konwersja hz->mel->hz ma wrócić do punktu wyjścia
    var hz := 1000.0
    assert_almost_eq(Features.mel_to_hz(Features.hz_to_mel(hz)), hz, 0.01)

func test_filterbank_shape_and_normalization():
    # n_mels=4, n_fft=16 -> 4 filtry, każdy o długości (n_fft/2 + 1) = 9 binów
    var fb := Features.mel_filterbank(4, 16, 44100.0, 80.0, 8000.0)
    assert_eq(fb.size(), 4)
    assert_eq(fb[0].size(), 9)

func test_filters_are_nonnegative():
    var fb := Features.mel_filterbank(4, 16, 44100.0, 80.0, 8000.0)
    for filt in fb:
        for v in filt:
            assert_true(v >= 0.0, "wagi filtra nie mogą być ujemne")
```

- [ ] **Step 2: Uruchom test — ma dać FAŁSZ (FAIL)**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/test_features_mel.gd -gexit`
Expected: FAIL — `mel_filterbank` / `hz_to_mel` nie zdefiniowane.

- [ ] **Step 3: Dopisz funkcje mel do `voice/features.gd`**

```gdscript
static func hz_to_mel(hz: float) -> float:
    return 2595.0 * (log(1.0 + hz / 700.0) / log(10.0))

static func mel_to_hz(mel: float) -> float:
    return 700.0 * (pow(10.0, mel / 2595.0) - 1.0)

## Buduje trójkątny filtrbank mel.
## Zwraca Array (n_mels) of PackedFloat32Array (n_fft/2 + 1 binów).
static func mel_filterbank(n_mels: int, n_fft: int, sample_rate: float, fmin: float, fmax: float) -> Array:
    var n_bins := n_fft / 2 + 1
    var mel_min := hz_to_mel(fmin)
    var mel_max := hz_to_mel(fmax)

    # n_mels+2 punktów równomiernie w skali mel
    var points := []
    for i in range(n_mels + 2):
        var mel := mel_min + (mel_max - mel_min) * float(i) / float(n_mels + 1)
        var hz := mel_to_hz(mel)
        var bin := int(round((n_fft + 1) * hz / sample_rate))
        points.append(clampi(bin, 0, n_bins - 1))

    var filters := []
    for m in range(1, n_mels + 1):
        var left := points[m - 1]
        var center := points[m]
        var right := points[m + 1]
        var filt := PackedFloat32Array()
        filt.resize(n_bins)
        for k in range(n_bins):
            var val := 0.0
            if k >= left and k < center and center > left:
                val = float(k - left) / float(center - left)
            elif k >= center and k <= right and right > center:
                val = float(right - k) / float(right - center)
            filt[k] = val
        filters.append(filt)
    return filters
```

- [ ] **Step 4: Uruchom test — ma PRZEJŚĆ**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/test_features_mel.gd -gexit`
Expected: 3 testy, 3 passing.

- [ ] **Step 5: Commit**

```bash
git add voice/features.gd test/test_features_mel.gd
git commit -m "feat: add mel filterbank"
```

---

## Task 4: Ekstrakcja cech log-mel (pełny potok PCM → sekwencja wektorów)

**Files:**
- Modify: `voice/features.gd` (dopisz `extract`)
- Test: `test/test_features_extract.gd`

- [ ] **Step 1: Napisz failing test**

`test/test_features_extract.gd`:

```gdscript
extends GutTest

const Features = preload("res://voice/features.gd")

func _sine(freq: float, n: int, sr: float) -> PackedFloat32Array:
    var s := PackedFloat32Array()
    s.resize(n)
    for i in range(n):
        s[i] = sin(2.0 * PI * freq * i / sr)
    return s

func test_extract_returns_sequence_of_nmels_vectors():
    var sr := 44100.0
    var sig := _sine(440.0, 8192, sr)
    # frame_size=2048, hop=512 -> (8192-2048)/512 + 1 = 13 ramek
    var feats := Features.extract(sig, 2048, 512, 20, sr, 80.0, 8000.0)
    assert_eq(feats.size(), 13)
    assert_eq(feats[0].size(), 20)

func test_different_pitches_produce_different_features():
    var sr := 44100.0
    var low := Features.extract(_sine(200.0, 4096, sr), 2048, 512, 20, sr, 80.0, 8000.0)
    var high := Features.extract(_sine(2000.0, 4096, sr), 2048, 512, 20, sr, 80.0, 8000.0)
    # wektory cech dla różnych wysokości muszą się różnić
    var diff := 0.0
    for k in range(20):
        diff += abs(low[0][k] - high[0][k])
    assert_true(diff > 1.0, "różne tony powinny dać różne cechy")
```

- [ ] **Step 2: Uruchom test — ma dać FAŁSZ (FAIL)**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/test_features_extract.gd -gexit`
Expected: FAIL — `extract` nie zdefiniowane.

- [ ] **Step 3: Dopisz `extract` do `voice/features.gd`**

```gdscript
## Pełny potok: PCM (mono, [-1,1]) -> sekwencja wektorów log-mel.
## Zwraca Array of PackedFloat32Array (każdy długości n_mels).
static func extract(samples: PackedFloat32Array, frame_size: int, hop: int,
        n_mels: int, sample_rate: float, fmin: float, fmax: float) -> Array:
    var window := hann_window(frame_size)
    var filterbank := mel_filterbank(n_mels, frame_size, sample_rate, fmin, fmax)
    var n_bins := frame_size / 2 + 1
    var frames := frame_signal(samples, frame_size, hop)

    var result := []
    for frame in frames:
        # okno + przygotowanie buforów FFT
        var re := []
        var im := []
        re.resize(frame_size)
        im.resize(frame_size)
        for i in range(frame_size):
            re[i] = frame[i] * window[i]
            im[i] = 0.0
        FFT.fft(re, im)

        # widmo mocy (połowa + DC)
        var power := []
        power.resize(n_bins)
        for k in range(n_bins):
            power[k] = re[k] * re[k] + im[k] * im[k]

        # log-mel
        var vec := PackedFloat32Array()
        vec.resize(n_mels)
        for m in range(n_mels):
            var filt: PackedFloat32Array = filterbank[m]
            var energy := 0.0
            for k in range(n_bins):
                energy += filt[k] * power[k]
            vec[m] = log(energy + 1e-10)  # log z floor, żeby uniknąć log(0)
        result.append(vec)
    return result
```

- [ ] **Step 4: Uruchom test — ma PRZEJŚĆ**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/test_features_extract.gd -gexit`
Expected: 2 testy, 2 passing.

- [ ] **Step 5: Commit**

```bash
git add voice/features.gd test/test_features_extract.gd
git commit -m "feat: add log-mel feature extraction pipeline"
```

---

## Task 5: DTW (Dynamic Time Warping)

**Files:**
- Create: `voice/dtw.gd`
- Test: `test/test_dtw.gd`

- [ ] **Step 1: Napisz failing test**

`test/test_dtw.gd`:

```gdscript
extends GutTest

const DTW = preload("res://voice/dtw.gd")

func _seq(values: Array) -> Array:
    # zamienia [[a],[b]] -> sekwencję 1-wymiarowych wektorów cech
    var out := []
    for v in values:
        out.append(PackedFloat32Array(v))
    return out

func test_identical_sequences_have_zero_distance():
    var a := _seq([[0.0], [1.0], [2.0]])
    var res := DTW.distance(a, a)
    assert_almost_eq(res.distance, 0.0, 0.0001)

func test_time_stretch_still_aligns_cheaply():
    # ta sama "melodia" rozciągnięta w czasie -> mała odległość
    var a := _seq([[0.0], [1.0], [2.0]])
    var b := _seq([[0.0], [0.0], [1.0], [2.0], [2.0]])
    var res := DTW.distance(a, b)
    assert_almost_eq(res.distance, 0.0, 0.0001)

func test_different_sequences_have_positive_distance():
    var a := _seq([[0.0], [0.0], [0.0]])
    var b := _seq([[5.0], [5.0], [5.0]])
    var res := DTW.distance(a, b)
    assert_true(res.distance > 0.0)
    assert_true(res.steps > 0)

func test_empty_sequence_returns_infinity():
    var res := DTW.distance([], _seq([[1.0]]))
    assert_eq(res.distance, INF)
```

- [ ] **Step 2: Uruchom test — ma dać FAŁSZ (FAIL)**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/test_dtw.gd -gexit`
Expected: FAIL — `voice/dtw.gd` nie istnieje.

- [ ] **Step 3: Zaimplementuj DTW**

`voice/dtw.gd`:

```gdscript
extends RefCounted
## Dynamic Time Warping między dwiema sekwencjami wektorów cech.

## Odległość euklidesowa między dwoma wektorami cech.
static func _dist(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
    var s := 0.0
    for i in range(a.size()):
        var d := a[i] - b[i]
        s += d * d
    return sqrt(s)

## Zwraca słownik {distance: float, steps: int}:
##   distance — całkowity koszt optymalnego dopasowania,
##   steps    — długość ścieżki dopasowania (do normalizacji).
static func distance(seq_a: Array, seq_b: Array) -> Dictionary:
    var n := seq_a.size()
    var m := seq_b.size()
    if n == 0 or m == 0:
        return {"distance": INF, "steps": 0}

    # macierz kosztów (n+1) x (m+1), wypełniona INF, [0][0] = 0
    var cost := []
    var path := []  # liczba kroków na optymalnej ścieżce do danej komórki
    for i in range(n + 1):
        var row := []
        var prow := []
        for j in range(m + 1):
            row.append(INF)
            prow.append(0)
        cost.append(row)
        path.append(prow)
    cost[0][0] = 0.0

    for i in range(1, n + 1):
        for j in range(1, m + 1):
            var d := _dist(seq_a[i - 1], seq_b[j - 1])
            # wybierz najtańszego poprzednika: ukos / góra / lewo
            var best := cost[i - 1][j - 1]
            var best_steps := path[i - 1][j - 1]
            if cost[i - 1][j] < best:
                best = cost[i - 1][j]
                best_steps = path[i - 1][j]
            if cost[i][j - 1] < best:
                best = cost[i][j - 1]
                best_steps = path[i][j - 1]
            cost[i][j] = d + best
            path[i][j] = best_steps + 1

    return {"distance": cost[n][m], "steps": path[n][m]}
```

- [ ] **Step 4: Uruchom test — ma PRZEJŚĆ**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/test_dtw.gd -gexit`
Expected: 4 testy, 4 passing.

- [ ] **Step 5: Commit**

```bash
git add voice/dtw.gd test/test_dtw.gd
git commit -m "feat: add DTW distance for feature sequences"
```

---

## Task 6: SpellMatcher — inskrypcja i dopasowanie z progiem tolerancji

**Files:**
- Create: `voice/spell_matcher.gd`
- Test: `test/test_spell_matcher.gd`

To spina cały rdzeń: `inscribe()` zamienia nagranie na szablon (sekwencję cech), a `match_sample()` porównuje nowe nagranie z szablonem i zwraca decyzję wg tolerancji. Normalizujemy odległość DTW przez liczbę kroków, żeby próg był niezależny od długości nagrania.

- [ ] **Step 1: Napisz failing test**

`test/test_spell_matcher.gd`:

```gdscript
extends GutTest

const SpellMatcher = preload("res://voice/spell_matcher.gd")

func _sine(freq: float, n: int) -> PackedFloat32Array:
    var s := PackedFloat32Array()
    s.resize(n)
    for i in range(n):
        s[i] = sin(2.0 * PI * freq * i / 44100.0)
    return s

func test_inscribe_returns_nonempty_template():
    var m := SpellMatcher.new()
    var tpl := m.inscribe(_sine(300.0, 8192))
    assert_true(tpl.size() > 0)

func test_same_sound_matches():
    var m := SpellMatcher.new()
    var tpl := m.inscribe(_sine(300.0, 8192))
    var res := m.match_sample(tpl, _sine(300.0, 8192))
    assert_true(res.matched, "to samo brzmienie powinno pasować")
    assert_almost_eq(res.distance, 0.0, 0.01)

func test_different_sound_does_not_match():
    var m := SpellMatcher.new()
    var tpl := m.inscribe(_sine(300.0, 8192))
    var res := m.match_sample(tpl, _sine(3000.0, 8192))
    assert_false(res.matched, "wyraźnie inne brzmienie nie powinno pasować")

func test_tolerance_controls_strictness():
    var m := SpellMatcher.new()
    var tpl := m.inscribe(_sine(300.0, 8192))
    var sample := _sine(360.0, 8192)  # lekko inna wysokość
    var strict := m.match_sample(tpl, sample, 0.001)
    var loose := m.match_sample(tpl, sample, 1000.0)
    assert_false(strict.matched, "ostra tolerancja odrzuca")
    assert_true(loose.matched, "luźna tolerancja akceptuje")
```

- [ ] **Step 2: Uruchom test — ma dać FAŁSZ (FAIL)**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/test_spell_matcher.gd -gexit`
Expected: FAIL — `voice/spell_matcher.gd` nie istnieje.

- [ ] **Step 3: Zaimplementuj SpellMatcher**

`voice/spell_matcher.gd`:

```gdscript
extends RefCounted
## Rdzeń mechaniki: inskrypcja znaku (nagranie wzorca) i dopasowanie powtórzenia.

const Features = preload("res://voice/features.gd")
const DTW = preload("res://voice/dtw.gd")

const FRAME_SIZE := 2048
const HOP := 512
const N_MELS := 20
const SAMPLE_RATE := 44100.0
const FMIN := 80.0
const FMAX := 8000.0

## Domyślny próg znormalizowanej odległości DTW (koszt na krok ścieżki).
## Do strojenia na żywo w scenie demo (Task 8).
const DEFAULT_TOLERANCE := 8.0

## Zamienia nagranie PCM na szablon zaklęcia (sekwencję wektorów log-mel).
func inscribe(samples: PackedFloat32Array) -> Array:
    return Features.extract(samples, FRAME_SIZE, HOP, N_MELS, SAMPLE_RATE, FMIN, FMAX)

## Porównuje nowe nagranie z szablonem.
## Zwraca {matched: bool, distance: float} — distance to koszt DTW
## znormalizowany przez liczbę kroków (niezależny od długości nagrania).
func match_sample(template: Array, samples: PackedFloat32Array, tolerance: float = DEFAULT_TOLERANCE) -> Dictionary:
    var sample_feats := inscribe(samples)
    if template.is_empty() or sample_feats.is_empty():
        return {"matched": false, "distance": INF}
    var res := DTW.distance(template, sample_feats)
    var normalized: float = res.distance / max(res.steps, 1)
    return {"matched": normalized <= tolerance, "distance": normalized}
```

- [ ] **Step 4: Uruchom test — ma PRZEJŚĆ**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/test_spell_matcher.gd -gexit`
Expected: 4 testy, 4 passing.

> Uwaga dot. strojenia: jeśli `test_different_sound_does_not_match` lub `test_same_sound_matches` zachowa się niespodziewanie, to znak, że `DEFAULT_TOLERANCE` wymaga kalibracji — wartość 8.0 jest punktem startowym do strojenia w Task 8. Testy syntetyczne (czyste sinusy) zwykle dają wyraźny rozdział; realne strojenie nastąpi na żywym głosie.

- [ ] **Step 5: Uruchom CAŁY zestaw testów**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://test -gexit`
Expected: wszystkie testy ze wszystkich plików passing.

- [ ] **Step 6: Commit**

```bash
git add voice/spell_matcher.gd test/test_spell_matcher.gd
git commit -m "feat: add SpellMatcher with tolerance-based matching"
```

---

## Task 7: Integracja mikrofonu (`AudioEffectCapture`)

**Files:**
- Create: `voice/mic_recorder.gd`
- Modify: `project.godot` (audio bus + włączenie wejścia audio)

Ta warstwa jest integracyjna (zależy od sprzętu), więc NIE pokrywamy jej testem jednostkowym — weryfikacja manualna w scenie demo (Task 8).

- [ ] **Step 1: Włącz wejście audio i magistralę nagrywania**

W Godocie: Project → Project Settings → Audio → Driver → włącz „Enable Input" (`audio/driver/enable_input = true`).

W edytorze Audio (dolny panel „Audio"): dodaj magistralę o nazwie `Record`, a na niej efekt `AudioEffectCapture`. (Zapis trafi do `project.godot` / `default_bus_layout.tres`.)

- [ ] **Step 2: Zaimplementuj MicRecorder**

`voice/mic_recorder.gd`:

```gdscript
extends Node
## Nagrywa wejście z mikrofonu do bufora PCM (mono float [-1,1]).
## Wymaga: magistrala "Record" z efektem AudioEffectCapture; enable_input = true.

var _capture: AudioEffectCapture
var _player: AudioStreamPlayer
var _recording := false
var _buffer := PackedFloat32Array()

func _ready() -> void:
    _player = AudioStreamPlayer.new()
    _player.stream = AudioStreamMicrophone.new()
    _player.bus = "Record"
    add_child(_player)
    var bus_idx := AudioServer.get_bus_index("Record")
    _capture = AudioServer.get_bus_effect(bus_idx, 0)

func start() -> void:
    _buffer = PackedFloat32Array()
    _capture.clear_buffer()
    _player.play()
    _recording = true

func stop() -> PackedFloat32Array:
    _recording = false
    _player.stop()
    _drain()
    return _buffer

func _process(_delta: float) -> void:
    if _recording:
        _drain()

func _drain() -> void:
    var frames := _capture.get_frames_available()
    if frames <= 0:
        return
    var stereo := _capture.get_buffer(frames)  # PackedVector2Array (L,R)
    for v in stereo:
        _buffer.append((v.x + v.y) * 0.5)  # do mono
```

- [ ] **Step 3: Weryfikacja**

Brak testu jednostkowego (zależność sprzętowa). Weryfikacja manualna w Task 8.

- [ ] **Step 4: Commit**

```bash
git add voice/mic_recorder.gd project.godot default_bus_layout.tres
git commit -m "feat: add microphone recorder via AudioEffectCapture"
```

---

## Task 8: Scena demo + strojenie tolerancji na żywo

**Files:**
- Create: `demo/voice_demo.gd`
- Create: `demo/voice_demo.tscn`
- Modify: `project.godot` (ustaw scenę główną na demo)

Cel: grywalny prototyp rdzenia. Naciśnij „Inskrybuj" i wypowiedz brzmienie znaku → zapis szablonu. Potem „Rzuć" i powtórz → gra mówi TRAFIONE/PUDŁO + pokazuje odległość. To narzędzie do walidacji ryzyka i strojenia `DEFAULT_TOLERANCE`.

- [ ] **Step 1: Zaimplementuj logikę demo**

`demo/voice_demo.gd`:

```gdscript
extends Control

const SpellMatcher = preload("res://voice/spell_matcher.gd")
const MicRecorder = preload("res://voice/mic_recorder.gd")

@onready var _status: Label = $VBox/Status
@onready var _inscribe_btn: Button = $VBox/InscribeBtn
@onready var _cast_btn: Button = $VBox/CastBtn

var _mic: Node
var _matcher := SpellMatcher.new()
var _template: Array = []
var _mode := ""  # "inscribe" | "cast" | ""

func _ready() -> void:
    _mic = MicRecorder.new()
    add_child(_mic)
    _inscribe_btn.pressed.connect(_on_inscribe)
    _cast_btn.pressed.connect(_on_cast)
    _cast_btn.disabled = true
    _status.text = "Naciśnij 'Inskrybuj' i wypowiedz znak."

func _on_inscribe() -> void:
    if _mode == "":
        _mic.start()
        _mode = "inscribe"
        _inscribe_btn.text = "Stop (zapisz wzorzec)"
        _status.text = "Nagrywam wzorzec... mów."
    elif _mode == "inscribe":
        var samples: PackedFloat32Array = _mic.stop()
        _template = _matcher.inscribe(samples)
        _mode = ""
        _inscribe_btn.text = "Inskrybuj ponownie"
        _cast_btn.disabled = _template.is_empty()
        _status.text = "Wzorzec zapisany (%d ramek). Teraz 'Rzuć'." % _template.size()

func _on_cast() -> void:
    if _mode == "":
        _mic.start()
        _mode = "cast"
        _cast_btn.text = "Stop (sprawdź)"
        _status.text = "Rzucam... powtórz brzmienie."
    elif _mode == "cast":
        var samples: PackedFloat32Array = _mic.stop()
        var res := _matcher.match_sample(_template, samples)
        _mode = ""
        _cast_btn.text = "Rzuć"
        var verdict := "TRAFIONE ✓" if res.matched else "PUDŁO ✗"
        _status.text = "%s  (odległość: %.2f, próg: %.2f)" % [verdict, res.distance, SpellMatcher.DEFAULT_TOLERANCE]
```

- [ ] **Step 2: Zbuduj scenę**

W edytorze utwórz `demo/voice_demo.tscn`:
- Korzeń: `Control` (skrypt `demo/voice_demo.gd`), layout „Full Rect".
- Dziecko `VBoxContainer` o nazwie `VBox` (wyśrodkowany), a w nim:
  - `Label` o nazwie `Status`
  - `Button` o nazwie `InscribeBtn` (tekst „Inskrybuj")
  - `Button` o nazwie `CastBtn` (tekst „Rzuć")

Ustaw scenę główną: Project → Project Settings → Application → Run → Main Scene → `demo/voice_demo.tscn`.

- [ ] **Step 3: Test manualny — przebieg podstawowy**

Uruchom grę (F5 lub `godot --path .`). Zezwól na dostęp do mikrofonu, jeśli system zapyta.
1. Kliknij „Inskrybuj", powiedz wyraźnie np. „abraxas", kliknij „Stop". Status: „Wzorzec zapisany".
2. Kliknij „Rzuć", powtórz „abraxas" podobnie, „Stop". Oczekiwane: **TRAFIONE**, mała odległość.
3. Kliknij „Rzuć", powiedz coś zupełnie innego („banan"), „Stop". Oczekiwane: **PUDŁO**, duża odległość.

- [ ] **Step 4: Strojenie tolerancji**

Zanotuj odległości dla kilku par (to samo brzmienie vs różne brzmienie, różni mówcy, różne tempo). Dobierz `DEFAULT_TOLERANCE` w `voice/spell_matcher.gd` tak, by leżał między typową odległością „to samo" a „różne". Powtórz test manualny z Step 3 po zmianie.

> Jeśli rozdział „to samo" vs „różne" jest słaby (odległości się nakładają) — to kluczowy sygnał ryzyka. Opcje do rozważenia w kolejnej iteracji (poza zakresem tego planu): normalizacja cech (odjęcie średniej / CMVN), pasmo Sakoe-Chiba w DTW, dodanie pochodnych (delta) cech, detekcja ciszy (przycięcie nagrania).

- [ ] **Step 5: Commit**

```bash
git add demo/voice_demo.gd demo/voice_demo.tscn project.godot
git commit -m "feat: add voice core demo scene with live tolerance tuning"
```

---

## Definicja ukończenia (Voice Core)

- [ ] Wszystkie testy jednostkowe przechodzą: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://test -gexit`
- [ ] Scena demo: to samo brzmienie → TRAFIONE, inne brzmienie → PUDŁO (powtarzalnie).
- [ ] `DEFAULT_TOLERANCE` wstępnie skalibrowane na żywym głosie.
- [ ] Zanotowana ocena ryzyka: czy rozdział „to samo / różne" jest wystarczający do dalszej budowy gry?

---

## Dalsze plany (roadmapa — poza zakresem tego dokumentu)

Każdy jako osobny plan, dopiero po zwalidowaniu rdzenia głosowego:

1. **002 — Platformówka (ruch + poziom):** sterowanie postacią, kolizje, kamera, jeden testowy poziom left-to-right.
2. **003 — System ksiąg i znaków:** definicje znaków, zbieranie ksiąg, rytuał inskrypcji w grze, trwały zapis szablonów gracza, ograniczone odsłuchiwanie wzorca.
3. **004 — Walka i demony:** wrogowie, słabości (mapowanie demon→znak), rzucanie zaklęć jako broni, pętla walki zręcznościowej.
4. **005 — Meta-zaklęcia:** combosy dwóch brzmień po sobie (rozpoznawanie sekwencji).
5. **006 — Progresja zakonnik→papież:** rangi, gating ksiąg, sloty zaklęć, pasywne zdolności, struktura świata/aktów.
```
