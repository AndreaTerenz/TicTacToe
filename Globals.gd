extends Node

signal socket_connected(url)
signal socket_closed(code, reason)
signal socket_received(data)
signal socket_connect_failed

var hostname := "127.0.0.1:5000"
var ws_route := "/game-socket"
# False only for local server
var wss := false

var in_game_scn := preload("res://InGame.tscn")
var username := ""
var lobby_id := ""
var players : Array = []
var awaiting_ok := false
var socket := WebSocket.new()

func _ready():
	print("ONGABONGA")
	
	socket.autoconnect_mode = WebSocket.AUTOCONNECT_MODE.PARENT_READY
	add_child(socket)
	
	socket.host = hostname
	socket.route = ws_route
	socket.use_WSS = wss
	
	socket.connected.connect(_on_web_socket_connected)
	socket.closed.connect(_on_web_socket_closed)
	socket.received.connect(_on_web_socket_received)
	socket.connect_failed.connect(_on_web_socket_connect_failed)

func _on_web_socket_connected(url):
	print("Socket connected to %s" % [url])
	socket_connected.emit(url)

func _on_web_socket_closed(code, reason):
	awaiting_ok = false
	print("WebSocket closed with code: %d, reason '%s'. Clean: %s" % [code, reason, code != -1])
	socket_closed.emit(code, reason)
	
func _on_web_socket_received(data: PackedByteArray):
	print(data)
	if data != null and len(data) > 0:
		socket_received.emit(data)
		var data_str : String = data.get_string_from_ascii()
		print("Received: %s" % data_str)
		var data_json : Dictionary = JSON.parse_string(data_str)
		
		if awaiting_ok:
			awaiting_ok = false
			
			if data_str != "":
				Globals.lobby_id = data_json["lobby_id"]
				Globals.players = data_json["players"]

				get_tree().change_scene_to_packed(in_game_scn)

func _on_web_socket_connect_failed():
	print("Socket failed to connect to server")
	socket_connect_failed.emit()
	
func send_new_game(uname):
	username = uname
	socket.send_dict({
		"type": "NEW_GAME",
		"body": {
			"user_id": username,
		}
	})
	awaiting_ok = true
	
func send_join_game(uname, lobby):
	username = uname
	lobby_id = lobby
	socket.send_dict({
		"type": "JOIN_GAME",
		"body": {
			"user_id": username,
			"lobby_id": lobby_id,
		}
	})
	awaiting_ok = true
