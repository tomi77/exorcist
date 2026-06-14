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
	var sample_feats: Array = inscribe(samples)
	if template.is_empty() or sample_feats.is_empty():
		return {"matched": false, "distance": INF}
	var res: Dictionary = DTW.distance(template, sample_feats)
	var normalized: float = res.distance / max(res.steps, 1)
	return {"matched": normalized <= tolerance, "distance": normalized}
