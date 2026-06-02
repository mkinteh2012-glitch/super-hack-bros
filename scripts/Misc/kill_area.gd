extends Area2D

func _ready() -> void:
	
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("universal_take_damage"):
		
		var detected_id: int = 1
		if "player_id" in body:
			detected_id = body.player_id
		elif "2" in body.name:
			detected_id = 2
			
		print("[DEATH] Player ", detected_id, " crossed the blast zone!")
		_kill_player(body, detected_id)

func _kill_player(player: Node2D, player_id: int) -> void:

	var camera = get_viewport().get_camera_2d()
	if camera and camera.has_method("start_shake"):
		camera.start_shake(25.0, 30.0) 
	
	SignalBus.player_died.emit(player_id)
