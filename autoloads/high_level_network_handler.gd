extends Node

const PORT: int = 42069
var peer: ENetMultiplayerPeer

func start_server(bind_ip: String = "*") -> void:
	peer = ENetMultiplayerPeer.new()
	peer.set_bind_ip(bind_ip)
	var err := peer.create_server(PORT, 4)  # Allow up to 4 players
	if err != OK:
		push_error("Failed to start ENet server. Error code: %s" % err)
		return

	multiplayer.multiplayer_peer = peer
	print("✅ Server started on %s:%d" % [bind_ip, PORT])
	
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func start_client(server_ip: String) -> void:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(server_ip, PORT)
	if err != OK:
		push_error("Failed to connect as client. Error code: %s" % err)
		return

	multiplayer.multiplayer_peer = peer
	print("✅ Client connecting to %s:%d" % [server_ip, PORT])
	
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func disconnect_peer() -> void:
	if peer:
		peer.close()
		multiplayer.multiplayer_peer = null
		print("🔌 Disconnected from network")


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
