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

static func hz_to_mel(hz: float) -> float:
	return 2595.0 * (log(1.0 + hz / 700.0) / log(10.0))

static func mel_to_hz(mel: float) -> float:
	return 700.0 * (pow(10.0, mel / 2595.0) - 1.0)

## Buduje trójkątny filtrbank mel.
## Zwraca Array (n_mels) of PackedFloat32Array (n_fft/2 + 1 binów).
static func mel_filterbank(n_mels: int, n_fft: int, sample_rate: float, fmin: float, fmax: float) -> Array:
	var n_bins: int = n_fft / 2 + 1
	var mel_min: float = hz_to_mel(fmin)
	var mel_max: float = hz_to_mel(fmax)

	# n_mels+2 punktów równomiernie w skali mel
	var points: Array = []
	for i in range(n_mels + 2):
		var mel: float = mel_min + (mel_max - mel_min) * float(i) / float(n_mels + 1)
		var hz: float = mel_to_hz(mel)
		var bin: int = int(round((n_fft + 1) * hz / sample_rate))
		points.append(clampi(bin, 0, n_bins - 1))

	var filters: Array = []
	for m in range(1, n_mels + 1):
		var left: int = points[m - 1]
		var center: int = points[m]
		var right: int = points[m + 1]
		var filt := PackedFloat32Array()
		filt.resize(n_bins)
		for k in range(n_bins):
			var val: float = 0.0
			if k >= left and k < center and center > left:
				val = float(k - left) / float(center - left)
			elif k >= center and k <= right and right > center:
				val = float(right - k) / float(right - center)
			filt[k] = val
		filters.append(filt)
	return filters

## Pełny potok: PCM (mono, [-1,1]) -> sekwencja wektorów log-mel.
## Zwraca Array of PackedFloat32Array (każdy długości n_mels).
static func extract(samples: PackedFloat32Array, frame_size: int, hop: int,
		n_mels: int, sample_rate: float, fmin: float, fmax: float) -> Array:
	var window: PackedFloat32Array = hann_window(frame_size)
	var filterbank: Array = mel_filterbank(n_mels, frame_size, sample_rate, fmin, fmax)
	var n_bins: int = frame_size / 2 + 1
	var frames: Array = frame_signal(samples, frame_size, hop)

	var result: Array = []
	for frame in frames:
		# okno + przygotowanie buforów FFT
		var re: Array = []
		var im: Array = []
		re.resize(frame_size)
		im.resize(frame_size)
		for i in range(frame_size):
			re[i] = frame[i] * window[i]
			im[i] = 0.0
		FFT.fft(re, im)

		# widmo mocy (połowa + DC)
		var power: Array = []
		power.resize(n_bins)
		for k in range(n_bins):
			power[k] = re[k] * re[k] + im[k] * im[k]

		# log-mel
		var vec := PackedFloat32Array()
		vec.resize(n_mels)
		for m in range(n_mels):
			var filt: PackedFloat32Array = filterbank[m]
			var energy: float = 0.0
			for k in range(n_bins):
				energy += filt[k] * power[k]
			vec[m] = log(energy + 1e-10)  # log z floor, żeby uniknąć log(0)
		result.append(vec)
	return result
