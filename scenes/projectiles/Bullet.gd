# Bullet.gd
extends RigidBody2D
class_name Bullet

@export var damage: int = 1
@export var lifetime: float = 10.0
@export var speed := 1000.0

var velocity: Vector2

func _ready():
	gravity_scale = 0
	lock_rotation = true
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(_destroy_bullet)

	# if nobody called set_velocity(), do a “forward” shot:
	if velocity == Vector2.ZERO:
		velocity = Vector2.RIGHT.rotated(rotation) * speed
	linear_velocity = velocity


func _integrate_forces(state):
	# Keep constant velocity (ignore friction/dampening)
	if velocity != Vector2.ZERO:
		state.linear_velocity = velocity

func set_velocity(new_velocity: Vector2):
	velocity = new_velocity
	linear_velocity = velocity

func _on_body_entered(body):
	if !is_multiplayer_authority():
		return
	# Check if we hit the player
	if body.has_method("take_damage"):
		body.take_damage.rpc_id(body.get_multiplayer_authority(),25)
		_destroy_bullet()
	_destroy_bullet().rpc()
	
	
@rpc("call_local")
func _destroy_bullet():
	# Add destruction effect here if desired
	queue_free()

# Clean up when leaving screen bounds
func _on_visible_on_screen_notifier_2d_screen_exited():
	_destroy_bullet()
