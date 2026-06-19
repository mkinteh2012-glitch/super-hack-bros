extends Control

# --- 🎨 VISUAL THEME CONFIGURATION ---
var COLOR_TITLE: Color = Color.WHITE
var COLOR_STATUS_DEFAULT: Color = Color.from_string("#ffffff", Color.WHITE)
var COLOR_STATUS_SEARCHING: Color = Color.from_string("#ffaa00", Color.ORANGE)
var COLOR_STATUS_CONNECTED: Color = Color.from_string("#00ff66", Color.GREEN)
var COLOR_STATUS_READY_PUBLIC: Color = Color.from_string("#00ffaa", Color.SPRING_GREEN)
var COLOR_STATUS_READY_PRIVATE: Color = Color.from_string("#ffd700", Color.GOLD)

# --- 🎯 DIRECT NODE SCENE MAPPING ---
@onready var title_label: Label = $Label
@onready var mode_label: Label = $Label2          
@onready var status_label: Label = $Label3        
@onready var mode_indicator_label: Label = $Label4 
@onready var action_button: Button = $Button

# --- 🏷️ PRIVATE SERVER NODE REFERENCES ---
@onready var password_container: HBoxContainer = $HBoxContainer
@onready var password_label: Label = $HBoxContainer/Label
@onready var password_edit: LineEdit = $HBoxContainer/LineEdit

# --- 🌐 LIVE SUPABASE CONFIG ---
const SUPABASE_URL = "https://drtecvqbghvmpjpjbmqs.supabase.co"
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRydGVjdnFiZ2h2bXBqcGpibXFzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA3Nzk3MTEsImV4cCI6MjA5NjM1NTcxMX0.USosgC_tALvdHzzDo3IkB1laLa3PygOY8CQf-_NJ1vk"
const PORT = 23516

var http_client: HTTPRequest
var peer: ENetMultiplayerPeer = null
var seconds_remaining: int = 120
var secondary_timer: Timer
var is_host_instance: bool = false
var force_client_mode: bool = false
var local_public_ip: String = ""

var current_match_connection_id: int = 0

const DEVELOPER_MODE: bool = false

func _ready() -> void:
	GlobalGameData.online = false
	
	if "--client-test" in OS.get_cmdline_args():
		force_client_mode = true
		
	_apply_visual_styling()
	_apply_custom_theme()
	_setup_password_input()
	
	if GlobalGameData.target_room_is_public:
		GlobalGameData.room_pass = ""
		if password_container: password_container.visible = false 
		action_button.grab_focus()
	else:
		if password_container: password_container.visible = true  
		if password_edit: password_edit.grab_focus()
		
	_update_room_type_ui()
	
	action_button.pressed.connect(_on_matchmaking_pressed)
	_setup_native_network_nodes()


func _apply_custom_theme() -> void:
	title_label.add_theme_font_size_override("font_size", 42)
	status_label.add_theme_font_size_override("font_size", 20)
	mode_label.add_theme_font_size_override("font_size", 16)
	mode_indicator_label.add_theme_font_size_override("font_size", 16)
	action_button.add_theme_font_size_override("font_size", 24)
	
	title_label.modulate = COLOR_TITLE
	status_label.modulate = COLOR_STATUS_DEFAULT


func _apply_visual_styling() -> void:
	title_label.text = "SUPER HACK BROS"
	action_button.text = "FIND A CHALLENGER"
	status_label.text = "Ready to connect..."
	if password_label: password_label.text = "ENTER 4-DIGIT ROOM CODE: "


func _setup_password_input() -> void:
	if password_edit:
		password_edit.placeholder_text = "0000"
		password_edit.max_length = 4
		password_edit.text_changed.connect(_on_password_text_changed)


func _on_password_text_changed(new_text: String) -> void:
	var regex = RegEx.new()
	regex.compile("[^0-9]")
	var clean_text = regex.sub(new_text, "", true)
	if new_text != clean_text:
		password_edit.text = clean_text
	GlobalGameData.room_pass = password_edit.text
	_update_room_type_ui()
	if password_edit.text.length() == 4:
		action_button.grab_focus()


func _update_room_type_ui() -> void:
	if mode_label: mode_label.visible = true
	if mode_indicator_label: mode_indicator_label.visible = true
	
	if GlobalGameData.target_room_is_public:
		mode_label.text = "MODE: PUBLIC MATCHMAKING"
		mode_label.modulate = Color.LIGHT_BLUE
		status_label.text = "READY TO SEARCH"
		status_label.modulate = COLOR_STATUS_READY_PUBLIC
		mode_indicator_label.text = "Press button below to search open player queues"
		mode_indicator_label.modulate = Color.DARK_GRAY
	else:
		mode_label.text = "MODE: PRIVATE ROOM CONNECTOR"
		mode_label.modulate = Color.LIGHT_BLUE
		if GlobalGameData.room_pass.length() < 4:
			status_label.text = "Awaiting Private Room Code Entry..."
			status_label.modulate = Color.LIGHT_GRAY
			mode_indicator_label.text = "Enter your 4-digit token to secure entry"
			mode_indicator_label.modulate = Color.DARK_GRAY
		else:
			status_label.text = "READY TO ENGAGE"
			status_label.modulate = COLOR_STATUS_READY_PRIVATE
			mode_indicator_label.text = "Locked to Room Token: " + GlobalGameData.room_pass
			mode_indicator_label.modulate = COLOR_STATUS_READY_PRIVATE


func _setup_native_network_nodes() -> void:
	http_client = HTTPRequest.new()
	add_child(http_client)
	http_client.request_completed.connect(_on_api_response_received)
	
	secondary_timer = Timer.new()
	secondary_timer.wait_time = 1.0
	secondary_timer.timeout.connect(_on_countdown_tick)
	add_child(secondary_timer)


func _on_matchmaking_pressed() -> void:
	if password_edit: password_edit.editable = false
	action_button.disabled = true
	seconds_remaining = 120
	secondary_timer.start()
	
	# Fetch IP first to handle localhost resolution dynamically
	var ip_fetcher = HTTPRequest.new()
	add_child(ip_fetcher)
	ip_fetcher.request_completed.connect(func(r, rc, h, b):
		local_public_ip = b.get_string_from_utf8().strip_edges()
		ip_fetcher.queue_free()
		_query_matchmaking_lobby()
	)
	ip_fetcher.request("https://api.ipify.org")


func _query_matchmaking_lobby() -> void:
	var time_now = Time.get_unix_time_from_system()
	var time_two_minutes_ago = time_now - 120
	var datetime_dict = Time.get_datetime_dict_from_unix_time(time_two_minutes_ago)
	var timestamp_filter = "%04d-%02d-%02dT%02d:%02d:%02dZ" % [
		datetime_dict.year, datetime_dict.month, datetime_dict.day,
		datetime_dict.hour, datetime_dict.minute, datetime_dict.second
	]
	
	var url = SUPABASE_URL + "/rest/v1/lobby?select=*&created_at=gte." + timestamp_filter.uri_encode() + "&order=id.asc&limit=1"
	
	if not GlobalGameData.target_room_is_public:
		if GlobalGameData.room_pass.length() < 4:
			status_label.text = "❌ Error: Code must be 4 digits!"
			status_label.modulate = Color.DARK_RED
			_reset_menu_ui()
			return
		url += "&room_password=eq." + GlobalGameData.room_pass.uri_encode()
		status_label.text = "Checking private code..."
	else:
		url += "&room_password=is.null"
		status_label.text = "Searching for an opponent..."
		
	status_label.modulate = COLOR_STATUS_SEARCHING
	var headers = ["apikey: " + SUPABASE_ANON_KEY, "Authorization: Bearer " + SUPABASE_ANON_KEY]
	http_client.request(url, headers, HTTPClient.METHOD_GET)


func _on_api_response_received(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var response_text = body.get_string_from_utf8().strip_edges()
	
	if response_code != 200 or response_text == "" or response_text == "[]":
		_pivot_to_host()
		return
		
	var json_data = JSON.parse_string(response_text)
	if typeof(json_data) == TYPE_ARRAY and json_data.size() > 0:
		var target_host_ip = json_data[0]["host_ip"]
		current_match_connection_id = int(json_data[0]["connection_id"])
		
		# 🏠 LOCAL MATCH LOOPBACK FIX
		if target_host_ip == local_public_ip or local_public_ip == "":
			print("[NET] Loopback match verified. Routing connection through localhost.")
			target_host_ip = "127.0.0.1"
			
		_connect_to_internet_host(target_host_ip)
	else:
		_pivot_to_host()


func _pivot_to_host() -> void:
	status_label.text = "Hosting match room..."
	is_host_instance = true
	
	var my_ip = local_public_ip if local_public_ip != "" else "127.0.0.1"
	
	if GlobalGameData.target_room_is_public:
		current_match_connection_id = randi_range(10000, 99999)
	else:
		current_match_connection_id = int(GlobalGameData.room_pass)
		
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(PORT, 1)
	
	# Safety check for port binding collision
	if err != OK:
		print("[NET] Port conflict! Server already hosted here. Switching to Client mode...")
		is_host_instance = false
		_connect_to_internet_host("127.0.0.1")
		return
		
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	var payload_dict: Dictionary = {
		"host_ip": my_ip,
		"connection_id": current_match_connection_id,
		"room_password": null if GlobalGameData.target_room_is_public else GlobalGameData.room_pass
	}
	
	var data_payload = JSON.stringify(payload_dict)
	var url = SUPABASE_URL + "/rest/v1/lobby"
	var headers = [
		"apikey: " + SUPABASE_ANON_KEY,
		"Authorization: Bearer " + SUPABASE_ANON_KEY,
		"Content-Type: application/json"
	]
	
	var post_client = HTTPRequest.new()
	add_child(post_client)
	post_client.request_completed.connect(func(r, rc, h, b): post_client.queue_free())
	post_client.request(url, headers, HTTPClient.METHOD_POST, data_payload)
	
	status_label.text = "LOBBY OPEN"
	mode_indicator_label.text = "Waiting for a challenger to connect..."
	status_label.modulate = COLOR_STATUS_CONNECTED
	mode_indicator_label.modulate = COLOR_STATUS_CONNECTED


func _connect_to_internet_host(target_ip: String) -> void:
	is_host_instance = false
	peer = ENetMultiplayerPeer.new()
	
	var error = peer.create_client(target_ip, PORT)
	if error != OK:
		status_label.text = "Connection failed. Retrying..."
		_reset_menu_ui()
		return
		
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	status_label.text = "Synchronizing..."
	mode_indicator_label.text = "Connecting to player hub..."
	status_label.modulate = Color.CYAN


func _on_peer_connected(id: int) -> void:
	GlobalGameData.online = true
	_force_online_default_settings()
	NetworkManager.start_heartbeat_watchdog()
	
	if multiplayer.is_server():
		GlobalGameData.P1 = str(multiplayer.get_unique_id())
		GlobalGameData.P2 = str(id)                         
	else:
		GlobalGameData.P1 = str(multiplayer.get_activated_mode_authority_id() if multiplayer.has_method("get_activated_mode_authority_id") else 1)
		GlobalGameData.P2 = str(multiplayer.get_unique_id())
	
	if is_host_instance:
		var url = SUPABASE_URL + "/rest/v1/lobby?connection_id=eq." + str(current_match_connection_id)
		var headers = ["apikey: " + SUPABASE_ANON_KEY, "Authorization: Bearer " + SUPABASE_ANON_KEY]
		var delete_client = HTTPRequest.new()
		add_child(delete_client)
		delete_client.request(url, headers, HTTPClient.METHOD_DELETE)
		
	secondary_timer.stop()
	status_label.text = "SUCCESS"
	mode_indicator_label.text = "Challenger found! Synchronizing level data..."
	status_label.modulate = COLOR_STATUS_CONNECTED
	
	await get_tree().create_timer(1.2).timeout
	get_tree().change_scene_to_file("res://scenes/UI/SelectMenu.tscn")


func _force_online_default_settings() -> void:
	GlobalGameData.match_stocks = 3
	GlobalGameData.stage_hazards_enabled = true
	GlobalGameData.damage_multiplier = 1.0
	GlobalGameData.character_size_multiplier = 1.0


func _on_peer_disconnected(_id: int) -> void:
	if not NetworkManager.is_match_active:
		GlobalGameData.online = false
		NetworkManager._trigger_global_disconnect_fallback()


func _on_countdown_tick() -> void:
	seconds_remaining -= 1
	if action_button.disabled and (status_label.text.begins_with("Searching") or status_label.text.begins_with("Connecting")):
		mode_indicator_label.text = "Searching player queues... (" + str(seconds_remaining) + "s)"
		
	if seconds_remaining <= 0:
		_clear_network_elements()
		status_label.text = "TIMEOUT"
		mode_indicator_label.text = "No opponents discovered. Try again!"
		status_label.modulate = Color.INDIAN_RED
		_reset_menu_ui()


func _reset_menu_ui() -> void:
	secondary_timer.stop()
	action_button.disabled = false
	action_button.grab_focus()
	if password_edit: password_edit.editable = true
	if not GlobalGameData.target_room_is_public and password_container:
		password_container.visible = true
	_update_room_type_ui()


func _clear_network_elements() -> void:
	GlobalGameData.online = false
	if is_host_instance:
		var url = SUPABASE_URL + "/rest/v1/lobby?connection_id=eq." + str(current_match_connection_id)
		var headers = ["apikey: " + SUPABASE_ANON_KEY, "Authorization: Bearer " + SUPABASE_ANON_KEY]
		var delete_client = HTTPRequest.new()
		add_child(delete_client)
		delete_client.request(url, headers, HTTPClient.METHOD_DELETE)
		
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
		
	if is_instance_valid(peer):
		peer.close()
	peer = null
	if is_instance_valid(multiplayer):
		multiplayer.multiplayer_peer = null


func _exit_tree() -> void:
	if not NetworkManager.is_match_active:
		_clear_network_elements()
