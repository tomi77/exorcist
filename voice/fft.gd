extends RefCounted
## Iteracyjna FFT radix-2 (Cooley-Tukey), modyfikuje tablice w miejscu.
## re, im: tablice float tej samej długości będącej potęgą dwójki.

static func fft(re: Array, im: Array) -> void:
	var n: int = re.size()
	if n <= 1:
		return

	# Permutacja bit-reversal
	var j: int = 0
	for i in range(1, n):
		var bit: int = n >> 1
		while j & bit:
			j ^= bit
			bit >>= 1
		j ^= bit
		if i < j:
			var tr: float = re[i]
			re[i] = re[j]
			re[j] = tr
			var ti: float = im[i]
			im[i] = im[j]
			im[j] = ti

	# Danielson-Lanczos
	var seg: int = 2
	while seg <= n:
		var ang: float = -2.0 * PI / seg
		var wre: float = cos(ang)
		var wim: float = sin(ang)
		var half: int = seg >> 1
		var start: int = 0
		while start < n:
			var cur_re: float = 1.0
			var cur_im: float = 0.0
			for k in range(half):
				var a: int = start + k
				var b: int = start + k + half
				var tr: float = cur_re * float(re[b]) - cur_im * float(im[b])
				var ti: float = cur_re * float(im[b]) + cur_im * float(re[b])
				re[b] = float(re[a]) - tr
				im[b] = float(im[a]) - ti
				re[a] = float(re[a]) + tr
				im[a] = float(im[a]) + ti
				var n_re: float = cur_re * wre - cur_im * wim
				cur_im = cur_re * wim + cur_im * wre
				cur_re = n_re
			start += seg
		seg <<= 1
