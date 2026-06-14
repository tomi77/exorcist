extends RefCounted
## Dynamic Time Warping między dwiema sekwencjami wektorów cech.

## Odległość euklidesowa między dwoma wektorami cech.
static func _dist(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	var s := 0.0
	for i in range(a.size()):
		var d := a[i] - b[i]
		s += d * d
	return sqrt(s)

## Zwraca słownik {distance: float, steps: int}:
##   distance — całkowity koszt optymalnego dopasowania,
##   steps    — długość ścieżki dopasowania (do normalizacji).
static func distance(seq_a: Array, seq_b: Array) -> Dictionary:
	var n := seq_a.size()
	var m := seq_b.size()
	if n == 0 or m == 0:
		return {"distance": INF, "steps": 0}

	# macierz kosztów (n+1) x (m+1), wypełniona INF, [0][0] = 0
	var cost := []
	var path := []  # liczba kroków na optymalnej ścieżce do danej komórki
	for i in range(n + 1):
		var row := []
		var prow := []
		for j in range(m + 1):
			row.append(INF)
			prow.append(0)
		cost.append(row)
		path.append(prow)
	cost[0][0] = 0.0

	for i in range(1, n + 1):
		for j in range(1, m + 1):
			var d := _dist(seq_a[i - 1], seq_b[j - 1])
			# wybierz najtańszego poprzednika: ukos / góra / lewo
			var best: float = cost[i - 1][j - 1]
			var best_steps: int = path[i - 1][j - 1]
			if cost[i - 1][j] < best:
				best = cost[i - 1][j]
				best_steps = path[i - 1][j]
			if cost[i][j - 1] < best:
				best = cost[i][j - 1]
				best_steps = path[i][j - 1]
			cost[i][j] = d + best
			path[i][j] = best_steps + 1

	return {"distance": cost[n][m], "steps": path[n][m]}
