# Player.gd
extends Node2D

# --- Configurable variables ---
@export var acceleration := 800.0
@export var max_speed := 400.0
@export var drag := 0.95
@export var turn_rate := 8.0
@export var dash_speed := 1200.0   
@export var dash_duration := 0.15  
@export var dash_cooldown := 1.5
@export var dash_start_boost := 1.5
@export var max_hp := 3
@export var invincibility_duration: float = 1.2

@export var main_color: Color
@export var other_color: Color
var color:Color
@export var spawn_point: Vector2

# --- Circling behavior ---
@export var circle_radius := 80.0
@export var circle_speed := 300.0
@export var circle_orbit_radius := 60.0

# --- Turn effects ---
@export var sharp_turn_threshold := 2.0
@export var turn_fx_duration := 0.3
@export var curved_trail_segments := 8

# --- Juice FX ---
@export var hit_pause_duration := 0.08
@export var dash_bloom_intensity := 1.8
@export var dash_trail_fade_duration := 0.2
@export var idle_pulse_speed := 2.0
@export var dash_dial_radius := 40.0


@export var player_data:Dictionary

# --- Bullet -- 
const Bullet = preload("res://scenes/projectiles/homing_missile.tscn")

# --- State ---
var velocity := Vector2.ZERO
var current_hp := max_hp
var score:= 0 
var is_dashing := false
var is_circling := false
var is_invincible := false
var is_hit_paused := false
var circle_angle := 0.0
var last_rotation := 0.0
var turn_fx_timer := 0.0
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var dash_direction := Vector2.ZERO
@export var target_position := Vector2.ZERO
var velocity_history: Array[Vector2] = []
var is_sharp_turning = false
var is_initialized: bool = false

@export var bullet_speed := 1000.0






var trails: Dictionary = {}

# --- Nodes ---
@onready var sprite: Sprite2D = $Sprite2D
@onready var reticle: Sprite2D = $Reticle
@onready var dash_particles: GPUParticles2D = $DashParticles
@onready var movement_particles: GPUParticles2D = $MovementParticles
@onready var idle_pulse_particles: GPUParticles2D = $IdlePulseParticles
@onready var collision_area: Area2D = $CollisionArea
@onready var turn_fx_left: Line2D = $TurnFXLeft
@onready var turn_fx_right: Line2D = $TurnFXRight
@onready var dash_trail: Line2D = $DashTrail
@onready var movement_trail: Line2D = $MovementTrail
@onready var dash_dial: Line2D = $DashDial
@onready var dash_dial_bg: Line2D = $DashDialBG






# --- Signals ---
signal hp_changed(current_hp: int)
signal score_changed(current_score:int)
signal dash_cooldown_updated(percent_ready: float)
signal player_died



func _enter_tree():
	set_multiplayer_authority(name.to_int())

func _ready():
	
	var AUTHORITY = get_multiplayer_authority()
	print("🔍 Player _ready() called - Node path: %s, Authority: %d" % [get_path(), AUTHORITY])
	
	print("In player ready")
	
	if is_multiplayer_authority():
		print("ASSINGING DATA (auth=%d)"% AUTHORITY )
		var pdata = PlayerData.new(AUTHORITY)
		player_data = pdata.to_dict()
 

	collision_area.connect("body_entered", _on_body_entered)
	
	last_rotation = rotation
	
	
		
	if is_multiplayer_authority():
		reticle.visible = true
		reticle.modulate.a = 0.5
		emit_signal("hp_changed", current_hp)
	else:
		reticle.visible = false

	_init_colors.call_deferred()

func _init_colors():
	print(player_data)
	global_position = player_data.get("spawn_position", Vector2.ZERO)
	target_position = player_data.get("spawn_position", Vector2.ZERO)
	
	
	
	is_initialized = true
	print("Player data found - position: %s, color: %s" % [global_position, color])
	
	_setup_dash_dial()
	_setup_trails()
	
	if is_multiplayer_authority():
		color = main_color
	else:
		color = other_color
	
	$Sprite2D.modulate = color
	$Reticle.modulate = color


func _setup_trails():
	trails["dash"] = TrailData.new(dash_trail, 15, dash_trail_fade_duration)
	trails["movement"] = TrailData.new(movement_trail, 20, 1.0)
	trails["turn_left"] = TrailData.new(turn_fx_left, 10, 1.0)
	trails["turn_right"] = TrailData.new(turn_fx_right, 10, 1.0)
	
	# Setup trail properties
	movement_trail.width = 24.18
	movement_trail.default_color = Color(1.0, 1.0, 1.0, 0.7)

func _setup_dash_dial():
	dash_dial_bg.width = 3.0
	dash_dial_bg.default_color = Color(0.3, 0.3, 0.3, 0.5)
	_create_circle_points(dash_dial_bg, dash_dial_radius, 32)
	
	dash_dial.width = 4.0
	dash_dial.default_color = Color(0.2, 0.8, 1.0, 0.8)

func _process(delta):
	#if !is_multiplayer_authority() or is_hit_paused:
		#return
		
		
		
	_update_velocity_history()
	
	if is_dashing:
		_handle_dash_movement(delta)
		trails["dash"].add_point(global_position, self)
		_apply_dash_bloom_effect()
		dash_timer -= delta
		if dash_timer <= 0:
			end_dash()
	else:
		if is_multiplayer_authority():
			_update_target_position()
		_apply_momentum_movement(delta)
		dash_cooldown_timer = max(dash_cooldown_timer - delta, 0.0)
		
		trails["movement"].add_point(global_position, self)
		_update_movement_particles()

	if is_multiplayer_authority():
		_update_reticle(delta)
		_update_dash_dial()
	emit_signal("dash_cooldown_updated", _get_dash_percent_ready())

func _update_velocity_history():
	velocity_history.append(velocity)
	if velocity_history.size() > 10:
		velocity_history.pop_front()

func _input(event):
	
	if !is_multiplayer_authority() or is_hit_paused:
		return
	
	if event.is_action_pressed("dash") and can_dash():
		start_dash()
	if event.is_action_pressed("shoot"):
		shoot.rpc(multiplayer.get_unique_id())
	if event.is_action_pressed("pause_player"):
		max_speed = 0.4
		
	


@onready var finger_tracker = $finger_tracker


# -- shooting --

@rpc("call_local")
func shoot(shooter_pid):
	var b = Bullet.instantiate()
	b.spawner = self
	b.set_color(color)
	b.set_multiplayer_authority(shooter_pid)
	b.global_position = $BulletSpawn.global_position
	b.rotation = rotation
	get_parent().add_child(b)



# --- Hit Pause System ---
func trigger_hit_pause():
	if is_hit_paused:
		return
		
	is_hit_paused = true
	Engine.time_scale = 0.1
	
	var impact_tween = create_tween()
	impact_tween.tween_property(sprite, "scale", Vector2(1.3, 0.7), hit_pause_duration * 0.3)
	impact_tween.tween_property(sprite, "scale", Vector2.ONE, hit_pause_duration * 0.7)
	
	await get_tree().create_timer(hit_pause_duration * Engine.time_scale).timeout
	Engine.time_scale = 1.0
	is_hit_paused = false

# --- Enhanced Dash System ---
func can_dash() -> bool:
	return not is_dashing and dash_cooldown_timer <= 0.0 and current_hp > 0

func start_dash():
	is_dashing = true
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	dash_direction = (target_position - global_position).normalized()
	
	trails["dash"].clear()
	dash_trail.visible = true
	
	sprite.modulate = Color(dash_bloom_intensity, dash_bloom_intensity, dash_bloom_intensity + 0.3, 0.9)
	sprite.scale = Vector2(1.3, 0.7)
	
	dash_particles.emitting = true
	if movement_particles:
		movement_particles.emitting = false

func _apply_dash_bloom_effect():
	var pulse = sin(Time.get_ticks_msec() * 0.02) * 0.2 + 1.0
	sprite.modulate = Color(dash_bloom_intensity * pulse, dash_bloom_intensity * pulse, 
						   (dash_bloom_intensity + 0.3) * pulse, 0.9)

func _handle_dash_movement(delta):
	var dash_progress = 1.0 - (dash_timer / dash_duration)
	var current_speed = dash_speed
	
	if dash_progress < 0.3:
		current_speed *= dash_start_boost
	
	global_position += dash_direction * current_speed * delta
	rotation = dash_direction.angle()

func end_dash():
	is_dashing = false
	
	var end_tween = create_tween()
	end_tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.2)
	end_tween.parallel().tween_property(sprite, "scale", Vector2.ONE, 0.2)
	
	dash_particles.emitting = false
	
	if movement_particles:
		movement_particles.emitting = true
	
	velocity += dash_direction * 200.0
	trails["dash"].start_fade(self)

# --- Enhanced Movement System ---

func _update_target_position() -> void:
	if !is_multiplayer_authority() or is_hit_paused:
		return
	
	# Prefer the finger tracker.
	if finger_tracker and finger_tracker.is_connected_to_client():
		target_position = finger_tracker.target_position
	else:
		# Fallback – no tracker, or not connected.
		target_position = get_global_mouse_position()

func _apply_momentum_movement(delta):
	var distance_to_target = global_position.distance_to(target_position)
	
	if distance_to_target < circle_radius:
		_handle_circling_movement(delta)
	else:
		is_circling = false
		_handle_direct_movement(delta)
	
	velocity *= drag
	global_position += velocity * delta
	_handle_rotation_and_turns(delta)

func _handle_direct_movement(delta):
	var direction_to_target = (target_position - global_position).normalized()
	velocity += direction_to_target * acceleration * delta
	
	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed

func _handle_circling_movement(delta):
	if not is_circling:
		is_circling = true
		var to_target = target_position - global_position
		circle_angle = to_target.angle() + PI/2
	
	circle_angle += (circle_speed / circle_orbit_radius) * delta
	var orbit_position = target_position + Vector2(cos(circle_angle), sin(circle_angle)) * circle_orbit_radius
	
	var direction_to_orbit = (orbit_position - global_position).normalized()
	velocity += direction_to_orbit * acceleration * delta
	
	if velocity.length() > circle_speed:
		velocity = velocity.normalized() * circle_speed

func _handle_rotation_and_turns(delta):
	if velocity.length() > 2.0:
		var target_rotation = velocity.angle()
		rotation = lerp_angle(rotation, target_rotation, turn_rate * delta)
		
		var rotation_change = abs(angle_difference(rotation, last_rotation))
		var turn_speed = rotation_change / delta
		
		if turn_speed > sharp_turn_threshold:
			if !is_sharp_turning:
				is_sharp_turning = true
				trails["turn_left"].clear()
				trails["turn_right"].clear()
			
			trails["turn_left"].add_point(global_position, self)
			trails["turn_right"].add_point(global_position, self)
		else:
			if is_sharp_turning:
				is_sharp_turning = false
				trails["turn_left"].start_fade(self)
				trails["turn_right"].start_fade(self)
		
		last_rotation = rotation

func _update_movement_particles():
	if movement_particles:
		if velocity.length() > 30.0:
			movement_particles.emitting = true
			movement_particles.process_material.direction = Vector3(-velocity.normalized().x, -velocity.normalized().y, 0)
		else:
			movement_particles.emitting = false

# --- Dash Dial System ---
func _update_dash_dial():
	var dash_percent = _get_dash_percent_ready()
	dash_dial.clear_points()
	
	if dash_percent < 1.0:
		var arc_angle = dash_percent * TAU
		_create_arc_points(dash_dial, dash_dial_radius, arc_angle, 24)
		dash_dial.visible = true
		dash_dial_bg.visible = true
		
		if dash_percent > 0.8:
			dash_dial.default_color = Color(0.2, 1.0, 0.3, 0.9)
		else:
			dash_dial.default_color = Color(1.0, 0.5, 0.2, 0.7)
	else:
		dash_dial.visible = false
		dash_dial_bg.visible = false

func _create_circle_points(line: Line2D, radius: float, segments: int):
	line.clear_points()
	for i in range(segments + 1):
		var angle = (float(i) / float(segments)) * TAU
		var point = Vector2(cos(angle), sin(angle)) * radius
		line.add_point(point)

func _create_arc_points(line: Line2D, radius: float, end_angle: float, segments: int):
	line.clear_points()
	var actual_segments = int(segments * (end_angle / TAU))
	
	for i in range(actual_segments + 1):
		var angle = (float(i) / float(segments)) * end_angle - PI/2
		var point = Vector2(cos(angle), sin(angle)) * radius
		line.add_point(point)

func _update_reticle(delta):
	reticle.global_position = target_position
	var pulse = (sin(Time.get_ticks_msec() / 200.0) + 1.5) * 0.5
	reticle.scale = Vector2.ONE * (1.0 + 0.2 * pulse)
	reticle.modulate.a = 0.5 + 0.3 * pulse

func _get_dash_percent_ready() -> float:
	return clamp(1.0 - dash_cooldown_timer / dash_cooldown, 0.0, 1.0)

# --- Enhanced Collision & Damage ---
func _on_body_entered(body: Node2D):
	print("Body entered: ", body.name)
	if is_dashing or is_invincible:
		return
	
	trigger_hit_pause()
	take_damage(1)
	body.queue_free()

func take_damage(amount: int):
	current_hp -= amount
	emit_signal("hp_changed", current_hp)
	print("Took damage! HP = ", current_hp)

	if current_hp <= 0:
		die()
	else:
		become_invincible()

func become_invincible():
	is_invincible = true
	
	var tween = create_tween().set_loops(int(invincibility_duration * 6))
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "modulate", Color(1.5, 0.5, 0.5, 0.4), invincibility_duration / 12)
	tween.tween_property(sprite, "modulate", Color.WHITE, invincibility_duration / 12)

	await get_tree().create_timer(invincibility_duration).timeout
	is_invincible = false
	print("Player is no longer invincible.")

func die():
	print("Player has died")
	player_died.emit()
	
	var death_tween = create_tween()
	death_tween.parallel().tween_property(sprite, "scale", Vector2.ZERO, 0.5)
	death_tween.parallel().tween_property(sprite, "modulate", Color.TRANSPARENT, 0.5)
	await death_tween.finished
	
	queue_free()


func increase_score():
	score +=1 
	emit_signal("score_changed", score)


func _on_finger_tracker_finger_dash() -> void:
	start_dash()


func _on_finger_tracker_finger_shoot() -> void:
	shoot.rpc(multiplayer.get_unique_id())
