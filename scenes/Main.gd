extends Node2D


@onready var spanwer = $MultiplayerSpawner
@onready var score_tree: Tree = $CanvasLayer/ScoreUI/Tree

signal scores_updated


func _ready():
	spanwer.scores_updated_event.connect(update_score_table)
	

func update_score_table(scores):
	score_tree.clear()  # Clear existing rows
	
	
	# Setup tree columns
	score_tree.set_column_titles_visible(true)
	score_tree.set_column_title(0, "Player")
	score_tree.set_column_title(1, "Score")

	var root = score_tree.create_item()  # Root item

	# Sort and add rows
	for player in scores.keys():
		var item = score_tree.create_item(root)
		item.set_text(0, "P%d"%player)
		item.set_text(1, str(spanwer.player_scores[player]))
