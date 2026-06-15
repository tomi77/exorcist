extends GutTest

const Movement = preload("res://player/movement.gd")

func test_gravity_increases_fall_speed():
	# vy=0, grawitacja 1000 px/s^2, krok 0.1 s -> 100 px/s w dół
	assert_almost_eq(Movement.apply_gravity(0.0, 1000.0, 2000.0, 0.1), 100.0, 0.0001)

func test_gravity_clamped_to_max_fall():
	# blisko limitu: 1950 + 1000*0.1 = 2050, ale limit 2000
	assert_almost_eq(Movement.apply_gravity(1950.0, 1000.0, 2000.0, 0.1), 2000.0, 0.0001)

func test_horizontal_accelerates_toward_target():
	# vx=0, kierunek +1, prędkość docelowa 300, accel 3000, krok 0.05 -> +150
	var vx := Movement.apply_horizontal(0.0, 1.0, 300.0, 3000.0, 3000.0, 0.05)
	assert_almost_eq(vx, 150.0, 0.0001)

func test_horizontal_does_not_overshoot_target():
	# już blisko docelowej: 290 + accel*dt by przekroczyło 300 -> clamp do 300
	var vx := Movement.apply_horizontal(290.0, 1.0, 300.0, 3000.0, 3000.0, 0.05)
	assert_almost_eq(vx, 300.0, 0.0001)

func test_horizontal_friction_stops_at_zero_without_overshoot():
	# brak wejścia (dir 0): tarcie sprowadza do 0 i nie przeskakuje poniżej
	var vx := Movement.apply_horizontal(150.0, 0.0, 300.0, 3000.0, 3000.0, 0.1)
	assert_almost_eq(vx, 0.0, 0.0001)

func test_can_jump_on_floor():
	assert_true(Movement.can_jump(true, 0.0))

func test_can_jump_within_coyote_window():
	assert_true(Movement.can_jump(false, 0.05))

func test_cannot_jump_in_air_after_coyote():
	assert_false(Movement.can_jump(false, 0.0))

func test_start_jump_sets_upward_velocity():
	# skok = ujemna prędkość Y (w górę)
	assert_almost_eq(Movement.start_jump(600.0), -600.0, 0.0001)

func test_cut_jump_reduces_rising_velocity():
	# wznoszenie (ujemne Y) przycięte mnożnikiem
	assert_almost_eq(Movement.cut_jump(-600.0, 0.5), -300.0, 0.0001)

func test_cut_jump_ignores_falling():
	# opadanie (dodatnie Y) nietknięte
	assert_almost_eq(Movement.cut_jump(200.0, 0.5), 200.0, 0.0001)
