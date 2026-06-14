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
	var feats: Array = Features.extract(sig, 2048, 512, 20, sr, 80.0, 8000.0)
	assert_eq(feats.size(), 13)
	assert_eq(feats[0].size(), 20)

func test_different_pitches_produce_different_features():
	var sr := 44100.0
	var low: Array = Features.extract(_sine(200.0, 4096, sr), 2048, 512, 20, sr, 80.0, 8000.0)
	var high: Array = Features.extract(_sine(2000.0, 4096, sr), 2048, 512, 20, sr, 80.0, 8000.0)
	# wektory cech dla różnych wysokości muszą się różnić
	var diff := 0.0
	for k in range(20):
		diff += abs(low[0][k] - high[0][k])
	assert_true(diff > 1.0, "różne tony powinny dać różne cechy")
