# res://TrailData.gd
class_name TrailData

var points: Array = []
var line: Line2D
var max_points: int
var fade_speed: float
var tween: Tween
var is_fading: bool = false

func _init(line_node: Line2D, max_pts: int, fade_spd: float = 1.0):
	line = line_node
	max_points = max_pts
	fade_speed = fade_spd

func add_point(point: Vector2, player: Node2D):
	points.append(point)
	if points.size() > max_points:
		points.pop_front()
	update_visual(player)

func update_visual(player: Node2D):
	line.clear_points()
	for point in points:
		line.add_point(player.to_local(point))
	line.visible = points.size() > 0

func clear():
	points.clear()
	line.clear_points()
	line.visible = false

func start_fade(player: Node2D):
	if is_fading:
		return

	is_fading = true
	tween = player.create_tween()
	tween.finished.connect(_on_fade_complete)
	tween.tween_property(line, "modulate:a", 0.0, fade_speed)

func _on_fade_complete():
	line.visible = false
	line.modulate.a = 1.0
	clear()
	is_fading = false
