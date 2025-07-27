extends Control
class_name PlayerUI

@export var heart_full_texture: Texture2D
@export var heart_empty_texture: Texture2D

@onready var hearts := $Hearts
@onready var score_label:=$ScoreLabel

#@onready var heart_tween := create_tween()
#@onready var score_tween := create_tween()

var original_scale: Vector2
var original_color: Color





func _ready():	
	original_scale = score_label.scale
	original_color = score_label.modulate
	
	_on_score_changed(0)
	_on_hp_changed(3)  # initialize


func _on_hp_changed(current_hp: int):
	print("change hp UI: ", current_hp)
	for i in range(hearts.get_child_count()):
		var heart = hearts.get_child(i)
		var target_texture = heart_full_texture if i < current_hp else heart_empty_texture

		if heart.texture != target_texture:
			var original_scale = heart.scale
			#heart_tween.kill()  # kill previous heart_tween to avoid overlap
			#heart_tween = create_tween()
			heart.texture = target_texture
			heart.scale = Vector2(1.5, 1.5)
			#heart_tween.heart_tween_property(heart, "scale", original_scale, 3).set_trans(heart_tween.TRANS_BOUNCE)
		else:
			heart.texture = target_texture


func _on_score_changed(current_score: int):
	print("change score UI ", current_score)

	# Format to 000 (e.g., 007)
	score_label.text = "%03d" % current_score

	# Stop any running animations
	#score_tween.kill()

	# -- PULSE animation (scale up and down)
	#var big_scale = original_scale * 1.3

	#var up = score_tween.tween_property(score_label, "scale", big_scale, 0.1)
	#if up:
		#up.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
#
	#var down = score_tween.tween_property(score_label, "scale", original_scale, 0.1)
	#if down:
		#down.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
#
	## -- FLASH animation (modulate white → back to original)
	#score_label.modulate = Color.WHITE
	#var flash = score_tween.tween_property(score_label, "modulate", original_color, 0.2)
	#if flash:
		#flash.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
