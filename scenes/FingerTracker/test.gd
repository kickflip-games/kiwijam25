extends Node

var server := TCPServer.new()
var peer : StreamPeerTCP

func _ready():
	server.listen(4242)
	print("Server started, waiting for Python...")

func _process(_delta):
	if server.is_connection_available():
		peer = server.take_connection()
		print("Python connected!")

	if peer and peer.get_available_bytes() > 0:
		var msg = peer.get_utf8_string(peer.get_available_bytes())
		print("Received:", msg)
