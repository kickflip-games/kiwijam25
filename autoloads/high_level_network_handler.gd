extends Node

const IP_ADDRESS: String = "127.0.0.1"
const PORT: int = 42069
var peer: ENetMultiplayerPeer

func start_server() -> void:
	peer = ENetMultiplayerPeer.new()
	peer.set_bind_ip(IP_ADDRESS)
	var err := peer.create_server(PORT, 2)  # Allow up to 4 players
	if err != OK:
		push_error("Failed to start ENet server. Error code: %s" % err)
		return
	
	multiplayer.multiplayer_peer = peer
	print("✅ Server started on %s:%d" % [IP_ADDRESS, PORT])
	
	# Server connection event
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func start_client() -> void:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(IP_ADDRESS, PORT)
	if err != OK:
		push_error("Failed to connect as client. Error code: %s" % err)
		return
	
	multiplayer.multiplayer_peer = peer
	print("✅ Client connecting to %s:%d" % [IP_ADDRESS, PORT])
	
	# Client connection events
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func disconnect_peer() -> void:
	if peer:
		peer.close()
		multiplayer.multiplayer_peer = null
		print("🔌 Disconnected from network")

# Debug input handling
func _unhandled_input(event):
	if event.is_action_pressed("ui_accept"):
		start_server()
	elif event.is_action_pressed("ui_select"):
		start_client()
	elif event.is_action_pressed("ui_cancel"):
		disconnect_peer()

func _ready():
	print("🕹 Network handler ready")

# Server events
func _on_peer_connected(id):
	print("🟢 Peer connected: %d" % id)

func _on_peer_disconnected(id):
	print("🔴 Peer disconnected: %d" % id)

# Client events  
func _on_connected_to_server():
	print("🎮 Successfully connected to server")

func _on_connection_failed():
	print("❌ Failed to connect to server")

func _on_server_disconnected():
	print("💔 Server disconnected")
