# HighLevelNetworkHandler.gd - Updated to handle everything networking
extends Node

const PORT: int = 42222
const MAX_PLAYERS: int = 4
var peer: ENetMultiplayerPeer

# Signals for UI to connect to
signal server_started(success: bool)
signal client_connected(success: bool)
signal client_connection_failed()
signal peer_joined(id: int)
signal peer_left(id: int)
signal server_disconnected()

func start_server(bind_ip: String = "*") -> void:
	peer = ENetMultiplayerPeer.new()
	peer.set_bind_ip(bind_ip)
	var err := peer.create_server(PORT, MAX_PLAYERS)
	
	if err != OK:
		push_error("Failed to start ENet server. Error code: %s" % err)
		server_started.emit(false)
		return

	multiplayer.multiplayer_peer = peer
	print("✅ Server started on %s:%d (Max %d players)" % [bind_ip, PORT, MAX_PLAYERS])
	
	# Connect server-specific signals
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	server_started.emit(true)

func start_client(server_ip: String) -> void:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(server_ip, PORT)
	
	if err != OK:
		push_error("Failed to connect as client. Error code: %s" % err)
		client_connection_failed.emit()
		return

	multiplayer.multiplayer_peer = peer
	print("✅ Client connecting to %s:%d" % [server_ip, PORT])
	
	# Connect client-specific signals
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func disconnect_peer() -> void:
	if peer:
		# Disconnect all signals first
		_disconnect_all_signals()
		
		peer.close()
		multiplayer.multiplayer_peer = null
		peer = null
		print("🔌 Disconnected from network")

func _disconnect_all_signals() -> void:
	# Server signals
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
	
	# Client signals
	if multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.disconnect(_on_connected_to_server)
	if multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.disconnect(_on_connection_failed)
	if multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.disconnect(_on_server_disconnected)

func _ready():
	print("🕹 Network handler ready")

# Server events
func _on_peer_connected(id):
	print("🟢 Peer connected: %d" % id)
	peer_joined.emit(id)

func _on_peer_disconnected(id):
	print("🔴 Peer disconnected: %d" % id)
	peer_left.emit(id)

# Client events  
func _on_connected_to_server():
	print("🎮 Successfully connected to server")
	client_connected.emit(true)

func _on_connection_failed():
	print("❌ Failed to connect to server")
	client_connection_failed.emit()

func _on_server_disconnected():
	print("💔 Server disconnected")
	server_disconnected.emit()

# Utility functions
func is_server() -> bool:
	return multiplayer.is_server()

func is_network_connected() -> bool:
	return peer != null and peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED

func get_unique_id() -> int:
	return multiplayer.get_unique_id()

func get_connected_peers() -> PackedInt32Array:
	return multiplayer.get_peers()

func get_player_count() -> int:
	if not is_network_connected():
		return 0
	return multiplayer.get_peers().size() + 1  # +1 for self
