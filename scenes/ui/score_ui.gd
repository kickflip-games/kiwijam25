extends Control

@onready var score_container = $VBoxContainer
var score_labels = {}
var game_server: Node

func _ready():
	# Get reference to game server
	game_server = get_node("/root/GameServer")  # Adjust path as needed
	
	# Connect to score updates
	if game_server:
		game_server.score_updated.connect(_on_score_updated)
		
	# Initialize display
	update_score_display()

func _on_score_updated(player_id: int, new_score: int):
	update_score_display()

func update_score_display():
	# Clear existing labels
	for label in score_labels.values():
		label.queue_free()
	score_labels.clear()
	
	if not game_server:
		return
		
	var scores = game_server.get_all_scores()
	
	# Sort players by score (highest first)
	var sorted_players = scores.keys()
	sorted_players.sort_custom(func(a, b): return scores[a] > scores[b])
	
	# Create labels for each player
	for i in range(sorted_players.size()):
		var player_id = sorted_players[i]
		var score = scores[player_id]
		
		var label = Label.new()
		label.text = "Player %d: %d" % [player_id, score]
		label.add_theme_font_size_override("font_size", 24)
		
		# Color coding for top players
		match i:
			0: label.add_theme_color_override("font_color", Color.GOLD)
			1: label.add_theme_color_override("font_color", Color.SILVER)
			2: label.add_theme_color_override("font_color", Color("#CD7F32"))  # Bronze
			_: label.add_theme_color_override("font_color", Color.WHITE)
		
		score_container.add_child(label)
		score_labels[player_id] = label
