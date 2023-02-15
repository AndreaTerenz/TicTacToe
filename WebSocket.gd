class_name WebSocket
extends Node

signal connected(url)
signal received(data)
signal closing
signal closed(code, reason)

@export var host := "127.0.0.1"
@export var route := "/"
@export var connect_on_ready := true

var full_url := ""

var socket := WebSocketPeer.new()
var buffer : PackedByteArray = []
var last_received : PackedByteArray = []
var socket_state:
	get:
		socket.poll()
		return socket.get_ready_state()
var socket_connected : bool :
	get:
		return socket_state == WebSocketPeer.STATE_OPEN
var closing_started := false

func _ready():
	if connect_on_ready:
		connect_socket()

func connect_socket(h = host, r = route):
	if socket_connected:
		push_error("Can't connect a socket already in use!")
		return false
	
	host = h
	full_url = "wss://%s/%s" % [host, route.trim_prefix("/")]
	
	print(full_url)
	var err = socket.connect_to_url(full_url)
	if err != OK: # or socket_state != WebSocketPeer.STATE_OPEN:
		push_error("Unable to connect socket! (tried connecting to %s)" % [full_url])
	else:
		closing_started = false
		
		print(socket_state)
		connected.emit(full_url)
		
	return socket_connected
	
# Receive ALL available packets
func receive():
	if not socket_connected:
		push_error("Can't use closing/closed socket!")
		return
	
	buffer = []
	while socket.get_available_packet_count():
		buffer.append_array(socket.get_packet())
		
	return buffer
	
func send_string(str_to_send : String):
	print("Sending: %s" % str_to_send)
	send(str_to_send.to_ascii_buffer())

# Send bytes
func send(to_send : PackedByteArray):
	if not socket_connected:
		push_error("Can't use closing/closed socket!")
		return
		
	socket.put_packet(to_send)
	
func _process(delta):
	socket.poll()
	if socket_state == WebSocketPeer.STATE_OPEN:
		var available = socket.get_available_packet_count()
		if available > 0:
			buffer.append_array(socket.get_packet())
		elif len(buffer) > 0:
			last_received = buffer.duplicate()
			received.emit(last_received)
			buffer.clear()
	elif socket_state == WebSocketPeer.STATE_CLOSING:
		if not closing_started:
			closing.emit()
	elif socket_state == WebSocketPeer.STATE_CLOSED:
		var code = socket.get_close_code()
		var reason = socket.get_close_reason()
		print("WebSocket closed with code: %d, reason %s. Clean: %s" % [code, reason, code != -1])
		closed.emit(code, reason)
