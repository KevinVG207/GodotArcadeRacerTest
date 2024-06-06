extends Node

var port: int = 8001

var socket: WebSocketPeer = null
var json := JSON.new()
var mutex: Mutex
var thread := Thread.new()
var should_exit := false
var vehicle_data: Variant = null
var sending_vehicle_data := false
var unique_id: String = ""
var fetching_id := false
var fetching_states := false
var cur_vehicle_states: Dictionary = {}

func _ready():
	mutex = Mutex.new()
	thread.start(poll)

func _connect():
	unique_id = ""
	socket = WebSocketPeer.new()
	socket.connect_to_url("wss://umapyoi.net/ws")

func poll():
	while true:
		mutex.lock()
		var _should_exit = should_exit
		mutex.unlock()
		
		if _should_exit:
			break
		
		if not socket:
			_connect()

		socket.poll()
		var state = socket.get_ready_state()
		#print(state)
		if state == WebSocketPeer.STATE_OPEN:
			while socket.get_available_packet_count():
				var packet_data: PackedByteArray = socket.get_packet()
				var res = json.parse(packet_data.get_string_from_utf8())
				
				if res != 0:
					print("ERR: ", error_string(res))
					continue
				
				var data = json.data
				handle_data(data)

		elif state == WebSocketPeer.STATE_CLOSING:
			# Keep polling to achieve proper close.
			pass
		elif state == WebSocketPeer.STATE_CONNECTING:
			pass
		else:
			_connect()
		
		mutex.lock()
		var _vehicle_data = vehicle_data
		mutex.unlock()
		
		if _vehicle_data and not sending_vehicle_data:
			sending_vehicle_data = true
			var res = send_vehicle_data(_vehicle_data)
			if res:
				mutex.lock()
				vehicle_data = null
				mutex.unlock()
			# Send vehicle data
			
			# send_data(_vehicle_data, "vehicle_data")
		
		if unique_id.is_empty() and not fetching_id:
			fetching_id = true
			var res = fetch_unique_id()
			if not res:
				fetching_id = false
		
		mutex.lock()
		var _cur_vehicle_states = cur_vehicle_states
		mutex.unlock()
		
		if not fetching_states and not _cur_vehicle_states:
			fetching_states = true
			var ret = fetch_vehicle_states()
			if not ret:
				fetching_states = false


func handle_data(_data: Dictionary):
	if 'type' not in _data or 'data' not in _data:
		return
	
	var type: String = _data['type']
	var data: Variant = _data['data']
	
	if type == "vehicle_data_received":
		sending_vehicle_data = false
	elif type == "unique_id_received":
		unique_id = str(data)
		fetching_id = false
	elif type == "unique_id_expired":
		unique_id = ""
	elif type == "vehicles":
		mutex.lock()
		cur_vehicle_states = data
		mutex.unlock()
		fetching_states = false


func send_data(data: Variant, type: String):
	if not socket:
		return false
	var state = socket.get_ready_state()
	if not state == WebSocketPeer.STATE_OPEN:
		return false
	
	print("Sending type " + type)
	
	var packet: Dictionary = {
		'type': type,
		'data': data
	}
	var json_data = JSON.stringify(packet)
	socket.send_text(json_data)
	return true

func fetch_unique_id():
	return send_data(true, "generate_unique_id")

func send_vehicle_data(vehicle_data: Dictionary):
	print("a")
	if unique_id.is_empty():
		return false
	print("b")
	var data = {
		"id": unique_id,
		"state": vehicle_data
	}
	print("c")
	return send_data(data, "vehicle_data")

func fetch_vehicle_states():
	if unique_id.is_empty():
		return false
	
	return send_data(true, "get_vehicles")
