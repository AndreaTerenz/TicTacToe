@icon("res://WebSocket.svg")
class_name WebSocket
extends Node

signal connected(url)
signal connect_failed
signal received(data)
signal closing
signal closed(code, reason)

@export var host := "127.0.0.1"
@export var route := "/"
@export var connect_on_ready := true
@export var use_WSS := true
@export_range(0, 128) var receive_limit : int = 0
@export_range(0, 300) var connection_timeout : int = 10

var full_url := ""

var socket := WebSocketPeer.new()
var buffer : PackedByteArray = []
var last_received : PackedByteArray = []
var received_count := 0
var socket_state:
	get:
		socket.poll()
		return socket.get_ready_state()
var connect_timedout : bool :
	get:
		return connect_timer.is_stopped() and connection_timeout > 0
var socket_connected := false
var closing_started := false

var connect_timer := Timer.new()

func _ready():
	add_child(connect_timer)
	connect_timer.one_shot = true
	
	if connect_on_ready:
		connect_socket()

func connect_socket(h = host, r = route):
	if socket_connected:
		push_error("Can't connect a socket already in use!")
		return false
	
	connect_timer.start(connection_timeout)
	set_process(true)
	
	host = h
	var protocol = "wss" if use_WSS else "ws"
	full_url = "%s://%s/%s" % [protocol, host, route.trim_prefix("/")]

	var err = socket.connect_to_url(full_url)
	if err != OK: # or socket_state != WebSocketPeer.STATE_OPEN:
		push_error("Unable to connect socket! (tried connecting to %s)" % [full_url])
		return false
	
	return true
	
# Receive ALL available packets
func receive():
	if not check_open():
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
	if not check_open():
		return
		
	socket.put_packet(to_send)
	
func check_open():
	if not socket_connected:
		push_error("Socket not connected yet!")
		return false
	if closing_started:
		push_error("Socket has closed/is closing!")
		return false
		
	return true
	
func _process(delta):
	socket.poll()
	
	match socket_state:
		WebSocketPeer.STATE_CONNECTING:
			if connect_timedout:
				socket.close(1001, "Connection timeout")
				connect_failed.emit()
		WebSocketPeer.STATE_OPEN:
			if not socket_connected:
				socket_connected = true
				closing_started = false
				connect_timer.stop()
				connected.emit(full_url)
			
			var available = socket.get_available_packet_count()
			var enable_receive = (receive_limit == 0 or (received_count < receive_limit))
			
			if available > 0 and enable_receive:
				buffer.append_array(socket.get_packet())
				received_count += 1
			elif len(buffer) > 0:
				last_received = buffer.duplicate()
				received_count = 0
				received.emit(last_received)
				buffer.clear()
		WebSocketPeer.STATE_CLOSING:
			if not closing_started:
				closing.emit()
		WebSocketPeer.STATE_CLOSED:
			var code = socket.get_close_code()
			var reason = socket.get_close_reason()
			closed.emit(code, reason)
			set_process(false)
