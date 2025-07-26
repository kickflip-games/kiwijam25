extends Node2D

@export var cloud_scenes: Array[PackedScene] = []
@export var spawn_count: int = 5
@export var spawn_area: Vector2 = Vector2(800, 600)
@export var cloud_min_scale: float = 0.8
@export var cloud_max_scale: float = 1.5
@export var spawn_delay_min: float = 0.2
@export var spawn_delay_max: float = 1.0
@export var random_seed: int = 14445  # Set same seed for all clients

var has_spawned: bool = false

func _ready():
	# Wait for multiplayer to be properly set up
	if multiplayer.has_multiplayer_peer():
		_check_and_spawn()
	else:
		# Wait for multiplayer connection if not ready
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.connected_to_server.connect(_on_connected_to_server)

func _on_peer_connected(id: int):
	_check_and_spawn()

func _on_connected_to_server():
	_check_and_spawn()

func _check_and_spawn():
	# Only spawn once and only on the actual server/host
	if not has_spawned and multiplayer.is_server():
		has_spawned = true
		spawn_clouds()

# Alternative: Call this manually from your main game scene after multiplayer setup
func initialize_clouds():
	if multiplayer.is_server() and not has_spawned:
		has_spawned = true
		spawn_clouds()

@rpc("any_peer", "call_local", "reliable")
func spawn_cloud_at(scene_index: int, pos: Vector2, scale_factor: float, cloud_id: int):
	if cloud_scenes.size() > scene_index:
		var cloud = cloud_scenes[scene_index].instantiate()
		cloud.position = pos
		cloud.scale = Vector2(scale_factor, scale_factor)
		cloud.name = "Cloud_" + str(cloud_id)  # Consistent naming
		add_child(cloud)

func spawn_clouds():
	# Use consistent seed for deterministic randomness
	var rng = RandomNumberGenerator.new()
	rng.seed = random_seed
	
	for i in spawn_count:
		if cloud_scenes.size() > 0:
			# Generate deterministic values
			var scene_index = rng.randi() % cloud_scenes.size()
			var pos = Vector2(
				rng.randf() * spawn_area.x,
				rng.randf() * spawn_area.y
			)
			var scale_factor = rng.randf_range(cloud_min_scale, cloud_max_scale)
			var delay = rng.randf_range(spawn_delay_min, spawn_delay_max)
			
			# Spawn with delay, then sync to all clients
			await get_tree().create_timer(delay).timeout
			spawn_cloud_at.rpc(scene_index, pos, scale_factor, i)
