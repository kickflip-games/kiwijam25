extends Node2D

# TCP Server setup (Godot as server, Python as client)
var tcp_server: TCPServer
var tcp_peer: StreamPeerTCP
var connection_status: String = "Waiting for Python"
var server_port: int = 12345

# Input handling
var using_finger_control: bool = false
var last_finger_update: float = 0.0
var finger_timeout: float = 1.0  # Switch to mouse after 1 second without finger data

# Movement settings
var screen_bounds: Rect2
var move_smoothing: float = 0.15
var target_position: Vector2


# Camera and projection settings
var main_camera: Camera2D = null
var use_camera_projection: bool = true
var world_depth: float = 0.0  # Z-depth for 3D cameras

# Debug counters
var no_data_counter: int = 0

# Debug visual elements
@onready var debug_marker: Node2D = $FingerDebugMarker
@export var show_debug_marker: bool = true

const SHOOT_COOLDOWN_MAX := 20
const DASH_COOLDOWN_MAX := 15

# these track the remaining frames until the next emit is allowed
var shoot_cooldown_frames: int = 0
var dash_cooldown_frames: int = 0

signal finger_dash
signal finger_shoot

func _ready():
	if not is_multiplayer_authority():
		queue_free()
		return  # This node isn't owned by this peer — disable it.
	
	# Setup screen bounds
	screen_bounds = get_viewport().get_visible_rect()
	target_position = global_position  # Use global_position for child scenes
	
	setup_tcp_server() # potentially switch to UDP?? 
	
	print("Finger Controller initialized as TCP SERVER")
	print("Screen size: ", screen_bounds.size)
	print("Camera found: ", main_camera != null)
	print("Using camera projection: ", use_camera_projection)
	print("Waiting for Python client on port: ", server_port)



func setup_tcp_server():
	"""Initialize TCP server for receiving finger data"""
	tcp_server = TCPServer.new()
	var error = tcp_server.listen(server_port)
	
	if error == OK:
		connection_status = "Listening on port " + str(server_port)
		print("TCP Server listening on port: ", server_port)
	else:
		connection_status = "Failed to start server"
		print("Failed to start TCP server: ", error)

func _process(delta):
	handle_tcp_server()
	update_debug_marker()


func handle_tcp_server():
	"""Handle TCP server and incoming data"""
	if not tcp_server:
		return
	
	# Check for new connections
	if tcp_server.is_connection_available():
		tcp_peer = tcp_server.take_connection()
		connection_status = "Python Connected!"
		print("*** PYTHON CLIENT CONNECTED! ***")
	
	# Read data from connected client
	if tcp_peer and tcp_peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		read_finger_data()
	elif tcp_peer and tcp_peer.get_status() == StreamPeerTCP.STATUS_ERROR:
		print("Python client disconnected")
		connection_status = "Python Disconnected"
		tcp_peer = null

func read_finger_data():
	"""Read and parse finger tracking data from TCP client"""
	var available_bytes = tcp_peer.get_available_bytes()
	
	if available_bytes > 0:
		# Read all available data
		var raw_data = tcp_peer.get_utf8_string(available_bytes)
		
		if raw_data != "":
			# Split by newlines and process each JSON line
			var lines = raw_data.split("\n")
			
			for line in lines:
				var trimmed_line = line.strip_edges()
				if trimmed_line != "" and trimmed_line.begins_with("{"):
					parse_finger_json(trimmed_line)

func convert_screen_to_world_position(screen_pos: Vector2) -> Vector2:
	"""Convert screen position to world position using camera projection"""
	if not use_camera_projection or not main_camera:
		# Fallback: use screen coordinates directly
		var screen_x = screen_pos.x * screen_bounds.size.x
		var screen_y = screen_pos.y * screen_bounds.size.y
		return Vector2(screen_x, screen_y)
	
	# Get viewport
	var viewport = get_viewport()
	
	# Convert screen coordinates (0-1) to viewport pixel coordinates
	var viewport_pos = Vector2(
		screen_pos.x * viewport.get_visible_rect().size.x,
		screen_pos.y * viewport.get_visible_rect().size.y
	)
	
	# Convert viewport coordinates to world coordinates through camera
	var world_pos = viewport_pos
	
	# Manual transformation using camera
	if main_camera:
		# Get the camera's transform
		var camera_transform = main_camera.get_global_transform()
		var camera_zoom = main_camera.zoom
		
		# Convert screen to camera space
		var camera_center = camera_transform.origin
		var viewport_center = viewport.get_visible_rect().size / 2.0
		
		# Calculate offset from center
		var offset_from_center = viewport_pos - viewport_center
		
		# Apply camera zoom and transform
		var world_offset = offset_from_center / camera_zoom
		world_pos = camera_center + world_offset
	
	return world_pos

#func parse_finger_json(json_string: String):
	#"""Parse JSON finger tracking data and update position"""
	#var json = JSON.new()
	#var parse_result = json.parse(json_string)
	#
	#if parse_result != OK:
		#print("JSON Parse Error: ", parse_result)
		#return
	#
	#var data = json.data
	#last_finger_update = Time.get_ticks_msec() / 1000.0
	#if data.has("h") and data["h"]:
		#
		#if data.has("x") and data.has("y"):
			#var screen_pos = Vector2(data["x"], data["y"])
			#var world_pos = convert_screen_to_world_position(screen_pos)
			#target_position = world_pos
			#using_finger_control = true
		#
		#if data.has('c') and data['c']:
			#finger_shoot.emit()
			#print("CLOSED FIST")
			## send signal 
		#
		#if data.has('fast') and data['fast']:
			#finger_dash.emit()
			#print("FAST HAND: DASH")
			## send signal 
	#
	#elif data.has("h") and not data["h"]:
		#using_finger_control = true
func parse_finger_json(json_string: String) -> void:
	"""Parse JSON finger tracking data, update position, and rate‑limit gestures."""
	var json = JSON.new()
	if json.parse(json_string) != OK:
		push_error("JSON Parse Error: %s" % json.get_error_message())
		return
	var data = json.data
	last_finger_update = Time.get_ticks_msec() / 1000.0

	# decrement cooldowns each call
	if shoot_cooldown_frames > 0:
		shoot_cooldown_frames -= 1
	if dash_cooldown_frames > 0:
		dash_cooldown_frames -= 1

	# position handling as before
	if data.has("h") and data["h"]:
		if data.has("x") and data.has("y"):
			var screen_pos = Vector2(data["x"], data["y"])
			target_position = convert_screen_to_world_position(screen_pos)
			using_finger_control = true

	# CLOSED FIST → shoot, but only if cooldown expired
		if data.has("c") and data["c"] and shoot_cooldown_frames <= 0:
			shoot_cooldown_frames = SHOOT_COOLDOWN_MAX
			finger_shoot.emit()
			print("CLOSED FIST")

	# FAST HAND → dash, but only if cooldown expired
		if data.has("fast") and data["fast"] and dash_cooldown_frames <= 0:
			dash_cooldown_frames = DASH_COOLDOWN_MAX
			finger_dash.emit()
			print("FAST HAND: DASH")

	elif data.has("h") and not data["h"]:
		using_finger_control = false

func update_debug_marker():
	"""Update the debug marker to show target position"""
	if not debug_marker or not show_debug_marker:
		if debug_marker:
			debug_marker.visible = false
		return
	
	#debug_marker.visible = using_finger_control 
	#debug_marker.global_position = target_position
	#
	#if using_finger_control:
		#var current_time = Time.get_ticks_msec() / 1000.0
		#var time_since_update = current_time - last_finger_update
		#
		#if time_since_update < 0.1:  # Recently received data
			#var pulse = sin(current_time * 10.0) * 0.2 + 1.0
			#debug_marker.scale = Vector2(pulse, pulse)
		#else:
			#debug_marker.scale = Vector2(1.0, 1.0)



func _exit_tree():
	"""Clean up when the node is removed"""
	if tcp_peer:
		tcp_peer.disconnect_from_host()
	if tcp_server:
		tcp_server.stop()
	print("TCP Server and auto-created elements cleaned up")


func is_connected_to_client() -> bool:
	return tcp_peer != null and tcp_peer.get_status() == StreamPeerTCP.STATUS_CONNECTED


func set_camera(camera: Camera2D):
	"""Manually set the camera to use for projection"""
	main_camera = camera
	use_camera_projection = (camera != null)
	print("Camera manually set: ", camera.name if camera else "None")
