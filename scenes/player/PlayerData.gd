class_name PlayerData
extends Resource

@export var player_id: int
@export var player_name: String = ""
@export var color: Color
@export var spawn_position: Vector2 
@export var current_score: int = 0
@export var deaths: int = 0


@export var spawn_positions = [
	Vector2(100, 500),
	Vector2(-100, 500),
	Vector2(100, 500),
	Vector2(-100, 100)
]
@export var spawn_colors = [
	Color(0.13, 0.941, 0.99, 1.0),
	Color(0.367, 0.685, 0.128, 1.0),
	Color(0.435, 0.845, 0.949, 1.0),  # Fixed: was > 1.0 values
	Color(0.354, 0.906, 0.467, 1.0),  # Fixed: was > 1.0 values
]


func _init(id: int = 0):
	player_id = id
	player_name =  "Player " + str(player_id)
	color = spawn_colors[player_id%len(spawn_colors)]
	spawn_position= spawn_positions[player_id%len(spawn_positions)]
	
