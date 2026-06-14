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
