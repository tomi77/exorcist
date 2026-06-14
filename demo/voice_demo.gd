extends Control

const SpellMatcher = preload("res://voice/spell_matcher.gd")
const MicRecorder = preload("res://voice/mic_recorder.gd")

@onready var _status: Label = %Status
@onready var _inscribe_btn: Button = %InscribeBtn
@onready var _cast_btn: Button = %CastBtn

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
		var res: Dictionary = _matcher.match_sample(_template, samples)
		_mode = ""
		_cast_btn.text = "Rzuć"
		var verdict := "TRAFIONE ✓" if res.matched else "PUDŁO ✗"
		_status.text = "%s  (odległość: %.2f, próg: %.2f)" % [verdict, res.distance, SpellMatcher.DEFAULT_TOLERANCE]
