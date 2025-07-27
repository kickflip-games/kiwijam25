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
	Vector2(200, 500),
	Vector2(100, 100),
	Vector2(200, 100)
]
@export var spawn_colors = [
	Color(0.13, 0.941, 0.99, 1.0),
	Color(0.367, 0.685, 0.128, 1.0),
	Color(0.758, 0.081, 0.28, 1.0),  
	Color(0.822, 0.633, 0.233, 1.0), 
]


func _init(id: int = 0):
	player_id = id
	player_name =  "Player " + str(player_id)
	color = spawn_colors[player_id%len(spawn_colors)]
	spawn_position= spawn_positions[player_id%len(spawn_positions)]
	

func to_dict() -> Dictionary:
	return {
		"player_id": player_id,
		"player_name": player_name,
		"color": color,
		"spawn_position": spawn_position
	}

static func from_dict(d: Dictionary) -> PlayerData:
	var pd = PlayerData.new()
	pd.player_id = d.get("player_id", 0)
	pd.player_name = d.get("player_name", "Player 0")
	pd.color = d.get("color", Color.WHITE)
	pd.spawn_position = d.get("spawn_position", Vector2.ZERO)
	return pd
