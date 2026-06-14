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
