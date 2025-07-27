extends MultiplayerSpawner
@export var network_player: PackedScene
var spawned_players: Dictionary = {}
var spawned_data: Dictionary = {}

func _ready() -> void:
	# Connect signals first
	multiplayer.peer_connected.connect(spawn_player)
	multiplayer.peer_disconnected.connect(despawn_player)

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
	var spawn_index = spawned_players.size() % 4
	var pdata = PlayerData.new(spawn_index)
	player.name = str(id)
	
	print("🎮 Creating player %d with position: %s, color: %s" % [spawn_index, pdata.spawn_position, pdata.color])
	# Add to scene
	var parent: Node = get_node(spawn_path)
	parent.add_child(player, true) 
	
	spawned_players[id] = player
	spawned_data[id] = pdata
	
	# INIT this player's data on their own client
	player.rpc_id(id, "init_player", pdata.to_dict())
	
	# Tell all *other* clients about this new player
	for peer_id in spawned_players:
		if peer_id != id:
			player.rpc_id(peer_id, "init_player", pdata.to_dict())
	
	print("✅ Spawned player %d at %s" % [id, player.global_position])
	print("COLLECTED DATA: ", spawned_data)
	
	set_player_authority(player, id)
	player.rpc_id(id, "init_authority_vars")
	
	
	
	

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
