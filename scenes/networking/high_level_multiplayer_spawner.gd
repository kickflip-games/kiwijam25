extends MultiplayerSpawner

@export var network_player: PackedScene
var spawned_players: Dictionary = {}

func _ready() -> void:
	# Connect signals first
	multiplayer.peer_connected.connect(spawn_player)
	multiplayer.peer_disconnected.connect(despawn_player)
	
	# If we're the server, spawn the server player
	if multiplayer.is_server():
		# Wait a frame to ensure everything is ready
		call_deferred("spawn_server_player")

func spawn_server_player() -> void:
	spawn_player(1)  # Server always has ID 1

func spawn_player(id: int) -> void:
	if not multiplayer.is_server():
		return
	
	# Prevent duplicate spawning
	if id in spawned_players:
		print("⚠️ Player %d already spawned" % id)
		return
	
	var player: Node = network_player.instantiate()
	player.name = str(id)
	
	# Set spawn position before adding to scene
	var spawn_positions = [
		Vector2(100, 100),
		Vector2(-100, 100),
		Vector2(100, -100),
		Vector2(-100, -100)
	]
	var spawn_index = spawned_players.size() % spawn_positions.size()
	player.global_position = spawn_positions[spawn_index]
	
	# Add to scene first, then set authority
	var parent: Node = get_node(spawn_path)
	parent.add_child(player, true)  # Force readable name
	
	# Set authority after the node is in the scene tree
	call_deferred("set_player_authority", player, id)
	
	# Track spawned players
	spawned_players[id] = player
	
	print("✅ Spawned player %d at %s" % [id, player.global_position])

func set_player_authority(player: Node, id: int) -> void:
	player.set_multiplayer_authority(id)
	print("🔑 Set authority for player %d" % id)

func despawn_player(id: int) -> void:
	if not multiplayer.is_server():
		return
	
	if id in spawned_players:
		spawned_players[id].queue_free()
		spawned_players.erase(id)
		print("🗑️ Despawned player %d" % id)
