extends Area2D

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	# 🌐 NETWORK RULE: Only the server calculates blast zone deaths to prevent de-sync splits
	if GlobalGameData.online and not multiplayer.is_server():
		return

	if body.has_method("universal_take_damage"):
		var detected_id: int = 1
		if "player_id" in body:
			detected_id = body.player_id
		elif "2" in body.name:
			detected_id = 2
			
		print("[DEATH] Player ", detected_id, " crossed the blast zone!")
		_kill_player(detected_id)

func _kill_player(player_id: int) -> void:
	_trigger_death_effects()
	
	if GlobalGameData.online:
		# Tell the remote client to trigger death visuals too
		rpc("_rpc_client_death_visuals", player_id)
		
	# Fire the signal! The StockManager will catch this and handle the lives math
	SignalBus.player_died.emit(player_id)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_client_death_visuals(_dead_player_id: int) -> void:
	_trigger_death_effects()
	# Client fires local signal so their local StockManager runs the visual death/respawn timers too
	SignalBus.player_died.emit(_dead_player_id)

func _trigger_death_effects() -> void:
	var camera = get_viewport().get_camera_2d()
	if camera and camera.has_method("start_shake"):
		camera.start_shake(25.0, 30.0)
