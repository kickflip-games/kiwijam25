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
@export var debug_marker: Node2D = null
@export var show_debug_marker: bool = true

# UI references
@export var status_label: RichTextLabel = null

func _ready():
	# Setup screen bounds
	screen_bounds = get_viewport().get_visible_rect()
	target_position = global_position  # Use global_position for child scenes
	
	# Try to find the main camera
	find_main_camera()
	
	# Create status label if it doesn't exist or isn't assigned
	if not status_label:
		setup_status_label()
	else:
		configure_existing_status_label()
	
	# Create debug marker if it doesn't exist or isn't assigned
	if not debug_marker:
		setup_debug_marker()
	else:
		configure_existing_debug_marker()
	
	# Initialize TCP server
	setup_tcp_server()
	
	print("Finger Controller initialized as TCP SERVER")
	print("Screen size: ", screen_bounds.size)
	print("Camera found: ", main_camera != null)
	print("Using camera projection: ", use_camera_projection)
	print("Waiting for Python client on port: ", server_port)

func find_main_camera():
	"""Find the main camera in the scene"""
	# Method 1: Try to find Camera2D in parent scenes
	var current_node = get_parent()
	while current_node != null:
		var camera = current_node.find_child("*", false, false) as Camera2D
		if camera:
			main_camera = camera
			print("Found Camera2D: ", camera.name, " in ", current_node.name)
			return
		
		# Also check if the current node itself is a camera
		if current_node is Camera2D:
			main_camera = current_node as Camera2D
			print("Found Camera2D: ", current_node.name)
			return
		
		current_node = current_node.get_parent()
	
	# Method 2: Try to get the current camera from viewport
	var viewport = get_viewport()
	if viewport.get_camera_2d():
		main_camera = viewport.get_camera_2d()
		print("Found active Camera2D from viewport: ", main_camera.name)
		return
	
	# Method 3: Search the entire scene tree
	var scene_tree = get_tree()
	if scene_tree:
		var cameras = find_all_cameras_in_scene(scene_tree.current_scene)
		if cameras.size() > 0:
			main_camera = cameras[0]
			print("Found Camera2D in scene tree: ", main_camera.name)
			return
	
	print("No Camera2D found - using screen coordinates")
	use_camera_projection = false

func find_all_cameras_in_scene(node: Node) -> Array:
	"""Recursively find all Camera2D nodes in the scene"""
	var cameras = []
	
	if node is Camera2D:
		cameras.append(node)
	
	for child in node.get_children():
		cameras.append_array(find_all_cameras_in_scene(child))
	
	return cameras

func setup_status_label():
	"""Create a new status label as HUD element when none is assigned"""
	# Create new RichTextLabel
	status_label = RichTextLabel.new()
	status_label.name = "StatusLabel"
	
	# Add to viewport as CanvasLayer for HUD positioning
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "FingerTrackerHUD"
	canvas_layer.layer = 100  # High layer to appear on top
	
	# Add to scene tree at viewport level (not as child of this node)
	get_viewport().add_child(canvas_layer)
	canvas_layer.add_child(status_label)
	
	# Configure the new label
	configure_existing_status_label()
	
	print("Created new HUD status label in CanvasLayer")

func configure_existing_status_label():
	"""Configure an existing status label (either created or assigned in editor)"""
	if not status_label:
		return
	
	# Configure label appearance for HUD
	status_label.position = Vector2(10, 10)
	status_label.size = Vector2(400, 160)
	status_label.add_theme_font_size_override("normal_font_size", 16)
	status_label.add_theme_color_override("default_color", Color.WHITE)
	status_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	status_label.add_theme_constant_override("shadow_offset_x", 2)
	status_label.add_theme_constant_override("shadow_offset_y", 2)
	
	# RichTextLabel specific settings
	status_label.bbcode_enabled = true
	status_label.fit_content = true
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# Add background for better visibility
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0, 0, 0, 0.7)  # Semi-transparent black
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color(0.5, 0.5, 0.5, 0.8)  # Gray border
	style_box.corner_radius_top_left = 5
	style_box.corner_radius_top_right = 5
	style_box.corner_radius_bottom_left = 5
	style_box.corner_radius_bottom_right = 5
	status_label.add_theme_stylebox_override("normal", style_box)
	
	print("Configured status label: ", status_label.name)

func setup_debug_marker():
	"""Create a new visual marker when none is assigned"""
	# Create a simple ColorRect as a visible marker
	var marker_rect = ColorRect.new()
	marker_rect.name = "FingerDebugMarker"
	marker_rect.size = Vector2(20, 20)
	marker_rect.color = Color.CYAN
	marker_rect.position = Vector2(-10, -10)  # Center the rect
	
	# Add border effect with multiple rects
	var border = ColorRect.new()
	border.name = "Border"
	border.size = Vector2(24, 24)
	border.color = Color.WHITE
	border.position = Vector2(-12, -12)
	
	var outer_border = ColorRect.new()
	outer_border.name = "OuterBorder"
	outer_border.size = Vector2(28, 28)
	outer_border.color = Color.BLACK
	outer_border.position = Vector2(-14, -14)
	
	# Create container for world positioning
	debug_marker = Node2D.new()
	debug_marker.name = "FingerMarkerContainer"
	
	
	var my_parent = get_parent()
	if my_parent:
		my_parent.add_child(debug_marker)
		print("Added debug marker to finger controller's parent: ", my_parent.name)
	else:
		# Fallback: add to scene root
		get_tree().current_scene.add_child(debug_marker)
		print("Added debug marker to scene root")
	
	debug_marker.add_child(outer_border)
	debug_marker.add_child(border)
	debug_marker.add_child(marker_rect)
	
	print("Created new debug marker for finger tracking visualization")

func configure_existing_debug_marker():
	"""Configure an existing debug marker (assigned in editor)"""
	if not debug_marker:
		return
	
	print("Using existing debug marker: ", debug_marker.name)

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
	# Handle TCP server and incoming connections
	handle_tcp_server()
	
	# Check for finger input timeout
	check_finger_timeout()
	
	# Handle mouse input if not using finger control
	if not using_finger_control:
		handle_mouse_input()
	
	# Smooth movement to target position
	apply_smooth_movement(delta)
	
	# Update debug marker
	update_debug_marker()
	
	# Update status display
	update_status_label()

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

func parse_finger_json(json_string: String):
	"""Parse JSON finger tracking data and update position"""
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		print("JSON Parse Error: ", parse_result)
		return
	
	var data = json.data
	
	# Always update the finger control timestamp when we receive any data
	last_finger_update = Time.get_ticks_msec() / 1000.0
	
	# Check if we have valid finger position data
	if data.has("h") and data["h"]:
		
		if data.has("x") and data.has("y"):
			# Convert finger position (0-1) to screen coordinates first
			var screen_pos = Vector2(data["x"], data["y"])
			
			# Then convert to world coordinates using camera projection
			var world_pos = convert_screen_to_world_position(screen_pos)
			
			# Update target position
			target_position = world_pos
			
			# Update finger control state
			using_finger_control = true
	
	elif data.has("h") and not data["h"]:
		# Hand not detected - stay in current position but remain in finger mode
		using_finger_control = true

func check_finger_timeout():
	"""Check if we should switch back to mouse control due to timeout"""
	if using_finger_control:
		var current_time = Time.get_ticks_msec() / 1000.0
		var time_since_last_update = current_time - last_finger_update
		
		# Only switch to mouse if we haven't received ANY data for a while
		if time_since_last_update > finger_timeout:
			using_finger_control = false
			print("Switched to mouse control (no data from Python script)")

func handle_mouse_input():
	"""Handle mouse input as fallback"""
	var mouse_pos = get_global_mouse_position()
	
	# Use global mouse position for world coordinates
	target_position = mouse_pos

func apply_smooth_movement(delta: float):
	"""Apply smooth movement to the target position"""
	if move_smoothing > 0:
		global_position = global_position.lerp(target_position, move_smoothing)
	else:
		global_position = target_position
	
	# Optional: Keep within world bounds if needed
	# You can add world boundary constraints here based on your scene

func update_debug_marker():
	"""Update the debug marker to show target position"""
	if not debug_marker or not show_debug_marker:
		if debug_marker:
			debug_marker.visible = false
		return
	
	debug_marker.visible = using_finger_control  # Only show when using finger control
	
	# Show where the target is (where finger is pointing)
	debug_marker.global_position = target_position
	
	# Pulse effect when finger is detected
	if using_finger_control:
		var current_time = Time.get_ticks_msec() / 1000.0
		var time_since_update = current_time - last_finger_update
		
		if time_since_update < 0.1:  # Recently received data
			var pulse = sin(current_time * 10.0) * 0.2 + 1.0
			debug_marker.scale = Vector2(pulse, pulse)
		else:
			debug_marker.scale = Vector2(1.0, 1.0)

func update_status_label():
	"""Update the status label with current input method and connection info"""
	if not status_label:
		return
	
	var input_method = "MOUSE CONTROL"
	var input_color = "[color=yellow]"
	
	if using_finger_control:
		# Check if we're actually receiving hand data
		var current_time = Time.get_ticks_msec() / 1000.0
		var time_since_update = current_time - last_finger_update
		
		if time_since_update < 0.5:  # Recently received data
			input_method = "FINGER CONTROL"
			input_color = "[color=lime]"
		else:
			input_method = "FINGER STANDBY"  # Connected but no hand detected
			input_color = "[color=orange]"
	
	# Build status text with BBCode formatting
	var status_text = "[font_size=18][b]FINGER TRACKER DEBUG[/b][/font_size]\n"
	status_text += "[color=white]Connection: [color=cyan]%s[/color][/color]\n" % connection_status
	status_text += "[color=white]Input Method: %s%s[/color][/color]\n" % [input_color, input_method]
	status_text += "[color=gray]World Pos: (%.0f, %.0f)[/color]\n" % [global_position.x, global_position.y]
	status_text += "[color=gray]Target Pos: (%.0f, %.0f)[/color]\n" % [target_position.x, target_position.y]
	status_text += "[color=gray]Camera: %s[/color]\n" % (main_camera.name if main_camera else "None")
	status_text += "[color=gray]Projection: %s " % ("ON" if use_camera_projection else "OFF")
	status_text += "| Marker: %s[/color]" % ("ON" if show_debug_marker else "OFF")
	
	status_label.text = status_text

func _input(event):
	"""Handle input events"""
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			using_finger_control = not using_finger_control
			print("Manually toggled to: ", "finger" if using_finger_control else "mouse")
		
		elif event.keycode == KEY_R:
			# Restart server
			restart_server()
		
		elif event.keycode == KEY_T:
			# Test data reception
			print("Manual test - checking for data...")
			if tcp_peer:
				read_finger_data()
		
		elif event.keycode == KEY_C:
			# Check connection status
			print("Server status: ", tcp_server.is_listening() if tcp_server else "No server")
			print("Peer status: ", tcp_peer.get_status() if tcp_peer else "No peer")
			print("Available bytes: ", tcp_peer.get_available_bytes() if tcp_peer else "No peer")
		
		elif event.keycode == KEY_M:
			# Toggle debug marker
			toggle_debug_marker()
		
		elif event.keycode == KEY_H:
			# Toggle debug HUD
			toggle_debug_hud()
		
		elif event.keycode == KEY_P:
			# Toggle camera projection
			use_camera_projection = not use_camera_projection
			print("Camera projection: ", "ON" if use_camera_projection else "OFF")
		
		elif event.keycode == KEY_D:
			# Debug positioning test - set marker to mouse position
			if debug_marker:
				var mouse_world_pos = get_global_mouse_position()
				debug_marker.global_position = mouse_world_pos
				target_position = mouse_world_pos
				print("Debug test: Set marker and target to mouse position: ", mouse_world_pos)

func toggle_debug_marker():
	"""Toggle the debug marker visibility"""
	show_debug_marker = not show_debug_marker
	if debug_marker:
		debug_marker.visible = show_debug_marker and using_finger_control
	print("Debug marker: ", "ON" if show_debug_marker else "OFF")

func toggle_debug_hud():
	"""Toggle the debug HUD visibility"""
	if status_label:
		status_label.visible = not status_label.visible
		print("Debug HUD: ", "ON" if status_label.visible else "OFF")

func set_debug_hud_position(pos: Vector2):
	"""Set the debug HUD position on screen"""
	if status_label:
		status_label.position = pos
		print("Debug HUD moved to: ", pos)

func restart_server():
	"""Restart the TCP server"""
	print("Restarting TCP server...")
	
	if tcp_peer:
		tcp_peer.disconnect_from_host()
		tcp_peer = null
	
	if tcp_server:
		tcp_server.stop()
	
	setup_tcp_server()

func _exit_tree():
	"""Clean up when the node is removed"""
	if tcp_peer:
		tcp_peer.disconnect_from_host()
	if tcp_server:
		tcp_server.stop()
	
	# Clean up HUD elements (only if we created them)
	var hud_layer = get_viewport().get_node_or_null("FingerTrackerHUD")
	if hud_layer:
		hud_layer.queue_free()
	
	# Clean up debug marker (only if we created it)
	if debug_marker and debug_marker.name == "FingerMarkerContainer":
		debug_marker.queue_free()
	
	print("TCP Server and auto-created elements cleaned up")

# Helper functions for external use
func get_input_method() -> String:
	return "finger" if using_finger_control else "mouse"

func is_connected_to_client() -> bool:
	return tcp_peer != null and tcp_peer.get_status() == StreamPeerTCP.STATUS_CONNECTED

func set_smoothing(value: float):
	move_smoothing = clamp(value, 0.0, 1.0)

func set_finger_timeout(timeout: float):
	finger_timeout = max(timeout, 0.1)

func set_camera(camera: Camera2D):
	"""Manually set the camera to use for projection"""
	main_camera = camera
	use_camera_projection = (camera != null)
	print("Camera manually set: ", camera.name if camera else "None")
