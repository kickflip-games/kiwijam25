class_name PlayerData
extends Resource

@export var player_id: int
@export var player_name: String = ""
@export var color: Color = Color.WHITE
@export var spawn_position: Vector2 = Vector2.ZERO
@export var current_score: int = 0
@export var deaths: int = 0

func _init(id: int = 0, name: String = "", player_color: Color = Color.WHITE):
	player_id = id
	player_name = name if name != "" else "Player " + str(id)
	color = player_color

func to_dict() -> Dictionary:
	return {
		"player_id": player_id,
		"player_name": player_name,
		"color": color,
		"spawn_position": spawn_position,
		"current_score": current_score,
		"is_connected": is_connected,
		"deaths": deaths,
	}

func from_dict(data: Dictionary):
	player_id = data.get("player_id", 0)
	player_name = data.get("player_name", "")
	color = data.get("color", Color.WHITE)
	spawn_position = data.get("spawn_position", Vector2.ZERO)
	current_score = data.get("current_score", 0)
	deaths = data.get("deaths", 0)
