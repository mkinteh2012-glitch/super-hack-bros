extends Area2D

var players_inside: Array[CharacterBody2D] = []
var damage_timer: Timer

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Handle the 1-second interval loop
	damage_timer = Timer.new()
	damage_timer.wait_time = 1.0
	damage_timer.autostart = false
	damage_timer.timeout.connect(_on_damage_tick)
	add_child(damage_timer)

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("universal_take_damage") and not players_inside.has(body):
		players_inside.append(body)
		if damage_timer.is_stopped():
			damage_timer.start()
			_apply_tick_damage_to_all()

func _on_body_exited(body: Node2D) -> void:
	if players_inside.has(body):
		players_inside.erase(body)
		if players_inside.is_empty():
			damage_timer.stop()

func _on_damage_tick() -> void:
	_apply_tick_damage_to_all()

func _apply_tick_damage_to_all() -> void:
	for player in players_inside:
		if is_instance_valid(player):
			player.universal_take_damage(1.0, 0.0, 0.0, 0.0, 0.0)
			var camera = get_viewport().get_camera_2d()
			if camera and camera.has_method("start_shake"):
				camera.start_shake(5.0, 30.0) 
