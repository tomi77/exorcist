extends Node
## Nagrywa wejście z mikrofonu do bufora PCM (mono float [-1,1]).
## Wymaga: magistrala "Record" z efektem AudioEffectCapture; enable_input = true.

var _capture: AudioEffectCapture
var _player: AudioStreamPlayer
var _recording := false
var _buffer := PackedFloat32Array()

func _ready() -> void:
	var bus_idx := AudioServer.get_bus_index("Record")
	if bus_idx == -1:
		push_error("MicRecorder: magistrala 'Record' nie znaleziona — sprawdź default_bus_layout.tres")
		return
	_capture = AudioServer.get_bus_effect(bus_idx, 0)
	if _capture == null:
		push_error("MicRecorder: brak efektu AudioEffectCapture na magistrali 'Record' (pozycja 0)")
		return
	_player = AudioStreamPlayer.new()
	_player.stream = AudioStreamMicrophone.new()
	_player.bus = "Record"
	add_child(_player)

func start() -> void:
	if _capture == null or _player == null:
		return
	_buffer = PackedFloat32Array()
	_capture.clear_buffer()
	_player.play()
	_recording = true

func stop() -> PackedFloat32Array:
	if _capture == null or _player == null:
		return _buffer
	_recording = false
	_player.stop()
	_drain()
	return _buffer

func _process(_delta: float) -> void:
	if _recording:
		_drain()

func _drain() -> void:
	if _capture == null:
		return
	var frames := _capture.get_frames_available()
	if frames <= 0:
		return
	var stereo := _capture.get_buffer(frames)  # PackedVector2Array (L,R)
	for v in stereo:
		_buffer.append((v.x + v.y) * 0.5)  # do mono
