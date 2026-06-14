extends GutTest

const Features = preload("res://voice/features.gd")

func test_hann_window_endpoints_are_zero_and_center_is_one():
	var w: PackedFloat32Array = Features.hann_window(5)
	assert_eq(w.size(), 5)
	assert_almost_eq(w[0], 0.0, 0.0001)
	assert_almost_eq(w[4], 0.0, 0.0001)
	assert_almost_eq(w[2], 1.0, 0.0001)

func test_framing_splits_with_correct_count_and_size():
	# 10 próbek, ramka 4, hop 2 -> ramki startują na 0,2,4,6 = 4 ramki
	var samples := PackedFloat32Array()
	for i in range(10):
		samples.append(float(i))
	var frames: Array = Features.frame_signal(samples, 4, 2)
	assert_eq(frames.size(), 4)
	assert_eq((frames[0] as PackedFloat32Array).size(), 4)
	assert_eq((frames[1] as PackedFloat32Array)[0], 2.0)  # druga ramka zaczyna się od próbki nr 2

func test_framing_drops_incomplete_tail():
	# 5 próbek, ramka 4, hop 2 -> tylko 1 pełna ramka (start 0); start 2 dałby [2,3,4,?] -> odrzucone
	var samples := PackedFloat32Array([0.0, 1.0, 2.0, 3.0, 4.0])
	var frames: Array = Features.frame_signal(samples, 4, 2)
	assert_eq(frames.size(), 1)
