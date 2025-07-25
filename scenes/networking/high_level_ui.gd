extends Control

@onready var ip_entry = $VBoxContainer/IPEntry
@onready var server_button = $VBoxContainer/ServerButton
@onready var join_button = $VBoxContainer/JoinButton

func _ready():
	server_button.pressed.connect(_on_server_button_pressed)
	join_button.pressed.connect(_on_join_button_pressed)
	ip_entry.text = _get_local_ip()

func _get_ip():
	var ip = ip_entry.text.strip_edges()
	if ip == "":
		push_error("❌ IP address is empty!")
		return
	return ip
	
func _get_local_ip() -> String:
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.") or ip.begins_with("10.") or ip.begins_with("172."):
			return ip
	return "127.0.0.1"


func _on_server_button_pressed() -> void:
	var ip = _get_ip()
	if ip:
		HighLevelNetworkHandler.start_server(ip)

func _on_join_button_pressed() -> void:
	var ip = _get_ip()
	if ip:
		HighLevelNetworkHandler.start_client(ip)
