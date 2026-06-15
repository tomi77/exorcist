extends CharacterBody2D
## Integracja: Input -> czyste funkcje kinematyki -> move_and_slide().
## Prototyp używa wbudowanych akcji ui_left / ui_right / ui_accept.

const Movement = preload("res://player/movement.gd")

const RUN_SPEED: float = 300.0
const ACCEL: float = 2000.0
const FRICTION: float = 2500.0
const GRAVITY: float = 1200.0
const MAX_FALL: float = 1400.0
const JUMP_SPEED: float = 520.0
const COYOTE_TIME: float = 0.1
const JUMP_CUT: float = 0.4

signal died

var _coyote_timer := 0.0

func _physics_process(delta: float) -> void:
	# is_on_floor() sprzed move_and_slide() — celowe: w klatce zejścia z krawędzi
	# licznik coyote startuje dopiero od następnej klatki (pełne okno COYOTE_TIME).
	var on_floor := is_on_floor()
	_coyote_timer = Movement.tick_coyote(_coyote_timer, on_floor, COYOTE_TIME, delta)

	var input_dir := Input.get_axis("ui_left", "ui_right")
	velocity.x = Movement.apply_horizontal(velocity.x, input_dir, RUN_SPEED, ACCEL, FRICTION, delta)
	velocity.y = Movement.apply_gravity(velocity.y, GRAVITY, MAX_FALL, delta)

	if Input.is_action_just_pressed("ui_accept") and Movement.can_jump(on_floor, _coyote_timer):
		velocity.y = Movement.start_jump(JUMP_SPEED)
		_coyote_timer = 0.0
	if Input.is_action_just_released("ui_accept"):
		velocity.y = Movement.cut_jump(velocity.y, JUMP_CUT)

	move_and_slide()

## Wywoływane przez poziom przy kontakcie z pułapką / kill-plane.
func die() -> void:
	emit_signal("died")
