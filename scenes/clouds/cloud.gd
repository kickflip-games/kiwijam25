extends Area2D
class_name Cloud

@export var fade_speed: float = 2.0
@export var min_alpha: float = 0.2
@export var restore_speed: float = 1.5
@export var spawn_fade_speed: float = 1.0

var original_alpha: float = 1.0
var target_alpha: float
var is_player_inside: bool = false
var is_spawning: bool = true
var players_inside: Array = []

func _ready():
	# Start invisible and fade in
	modulate.a = 0.0
	target_alpha = original_alpha
	
	# Connect signals for player entering/exiting
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func _process(delta):
	if is_spawning:
		# Fade in from spawn
		modulate.a = lerp(modulate.a, original_alpha, spawn_fade_speed * delta)
		if modulate.a >= original_alpha - 0.01:
			is_spawning = false
	elif players_inside.size() > 0:
		# Fade the cloud while any player is inside
		target_alpha = min_alpha
		modulate.a = lerp(modulate.a, target_alpha, fade_speed * delta)
	else:
		# Restore original transparency when no players inside
		target_alpha = original_alpha
		modulate.a = lerp(modulate.a, target_alpha, restore_speed * delta)

func _on_area_entered(area):
	print("Area entered!")
	if area.get_parent().is_in_group("player"):
		print("PLAYER ENTERED!")
		# Only server manages the player list to avoid conflicts
		if multiplayer.is_server():
			if area not in players_inside:
				players_inside.append(area)
				sync_cloud_state.rpc()
		
		# Set local hiding state
		if area.has_method("set_hiding"):
			area.set_hiding(true)

func _on_area_exited(area):
	if area.get_parent().is_in_group("player"):
		# Only server manages the player list
		if multiplayer.is_server():
			if area in players_inside:
				players_inside.erase(area)
				sync_cloud_state.rpc()
		
		# Clear local hiding state
		if area.has_method("set_hiding"):
			area.set_hiding(false)

@rpc("any_peer", "call_local", "reliable")
func sync_cloud_state():
	# Sync the occupied state across all clients
	is_player_inside = players_inside.size() > 0
