# SimpleLobbyManager.gd - UI only, no networking logic
extends Control

# UI References
@onready var ip_entry = $VBoxContainer/IPEntry
@onready var server_button = $VBoxContainer/HBoxContainer/ServerButton
@onready var join_button = $VBoxContainer/HBoxContainer/JoinButton
@onready var start_game_button = $VBoxContainer/StartGameButton
@onready var player_list = $PlayerList
@onready var status_label = $StatusLabel

# Player data
var connected_players: Dictionary = {}
var is_host: bool = false


# Game scene path
@export var game_scene_path: String = "res://scenes/Main.tscn"

func _ready():
	_setup_ui()
	_connect_signals()
	ip_entry.text = _get_local_ip()

func _setup_ui():
	start_game_button.visible = false
	start_game_button.disabled = true

func _connect_signals():
	# UI button signals
	server_button.pressed.connect(_on_server_button_pressed)
	join_button.pressed.connect(_on_join_button_pressed)
	start_game_button.pressed.connect(_on_start_game_button_pressed)
	
	# Network handler signals
	NetworkHandler.server_started.connect(_on_server_started)
	NetworkHandler.client_connected.connect(_on_client_connected)
	NetworkHandler.client_connection_failed.connect(_on_client_connection_failed)
	NetworkHandler.peer_joined.connect(_on_peer_joined)
	NetworkHandler.peer_left.connect(_on_peer_left)
	NetworkHandler.server_disconnected.connect(_on_server_disconnected)

func _get_local_ip() -> String:
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.") or ip.begins_with("10.") or ip.begins_with("172."):
			return ip
	return "127.0.0.1"

func _get_ip() -> String:
	var ip = ip_entry.text.strip_edges()
	if ip == "":
		_update_status("❌ IP address is empty!", Color.RED)
		return ""
	return ip

# Button handlers
func _on_server_button_pressed():
	var ip = _get_ip()
	if ip:
		_update_status("🔄 Starting server...", Color.YELLOW)
		NetworkHandler.start_server(ip)

func _on_join_button_pressed():
	var ip = _get_ip()
	if ip:
		_update_status("🔄 Connecting to server...", Color.YELLOW)
		NetworkHandler.start_client(ip)

func _on_start_game_button_pressed():
	if is_host and connected_players.size() >= 2:
		_start_game.rpc()
		$VBoxContainer.visible = false

# Network event handlers from NetworkHandler signals
func _on_server_started(success: bool):
	if success:
		is_host = true
		_add_local_player()
		_update_ui_for_host()
		_update_status("🎮 Server started!", Color.GREEN)
		$VBoxContainer.visible = false
		status_label.visible = true
		
	else:
		_update_status("❌ Failed to start server", Color.RED)

func _on_client_connected(success: bool):
	if success:
		is_host = false
		_add_local_player()
		_update_ui_for_client()
		_update_status("✅ Connected!", Color.GREEN)
		
		# Send player info to host
		var local_name = "Player_" + str(NetworkHandler.get_unique_id())
		_add_player.rpc_id(1, NetworkHandler.get_unique_id(), local_name)

func _on_client_connection_failed():
	_update_status("❌ Failed to connect to server", Color.RED)

func _on_peer_joined(id: int):
	print("🟢 Player joined: %d" % id)
	if is_host:
		_sync_players.rpc()
	_update_player_list()

func _on_peer_left(id: int):
	print("🔴 Player left: %d" % id)
	if id in connected_players:
		connected_players.erase(id)
	_update_player_list()

func _on_server_disconnected():
	_reset_lobby()
	_update_status("💔 Server disconnected", Color.RED)

# Player management
func _add_local_player():
	var local_id = NetworkHandler.get_unique_id()
	var local_name = "Host" if is_host else "Player_" + str(local_id)
	connected_players[local_id] = local_name
	_update_player_list()

@rpc("any_peer", "call_local")
func _add_player(id: int, name: String):
	connected_players[id] = name
	_update_player_list()

@rpc("authority", "call_local")
func _sync_players():
	# Host sends current player list to new client
	for player_id in connected_players:
		_add_player.rpc(player_id, connected_players[player_id])

@rpc("authority", "call_local")
func _start_game():
	_update_status("🚀 Starting game...", Color.CYAN)
	get_tree().change_scene_to_file(game_scene_path)

# UI updates
func _update_ui_for_host():
	server_button.visible = false
	join_button.visible = false
	start_game_button.visible = true
	ip_entry.editable = false
	status_label.visible = true
	player_list.visible = false
	$VBoxContainer.visible = false

func _update_ui_for_client():
	server_button.visible = false
	join_button.visible = false
	ip_entry.editable = false
	status_label.visible = true
	player_list.visible = false
	
	get_parent().get_node("CanvasLayer").visible = false
	

func _reset_lobby():
	# Reset to initial state
	connected_players.clear()
	is_host = false
	server_button.visible = true
	join_button.visible = true
	start_game_button.visible = false
	ip_entry.editable = true
	_update_player_list()

func _update_status(message: String, color: Color = Color.WHITE):
	status_label.text = message
	status_label.modulate = color

func _update_player_list():
	player_list.clear()
	
	# Add header
	var header = player_list.create_item()
	header.set_text(0, "Players (%d/4)" % connected_players.size())
	header.set_custom_color(0, Color.YELLOW)
	
	# Add each player
	for player_id in connected_players:
		var item = player_list.create_item()
		var player_name = connected_players[player_id]
		
		# Add crown for host
		if player_id == 1:
			player_name += " 👑"
			item.set_custom_color(0, Color.GOLD)
		else:
			item.set_custom_color(0, Color.WHITE)
		
		item.set_text(0, player_name)
	
	# Update start button
	if is_host:
		start_game_button.disabled = connected_players.size() < 2

# Get player data for spawner
func get_connected_players() -> Dictionary:
	return connected_players
