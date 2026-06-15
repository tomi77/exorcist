extends Node2D
## Okablowanie poziomu: respawn po śmierci, ukończenie na markerze.
## Pułapki i kill-plane są w grupie "hazard" (Area2D). Marker końca: %EndMarker.

signal level_completed

@onready var _player: CharacterBody2D = %Player
@onready var _start: Marker2D = %StartPoint
@onready var _end_label: Label = %EndLabel

func _ready() -> void:
	_end_label.visible = false
	_player.global_position = _start.global_position
	_player.died.connect(_on_player_died)
	for hazard in get_tree().get_nodes_in_group("hazard"):
		hazard.body_entered.connect(_on_hazard_entered)
	%EndMarker.body_entered.connect(_on_end_entered)

func _on_hazard_entered(body: Node) -> void:
	if body == _player:
		_player.die()

func _on_player_died() -> void:
	_player.velocity = Vector2.ZERO
	_player.global_position = _start.global_position

func _on_end_entered(body: Node) -> void:
	if body == _player:
		emit_signal("level_completed")
		_end_label.visible = true
