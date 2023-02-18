extends Node

signal socket_connected(url)
signal socket_closed(code, reason)
signal socket_received(data)
signal socket_connect_failed

signal player_joined(player)
signal player_left(players)
signal other_moved(r,c)
signal gameover(winner)

enum PLAYER {
	EMPTY = 0,
	X = 1, O = -1,
	DRAW = 2
}

var hostname := "flask-hello-world-75s7.onrender.com"
var ws_route := "/game-socket"
var wss := true

var local_mode := true

var in_game_scn := preload("res://InGame.tscn")
var username := ""
var lobby_id := ""
var role := PLAYER.EMPTY
var other_role := PLAYER.EMPTY
var winner := PLAYER.EMPTY
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
	print_db("Socket connected to %s" % [url])
	socket_connected.emit(url)

func _on_web_socket_closed(code, reason):
	print_db("WebSocket closed with code: %d, reason '%s'. Clean: %s" % [code, reason, code != -1])
	socket_closed.emit(code, reason)
	
func _on_web_socket_received(data: PackedByteArray):
	socket_received.emit(data)
	
	if data != null and len(data) > 0:
		var data_str : String = data.get_string_from_ascii()
		print_db("Received: %s" % [data_str])
			
		if data_str != "":
			data_str = data_str.replace("}{", "}#{")
			var messages : PackedStringArray = data_str.split("#", false)
			
			for msg_str in messages:
				var data_json : Dictionary = JSON.parse_string(msg_str)
				parse_message(data_json)
			
func parse_message(data):
	var msg_type = data["type"]
	print_db("msg_type: %s" % [msg_type])
	
	if msg_type in ["NEW_GAME_OK", "JOIN_GAME_OK"]:
		Globals.lobby_id = data["lobby_id"]
		Globals.players = data["players"]
		
		Globals.role = PLAYER.X if msg_type == "NEW_GAME_OK" else PLAYER.O
		Globals.other_role = PLAYER.O if role == PLAYER.X else PLAYER.X

		get_tree().change_scene_to_packed(in_game_scn)
		
	if msg_type == "PLAYER_JOINED":
		var new_p = data["new_player"]
		Globals.players.append(new_p)
		player_joined.emit(new_p)
		
	if msg_type == "PLAYER_LEFT":
		var players_left = data["players"]
		Globals.players = players_left
		player_left.emit(players_left)
		
	if msg_type == "OTHER_MOVED":
		var move_r = data["move_r"]
		var move_c = data["move_c"]
		
		other_moved.emit(move_r, move_c)
		
	if msg_type == "GAME_OVER":
		winner = data["winner"]
		gameover.emit(winner)

func _on_web_socket_connect_failed():
	print_db("Socket failed to connect to server")
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

func send_move(r, c):
	socket.send_dict({
		"type": "MOVE",
		"body": {
			"user_id": username,
			"move_r": r,
			"move_c": c,
		}
	})

func print_db(msg: String):
	print("[%s - %s] %s" % [username, Time.get_time_string_from_system(), msg])
