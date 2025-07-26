# HomingMissile.gd
# Attach this script to a CharacterBody2D node

extends CharacterBody2D

@export var speed         : float = 200.0
@export var turn_speed    : float = 3.0
@export var acceleration  : float = 50.0
@export var init_velocity : float = 400.0

# ── NEW: how strong the mutual repulsion is (px/sec²)
@export var repulsion_force  : float = 4000.0
# ── NEW: radius of the repulsion area (px)
@export var repulsion_radius : float = 100.0

# lifespan as before
@export var lifespan      : float = 5.0

# Trail settings
@export var trail_length  : int   = 30
@export var trail_width   : float = 8.0
@export var trail_color_start : Color = Color.ORANGE
@export var trail_color_end   : Color = Color(1.0, 0.3, 0.0, 0.0)

var target        : Node2D
var current_speed : float = 0.0
var trail_points  : Array  = []

# track all other missiles inside our repulsion area
var _bodies_in_repulsion : Array = []

# scene children
@onready var trail           := $Trail
@onready var repulsion_area  := $RepulsionArea

var spawner : Node2D  # who fired us

func _ready() -> void:
	current_speed = init_velocity
	add_to_group("missile")
	
	# set up homing target
	find_target()

	# self‑destruct timer
	var t = get_tree().create_timer(lifespan, false)
	t.timeout.connect(destroy)

	# configure repulsion area
	var cs = repulsion_area.get_node("CollisionShape2D") as CollisionShape2D
	(cs.shape as CircleShape2D).radius = repulsion_radius

	# connect signals
	repulsion_area.body_entered.connect(_on_repulsion_area_body_entered)
	repulsion_area.body_exited.connect(_on_repulsion_area_body_exited)


func find_target() -> void:
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if p != spawner:
			target = p
			return
	# no players → clear *all* missiles
	for m in get_tree().get_nodes_in_group("missile"):
		m.destroy()


func _physics_process(delta: float) -> void:
	if not target:
		find_target()
		return

	# HOMING
	var dir = (target.global_position - global_position).normalized()
	rotation = lerp_angle(rotation, dir.angle(), turn_speed * delta)

	current_speed = min(current_speed + acceleration * delta, speed)
	velocity = Vector2.RIGHT.rotated(rotation) * current_speed

	# REPULSION: push away from every other missile in our repulsion zone
	for other in _bodies_in_repulsion:
		# skip self‑collisions
		if other == self:
			continue
		var away = (global_position - other.global_position).normalized()
		velocity += away * repulsion_force * delta

	move_and_slide()
	update_trail()


func update_trail() -> void:
	trail_points.append(global_position)
	if trail_points.size() > trail_length:
		trail_points.pop_front()
	trail.clear_points()
	for p in trail_points:
		trail.add_point(to_local(p))
	trail.visible = true


func destroy() -> void:
	queue_free()


# ----- repulsion area signals -----
func _on_repulsion_area_body_entered(body: Node) -> void:
	if body.is_in_group("missile") and body != self:
		_bodies_in_repulsion.append(body)


func _on_repulsion_area_body_exited(body: Node) -> void:
	if body in _bodies_in_repulsion:
		_bodies_in_repulsion.erase(body)


func _on_area_2d_body_entered(body: Node) -> void:
	# your existing collision logic
	if body.is_in_group("player"):
		print("Player hit by missile!")
		if spawner.has_method("increase_score"):
			print("score increased'")
			spawner.increase_score() # Call the function if it exists
		else:
			print("Player does not have 'increase_score'")
		destroy()
