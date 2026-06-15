extends RefCounted
## Czysta kinematyka platformówki — statyczne funkcje nad skalarami.
## Brak zależności od sceny, węzłów i Input. Oś Y rośnie w dół (skok = ujemne Y).

## Prędkość pionowa po jednym kroku grawitacji, ograniczona prędkością graniczną.
static func apply_gravity(vy: float, gravity: float, max_fall: float, delta: float) -> float:
	return min(vy + gravity * delta, max_fall)

## Prędkość pozioma po jednym kroku: przy wejściu dąży do prędkości docelowej
## (input_dir w [-1,1]) z przyspieszeniem accel; bez wejścia wytraca się tarciem
## do zera. move_toward gwarantuje brak przeskoku poza cel.
static func apply_horizontal(vx: float, input_dir: float, run_speed: float,
		accel: float, friction: float, delta: float) -> float:
	if input_dir != 0.0:
		var target := input_dir * run_speed
		return move_toward(vx, target, accel * delta)
	return move_toward(vx, 0.0, friction * delta)

## Czy skok jest dozwolony: na ziemi lub w aktywnym oknie coyote.
static func can_jump(on_floor: bool, coyote_timer: float) -> bool:
	return on_floor or coyote_timer > 0.0

## Prędkość pionowa nadawana przy starcie skoku (ujemna = w górę).
static func start_jump(jump_speed: float) -> float:
	return -jump_speed

## Przycięcie skoku przy puszczeniu przycisku: skraca tylko ruch w górę
## (ujemne Y); ruch w dół pozostaje bez zmian.
static func cut_jump(vy: float, cut_factor: float) -> float:
	if vy < 0.0:
		return vy * cut_factor
	return vy
