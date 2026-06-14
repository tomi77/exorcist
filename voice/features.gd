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
	var frames: Array = []
	var i := 0
	while i + frame_size <= samples.size():
		var frame := PackedFloat32Array()
		frame.resize(frame_size)
		for k in range(frame_size):
			frame[k] = samples[i + k]
		frames.append(frame)
		i += hop
	return frames
