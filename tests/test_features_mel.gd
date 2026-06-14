extends GutTest

const Features = preload("res://voice/features.gd")

func test_mel_hz_roundtrip():
	# konwersja hz->mel->hz ma wrócić do punktu wyjścia
	var hz := 1000.0
	assert_almost_eq(Features.mel_to_hz(Features.hz_to_mel(hz)), hz, 0.01)

func test_filterbank_shape_and_normalization():
	# n_mels=4, n_fft=16 -> 4 filtry, każdy o długości (n_fft/2 + 1) = 9 binów
	var fb: Array = Features.mel_filterbank(4, 16, 44100.0, 80.0, 8000.0)
	assert_eq(fb.size(), 4)
	assert_eq(fb[0].size(), 9)

func test_filters_are_nonnegative():
	var fb: Array = Features.mel_filterbank(4, 16, 44100.0, 80.0, 8000.0)
	for filt in fb:
		for v in filt:
			assert_true(v >= 0.0, "wagi filtra nie mogą być ujemne")
