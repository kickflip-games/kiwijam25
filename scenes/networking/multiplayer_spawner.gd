extends MultiplayerSpawner
@export var network_player: PackedScene
var spawned_players: Dictionary = {}
var player_scores: Dictionary = {}


signal scores_updated_event(scores_dict:Dictionary)




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
	
	var player = network_player.instantiate()
	player.name = str(id)
	var spawn_index = spawned_players.size() % 4
	
	# Create PlayerData
	var pdata = PlayerData.new(id)
	
	print("🎮 Creating player %d with position: %s, color: %s" % [id, pdata.spawn_position, pdata.color])
	
	
	# Add to scene
	var parent = get_node(spawn_path)
	parent.add_child(player, true)  # Force readable name
	
	# Set authority after the node is in the scene tree
	call_deferred("set_player_authority", player, id)
	
	# Track spawned players
	spawned_players[id] = player
	player_scores[id] = 0
	player.position = pdata.spawn_position
	player.player_shot_successful.connect(increase_score)
	
	
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




@rpc("any_peer")
func increase_score(player_id:int):
	player_scores[player_id] += 100
	print("increase %d's score " % player_id)
	print(player_scores)
	spawned_players[player_id].increase_score()
	scores_updated_event.emit(player_scores)
