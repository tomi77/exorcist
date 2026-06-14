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
	var res: Dictionary = DTW.distance(a, a)
	assert_almost_eq(res.distance, 0.0, 0.0001)

func test_time_stretch_still_aligns_cheaply():
	# ta sama "melodia" rozciągnięta w czasie -> mała odległość
	var a := _seq([[0.0], [1.0], [2.0]])
	var b := _seq([[0.0], [0.0], [1.0], [2.0], [2.0]])
	var res: Dictionary = DTW.distance(a, b)
	assert_almost_eq(res.distance, 0.0, 0.0001)

func test_different_sequences_have_positive_distance():
	var a := _seq([[0.0], [0.0], [0.0]])
	var b := _seq([[5.0], [5.0], [5.0]])
	var res: Dictionary = DTW.distance(a, b)
	assert_true(res.distance > 0.0)
	assert_true(res.steps > 0)

func test_empty_sequence_returns_infinity():
	var res: Dictionary = DTW.distance([], _seq([[1.0]]))
	assert_eq(res.distance, INF)
