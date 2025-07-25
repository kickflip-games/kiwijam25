extends Control


func _on_server_button_pressed() -> void:
	HighLevelNetworkHandler.start_server()


func _on_join_button_pressed() -> void:
	HighLevelNetworkHandler.start_client()
