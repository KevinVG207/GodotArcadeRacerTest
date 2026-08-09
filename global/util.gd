extends Node3D

const uuid = preload('res://addons/uuid/uuid.gd')

var version: String:
	get():
		var tmp: String = ProjectSettings.get_setting("application/config/version")
		if OS.is_debug_build():
			return tmp + "-dev"
		return tmp

#class Clonable:
	#func clone(new: Clonable) -> Clonable:
		#var prop_list := self.get_property_list()
		#for prop in prop_list:
			#if prop.name not in new:
				#continue
			#if prop.name == "script":
				#new[prop.name] = self[prop.name]
			#else:
				#new[prop.name] = self[prop.name]
			#
		#return new

func get_vehicle_accel(max_speed: float, cur_speed: float, initial_accel: float, exponent: float) -> float:
	var speed_ratio: float = clamp(cur_speed / max_speed, 0, 1)
	return max(-initial_accel * speed_ratio ** exponent + initial_accel, 0)

func sum(array: Array) -> Variant:
	if not array:
		return null
	
	var out: Variant = array[0]
	
	if len(array) == 1:
		return out
	
	for ele: Variant in array.slice(1):
		out += ele
	return out

func raycast_for_group(space_state: PhysicsDirectSpaceState3D, start_pos: Vector3, end_pos: Vector3, group: Variant, ignore_array: Array = [], collision_mask:=0xFFFFFFFF) -> Dictionary:
	if typeof(group) == TYPE_STRING:
		group = [group]
	var out: Dictionary = {}
	var idx := 0
	while idx < 5:
		idx += 1
		var result := space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start_pos, end_pos, collision_mask, ignore_array))
		# Debug.print(result)
		if not result:
			break
		# FIXME: Use shape!
		var collider := result["collider"] as Node3D
		var shape := get_collision_shape_from_idx(collider as CollisionObject3D, result["shape"])
		if is_in_group_list(shape, group):
			out = result
			result["start"] = start_pos
			result["end"] = end_pos
			result["distance"] = result["position"].distance_to(start_pos)
			break
		ignore_array.append(collider)
	ignore_array.clear()
	return out

func is_in_group_list(node: Node, group_list: Array) -> bool:
	for group: String in group_list:
		if node.is_in_group(group):
			return true
	return false

func to_array(v: Vector3) -> Array:
	return [v.x, v.y, v.z]

func to_vector3(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])

func quat_to_array(q: Quaternion) -> Array:
	return [q.x, q.y, q.z, q.w]

func array_to_quat(a: Array) -> Quaternion:
	return Quaternion(a[0], a[1], a[2], a[3])

func sec_to_ticks(sec: float) -> int:
	# Turns seconds into physics ticks
	return int(sec * Engine.physics_ticks_per_second)

func ticks_to_sec(ticks: int) -> float:
	# Turns physics ticks into seconds
	return float(ticks) / Engine.physics_ticks_per_second

func format_time_minutes(seconds: float) -> String:
	var _seconds := ceili(seconds)
	var minutes := floori(_seconds / 60.0)
	_seconds -= minutes * 60
	return str(minutes).pad_zeros(1) + ":" + str(_seconds).pad_zeros(2)

func format_time_ms(seconds: float) -> String:
	var minutes := floori(seconds / 60.0)
	var _seconds := floori(seconds - minutes * 60)
	var ms := floori((seconds - minutes * 60 - _seconds) * 1000)
	return str(minutes).pad_zeros(1) + ":" + str(_seconds).pad_zeros(2) + "." + str(ms).pad_zeros(3)

func get_race_courses() -> Array:
	# All race courses are stored as scenes/race/COURSE_NAME/COURSE_NAME.tscn
	var race_dir := DirAccess.open("res://scenes/levels/race")
	var dirs := race_dir.get_directories()
	var courses := []
	for dir in dirs:
		var course_name: String = dir.split("/")[-1]
		# Ignore test courses
		if course_name[0] == "_":
			continue
		courses.append(course_name)
	courses.sort_custom(func(a: String, b: String) -> bool: return a.to_lower()<b.to_lower())
	return courses

func get_race_course_path(course_name: String) -> String:
	return "res://scenes/levels/race/" + course_name + "/" + course_name + ".tscn"

func get_race_course_name_from_path(path: String) -> String:
	return path.rsplit("/", true, 1)[1].replace(".tscn", "")

func get_vehicles() -> Array:
	# All vehicles are stored as scenes/vehicles/list/NAME.tscn
	var dir := DirAccess.open("res://scenes/vehicles/list")
	var files := dir.get_files()
	var vehicles := []
	for file in files:
		var key: String = file.split("/")[-1].rsplit(".", true, 1)[0]
		vehicles.append(key)
	return vehicles

func get_vehicle_texture(vehicle_name: String) -> CompressedTexture2D:
	return load("res://assets/vehicles/" + vehicle_name + ".png")

func get_vehicle_scene_path(vehicle_name: String) -> String:
	return "res://scenes/vehicles/list/" + vehicle_name + ".tscn"

func ticks_to_time_with_ping(ticks_left: int, tick_rate: int, ping_ms: int) -> float:
	# Debug.print(["Ping: ", ping_ms])
	return (float(ticks_left) / tick_rate) - (ping_ms / 1000.0)

func make_ordinal(n: int) -> String:
	var suffix = ""
	if n % 100 in [11, 12, 13]:
		suffix = "th"
	else:
		match n % 10:
			1:
				suffix = "st"
			2:
				suffix = "nd"
			3:
				suffix = "rd"
			_:
				suffix = "th"
	return str(n) + suffix

func align_with_y(xform: Transform3D, new_y: Vector3) -> Transform3D:
	xform.basis.y = new_y
	xform.basis.x = -xform.basis.z.cross(new_y)
	xform.basis = xform.basis.orthonormalized()
	return xform

func get_path_point_ahead_of_player(player: Vehicle4) -> EnemyPath:
	var points: Array = player.world.all_enemy_points
	var plane_pos: Vector3 = player.get_node("%Front").global_position
	var plane_normal: Vector3 = player.transform.basis.z.normalized()
	
	var filtered_point: EnemyPath
	var filtered_distance := 1000000000.0
	
	for point: EnemyPath in points:
		var dist_ahead: float = plane_normal.dot(point.global_position - plane_pos)
		if dist_ahead >= 0:
			var dist: float = player.global_position.distance_to(point.global_position)
			if dist < filtered_distance:
				filtered_distance = dist
				filtered_point = point
	
	if filtered_point:
		return filtered_point
	
	# Fallback to nearest
	for point: EnemyPath in points:
		var dist: float = player.global_position.distance_to(point.global_position)
		if dist < filtered_distance:
			filtered_distance = dist
			filtered_point = point
	
	return filtered_point

func dist_to_plane(plane_normal: Vector3, plane_pos: Vector3, point: Vector3) -> float:
	return plane_normal.dot(point - plane_pos)

func multi_emit(cont: Node3D, emitting: bool) -> void:
	for child: GPUParticles3D in cont.get_children():
		child.emitting = emitting

func get_random_head() -> Node3D:
	var head_path: String = Global.heads.values().pick_random()
	var head: Node3D = load(head_path).instantiate()
	return head

func remove_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()

func save_string(path: String, data: String) -> void:
	var store_file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	store_file.store_pascal_string(data)
	store_file.close()

func load_string(path: String) -> String:
	var load_file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var data: String = load_file.get_pascal_string()
	load_file.close()
	return data

func save_string_zip(path: String, data: String) -> void:
	var writer := ZIPPacker.new()
	var err := writer.open(path)
	if err != OK:
		print("ERR: Could not open zip file for writing " + path)
		print(err)
		return
	
	writer.start_file("data")
	writer.write_file(data.to_utf8_buffer())
	writer.close_file()
	writer.close()
	return

func load_string_zip(path: String) -> String:
	var reader := ZIPReader.new()
	var err := reader.open(path)
	if err != OK:
		print("ERR: Could not open zip file for reading " + path)
		print(err)
		return ""
	
	var data := reader.read_file("data")
	reader.close()
	return data.get_string_from_utf8()

func save_json(path: String, object: Variant) -> void:
	var store_file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	store_file.store_string(JSON.stringify(object))
	store_file.close()

func load_json(path: String) -> Variant:
	var load_file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var object: Variant = JSON.parse_string(load_file.get_as_text())
	load_file.close()
	return object

func save_var(path: String, object: Variant) -> void:
	var store_file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	store_file.store_var(object)
	store_file.close()
	
func load_var(path: String) -> Variant:
	var load_file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var object: Variant = load_file.get_var()
	load_file.close()
	return object

func doppler_sigmoid(dist_delta: float, max_distance: float) -> float:
	var exp_multi: float = 6/max_distance
	return (1.0/(1+exp(-exp_multi*dist_delta))) + 0.5

# These don't work!
#func save_var_gz(path: String, object: Variant) -> void:
	#var gzip := StreamPeerGZIP.new()
	#gzip.start_compression()
	#gzip.put_data(var_to_bytes(object))
	#gzip.finish()
	#var store_file := FileAccess.open(path, FileAccess.WRITE)
	#store_file.store_buffer(gzip.get_data(gzip.get_available_bytes())[1])
	#store_file.close()
#
#func load_var_gz(path: String) -> Variant:
	#var load_file := FileAccess.open(path, FileAccess.READ)
	#var gzip := StreamPeerGZIP.new()
	#gzip.start_decompression()
	#gzip.put_data(load_file.get_buffer(load_file.get_length()))
	#gzip.finish()
	#var object: Variant = bytes_to_var(gzip.get_data(gzip.get_available_bytes())[1])
	#load_file.close()
	#return object
func get_contact_collision_shape(physics_state: PhysicsDirectBodyState3D, idx: int) -> CollisionShape3D:
		var collider := physics_state.get_contact_collider_object(idx) as CollisionObject3D
		var shape_index := physics_state.get_contact_collider_shape(idx)
		var shape_owner := collider.shape_find_owner(shape_index)
		return collider.shape_owner_get_owner(shape_owner) as CollisionShape3D

func get_collision_shape(collision: KinematicCollision3D, idx: int) -> CollisionShape3D:
	var collider := collision.get_collider(idx) as CollisionObject3D
	if collider == null:
		return null
	var shape_index := collision.get_collider_shape_index(idx)
	var shape_owner := collider.shape_find_owner(shape_index)
	return collider.shape_owner_get_owner(shape_owner) as CollisionShape3D

func get_collision_shape_from_idx(collider: CollisionObject3D, shape_index: int) -> CollisionShape3D:
	var shape_owner := collider.shape_find_owner(shape_index)
	return collider.shape_owner_get_owner(shape_owner) as CollisionShape3D

func center_window(window_id: int = 0) -> void:
	var scr := DisplayServer.window_get_current_screen(window_id)
	var pos := DisplayServer.screen_get_position(scr)
	var siz := DisplayServer.screen_get_size(scr)

	var window_size := DisplayServer.window_get_size()

	var new_pos := Vector2(pos.x + (siz.x - window_size.x) / 2, pos.y + (siz.y - window_size.y) / 2)

	DisplayServer.window_set_position(new_pos, window_id)

func v3_length_squared(v: Vector3) -> float:
	return v.x * v.x + v.y * v.y + v.z * v.z

func v3_length_compare(v: Vector3, length: float) -> float:
	# Returns negative if v is shorter than length, 0 if equal, positive if longer
	return v3_length_squared(v) - length * length

func v3_length_compare_v3(v1: Vector3, v2: Vector3) -> float:
	# Returns negative if v1 is shorter than v2, 0 if equal, positive if longer
	return v3_length_squared(v1) - v3_length_squared(v2)

func round_to_dec(num: Variant, digit: int) -> float:
	return roundf(num * pow(10.0, digit)) / pow(10.0, digit)

func find_race_base_parent(node: Node) -> RaceBase:
	var max_iter := 10
	var iter := 0
	while iter < max_iter:
		node = node.get_parent()
		if node is RaceBase:
			return node
		iter += 1
	return null

func just_pressed_accept_or_cancel() -> bool:
	return Input.is_action_just_pressed("ui_cancel") or Input.is_action_just_pressed("brake") or Input.is_action_just_pressed("brake2") or Input.is_action_just_pressed("accelerate") or Input.is_action_just_pressed("ui_accept")

func get_file_name_from_path(path: String) -> String:
	return path.rsplit("/", true, 1)[1].rsplit(".", true, 1)[0]
