extends CharacterBody3D

var physical_item = true
var item_id: String
var owner_id: String
var world: RaceBase
var no_updates: bool = false

var gravity: Vector3
var target_speed: float = 40.0
var despawn_time: float = 30.0
var grace_frames: int = 30
var cur_grace: int = 0

func _enter_tree():
	if Global.MODE1 == Global.MODE1_ONLINE:
		$Area3D.set_collision_mask_value(3, false)
	var thrower = world.players_dict[owner_id] as Vehicle3
	gravity = thrower.gravity
	var offset = thrower.transform.basis.x * (thrower.vehicle_length_ahead * 2)
	var dir_multi = 1.0
	if thrower.input_updown < 0:
		dir_multi = -1.0
		offset = -thrower.transform.basis.x * (thrower.vehicle_length_behind * 2)
	var direction = thrower.transform.basis.x * dir_multi
	
	global_position = thrower.global_position + offset

	# Subtract component of direction along gravity
	direction = direction - direction.project(gravity.normalized())
	direction = direction.normalized()

	var speed = max(0, thrower.linear_velocity.project(direction).length()) + 5
	
	look_at(global_position + direction, -gravity)
	velocity = direction * speed

func _ready():
	$DespawnTimer.start(despawn_time)

func _physics_process(delta):
	if item_id in world.deleted_physical_items:
		self.queue_free()
		return
	
	var speed = velocity.length()
	var new_speed = move_toward(speed, target_speed, delta * 30)
	var ratio = new_speed / speed
	velocity *= ratio
	
	velocity += gravity * delta * 2
	
	#var ray_result = Util.raycast_for_group(self, global_position, global_position + gravity.normalized() * 1.5, "floor", [self])
	#if not ray_result:
		#velocity += gravity * delta * 10
	#else:
		#velocity += gravity * delta * 30
	up_direction = -gravity.normalized()
	move_and_slide()
	
	if is_on_floor():
		velocity = velocity - velocity.project(gravity)
	
	if velocity.length() < 0.01:
		velocity = Vector3(0.1, 0.1, 0.1)
	
	look_at(global_position + velocity.normalized(), -gravity.normalized())

	for i in get_slide_collision_count():
		var col_data = get_slide_collision(i)
		var collider = col_data.get_collider(0)
		if collider.is_in_group("wall"):
			# Bounce off walls
			var normal = col_data.get_normal(0)
			if velocity.length() > 0.1 and velocity.normalized().dot(normal) < 0:
				velocity = velocity.bounce(normal)
				velocity = velocity - velocity.project(gravity.normalized())
	
	cur_grace += 1


func get_state() -> Dictionary:
	return {
		"pos": Util.to_array(global_position),
		"rot": Util.to_array(global_rotation),
		"velocity": Util.to_array(velocity),
		"gravity": Util.to_array(gravity)
	}
	
func set_state(state: Dictionary):
	global_position = Util.to_vector3(state.pos)
	global_rotation = Util.to_vector3(state.rot)
	velocity = Util.to_vector3(state.velocity)
	gravity = Util.to_vector3(state.gravity)
	return


func _on_despawn_timer_timeout():
	world.destroy_physical_item(item_id)


func _on_area_3d_body_entered(body):
	if body == self:
		return
	if "physical_item" in body:
		world.destroy_physical_item(item_id)
		world.destroy_physical_item(body.item_id)
		return
	
	if not body is Vehicle3:
		return
		
	if body.is_network:
		return
	
	if body == world.players_dict[owner_id] and cur_grace <= grace_frames:
		return
	
	body.damage(Vehicle3.DamageType.spin)
	world.destroy_physical_item(item_id)
