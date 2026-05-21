extends Area2D

func _ready() -> void:
	pass
	
func _on_body_entered(body: Node2D) -> void:
	if body.has_method("universal_take_damage"):
		print("[DEATH] Player ", body.player_id, " crossed the blast zone!")
		_kill_player(body)

func _kill_player(player: CharacterBody2D) -> void:
	var camera = get_viewport().get_camera_2d()
	if camera and camera.has_method("start_shake"):
		camera.start_shake(25.0, 30.0) 
	player.queue_free()
