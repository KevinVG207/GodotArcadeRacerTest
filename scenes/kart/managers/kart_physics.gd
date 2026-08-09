extends Node

class_name KartPhysics

var kart: Kart;

var cur_physics := PhysicsState.new();
var prev_physics := PhysicsState.new();

var floor_check_grid: Array[Vector3] = []
const FLOOR_CHECK_DISTANCE: float = 5.0

class PhysicsState:
	var delta: float = 0
	var body_state: PhysicsDirectBodyState3D = null
	var floor_normal: Vector3 = Vector3.UP
	var floor_distance: float = 9999
	
	var contacts: Dictionary[ContactType, Array] = {}
	
	var gravity := Vector3.DOWN;
	var gravity_velocity := Vector3.ZERO;
	
	var floor_bounce_velocity := Vector3.ZERO
	
	func velocity() -> Vector3:
		return gravity_velocity + floor_bounce_velocity;

class Contact:
	var collider: Object
	var position: Vector3
	var normal: Vector3
	var type: ContactType

enum ContactType {
	UNKNOWN,
	FLOOR,
	WALL,
	OFFROAD,
	TRICK,
	BOOST,
	FALL,
	OBJECT
}

static var floor_types := [
	ContactType.UNKNOWN,
	ContactType.FLOOR,
	ContactType.TRICK,
	ContactType.BOOST,
	ContactType.OFFROAD
	]

class WallContact extends Contact:
	var bounce := 0.2

class OffroadContact extends Contact:
	var speed_multi := 0.4

class TrickContact extends Contact:
	var boost := BoostType.NORMAL

enum BoostType {
	NONE,
	SMALL,
	NORMAL,
	BIG
}

const MAX_GRAVITY := 10;

func _init(_kart: Kart) -> void:
	self.kart = _kart;

func ready() -> void:
	setup_floor_check_grid()

func setup_floor_check_grid() -> void:
	var fl: Vector3 = kart.front_left.position
	var fr: Vector3 = kart.front_right.position
	var bl: Vector3 = kart.back_left.position
	var br: Vector3 = kart.back_right.position
	var ml: Vector3 = fl.lerp(bl, 0.5)
	var mr: Vector3 = fr.lerp(br, 0.5)
	
	floor_check_grid = [
		fl, fl.lerp(fr, 0.5), fr,
		ml, ml.lerp(mr, 0.5), mr,
		bl, bl.lerp(br, 0.5), br
	]

func integrate_forces(body_state: PhysicsDirectBodyState3D) -> void:
	prev_physics = cur_physics
	cur_physics = PhysicsState.new()
	cur_physics.body_state = body_state
	cur_physics.delta = body_state.step
	
	setup_gravity()
	
	build_contacts()
	
	detect_floor()
	apply_floor_bounce()
	apply_gravity()
	
	apply_maximums()
	
	apply_velocities()
	return

func setup_gravity() -> void:
	cur_physics.gravity_velocity = prev_physics.gravity_velocity

func apply_gravity() -> void:
	cur_physics.gravity_velocity += cur_physics.gravity * cur_physics.delta;

func apply_maximums() -> void:
	cur_physics.gravity_velocity = cur_physics.gravity_velocity.limit_length(MAX_GRAVITY);
	
func apply_velocities() -> void:
	kart.linear_velocity = Vector3.ZERO;
	kart.angular_velocity = Vector3.ZERO;
	
	kart.linear_velocity = cur_physics.velocity();

func raycast_below() -> Array[Vector3]:
	var below_normals: Array[Vector3] = []

	for loc_start_pos: Vector3 in floor_check_grid:
		# loc_start_pos *= vani.scale # TODO: Implement
		var start_pos := kart.to_global(loc_start_pos)
		var end_pos := start_pos + (kart.global_transform.basis.y.normalized() * -FLOOR_CHECK_DISTANCE) # * vani.scale)
		start_pos += kart.global_transform.basis.y.normalized() * 0.1
		# TODO: Revert
		var result := Util.raycast_for_group(kart.get_world_3d().direct_space_state, start_pos, end_pos, "col_floor", [self])
		if result:
			below_normals.append(result.normal)
			var dist := start_pos.distance_to(result.position) - 0.1
			if dist < cur_physics.floor_distance:
				cur_physics.floor_distance = maxf(dist, 0)
	
	return below_normals

func detect_floor() -> void:
	var normals := raycast_below()
	
	if normals.is_empty():
		return

	cur_physics.floor_normal = Util.sum(normals) / normals.size()
	
	if ContactType.FLOOR in cur_physics.contacts:
		cur_physics.floor_distance = 0.0
		cur_physics.gravity_velocity = Vector3.ZERO
	return

func apply_floor_bounce() -> void:
	var float_diff := cur_physics.floor_distance - kart.float_height
	if float_diff > 0:
		return
	float_diff = minf(float_diff, 0)
	float_diff = float_diff ** 2
	print(float_diff)
	var gravity_tick := cur_physics.gravity * cur_physics.delta
	cur_physics.gravity_velocity -= gravity_tick * float_diff * 2
	print("FLOOR BOUNCE VEL: ", cur_physics.floor_bounce_velocity.length())

func build_contacts() -> void:
	var state := cur_physics.body_state
	for i in range(state.get_contact_count()):
		var cur_ground_contact := false
		var collider := state.get_contact_collider_object(i) as CollisionObject3D
		var collision_shape := Util.get_contact_collision_shape(state, i)
		
		if collider is StageObjectCharacterBody3D:
			var object := (collider as StageObjectCharacterBody3D).object_root
			# object._hit_by_vehicle(self)
			print("StageObject no_bounce: ", object.no_bounce)
			# TODO: Ignore this contact when determining wall bounce
			# if object.no_bounce:
				# ignore_wall_slide = true

		# FIXME: Don't use STRINGS. On model import, change to separate type with checkboxes in inspector.
		var groups := collision_shape.get_groups()
		if groups.is_empty():
			groups.append("COL_UNKNOWN")
		for group_raw in groups:
			var group_str := str(group_raw).to_upper()
			if !group_str.begins_with("COL_"):
				continue
			group_str = group_str.substr(4)

			var split_settings := group_str.split("_")
			var type_str := split_settings[0]
			var settings := split_settings.slice(0,0) if split_settings.size() == 1 else split_settings.slice(1)

			if type_str not in ContactType:
				continue

			var contact_type: ContactType = ContactType[type_str]
			if contact_type in floor_types:
				cur_ground_contact = true
			
			var contact: Contact = null

			match contact_type:
				ContactType.FLOOR:
					continue
				ContactType.WALL:
					contact = WallContact.new()
				ContactType.OFFROAD:
					contact = OffroadContact.new()
					if !settings.is_empty():
						match settings[0]:
							"WEAK":
								contact.speed_multi = 0.7
							"STRONG":
								contact.speed_multi = 0.3
				ContactType.BOOST:
					# apply_boost(BoostType.NORMAL)  TODO: Apply boost.
					continue
				ContactType.TRICK:
					contact = TrickContact.new()
					if !settings.is_empty():
						match settings[0]:
							"BIG":
								contact.boost = BoostType.BIG
							"SMALL":
								contact.boost = BoostType.SMALL
			
			if contact == null:
				contact = Contact.new()

			contact.collider = collision_shape
			contact.position = state.get_contact_local_position(i)
			contact.normal = state.get_contact_local_normal(i)
			contact.type = contact_type

			if contact_type not in cur_physics.contacts:
				cur_physics.contacts[contact_type] = []

			cur_physics.contacts[contact_type].append(contact)
		
		if cur_ground_contact:
			var contact := Contact.new()
			contact.collider = collision_shape
			contact.position = state.get_contact_local_position(i)
			contact.normal = state.get_contact_local_normal(i)
			contact.type = ContactType.FLOOR
			if ContactType.FLOOR not in cur_physics.contacts:
				cur_physics.contacts[ContactType.FLOOR] = []

			cur_physics.contacts[ContactType.FLOOR].append(contact)
	return
