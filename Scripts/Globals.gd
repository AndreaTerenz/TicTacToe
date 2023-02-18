extends Node

signal socket_connected(url)
signal socket_closed(code, reason)
signal socket_received(data)
signal socket_connect_failed

signal player_joined(player)
signal player_left(players)

var hostname := "flask-hello-world-75s7.onrender.com"
var ws_route := "/game-socket"
var wss := true

var local_mode := true

var in_game_scn := preload("res://InGame.tscn")
var username := ""
var lobby_id := ""
var players : Array = []
var socket := WebSocket.new()

func _ready():
	print("ONGABONGA")
	
	if local_mode:
		hostname = "127.0.0.1:5000"
		wss = false
	
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
	print("[%s] Socket connected to %s" % [username, url])
	socket_connected.emit(url)

func _on_web_socket_closed(code, reason):
	print("[%s] WebSocket closed with code: %d, reason '%s'. Clean: %s" % [username, code, reason, code != -1])
	socket_closed.emit(code, reason)
	
func _on_web_socket_received(data: PackedByteArray):
	socket_received.emit(data)
	
	if data != null and len(data) > 0:
		var data_str : String = data.get_string_from_ascii()
		print("[%s] Received: %s" % [username, data_str])
			
		if data_str != "":
			var data_json : Dictionary = JSON.parse_string(data_str)
			var msg_type = data_json["type"]
			print("[%s] msg_type: %s" % [username, msg_type])
			
			if msg_type in ["NEW_GAME_OK", "JOIN_GAME_OK"]:
				Globals.lobby_id = data_json["lobby_id"]
				Globals.players = data_json["players"]

				get_tree().change_scene_to_packed(in_game_scn)
				
			if msg_type == "PLAYER_JOINED":
				var new_p = data_json["new_player"]
				Globals.players.append(new_p)
				player_joined.emit(new_p)
				
			if msg_type == "PLAYER_LEFT":
				var players_left = data_json["players"]
				Globals.players = players_left
				player_left.emit(players_left)

func _on_web_socket_connect_failed():
	print("[%s] Socket failed to connect to server" % [username])
	socket_connect_failed.emit()
	
func send_new_game(uname):
	username = uname
	socket.send_dict({
		"type": "NEW_GAME",
		"body": {
			"user_id": username,
		}
	})
	
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
