extends Node3D

class_name RaceBase

@onready var player_camera: Camera3D = $PlayerCamera
var checkpoints: Array = []
var key_checkpoints: Dictionary = {}
var players_dict: Dictionary = {}
var frames_between_update: int = 45
var update_wait_frames: int = 0
var should_exit: bool = false
var update_thread: Thread
var player_vehicle: Vehicle3 = null
var player_user_id: String = ""
var removed_player_ids: Array = []
var starting_order: Array = []
var spectate: bool = false
var timer_tick: int = 0
var physical_item_counter = 0
var physical_items: Dictionary = {}
var deleted_physical_items: Array = []

@export var start_offset_z: float = 2
@export var start_offset_x: float = 3

@onready var vehicles_node: Node3D = $Vehicles

var player_scene: PackedScene = preload("res://scenes/vehicles/vehicle_3.tscn")
var rank_panel_scene: PackedScene = preload("res://scenes/ui/rank_panel.tscn")

var lobby_scene: PackedScene = load("res://scenes/ui/lobby/lobby.tscn")

@export var lap_count: int = 3
var finished = false

var finish_order: Array = []
var rankings_timer: int = 0
var rankings_delay: int = 30
var stop_rankings: bool = false


class raceOp:
	const SERVER_UPDATE_VEHICLE_STATE = 1
	const CLIENT_UPDATE_VEHICLE_STATE = 2
	const SERVER_PING = 3
	const CLIENT_VOTE = 4
	const SERVER_PING_DATA = 5
	const SERVER_RACE_START = 6
	const CLIENT_READY = 7
	const SERVER_RACE_OVER = 8
	const SERVER_CLIENT_DISCONNECT = 9
	const SERVER_ABORT = 10
	const CLIENT_SPAWN_ITEM = 11
	const CLIENT_DESTROY_ITEM = 12
	const SERVER_SPAWN_ITEM = 13
	const SERVER_DESTROY_ITEM = 14
	const CLIENT_ITEM_STATE = 15
	const SERVER_ITEM_STATE = 16

class finishType:
	const NORMAL = 0
	const TIMEOUT = 1

const STATE_DISCONNECT = -1
const STATE_INITIAL = 0
const STATE_JOINING = 1
const STATE_CAN_READY = 2
const STATE_READY_FOR_START = 3
const STATE_WAIT_FOR_START = 4
const STATE_COUNTDOWN = 5
const STATE_COUNTING_DOWN = 6
const STATE_RACE = 7
const STATE_RACE_OVER = 8
const STATE_READY_FOR_RANKINGS = 9
const STATE_SHOW_RANKINGS = 10
const STATE_JOIN_NEXT = 11
const STATE_JOINING_NEXT = 12
const STATE_SPECTATING = 13

const UPDATE_STATES = [
	STATE_COUNTDOWN,
	STATE_COUNTING_DOWN,
	STATE_RACE
]

var state = STATE_INITIAL

@onready var map_camera: Camera3D = $MapCamera

func _ready():
	UI.race_ui.set_max_laps(lap_count)
	UI.race_ui.set_cur_lap(0)
	
	UI.show_race_ui()
	
	UI.race_ui.back_btn.pressed.connect(_on_back_pressed)

	checkpoints = []
	key_checkpoints = {}
	
	# Setup checkpoints
	for checkpoint: Checkpoint in $Checkpoints.get_children():
		checkpoints.append(checkpoint)
		if checkpoint.is_key:
			key_checkpoints[checkpoint] = key_checkpoints.size()
	
	var path_points = $EnemyPathPoints.get_children()
	for i in range(len(path_points)):
		var path_point = path_points[i] as EnemyPath
		var next_i = i+1
		if next_i >= path_points.size():
			next_i = 0
		
		path_point.next_points.append(path_points[next_i])
	
	#minimap_recursive($Course)
	$Course/MapMesh.visible = true
	UI.race_ui.set_map_camera(map_camera)
	UI.race_ui.set_startline(checkpoints[0])


func _process(delta):
	UI.race_ui.set_startline(checkpoints[0])
	
	if not $CountdownTimer.is_stopped() and $CountdownTimer.time_left <= 3.0:
		UI.race_ui.update_countdown(str(ceil($CountdownTimer.time_left)))
	else:
		UI.race_ui.update_countdown("")
	
	if state == STATE_RACE:
		UI.race_ui.update_time(timer_tick * (1.0/Engine.physics_ticks_per_second))
	
	if state == STATE_SHOW_RANKINGS:
		UI.race_ui.show_back_btn()
		UI.race_ui.update_timeleft($NextRaceTimer.time_left)
	
	if spectate:
		if !player_camera.target and players_dict:
			player_camera.target = players_dict.values()[0]
			player_camera.instant = true
			UI.end_scene_change()
		
		var spectator_index = players_dict.values().find(player_camera.target)
		if spectator_index > -1:
			UI.race_ui.enable_spectating()
			#UI.race_ui.set_username(players_dict[players_dict.keys()[spectator_index]].username)
			
			if get_window().has_focus() and Input.is_action_just_pressed("accelerate"):
				player_camera.instant = true
				spectator_index += 1
				if spectator_index >= players_dict.size():
					spectator_index = 0
			elif get_window().has_focus() and Input.is_action_just_pressed("brake"):
				player_camera.instant = true
				spectator_index -= 1
				if spectator_index < 0:
					spectator_index = players_dict.size()-1
			
			player_camera.target = players_dict.values()[spectator_index]
	
	# Minimap icons
	UI.race_ui.update_icons(players_dict.values())
	
	# Nametags
	if player_camera.target:
		# Display nametags.
		var exclude_list: Array = []
		for vehicle: Vehicle3 in players_dict.values():
			exclude_list.append(vehicle.get_rid())
			
		var viewport_size: Vector2 = get_viewport().get_visible_rect().size
		var nt_deadzone_sides = viewport_size.x / 10
		var nt_deadzone_top = viewport_size.y / 14
		var nt_deadzone_bottom = viewport_size.y / 3
		
		for user_id: String in players_dict.keys():
			var vehicle = players_dict[user_id] as Vehicle3
			if vehicle == player_vehicle:
				continue
			var nametag_pos = vehicle.transform.origin + (player_camera.transform.basis.y * 1.5) as Vector3
			#var second_check = nametag_pos + (player_camera.transform.basis.z * -5.0)
			var dist = nametag_pos.distance_to(player_camera.global_position)
			var tag_visible = true
			var force = false
			#if dist > 75 or player_camera.is_position_behind(second_check):
			if dist > 75:
				tag_visible = false
			
			if not player_camera.is_position_in_frustum(nametag_pos):
				tag_visible = false
				force = true
			
			# Raycast between camera pos and nametag_pos. If anything is in-between, don't render the nametag.
			if tag_visible:
				var ray_result = get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(player_camera.global_position, nametag_pos, 0xFFFFFFFF, exclude_list))
				if ray_result:
					tag_visible = false
			
			var screen_pos = player_camera.unproject_position(nametag_pos)

			if screen_pos.x < nt_deadzone_sides or screen_pos.x > viewport_size.x - nt_deadzone_sides or screen_pos.y < nt_deadzone_top or screen_pos.y > viewport_size.y - nt_deadzone_bottom:
				tag_visible = false
				
			var opacity = 1.0
			if dist > 60:
				opacity = remap(dist, 60, 75, 1.0, 0.0)
			
			if state == STATE_RACE_OVER or state in UPDATE_STATES and player_vehicle.finished:
				tag_visible = false
			
			UI.race_ui.update_nametag(user_id, vehicle.username, screen_pos, opacity, dist, tag_visible, force, delta)
		UI.race_ui.sort_nametags()

func minimap_recursive(node: Node):
	for child in node.get_children():
		minimap_recursive(child)
	
	# Add floor meshes to minimap layer
	if node is MeshInstance3D:
		if node.is_in_group("map"):
			node.set_layer_mask_value(19, true)  # Minimap layer

func change_state(new_state: int, state_func: Callable = Callable()):
	state = new_state
	state_func.call()

func make_physical_item(key: String, player: Vehicle3) -> Node:
	if player.is_network:
		return

	physical_item_counter += 1
	var unique_key = player_user_id + str(physical_item_counter)
	var instance = Global.physical_items[key].instantiate()
	instance.item_id = unique_key
	instance.owner_id = player.user_id
	instance.world = self
	physical_items[unique_key] = instance
	$Items.add_child(instance)

	Network.send_match_state(raceOp.CLIENT_SPAWN_ITEM, {"uniqueId": unique_key, "type": key, "state": instance.get_state()})

	return instance


func spawn_physical_item(data: Dictionary):
	var key = data["uniqueId"]
	var owner_id = data["ownerId"]
	var item_type = data["type"]
	var item_state = data["state"]

	if key in deleted_physical_items:
		return
	
	# Ignore already owned items
	if owner_id == player_user_id:
		return
	
	if key in physical_items.keys():
		return
	
	var instance = Global.physical_items[item_type].instantiate()
	instance.item_id = key
	instance.owner_id = owner_id
	instance.world = self
	physical_items[key] = instance
	$Items.add_child(instance)
	instance.set_state(item_state)


func destroy_physical_item(key: String):
	if key in deleted_physical_items:
		return
	var instance = physical_items[key]

	physical_items.erase(key)
	instance.queue_free()
	deleted_physical_items.append(key)
	Network.send_match_state(raceOp.CLIENT_DESTROY_ITEM, {"uniqueId": key})


func server_destroy_physical_item(data: Dictionary):
	var key = data["uniqueId"]
	if key in deleted_physical_items:
		return
	
	if not key in physical_items.keys():
		return

	var instance = physical_items[key]
	physical_items.erase(key)
	instance.queue_free()
	deleted_physical_items.append(key)


func send_item_state(item: Node):
	# Only the owner can send the state
	if not item.owner_id == player_user_id:
		return
	
	var item_state = item.get_state()

	# Skip sending items that don't have a state
	if not state:
		return
	
	#print(player_user_id, " sends ", item.item_id)
	Network.send_match_state(raceOp.CLIENT_ITEM_STATE, {"uniqueId": item.item_id, "state": item_state})


func apply_item_state(data: Dictionary):
	var key = data["uniqueId"]
	var owner_id = data["ownerId"]
	var item_state = data["state"]

	if key in deleted_physical_items:
		return
	
	if not key in physical_items.keys():
		return
	
	if owner_id == player_user_id:
		return
	
	var instance = physical_items[key]
	instance.set_state(item_state)
	#print(player_user_id, " receives ", key)
	#print("New owner ", instance.owner_id)


func _physics_process(_delta):
	match state:
		STATE_INITIAL:
			state = STATE_JOINING
			await join()
		STATE_CAN_READY:
			change_state(STATE_READY_FOR_START, send_ready)
		STATE_COUNTDOWN:
			UI.end_scene_change()
			$CountdownTimer.start(4.0)
			timer_tick = -Engine.physics_ticks_per_second * 3
			state = STATE_COUNTING_DOWN
		STATE_COUNTING_DOWN:
			timer_tick += 1
		STATE_RACE:
			timer_tick += 1
		STATE_RACE_OVER:
			UI.race_ui.race_over()
		STATE_READY_FOR_RANKINGS:
			if spectate:
				change_state(STATE_JOINING_NEXT, join_next)
			else:
				UI.race_ui.race_over()
				$NextRaceTimer.start(25)
				state = STATE_SHOW_RANKINGS
		STATE_SHOW_RANKINGS:
			UI.race_ui.hide_time()
			handle_rankings()
		STATE_JOIN_NEXT:
			if Global.MODE1 == Global.MODE1_ONLINE:
				change_state(STATE_JOINING_NEXT, join_next)
		_:
			pass
	
	if state in UPDATE_STATES or Global.MODE1 == Global.MODE1_OFFLINE:
		# Player checkpoints
		for vehicle: Vehicle3 in $Vehicles.get_children():
			update_checkpoint(vehicle)
			update_ranks()
			if vehicle == player_camera.target:
				UI.race_ui.set_cur_lap(vehicle.lap)
		
		if Global.MODE1 == Global.MODE1_ONLINE:
			update_wait_frames += 1
			if update_wait_frames > frames_between_update:
				update_wait_frames = 0
				if player_vehicle:
					var vehicle_data: Dictionary = player_vehicle.get_state()
					Network.send_match_state(raceOp.CLIENT_UPDATE_VEHICLE_STATE, vehicle_data)
					#player_vehicle.call_deferred("upload_data")
				
				for unique_id in physical_items.keys():
					var item = physical_items[unique_id]
					if not item.no_updates and item.owner_id == player_user_id:
						send_item_state(item)
		
		check_finished()

func handle_rankings():
	if stop_rankings:
		return
	
	if rankings_timer % rankings_delay == 0:
		@warning_ignore("integer_division")
		var cur_idx: int = rankings_timer / rankings_delay
		
		if cur_idx >= len(finish_order)-1:
			stop_rankings = true
			
		var cur_vehicle: Vehicle3 = players_dict[finish_order[cur_idx]]
		
		var end_position = Vector2(-262, 16 + (40+5)*cur_idx)
		var start_position = end_position
		start_position.x = 800
		var new_panel = rank_panel_scene.instantiate() as RankPanel
		new_panel.get_node("Rank").text = tr("ORD_%d" % (cur_idx+1))  # Util.make_ordinal(cur_idx+1)
		new_panel.get_node("PlayerName").text = cur_vehicle.username
		new_panel.position = start_position
		
		if cur_vehicle == player_vehicle:
			new_panel.set_border()
		
		UI.race_ui.get_node("Rankings").add_child(new_panel)
		var tween = create_tween()
		tween.tween_property(new_panel, "position", end_position, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	rankings_timer += 1

func check_finished():
	# Offline mode: All players have finished.
	# Online mode: Wait for server
	if finished:
		return
	
	if Global.MODE1 == Global.MODE1_OFFLINE:
		var is_finished: bool = true
		for vehicle: Vehicle3 in players_dict.values():
			if vehicle.is_player and not vehicle.finished:
				is_finished = false
				break
		finished = is_finished
		if finished:
			state = STATE_RACE_OVER


func _add_vehicle(user_id: String, new_position: Vector3, look_dir: Vector3, up_dir: Vector3):
	var new_vehicle = player_scene.instantiate() as Vehicle3
	players_dict[user_id] = new_vehicle
	vehicles_node.add_child(new_vehicle)
	new_vehicle.teleport(new_position, look_dir, up_dir)
	new_vehicle.axis_lock()
	new_vehicle.is_player = false
	new_vehicle.world = self
	new_vehicle.user_id = user_id
	
	match Global.MODE1:
		Global.MODE1_OFFLINE:
			new_vehicle.is_cpu = true
			new_vehicle.is_network = false
			new_vehicle.username = "CPU"
			new_vehicle.cpu_target = $EnemyPathPoints.get_child(0)
		Global.MODE1_ONLINE:
			new_vehicle.is_cpu = false
			new_vehicle.is_network = true
			new_vehicle.username = "Network Player"
	
	if user_id == player_user_id:
		new_vehicle.make_player()
		player_vehicle = new_vehicle
		player_camera.target = new_vehicle
		new_vehicle.username = "Player"
		if Global.MODE1 == Global.MODE1_ONLINE:
			new_vehicle.username = await Network.get_display_name()

func _remove_vehicle(user_id: String):
	if user_id in players_dict.keys():
		var vehicle = players_dict[user_id]
		if player_camera.target == vehicle:
			player_camera.target = null
		vehicle.queue_free()
		players_dict.erase(user_id)
		removed_player_ids.append(user_id)
		UI.race_ui.remove_nametag(user_id)


func setup_vehicles():
	var start_checkpoint = checkpoints[0] as Checkpoint
	var start_position = start_checkpoint.global_position
	var start_direction = -start_checkpoint.transform.basis.z
	var side_direction = start_checkpoint.transform.basis.x
	var up_dir = start_checkpoint.transform.basis.y
	start_position += up_dir * 1.0

	for i in range(starting_order.size()):
		var user_id = starting_order[i]
		
		var side_multi = 1
		if i % 2 == 1:
			side_multi = -1

		var cur_pos = start_position + start_offset_z * (i + 3) * start_direction + side_multi * start_offset_x * side_direction
		_add_vehicle(user_id, cur_pos, -start_direction, up_dir)

func get_starting_order():
	match Global.MODE1:
		Global.MODE1_ONLINE:
			player_user_id = Network.session.user_id

			if !Network.next_match_data.get('startingIds'):
				spectate = true
				return []

			return Network.next_match_data.startingIds
		Global.MODE1_OFFLINE:
			player_user_id = "Player"
			var player_array = []

			for i in range(Global.player_count-1):
				player_array.append("CPU" + str(i))
			player_array.append(player_user_id)
			player_array.shuffle()
			return player_array
	return []

func join():
	starting_order = get_starting_order()
	setup_vehicles()
	Network.next_match_data = {}
	
	if Global.MODE1 == Global.MODE1_OFFLINE:
		state = STATE_COUNTDOWN
		return

	var res: bool = await Network.join_match(Network.ready_match)
	
	Network.socket.received_match_state.connect(_on_match_state)

	if not res or not Network.cur_match:
		# Disconnect functions
		Network.socket.received_match_state.disconnect(_on_match_state)

		state = STATE_DISCONNECT
		return
	
	if spectate:
		state = STATE_SPECTATING
		return

	state = STATE_CAN_READY
	return

func send_ready():
	var res: bool = await Network.send_match_state(raceOp.CLIENT_READY, {})
	UI.end_scene_change()
	
	if not res:
		state = STATE_DISCONNECT
		return
	
	state = STATE_WAIT_FOR_START
	return

func get_vehicle_progress(vehicle: Vehicle3) -> float:
	var check_idx = vehicle.check_idx
	if check_idx < 0:
		check_idx = checkpoints.size() - check_idx - 2
	var cur_progress = 10000 * vehicle.lap + check_idx + vehicle.check_progress
	return cur_progress

func update_ranks():
	var ranks = []
	var ranks_vehicles = []

	var finished_vehicles = []

	for vehicle: Vehicle3 in $Vehicles.get_children():
		if vehicle.finished:
			finished_vehicles.append(vehicle)
			continue

		var cur_progress = get_vehicle_progress(vehicle)
		if not ranks:
			ranks.append(cur_progress)
			ranks_vehicles.append(vehicle)
			continue

		var stop = false
		for i in range(ranks.size()):
			if cur_progress > ranks[i]:
				ranks.insert(i, cur_progress)
				ranks_vehicles.insert(i, vehicle)
				stop = true
				break

		if stop:
			continue

		ranks.append(cur_progress)
		ranks_vehicles.append(vehicle)
	

	finished_vehicles.sort_custom(func(a, b): return a.finish_time < b.finish_time)

	finished_vehicles.append_array(ranks_vehicles)


	for i in range(finished_vehicles.size()):
		finished_vehicles[i].rank = i
	
	UI.update_ranks(finished_vehicles)

	# print("Ranks:")
	# for vehicle: Vehicle3 in finished_vehicles.slice(0, 5):
	# 	print(vehicle.rank, " ", vehicle.finish_time)
	# print("===")


func update_checkpoint(player: Vehicle3):
	if player.respawn_stage:
		return
	
	while true:
		var next_idx = player.check_idx+1 % len(checkpoints)
		if next_idx >= len(checkpoints):
			next_idx -= len(checkpoints)
		if dist_to_checkpoint(player, next_idx) > 0:
			var next_checkpoint: Checkpoint = checkpoints[next_idx]
			
			# Don't advance to next key checkpoint if the previous key checkpoint wasn't reached
			if next_checkpoint.is_key:
				var cur_key_idx = key_checkpoints[next_checkpoint]
				var prev_key_idx = cur_key_idx - 1
				if prev_key_idx < 0:
					prev_key_idx = key_checkpoints.size()-1
				if prev_key_idx != player.check_key_idx and player.check_key_idx != cur_key_idx:
					break
				player.check_key_idx = cur_key_idx

			player.check_idx = next_idx
			if next_idx == 0:
				# Crossed the finish line
				player.lap += 1
				if player.lap > lap_count:
					var time_after_finish = (timer_tick - 1) * (1.0/Engine.physics_ticks_per_second)
					
					var finish_plane_normal: Vector3 = checkpoints[0].transform.basis.z
					var vehicle_vel: Vector3 = player.prev_frame_pre_sim_vel
					var seconds_per_tick = 1.0/Engine.physics_ticks_per_second

					# Determine the ratio of the vehicle_vel to the finish_plane_normal, and determine how much time it had taken to cross the finish line since the last frame
					var final_time = time_after_finish - clamp(dist_to_checkpoint(player, 0) / vehicle_vel.project(finish_plane_normal).length(), 0, seconds_per_tick)
					
					player.set_finished(final_time)
		else:
			break
	
	while true:
		var prev_idx = (player.check_idx - 1) % len(checkpoints)
		if prev_idx < 0:
			prev_idx = len(checkpoints) + prev_idx
		if dist_to_checkpoint(player, player.check_idx) < 0:
			var prev_checkpoint: Checkpoint = checkpoints[prev_idx]
			if prev_checkpoint.is_key:
				var cur_key = player.check_key_idx
				
				#Debug.print([cur_key, key_checkpoints[prev_checkpoint]])
				var prev_key = key_checkpoints[prev_checkpoint]
				var subtract = 0
				if prev_key == 0:
					subtract = key_checkpoints.size()
					prev_key += subtract
					cur_key += subtract
				elif cur_key == 0:
					cur_key += key_checkpoints.size()
				
				if prev_key != cur_key-1 and prev_key != cur_key:
					break
				
				if prev_key == cur_key-1:
					player.check_key_idx = prev_key - subtract
			
			player.check_idx = prev_idx
			if prev_idx == len(checkpoints)-1:
				player.lap -= 1
		else:
			break

	player.check_progress = progress_in_cur_checkpoint(player)


func dist_to_checkpoint(player: Vehicle3, checkpoint_idx: int) -> float:
	var checkpoint = checkpoints[checkpoint_idx % len(checkpoints)] as Node3D
	return checkpoint.transform.basis.z.dot(player.get_node("Front").global_position - checkpoint.global_position)


func progress_in_cur_checkpoint(player: Vehicle3) -> float:
	var dist_behind: float = abs(dist_to_checkpoint(player, player.check_idx))
	var dist_ahead: float = abs(dist_to_checkpoint(player, player.check_idx+1))
	return dist_behind / (dist_behind + dist_ahead)


func get_respawn_point(vehicle: Vehicle3) -> Dictionary:
	var out: Dictionary = {
		"position": Vector3.ZERO,
		"rotation": Vector3.ZERO
	}
	
	var cur_checkpoint = checkpoints[vehicle.check_idx] as Checkpoint
	var player_idx = players_dict.values().find(vehicle)
	
	var spawn_pos = cur_checkpoint.global_position
	var spawn_dir = -cur_checkpoint.transform.basis.z
	var side_direction = cur_checkpoint.transform.basis.x
	var up_dir = cur_checkpoint.transform.basis.y
	
	var side_multi = player_idx % 2
	if side_multi < 0:
		side_multi = -1
	
	var offset = spawn_dir * player_idx * 0.1 + side_direction * 0.2 * side_multi + up_dir * 2.0
	spawn_pos += offset
	
	out.position = spawn_pos
	out.rotation = cur_checkpoint.basis.rotated(up_dir, deg_to_rad(-90)).get_euler()
	
	return out

func update_vehicle_state(vehicle_state: Dictionary, user_id: String):
	if user_id == player_user_id:
		return
	
	if user_id in removed_player_ids:
		return
	
	if not user_id in players_dict.keys():
		var cur_position: Vector3 = Util.to_vector3(vehicle_state["pos"])
		var cur_rotation: Vector3 = Util.to_vector3(vehicle_state["rot"])

		var look_dir: Vector3 = cur_rotation.normalized()
		var up_dir: Vector3 = Vector3(0, 1, 0)

		_add_vehicle(user_id, cur_position, look_dir, up_dir)
		players_dict[user_id].axis_unlock()
	
	players_dict[user_id].apply_state(vehicle_state)
	#players_dict[user_id].call_deferred("apply_state", vehicle_state)


func handle_race_start(data: Dictionary):
	var pings: Dictionary = data.pings as Dictionary
	var ticks_to_start: int = data.ticksToStart as int
	var tick_rate: int = data.tickRate as int

	var seconds_left: float = Util.ticks_to_time_with_ping(ticks_to_start, tick_rate, pings[Network.session.user_id])
	$StartTimer.start(seconds_left)


func _on_match_state(match_state : NakamaRTAPI.MatchData):
	if Global.randPing:
		await get_tree().create_timer(Global.randPing / 1000.0).timeout
	
	var data: Dictionary = JSON.parse_string(match_state.data)
	match match_state.op_code:
		raceOp.SERVER_UPDATE_VEHICLE_STATE:
			update_vehicle_state(data, match_state.presence.user_id)
		raceOp.SERVER_PING:
			Network.send_match_state(raceOp.SERVER_PING, data)
		raceOp.SERVER_RACE_START:
			handle_race_start(data)
		raceOp.SERVER_CLIENT_DISCONNECT:
			_remove_vehicle(data.userId)
		raceOp.SERVER_RACE_OVER:
			finished = true
			Network.ready_match = data.matchId
			finish_order = data.finishOrder
			state = STATE_READY_FOR_RANKINGS
		raceOp.SERVER_SPAWN_ITEM:
			spawn_physical_item(data)
		raceOp.SERVER_DESTROY_ITEM:
			server_destroy_physical_item(data)
		raceOp.SERVER_ITEM_STATE:
			apply_item_state(data)		
		raceOp.SERVER_ABORT:
			UI.change_scene(lobby_scene)
		_:
			print("Unknown match state op code: ", match_state.op_code)


func _on_start_timer_timeout():
	state = STATE_COUNTDOWN


func _on_countdown_timer_timeout():
	state = STATE_RACE
	for vehicle: Vehicle3 in $Vehicles.get_children():
		vehicle.axis_unlock()

func join_next():
	UI.reset_race_ui()
	UI.race_ui.visible = false
	Network.socket.received_match_state.disconnect(_on_match_state)
	UI.change_scene(lobby_scene)

func _on_back_pressed():
	state = STATE_JOIN_NEXT

func _on_next_race_timer_timeout():
	state = STATE_JOIN_NEXT
