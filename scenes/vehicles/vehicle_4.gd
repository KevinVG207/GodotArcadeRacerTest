extends RigidBody3D

class_name Vehicle4

signal before_update(delta: float)
signal after_update(delta: float)

@export var icon: CompressedTexture2D

@onready var vani: VehicleAnimationTree = %VehicleAnimationTree
@onready var cani: AnimationPlayer = %CharacterAnimationPlayer # TODO: Character animation player
@onready var still_timer: Timer = %StillTurboTimer

var tick: int = -1
var delta: float = 1.0 / Engine.physics_ticks_per_second
var visual_delta := delta * 3.0

var sleep := false

var world: RaceBase = null
var physics_state: PhysicsDirectBodyState3D
var prev_transform: Transform3D = Transform3D.IDENTITY

static var max_displacement_for_sleep := 0.01
static var max_degrees_change_for_sleep := 0.5

@onready var respawn_timer: Timer = %RespawnTimer

@export var radius: float = 2.2
@export var vehicle_height_below: float = 0
@export var vehicle_length_ahead: float = 1.5
@export var vehicle_length_behind: float = 1.5

@export var chara_running_extra_y: float = 0.46

@export var base_max_speed: float = 25
var max_speed := base_max_speed
@export var base_initial_accel: float = 10
@export var base_accel_exponent: float = 10
var initial_accel := base_initial_accel
var accel_exponent := base_accel_exponent
@export var reverse_multi := 0.5
var friction_multi := 1.5
@export var base_grip: float = 100
var grip := base_grip

var cur_speed := 0.0
var start_side_multi: int = 1

var item: UsableItem = null
var can_use_item : = false
var has_dragged_item := false

var gravity := Vector3.ZERO
var gravity_zones: Dictionary = {}
@export var terminal_velocity: float = 3000
var air_frames := 0

var prev_input := VehicleInput.new()
var input := VehicleInput.new()
var item_was_pressed: bool = false

var is_controlled := false
var in_cannon := false

var is_player := true
var is_cpu := false
var use_cpu_logic := false
var is_network := false
var is_replay := false
var user_id: int = 0
var username := "Player"

@export var weight: float = 1.0
var push_force: float = 8.0

@onready var visual_node: Node3D = %Visual
@onready var wheelie_node: Node3D = %WheelieAxis
@onready var cpu_logic: CPULogic = %CPULogic
@onready var audio: VehicleAudio = %VehicleAudio
@onready var network: NetworkPlayer = %NetworkPlayer

var started := false
var finished := false
var check_idx := -1  #:
	#get:
		#return CheckpointManager.fix_check_idx(check_idx)
var check_key_idx := 0
var check_progress := 0.0
var checkpoint: Checkpoint = null
var key_checkpoint: Checkpoint = null
var lap := 0
var rank := 999999
var finish_time := 0.0

var extra_fov := 0.0

var prev_velocity := Velocity.new()
var velocity := Velocity.new()

class Velocity:
	var prop_vel: Vector3 = Vector3.ZERO
	var rest_vel: Vector3 = Vector3.ZERO

	func total() -> Vector3:
		return prop_vel + rest_vel
	
	func grav_component(gravity: Vector3) -> Vector3:
		return rest_vel.project(gravity.normalized())
	
	func to_dict() -> Dictionary:
		return {
			"prop_vel": Util.to_array(prop_vel),
			"rest_vel": Util.to_array(rest_vel)
		}
	
	static func from_dict(dict: Dictionary) -> Velocity:
		var out := Velocity.new()
		out.prop_vel = Util.to_vector3(dict.prop_vel)
		out.rest_vel = Util.to_vector3(dict.rest_vel)
		return out


class VehicleInput:
	var accel := false
	var brake := false
	var steer := 0.0
	var trick := false
	var item := false
	var item_just := false
	var tilt := 0.0
	var mirror := false
	var rewind := false

	func to_dict() -> Dictionary:
		return {
			"accel": accel,
			"brake": brake,
			"steer": steer,
			"trick": trick,
			"item": item,
			"item_just": item_just,
			"tilt": tilt,
			"mirror": mirror,
			"rewind": rewind
		}
	
	static func from_dict(dict: Dictionary) -> VehicleInput:
		var out := VehicleInput.new()
		out.accel = dict.accel
		out.brake = dict.brake
		out.steer = dict.steer
		out.trick = dict.trick
		out.item = dict.item
		out.item_just = dict.item_just
		out.tilt = dict.tilt
		out.mirror = dict.mirror
		out.rewind = dict.rewind
		return out

var prev_contacts := {}
var contacts := {}
var prev_ground_contacts := []
var ground_contacts := []
var ignore_wall_slide := false
var wall_turn_multi := 1.0
var max_wall_turn_multi := 2.0
var prev_grounded := false
var grounded := false
var floor_normal: Vector3 = Vector3.UP
var below_normals := []
var floor_check_grid: Array = []
var floor_check_distance: float = 1.0
var ground_rot_multi: float = 5.0
var air_rot_multi: float = 1.0
var is_stick := false
var stick_speed: float = 5
var in_hop := false
var hop_force: float = 3.5
var hop_frames := 0
var max_hop_frames := 1
var hop_time: float = 0.15
var min_hop_speed := base_max_speed * 0.33
var min_drift_speed := base_max_speed * 0.42
var in_bounce := false
@export var min_bounce_ratio: float = 0.5
var bounce_force: float = 5.0
var bounce_frames: int = 0

@export var outside_drift := false
var in_drift := false
var prev_in_drift := false
var drift_dir := 0
var drift_gauge: float = 0
var drift_gauge_max: float = 100
@export var drift_gauge_multi: float = 55.0
var drift_offset: float = 0.0
@export var outside_drift_slide_angle: float = 45
@onready var max_drift_offset: float = deg_to_rad(outside_drift_slide_angle)
var drift_offset_multi: float = 1.0
@export var drift_tilt: bool = false
@export var drift_tilt_degrees: float = 20.0
var drift_tilt_max := deg_to_rad(drift_tilt_degrees)
var drift_tilt_speed: float = 3.0
# var drift_grip: float = 1.0
# @export var outside_drift_recover_speed: float = 0.2
# @export var ouside_drift_max_grip: float = 0.3

var still_turbo_charge_time: float = drift_gauge_multi / 36.666
var still_turbo_max_speed: float = 1
var still_turbo_ready: bool = false

var along_ground_multi := 0.0
var along_ground_dec := 5.0
var min_angle_to_detach := 10.0

static var wheelie_gauge_max := 100.0
static var wheelie_ticks := 4 * 60
var wheelie_gauge := wheelie_gauge_max
@export var wheelie_gauge_gain := 1.0
var in_wheelie := false
var wheelie_ticks_left := 0
@export var wheelie_offset_y := 0.0
@export var wheelie_offset_z := 0.0

var respawn_stage := RespawnStage.NONE
static var respawn_time: float = 3.5
static var respawn_stage2_time: float = 1.0
var respawn_data := {}

enum RespawnStage {
	NONE,
	FALLING,
	RESPAWNING
}

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

var cur_boost_type: BoostType = BoostType.NONE
@onready var boost_timer: Timer = %BoostTimer
enum BoostType {
	NONE,
	SMALL,
	NORMAL,
	BIG
}

static var boosts: Dictionary[BoostType,Boost] = {
	BoostType.SMALL: Boost.new(0.6, 1.2, 5, 1),
	BoostType.NORMAL: Boost.new(1.5, 1.4, 5, 1),
	BoostType.BIG: Boost.new(2.5, 1.6, 5, 1)
}
class Boost:
	var length: float
	var speed_multi: float
	var initial_accel_multi: float
	var exponent_multi: float

	func _init(_length: float, _speed_multi: float, _initial_accel_multi: float, _exponent_multi: float) -> void:
		length = _length
		speed_multi = _speed_multi
		initial_accel_multi = _initial_accel_multi
		exponent_multi = _exponent_multi

var in_trick := false
var trick_boost_type: BoostType = BoostType.NONE

var steering := 0.0
@export var base_max_turn_speed: float = 80.0
var max_turn_speed := base_max_turn_speed
@export var steer_speed_decrease: float = 0.025
@export var drift_turn_multiplier: float = 1.2
@export var drift_turn_min_multiplier: float = 0.5
@export var air_turn_multiplier: float = 0.5
var turn_speed := 0.0
@export var base_turn_accel: float = 800
var turn_accel := base_turn_accel

static var replay_transparency := 0.75
var standard_colliders: Array[CollisionShape3D] = []

static var trick_safezone_frames := 30
var trick_input_frames := 0
var trick_timer := 0
var trick_timer_length := int(180 * 0.4)

var collided_with: Dictionary[Vehicle4, int] = {}
var colliding_vehicles: Dictionary[Vehicle4, Array] = {}
var colliding_bodies: Array[PhysicsBody3D] = []

enum DamageType {
	NONE,
	SPIN,
	TUMBLE,
	EXPLODE,
	SQUISH
}

var cur_damage_type := DamageType.NONE
var do_damage_type := DamageType.NONE

var targeted_by_dict: Dictionary = {}

var in_water := false
var water_bodies: Dictionary = {}

var countdown_gauge := 0.0
static var countdown_timer := 1.5
var countdown_gauge_max := 0.0
var countdown_gauge_min := 0.0
var countdown_gauge_middle := 0.0
var countdown_gauge_tick_size := 0.0

var visual_event_queue := []

var prev_progress: float = -1
var cur_progress: float = 0

var respawn_boost_enable: bool = false
var respawn_boost_accel_frames: int = 0
var respawn_boost_landed_frames: int = 0
var respawn_boost_safezone_frames: int = 0
static var respawn_boost_safezone_seconds: float = 0.1

var wall_cooldown: int = 0
var catchup_multi: float = 1.0

var in_rewind: bool = false
@onready var min_rewind_frames: int = roundi(1.0 * world.PHYSICS_TICKS_PER_SECOND)
var rewind_start_frame: int = 0
var rewind_frame: int = 0
var exited_rewind: bool = false
var rewind_data: Array[RewindData] = []
@onready var max_rewind_data: int = roundi(60.0 * world.PHYSICS_TICKS_PER_SECOND)

var active_items: Array[PhysicalItem] = []

var running_ani_multi: float = 2.0

class RewindData:
	var pos: Vector3
	var rot: Quaternion
	func _init(p: Vector3, r: Quaternion) -> void:
		pos = p
		rot = r

func _ready() -> void:
	# UI.show_race_ui()
	custom_integrator = true
	%Character.get_node("Body").hide_tail = true
	
	setup_floor_check_grid()
	setup_head()
	setup_colliders()

	setup_countdown_boost()

	respawn_boost_safezone_frames = int(respawn_boost_safezone_seconds * Engine.physics_ticks_per_second)

	max_hop_frames = int(hop_time * Engine.physics_ticks_per_second)

	checkpoint = CheckpointManager.last_segment.last
	key_checkpoint = checkpoint

	if is_replay:
		recursive_set_transparency(visual_node)

func setup_countdown_boost() -> void:
	# Countdown boost
	countdown_gauge_tick_size = 1.0 / Engine.physics_ticks_per_second
	countdown_gauge_max = countdown_gauge_tick_size * countdown_timer * Engine.physics_ticks_per_second
	countdown_gauge_middle = countdown_gauge_max * 0.75
	countdown_gauge_min = countdown_gauge_max * 0.5

func setup_colliders() -> void:
	for child: Node in get_children():
		if child is CollisionShape3D:
			standard_colliders.append(child)

func recursive_set_transparency(n: Node) -> void:
	if n is GeometryInstance3D:
		n.transparency = replay_transparency
		n.cast_shadow = false
	
	for c: Node in n.get_children():
		recursive_set_transparency(c)

func setup_head() -> void:
	$Visual/WheelieAxis/Character/Body.get_node("%Head").add_child(Util.get_random_head())

func setup_floor_check_grid() -> void:
	var fl: Vector3 = %FrontLeft.position
	var fr: Vector3 = %FrontRight.position
	var bl: Vector3 = %BackLeft.position
	var br: Vector3 = %BackRight.position
	var ml: Vector3 = fl.lerp(bl, 0.5)
	var mr: Vector3 = fr.lerp(br, 0.5)
	
	floor_check_grid = [
		fl, fl.lerp(fr, 0.5), fr,
		ml, ml.lerp(mr, 0.5), mr,
		bl, bl.lerp(br, 0.5), br
	]

func _process(delta: float) -> void:
	while visual_event_queue.size() > 0:
		var event: Callable = visual_event_queue.pop_at(0)
		event.call()
	
	handle_particles()
	handle_animations()
	
	if Input.is_action_just_pressed("item"):
		item_was_pressed = true

	if is_player:
		UI.race_ui.update_speed(velocity.total().length())

		update_alerts(delta)

		update_fov()

func handle_animations() -> void:
	cani.speed_scale = 1.0
	if cani.assigned_animation == "running_shoes_run":
		cani.speed_scale = (cur_speed / max_speed) * running_ani_multi

func update_alerts(delta: float) -> void:
	for alert_object: Node3D in targeted_by_dict:
		var tex: CompressedTexture2D = targeted_by_dict[alert_object]
		UI.race_ui.update_alert(alert_object, tex, self, world.player_camera, delta)
	return

func update_fov() -> void:
	if cur_speed > base_max_speed:
		extra_fov = (cur_speed - base_max_speed) * 0.3
	else:
		extra_fov = 0.0

func handle_particles() -> void:
	handle_drift_particles()
	handle_exhaust_particles()

func handle_exhaust_particles() -> void:
	Util.multi_emit(%ExhaustIdle, false)
	Util.multi_emit(%ExhaustBoost, false)
	
	if cur_boost_type != BoostType.NONE:
		Util.multi_emit(%ExhaustBoost, true)
		return
	Util.multi_emit(%ExhaustIdle, true)


func handle_drift_particles() -> void:
	Util.multi_emit(%DriftCenterCharging, false)
	Util.multi_emit(%DriftCenterCharged, false)
	Util.multi_emit(%DriftLeftCharging, false)
	Util.multi_emit(%DriftLeftCharged, false)
	Util.multi_emit(%DriftRightCharging, false)
	Util.multi_emit(%DriftRightCharged, false)
	
	if in_drift:
		if drift_gauge >= drift_gauge_max:
			if drift_dir > 0:
				Util.multi_emit(%DriftLeftCharged, true)
			else:
				Util.multi_emit(%DriftRightCharged, true)
		else:
			if drift_dir > 0:
				Util.multi_emit(%DriftLeftCharging, true)
			else:
				Util.multi_emit(%DriftRightCharging, true)
	elif !still_timer.is_stopped():
		Util.multi_emit(%DriftCenterCharging, true)
	elif still_turbo_ready:
		Util.multi_emit(%DriftCenterCharged, true)

func visual_tick() -> void:
	set_inputs()

func _integrate_forces(new_physics_state: PhysicsDirectBodyState3D) -> void:
	physics_state = new_physics_state
	tick += 1
	delta = new_physics_state.step
	visual_delta += delta

	prev_in_drift = in_drift
	
	# if Input.is_action_just_pressed("_F2"):
	# 	damage(DamageType.SQUISH)

	if is_replay:
		return
		
	update_progress()
	
	update_rewind_state()
	handle_rewind()
	
	set_control()
	set_do_damage()

	before_update.emit(delta)
	
	if !in_rewind:
		handle_sleep()
		handle_failsafe_timer()

	if tick % 3 == 0:
		visual_tick()
		visual_delta = 0.0

	if !in_rewind:
		respawn_if_too_low()
		detect_collisions()
		
	determine_gravity()

	if !in_rewind:
		handle_item()

		handle_steer()

		handle_countdown_gauge()

		apply_network_drift()

	apply_velocities()

	apply_rotations()

	if !in_rewind:
		apply_drift_tilt()

	prev_transform = transform

	after_update.emit(delta)
	return

func set_control() -> void:
	if is_network:
		return
	if is_player:
		is_controlled = false
		is_cpu = false
	for item: PhysicalItem in active_items:
		if item.control_vehicle:
			is_controlled = true
			is_cpu = true
			break

func set_do_damage() -> void:
	do_damage_type = DamageType.NONE
	for item: PhysicalItem in active_items:
		if item.do_damage_type != DamageType.NONE:
			do_damage_type = item.do_damage_type
			break

func update_rewind_state() -> void:
	exited_rewind = false
	
	if !is_player or is_network:
		in_rewind = false
		return
	
	if !in_rewind:
		rewind_data.append(RewindData.new(global_position, global_basis.get_rotation_quaternion()))
		if rewind_data.size() >= max_rewind_data:
			rewind_data.pop_front()
		#print("REWIND DATA SIZE: ", rewind_data.size())
	
	if !started or respawn_stage != RespawnStage.NONE:
		rewind_data.clear()
	
	if !in_rewind and !input.rewind:
		return
	
	if !started:
		in_rewind = false
		return
	
	if active_items.size() > 0:
		in_rewind = false
		return

	#if is_player:
		#print(min_rewind_frames, " ", rewind_start_frame - rewind_frame)
	
	if in_rewind and ((!input.rewind and rewind_start_frame - rewind_frame > min_rewind_frames) or rewind_frame <= 0):
		in_rewind = false
		exited_rewind = true
		rewind_data.resize(rewind_frame)
		return
	
	if in_rewind and input.rewind:
		in_rewind = true
		return
	
	if !in_rewind and input.rewind:
		in_rewind = can_start_rewind()
		if in_rewind:
			# start rewind.
			rewind_frame = rewind_data.size() - 1
			rewind_start_frame = rewind_frame

func can_start_rewind() -> bool:
	if rewind_data.size() < min_rewind_frames:
		return false
	return true

func handle_rewind() -> void:
	if !started:
		return
	
	if exited_rewind:
		velocity = Velocity.new()
		cur_speed = 0.0
		if input.accel:
			cur_speed = max_speed * 0.5
		global_position += transform.basis.y.normalized() * 0.1
		return
	
	if !in_rewind:
		return
	
	rewind_frame = maxi(rewind_frame - 2, 0)
	input.steer = 0.0
	input.brake = false
	var state: RewindData = rewind_data[rewind_frame]

	global_position = state.pos
	global_transform.basis = Basis(state.rot)

func update_progress() -> void:
	prev_progress = cur_progress
	cur_progress = CheckpointManager.get_progress(self)

func handle_failsafe_timer() -> void:
	if is_cpu:
		cpu_logic.handle_failsafe_timer()

func handle_countdown_gauge() -> void:
	if started:
		return
	
	if world.state != world.STATE_COUNTING_DOWN:
		return
	
	if input.accel:
		countdown_gauge += countdown_gauge_tick_size
	else:
		countdown_gauge -= countdown_gauge_tick_size
	countdown_gauge = maxf(countdown_gauge, 0)

func handle_sleep() -> void:
	sleep = false
	if !is_network and Util.v3_length_compare(velocity.prop_vel, 0.01) and prev_transform.origin.distance_to(transform.origin) < max_displacement_for_sleep and prev_transform.basis.x.angle_to(transform.basis.x) < max_degrees_change_for_sleep and prev_transform.basis.y.angle_to(transform.basis.y) < max_degrees_change_for_sleep and prev_transform.basis.z.angle_to(transform.basis.z) < max_degrees_change_for_sleep:
		transform = prev_transform
		sleep = true

func respawn_if_too_low() -> void:
	if global_position.y < world.fall_failsafe:
		respawn()

func respawn() -> void:
	if respawn_stage != RespawnStage.NONE:
		return
	
	if is_network:
		return
		
	if in_cannon:
		return
	
	respawn_stage = RespawnStage.FALLING
	if item and "remove" in item:
		item.remove()
	else:
		remove_item()
	respawn_timer.start(respawn_time)
	if is_player:
		world.player_camera.do_respawn()

func set_inputs() -> void:
	prev_input = input
	input = VehicleInput.new()

	# FIXME: Deal with just_pressed situations correctly. Maybe add them to VehicleInput?
	# Then whatever sets just_pressed should update inside integrate_forces so it only gets set for 1 physics tick.

	# Some inputs that don't affect gameplay might be set at any point
	if is_player and get_window().has_focus():
		input.mirror = Input.is_action_pressed("mirror")
	
	if in_cannon:
		return
	
	if cur_damage_type != DamageType.NONE:
		return

	if respawn_stage != RespawnStage.NONE:
		return

	if is_cpu or use_cpu_logic:
		cpu_logic.set_inputs(visual_delta)
		return

	if is_controlled:
		return
	
	if finished:
		return
	
	if !get_window().has_focus():
		return

	input.accel = Input.is_action_pressed("accelerate")
	input.brake = Input.is_action_pressed("brake") or Input.is_action_pressed("brake2")
	input.steer = Input.get_axis("right", "left")
	input.trick = Input.is_action_pressed("trick")
	input.item = Input.is_action_pressed("item")
	input.item_just = item_was_pressed
	item_was_pressed = false
	input.tilt = Input.get_axis("down", "up")
	input.rewind = Input.is_action_pressed("rewind")
	return


func detect_collisions() -> void:
	set_col_layer()

	handle_body_collisions()

	build_contacts()

	determine_grounded()
	determine_stick()
	determine_max_speed_and_accel()
	
	if grounded:
		air_frames = 0
	else:
		air_frames += 1

	determine_floor_normal()
	return

func determine_gravity() -> void:
	gravity = world.base_gravity

	if gravity_zones.is_empty():
		return

	var zones := gravity_zones.values()
	zones.sort_custom(func(a: GravityZone.GravityZoneParams, b: GravityZone.GravityZoneParams) -> bool: return a.priority > b.priority)
	gravity = zones[0].direction * world.base_gravity.length() * zones[0].multiplier
	
	for item: PhysicalItem in active_items:
		gravity *= item.gravity_multi

func determine_grounded() -> void:
	prev_grounded = grounded
	grounded = !ground_contacts.is_empty()
	return

func determine_stick() -> void:
	is_stick = false
	if air_frames < 15:
		var ray_origin := transform.origin
		var ray_end := ray_origin + gravity.normalized() * 1.4
		var ray_result := world.space_state.intersect_ray(PhysicsRayQueryParameters3D.create(ray_origin, ray_end, 0xFFFFFFFF, [self]))

		if ray_result:
			is_stick = true
			grounded = true
			# keep_grav = true

func determine_max_speed_and_accel() -> void:
	if in_hop and air_frames < 30:
		return
	max_speed = base_max_speed
	max_speed *= cpu_logic.speed_multi
	for item: PhysicalItem in active_items:
		max_speed *= item.speed_multi
	initial_accel = base_initial_accel
	for item: PhysicalItem in active_items:
		initial_accel *= item.accel_multi
	
	accel_exponent = base_accel_exponent
	grip = base_grip # * drift_grip
	apply_offroad_speed_multi()
	apply_water_grip()
	apply_boost_speed_multi()
	apply_turn_speed_reduction()
	apply_damage_speed_reduction()
	return

func apply_offroad_speed_multi() -> void:
	if ContactType.OFFROAD not in contacts:
		return
	
	if cur_boost_type != BoostType.NONE:
		return
	
	for item: PhysicalItem in active_items:
		if item.ignore_offroad:
			return
	
	var speed_multi := 1.0
	for contact: OffroadContact in contacts[ContactType.OFFROAD]:
		if contact.speed_multi < speed_multi:
			speed_multi = contact.speed_multi
	
	max_speed *= speed_multi
	grip *= 0.5
	return

func apply_water_grip() -> void:
	if in_water:
		grip *= 0.7

func apply_boost_speed_multi() -> void:
	if cur_boost_type == BoostType.NONE:
		return
	
	var cur_boost: Boost = boosts[cur_boost_type]
	max_speed *= cur_boost.speed_multi
	initial_accel *= cur_boost.initial_accel_multi
	accel_exponent *= cur_boost.exponent_multi

func apply_turn_speed_reduction() -> void:
	max_speed -= abs(turn_speed) * steer_speed_decrease
	return

func apply_damage_speed_reduction() -> void:
	if cur_damage_type == DamageType.SQUISH:
		max_speed *= 0.5
	elif !%SquishTimer.is_stopped():
		max_speed *= 0.8

func determine_floor_normal() -> void:
	if !ground_contacts:
		return
	
	raycast_below()

	var normals := below_normals
	#normals = []
	
	# TODO: Check if this is needed. Issues with object collisions!
	#if normals.is_empty():
		## Naive floor normal detection
		#for contact: Contact in ground_contacts:
			#normals.append(contact.normal)
	
	if normals.is_empty():
		return

	floor_normal = Util.sum(normals) / normals.size()
	return

func raycast_below() -> void:
	below_normals = []

	for loc_start_pos: Vector3 in floor_check_grid:
		loc_start_pos *= vani.scale
		var start_pos := to_global(loc_start_pos)
		var end_pos := start_pos + (transform.basis.y.normalized() * -floor_check_distance * vani.scale)
		# TODO: Revert
		var result := Util.raycast_for_group(world.space_state, start_pos, end_pos, "col_floor", [self])
		if result:
			below_normals.append(result.normal)


func set_col_layer() -> void:
	if !is_player:
		set_collision_layer_value(2, false)
		set_collision_layer_value(3, true)
	else:
		set_collision_layer_value(2, true)
		set_collision_layer_value(3, false)

func handle_body_collisions() -> void:
	expire_vehicle_collisions()
	build_body_collisions()
	handle_vehicle_collisions()
	#handle_stage_object_collisions()

#func handle_stage_object_collisions() -> void:
	#for body in colliding_bodies:
		#if not body is StageObjectCharacterBody3D:
			#continue
		#var object := (body as StageObjectCharacterBody3D).object_root
		#object._hit_by_vehicle(self)

func expire_vehicle_collisions() -> void:
	var keys := collided_with.keys()
	for vehicle: Vehicle4 in keys:
		collided_with[vehicle] -= 1
		if collided_with[vehicle] <= 0:
			collided_with.erase(vehicle)
	return

func build_body_collisions() -> void:
	colliding_vehicles.clear()
	colliding_bodies.clear()
	
	for shape: ShapeCast3D in %PlayerCollision.get_children():
		if !shape.enabled:
			continue
		shape.force_shapecast_update()
		for i in range(shape.get_collision_count()):
			var collider: Node3D = shape.get_collider(i)
			if collider == self:
				continue
			
			colliding_bodies.append(collider)
			
			if collider is Vehicle4:
				var col_vehicle := collider as Vehicle4
				if col_vehicle not in colliding_vehicles:
					colliding_vehicles[col_vehicle] = []
				colliding_vehicles[col_vehicle].append(shape.get_collision_point(i))

func handle_vehicle_collisions() -> void:
	for other: Vehicle4 in colliding_vehicles.keys():
		if do_damage_type != DamageType.NONE:
			other.damage(do_damage_type)

		# if velocity.total().length() < other.velocity.total().length():
		if Util.v3_length_compare_v3(velocity.total(), other.velocity.total()) < 0:
			continue

		var avg_point: Vector3 = Util.sum(colliding_vehicles[other]) / len(colliding_vehicles[other])
		
		var my_weight: float = weight * remap(min(velocity.total().length(), 2*max_speed), 0, 2*max_speed, 1.0, 2.0)
		var their_weight: float = other.weight * remap(min(other.velocity.total().length(), 2*other.max_speed), 0, 2*other.max_speed, 1.0, 2.0)

		var my_weight_ratio: float = their_weight / my_weight
		var their_weight_ratio: float = my_weight / their_weight

		var my_force: float = push_force * my_weight_ratio
		var their_force: float = push_force * their_weight_ratio

		
		var my_dir: Vector3 = (global_transform.origin - avg_point).project(global_transform.basis.x).normalized()
		var their_dir: Vector3 = (other.global_transform.origin - avg_point).project(other.global_transform.basis.x).normalized()
		# var my_dir: Vector3 = Plane(prev_transform.basis.y).project(prev_transform.origin - avg_point).normalized()
		# var their_dir: Vector3 = Plane(other.prev_transform.basis.y).project(other.prev_transform.origin - avg_point).normalized()
		
		apply_push(my_force * my_dir, other)
		other.apply_push(their_force * their_dir, self)
	return

func apply_push(force: Vector3, vehicle: Vehicle4) -> void:
	# if do_damage != DamageType.none:
	# 	return
	
	if vehicle in collided_with:
		return
	
	if vehicle.do_damage_type == DamageType.SQUISH or do_damage_type == DamageType.SQUISH:
		return
	
	collided_with[vehicle] = roundi(0.05 * Engine.physics_ticks_per_second)

	velocity.rest_vel += force

func build_contacts() -> void:
	prev_contacts = contacts
	contacts = {}
	prev_ground_contacts = ground_contacts
	ground_contacts = []
	ignore_wall_slide = false

	for i in range(physics_state.get_contact_count()):
		var cur_ground_contact := false
		var collider := physics_state.get_contact_collider_object(i) as CollisionObject3D
		var collision_shape := Util.get_contact_collision_shape(physics_state, i)
		
		if collider is StageObjectCharacterBody3D:
			var object := (collider as StageObjectCharacterBody3D).object_root
			object._hit_by_vehicle(self)
			print("StageObject no_bounce: ", object.no_bounce)
			if object.no_bounce:
				ignore_wall_slide = true

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
				ContactType.WALL:
					var point := global_position + (global_transform.basis.y * -vehicle_height_below)
					
					var in_front_half := Util.dist_to_plane(velocity.total().normalized(), global_position, physics_state.get_contact_local_position(i))
					if in_front_half < 0:
						continue
					
					# var dist_above_floor = transform.basis.y.dot(physics_state.get_contact_local_position(i) - point)
					var dist_above_floor := Util.dist_to_plane(transform.basis.y, point, physics_state.get_contact_local_position(i))
					if dist_above_floor < 0.05 and not collision_shape.is_in_group("col_bonk"):
						continue

					contact = WallContact.new()
					# TODO: Find a new way to do this without the shape3ds
					#if collider.get("physics_material_override") and collider.physics_material_override.get("bounce"):
						#contact.bounce = collider.physics_material_override.bounce
				ContactType.OFFROAD:
					contact = OffroadContact.new()
					if !settings.is_empty():
						match settings[0]:
							"WEAK":
								contact.speed_multi = 0.7
							"STRONG":
								contact.speed_multi = 0.3
				ContactType.BOOST:
					apply_boost(BoostType.NORMAL)
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
			contact.position = physics_state.get_contact_local_position(i)
			contact.normal = physics_state.get_contact_local_normal(i)
			contact.type = contact_type

			if contact_type not in contacts:
				contacts[contact_type] = []

			contacts[contact_type].append(contact)
		
		if cur_ground_contact:
			var contact := Contact.new()
			contact.collider = collision_shape
			contact.position = physics_state.get_contact_local_position(i)
			contact.normal = physics_state.get_contact_local_normal(i)
			contact.type = ContactType.FLOOR
			ground_contacts.append(contact)
	return

func apply_boost(boost_type: BoostType) -> void:
	if boost_type < cur_boost_type:
		return
	
	for item: PhysicalItem in active_items:
		if item.ignore_boost:
			cur_boost_type = BoostType.NONE
			boost_timer.start(0)
			return
	
	cur_boost_type = boost_type
	boost_timer.start(boosts[boost_type].length)

func stop_boost() -> void:
	cur_boost_type = BoostType.NONE
	boost_timer.stop()

func handle_steer() -> void:
	angular_velocity = Vector3.ZERO
	steering = 0.0
	turn_accel = base_turn_accel
	for item: PhysicalItem in active_items:
		turn_accel *= item.turn_multi

	# if respawn_stage:
	# 	return
	steering = clampf(input.steer, -1.0 * catchup_multi*catchup_multi*catchup_multi, 1.0 * catchup_multi*catchup_multi*catchup_multi)

	if in_drift:
		steering = drift_dir * remap(steering * drift_dir, -1, 1, drift_turn_min_multiplier, drift_turn_multiplier)

	max_turn_speed = base_max_turn_speed
	max_turn_speed *= cpu_logic.turn_speed_multi
	for item: PhysicalItem in active_items:
		max_turn_speed *= item.turn_multi
	max_turn_speed = 0.5/(2*max(0.001, cur_speed)+1) + max_turn_speed
	var turn_target := steering * max_turn_speed * wall_turn_multi
	
	if hop_frames > 0:
		var multi := (float(hop_frames) / max_hop_frames) * 0.5 + 1
		turn_target *= multi
		turn_accel *= multi

	turn_speed = move_toward(turn_speed, turn_target, turn_accel * delta)
	
	if is_controlled:
		turn_speed = turn_target

	var multi := 1.0 if grounded else air_turn_multiplier

	if started:
		transform.basis = transform.basis.rotated(transform.basis.y, deg_to_rad(turn_speed * delta * multi))
	return

func apply_velocities() -> void:
	prev_velocity = velocity
	velocity = Velocity.new()
	
	if in_rewind:
		return
	
	velocity.prop_vel = prev_velocity.prop_vel
	velocity.rest_vel = prev_velocity.rest_vel

	collide_vehicles()
	# collide_walls()

	if !is_network:
		bounce_walls()
	
	handle_bounce()
	
	handle_respawn()
	
	apply_friction()

	if respawn_stage != RespawnStage.RESPAWNING:
		if started:
			handle_trick()
			handle_hop()
			handle_drift()
			#handle_wheelie()

		handle_standstill_turbo()

		apply_gravity()

		stick_to_ground()

		apply_acceleration()

		outside_drift_force()

		var grip_multi := pow(grip / base_grip, 2)

		if started:
			velocity.prop_vel = prev_velocity.prop_vel.slerp(transform.basis.z.normalized().rotated(transform.basis.y.normalized(), drift_offset) * cur_speed * catchup_multi, clampf(grip_multi, 0, 1))

		rotate_accel_along_floor()
		
		for item: PhysicalItem in active_items:
			velocity.rest_vel += item.rest_vel


	linear_velocity = velocity.total()

	failsafe()
	return

func failsafe() -> void:
	if !velocity.prop_vel.is_finite():
		print("PANIC: " + username + " Prop vel infinite! Setting to 0")
		velocity = prev_velocity
	if !velocity.rest_vel.is_finite():
		print("PANIC: " + username + " Rest vel is infinite! Setting to 0")
		velocity = prev_velocity
	
	if !linear_velocity.is_finite():
		print("PANIC: " + username + " Lin_vel is infinite! Setting to 0")
		linear_velocity = velocity.total()
	
	if !linear_velocity.is_finite():
		print("PANIC: FAILSAFE FAILED! SETTING ALL VELOCITY TO ZERO!")
		velocity = Velocity.new()
		linear_velocity = velocity.total()

func collide_vehicles() -> void:
	return

func collide_walls() -> void:
	if is_controlled:
		return

	# Bounce of all walls?
	# Reduce speed to minimum after all contacts?
	return

func apply_friction() -> void:
	if !grounded:
		return
	
	var grav_component := velocity.grav_component(gravity)
	var velocity_not_gravity := velocity.rest_vel - grav_component
	velocity_not_gravity = velocity_not_gravity.move_toward(Vector3.ZERO, delta * grip)
	velocity.rest_vel = velocity_not_gravity + grav_component


func bounce_walls() -> void:
	if is_controlled:
		return
	
	if ContactType.WALL not in contacts:
		return
	
	if ignore_wall_slide:
		return
	
	#if is_network:
		#network.teleport_to_network_now()
		#return
	
	var avg_normal := Vector3.ZERO
	var wall_contacts: Array = contacts[ContactType.WALL]

	for contact: WallContact in wall_contacts:
		avg_normal += contact.normal
	
	avg_normal /= wall_contacts.size()

	var bonk := false
	var bounce_ratio: float = 0.2
	for contact: WallContact in wall_contacts:
		if contact.collider.is_in_group("col_bonk"):
			bonk = true
		if contact.collider.get("physics_material_override") and contact.collider.physics_material_override.get("bounce"):
			var cur_bounce_ratio: float = contact.collider.physics_material_override.bounce
			if cur_bounce_ratio > bounce_ratio:
				bounce_ratio = cur_bounce_ratio
	
	bounce_ratio += 0.2
	
	var prev_vel := prev_velocity.total() - prev_velocity.grav_component(gravity)

	# If we are already moving away from the wall, don't bounce
	var dp := avg_normal.normalized().dot(prev_vel.normalized())

	if dp > 0:
		return

	var min_bounce_speed := max_speed * min_bounce_ratio if dp < 0.50 else 1000.0
	var perp_vel := prev_vel.project(avg_normal).length()

	if !in_bounce and (dp < 0.60 or bonk) and perp_vel > min_bounce_speed:
		# Get the component of the linear velocity that is perpendicular to the wall
		var new_total_vel := prev_vel.bounce(avg_normal.normalized()) * bounce_ratio
		velocity.prop_vel = new_total_vel.project(transform.basis.z.normalized())
		velocity.rest_vel = new_total_vel - velocity.prop_vel
		velocity.rest_vel -= velocity.grav_component(gravity)
		velocity.rest_vel += -gravity.normalized() * bounce_force
		in_bounce = true
		bounce_frames = 0
	else:
		# Slide along wall
		var on_grav_plane := prev_velocity.total().slide(gravity.normalized())
		var wall_on_grav_plane := avg_normal.slide(gravity.normalized())
		var tmp := on_grav_plane.project(wall_on_grav_plane.normalized())
		var new_total_vel := on_grav_plane - tmp
		var grav_comp := velocity.grav_component(gravity)
		if grav_comp.normalized().dot(gravity.normalized()) < 0:
			grav_comp = Vector3.ZERO
		velocity.prop_vel = new_total_vel.project(transform.basis.z.normalized())
		velocity.rest_vel = new_total_vel - velocity.prop_vel
		velocity.rest_vel += grav_comp

		# FIXME: The velocity ends up with NAN in rare cases?
		if !velocity.total().is_finite():
			print("PANIC: DURING SLIDE ALONG WALL, VELOCITY NAN")
			velocity = prev_velocity
	cur_speed = velocity.prop_vel.length()
	if velocity.prop_vel.normalized().dot(global_transform.basis.z.normalized()) < 0:
		cur_speed = -cur_speed
	prev_velocity = velocity

func handle_respawn() -> void:
	freeze = false

	handle_respawn_boost()

	if respawn_stage == RespawnStage.NONE:
		return
	
	if respawn_timer.is_stopped():
		respawn_stage = RespawnStage.NONE
		return
	
	if respawn_stage == RespawnStage.FALLING and $RespawnTimer.time_left <= respawn_stage2_time:
		respawn_stage = RespawnStage.RESPAWNING
		respawn_data = world.get_respawn_point(self)
		
		for zone: Node3D in gravity_zones:
			zone.remove_vehicle(self)
		
		if respawn_data.gravity_zone:
			respawn_data.gravity_zone.add_vehicle(self)
		
		if is_player:
			world.player_camera.instant = true
			world.player_camera.undo_respawn()
	
	if respawn_stage == RespawnStage.RESPAWNING:
		stop_movement()
		global_position = respawn_data.position
		global_rotation = respawn_data.rotation
		if world.player_camera.target == self:
			world.player_camera.target_gravity = gravity

func handle_respawn_boost() -> void:
	if !respawn_boost_enable and respawn_stage == RespawnStage.RESPAWNING:
		respawn_boost_enable = true
		respawn_boost_accel_frames = 0
		respawn_boost_landed_frames = 0
	
	if !respawn_boost_enable:
		return
	
	if input.accel:
		respawn_boost_accel_frames += 1
	else:
		respawn_boost_accel_frames = 0
	
	var landed := contacts.has(ContactType.FLOOR)

	if landed or respawn_boost_landed_frames > 0:
		respawn_boost_landed_frames += 1
	
	if respawn_boost_landed_frames > respawn_boost_safezone_frames:
		respawn_boost_enable = false
		return
	
	if landed and respawn_boost_accel_frames and respawn_boost_accel_frames < respawn_boost_safezone_frames:
		apply_boost(BoostType.SMALL)


func handle_trick() -> void:
	trick_input_frames = maxi(trick_input_frames - 1, 0)
	trick_timer = maxi(trick_timer - 1, 0)

	if input.trick:
		trick_input_frames = trick_safezone_frames
	
	if ContactType.TRICK in prev_contacts and !ground_contacts:
		# Trick can begin
		trick_timer = trick_timer_length
		for contact: TrickContact in prev_contacts[ContactType.TRICK]:
			if contact.boost > trick_boost_type:
				trick_boost_type = contact.boost
	
	if trick_input_frames and trick_timer and trick_timer < (trick_timer_length - 10):
		trick_input_frames = 0
		trick_timer = 0
		in_trick = true
		start_hop()
	
	if ground_contacts and in_trick:
		in_trick = false
		trick_boost_type = BoostType.NONE
		apply_boost(BoostType.NORMAL)
	
	if ground_contacts:
		trick_input_frames = 0
		trick_timer = 0

func handle_hop() -> void:
	if !in_hop and grounded and input.accel and input.brake and !prev_input.brake and cur_speed > min_hop_speed:
		# Perform hop
		prev_input.brake = true
		start_hop()

	if in_hop:
		hop_frames = max(0, hop_frames - 1)

		# if hop_frames < 9:
		# 	velocity.rest_vel += -gravity * 0.03
		# 	is_stick = false

		var hop_distance: float = 0.05 * (float(hop_frames) / max_hop_frames) * (delta / (1.0 / Engine.physics_ticks_per_second))
		global_position += global_transform.basis.y * hop_distance
		
		# if input.steer != 0 and drift_dir == 0 and hop_frames > 30:
		if turn_speed != 0 and !in_drift:
			drift_dir = 1 if turn_speed > 0 else -1

		if hop_frames == max_hop_frames - 1:
			return

		if ground_contacts:
			in_hop = false
			hop_frames = 0
			if input.brake and cur_speed > min_drift_speed and drift_dir != 0:
				in_drift = true
				drift_gauge = 0
	return

func handle_bounce() -> void:
	if in_bounce:
		bounce_frames += 1

		if bounce_frames < 30:
			is_stick = false
		
		if bounce_frames >= 30:
			bounce_frames = 0
			in_bounce = false

func start_hop() -> void:
	if in_hop:
		return
	in_hop = true
	hop_frames = max_hop_frames
	
	if air_frames and hop_frames < 2:
		if in_trick:
			hop_frames = int(max_hop_frames * 0.5)
		else:
			hop_frames = 0
	return

func handle_drift() -> void:
	if !in_drift:
		return
	
	if cur_speed < min_drift_speed:
		in_drift = false
		drift_dir = 0

	if !(input.brake and input.accel):
		in_drift = false
		drift_dir = 0
		if input.accel and drift_gauge >= drift_gauge_max:
			apply_boost(BoostType.SMALL)
		return
	
	drift_gauge += remap(abs(steering), drift_turn_min_multiplier, drift_turn_multiplier, 1, 2) * drift_gauge_multi * delta
	drift_gauge = clampf(drift_gauge, 0, drift_gauge_max)
	return

func handle_standstill_turbo() -> void:
	if input.brake and !input.accel:
		still_timer.stop()
		still_turbo_ready = false

	if prev_input.brake and !input.brake:
		prev_input.brake = false
		still_timer.stop()
		if still_turbo_ready:
			still_turbo_ready = false
			apply_boost(BoostType.SMALL)

func stick_to_ground() -> void:
	if !is_stick:
		return
	
	velocity.rest_vel += -transform.basis.y.project(gravity.normalized()) * gravity.length() * delta
	return

func apply_gravity() -> void:
	var grav_component := velocity.grav_component(gravity)
	if ground_contacts and grav_component.normalized().dot(gravity.normalized()) > 0:
		velocity.rest_vel -= grav_component
		# velocity.rest_vel += gravity / 10
	
	# if prev_grounded and !grounded:
	# 	velocity.rest_vel += gravity / 4

	var grav_mult := 1.0
	if is_network and catchup_multi > 1.5:
		grav_mult = 2.0
	velocity.rest_vel += gravity * delta * grav_mult

	if hop_frames > 0:
		velocity.rest_vel = -velocity.grav_component(gravity)

	grav_component = velocity.grav_component(gravity)
	if Util.v3_length_compare(grav_component, terminal_velocity) >= 0:
	# if grav_component.length() >= terminal_velocity:
		velocity.rest_vel -= grav_component
		velocity.rest_vel += gravity.normalized() * terminal_velocity

func apply_acceleration() -> void:
	if !grounded:
		return
		
	if in_bounce:
		return

	var speed_delta: float = 0.0
	if input.accel and input.brake and !in_hop and !in_drift and cur_boost_type == BoostType.NONE:
		if started and abs(cur_speed) <= still_turbo_max_speed:
			speed_delta = get_standstill_turbo_speed()
			start_standstill_turbo()
		elif cur_speed > 0:
			speed_delta = get_brake_speed()
		else:
			speed_delta = get_accel_speed()
	elif input.accel or cur_boost_type != BoostType.NONE:
		speed_delta = get_accel_speed()
	elif input.brake:
		speed_delta = get_reverse_speed()
	else:
		speed_delta = get_friction_speed()
	
	var new_speed := clampf(cur_speed + speed_delta * delta, -max_speed, max_speed)
	cur_speed = move_toward(cur_speed, new_speed, delta * grip)

func start_standstill_turbo() -> void:
	if grounded and not still_turbo_ready and still_timer.is_stopped():
		still_timer.start(still_turbo_charge_time)

func rotate_accel_along_floor() -> void:
	# TODO: This might not be the correct angle?
	# Rotate the propulsion direction
	if grounded and !prev_grounded:
		# We were in the air and have now landed
		along_ground_multi = 1.0
	
	var angle_z := velocity.prop_vel.normalized().angle_to(floor_normal)
	var angle_to_ground := 90 - rad_to_deg(angle_z)
	
	var new_prop_vel := velocity.prop_vel.rotated(transform.basis.x, deg_to_rad(angle_to_ground))
	velocity.prop_vel = velocity.prop_vel.normalized().slerp(new_prop_vel.normalized(), along_ground_multi) * velocity.prop_vel.length()

	along_ground_multi -= along_ground_dec * delta
	along_ground_multi = clamp(along_ground_multi, 0.0, 1.0)
	return

func outside_drift_force() -> void:
	# if !in_drift or !outside_drift:
	# 	drift_grip = 1.0
	# 	return
	
	# if !prev_in_drift:
	# 	# Just entered drift
	# 	drift_grip = 0.0
	
	# drift_grip = move_toward(drift_grip, ouside_drift_max_grip, delta * outside_drift_recover_speed)

	# Attempt 2
	# if !in_drift:
	# 	drift_offset = 0.0
	# 	return
	
	# drift_offset = move_toward(drift_offset, max_drift_offset * -drift_dir, delta * drift_offset_multi)
	


	if !outside_drift or in_cannon or contacts.has(ContactType.WALL):
		drift_offset = 0.0
		return

	if !in_drift:
		var multi := 1.5
		if !grounded:
			multi = 0.5

		drift_offset = move_toward(drift_offset, 0.0, delta * drift_offset_multi * multi)
		return
	
	drift_offset = move_toward(drift_offset, max_drift_offset * -drift_dir, delta * drift_offset_multi * 2)

	return

func get_standstill_turbo_speed() -> float:
	var mult := -1.0

	if cur_speed < 0:
		mult = 1.0

	return Util.get_vehicle_accel(max_speed, abs(abs(cur_speed) - max_speed), initial_accel, accel_exponent) * mult
func get_accel_speed() -> float:
	if cur_speed < 0:
		return -get_brake_speed()
	
	return Util.get_vehicle_accel(max_speed, cur_speed, initial_accel, accel_exponent)

func get_brake_speed() -> float:
	return initial_accel * -2

func get_reverse_speed() -> float:
	if cur_speed > 0:
		return get_brake_speed()
	
	return -Util.get_vehicle_accel(max_speed * reverse_multi, -cur_speed, initial_accel * reverse_multi, accel_exponent)

func get_friction_speed() -> float:
	var mult := 1.0 if cur_speed < 0 else -1.0
	return mult * Util.get_vehicle_accel(max_speed, abs(abs(cur_speed) - max_speed), initial_accel * friction_multi, accel_exponent)

func apply_rotations() -> void:
	# unstick_from_walls()  # TODO: May not be needed anymore
	rotate_stick()
	rotate_to_gravity()

func unstick_from_walls() -> void:
	if ContactType.WALL not in contacts:
		wall_turn_multi = 1.0
	else:
		wall_turn_multi += delta * 3
	
	wall_turn_multi = clamp(wall_turn_multi, 1.0, max_wall_turn_multi)

func rotate_stick() -> void:
	if !grounded:
		return
	
	# # Rotate the vehicle to match the ground.
	# var multi := 0.1

	# if below_normals:
	# 	multi = float(len(below_normals)) / len(floor_check_grid)

	# FIXME: This is garbage
	var tmp := transform
	look_at(global_position + floor_normal, -global_transform.basis.z.normalized(), true)
	var rotated_transform := global_transform.rotated(global_transform.basis.x.normalized(), 0.5*PI)
	transform = tmp
	global_transform.basis = Basis(global_transform.basis.get_rotation_quaternion().slerp(rotated_transform.basis.get_rotation_quaternion(), delta * ground_rot_multi))

func rotate_to_gravity() -> void:
	if grounded:
		return

	var tmp := transform
	look_at(global_position - gravity, -global_transform.basis.z.normalized(), true)
	var rotated_transform := global_transform.rotated(global_transform.basis.x.normalized(), 0.5*PI)
	transform = tmp
	global_transform.basis = Basis(global_transform.basis.get_rotation_quaternion().slerp(rotated_transform.basis.get_rotation_quaternion(), delta * air_rot_multi))


func apply_network_drift() -> void:
	var prev_multi = catchup_multi
	catchup_multi = 1.0
	
	if !is_network:
		return

	if !network.prev_state:
		return

	var network_pos: Vector3 = cpu_logic.next_target_1.global_position
	var network_rot: Quaternion = Util.array_to_quat(network.prev_state.rot)
	var move_multi := 0.0
	var rot_multi := 1.0
	
	if !cpu_logic.moved_to_next and network.prev_state.cur_speed >= 5.0:
		var dist: float = global_position.distance_to(cpu_logic.next_target_1.global_position)
		move_multi = clampf(remap(dist, 0, network.network_teleport_distance, 0.0, 1.0), 0, 1.0)
	
	else:
		move_multi = 0.0
	
	if network.prev_state.cur_speed < 5.0: # and global_position.distance_to(network_pos) < 3.0:
		network_pos = Util.to_vector3(network.prev_state.pos)
		move_multi = clampf(remap(network.prev_state.cur_speed, 0, 5.0, 5.0, 0.0), 0.0, 0.5)
		rot_multi = 3.0
		prev_input.steer = 0.0
		input.steer = 0.0
		
		var new_pos: Vector3 = global_position.lerp(network_pos, delta * move_multi*5)
		var new_movement: Vector3 = new_pos - global_position

		# Remove the component along the gravity vector
		var adjusted_movement: Vector3 = Plane(-gravity.normalized()).project(new_movement)
		var vertical_movement: Vector3 = new_movement - adjusted_movement

		global_position += adjusted_movement
	
	#if ContactType.WALL in contacts:
		#wall_cooldown = roundi(Engine.physics_ticks_per_second * (world.pings[user_id] / 1000))
	#
	#if wall_cooldown > 0:
		#wall_cooldown -= 1
		#network_pos = Util.to_vector3(network.prev_state.pos)
	
	if cpu_logic.moved_to_next:
		#Debug.print("PASSED")
		move_multi = -move_multi
		if cur_speed < 5.0:
			move_multi = 0.0
	
	catchup_multi += move_multi
	
	if network.prev_state.in_drift:
		catchup_multi = 1.0
	#Debug.print("===")
	#Debug.print(["B", catchup_multi])
	catchup_multi = move_toward(prev_multi, catchup_multi, delta * 0.2)
	#Debug.print(["A", catchup_multi])
	#Debug.print(cur_speed)
	#Debug.print("===")
	# FIXME: Wide drift doesn't work over network
	
	var cur_quat := Quaternion.from_euler(rotation)
	var target_quat := network_rot
	rotation = cur_quat.slerp(target_quat, rot_multi * delta).get_euler()
	return
	
	#var new_pos: Vector3 = global_position.lerp(network_pos, delta * move_multi)
	#var new_movement: Vector3 = new_pos - global_position
#
	## Remove the component along the gravity vector
	#var adjusted_movement: Vector3 = Plane(-gravity.normalized()).project(new_movement)
	#var vertical_movement: Vector3 = new_movement - adjusted_movement
#
	##global_position += adjusted_movement
	#
	#if Util.v3_length_compare(vertical_movement, network.network_teleport_distance / 2) > 0 and !cpu_logic.moved_to_next:
	## if vertical_movement.length() > network.network_teleport_distance / 2 and !cpu_logic.moved_to_next:
		#global_position = network_pos
	#

func stop_movement() -> void:
	prev_transform = transform
	prev_velocity = Velocity.new()
	velocity = prev_velocity
	cur_speed = 0
	turn_speed = 0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	stop_boost()
	in_hop = false
	in_drift = false
	in_bounce = false
	in_trick = false
	trick_timer = 0

func teleport(new_pos: Vector3, look_dir: Vector3, up_dir: Vector3, keep_velocity: bool = true) -> void:
	global_position = new_pos
	look_at(new_pos + look_dir, up_dir, true)
	if !keep_velocity:
		stop_movement()

# func axis_lock() -> void:
# 	axis_lock_linear_x = true
# 	axis_lock_linear_z = true

# func axis_unlock() -> void:
# 	axis_lock_linear_x = false
# 	axis_lock_linear_z = false

func start() -> void:
	started = true
	cur_speed = 0
	do_countdown_boost()

func do_countdown_boost() -> void:
	if !input.accel:
		return

	if countdown_gauge > countdown_gauge_max:
		damage(DamageType.SPIN)
		return
	
	if countdown_gauge > countdown_gauge_middle:
		apply_boost(BoostType.NORMAL)
	elif countdown_gauge > countdown_gauge_min:
		apply_boost(BoostType.SMALL)

func initialize_player() -> void:
	is_player = true
	is_cpu = false
	is_network = false
	is_replay = false
	UI.race_ui.roulette_ended.connect(_on_roulette_stop)

func set_rank(new_rank: int) -> void:
	if is_player and new_rank != rank:
		UI.race_ui.update_rank(new_rank)
	rank = new_rank

func set_finished(_finish_time: float) -> void:
	finished = true
	finish_time = _finish_time

	if !is_network:
		is_cpu = true

	if is_player:
		UI.race_ui.hide_roulette()
		UI.race_ui.finished()
	
	cpu_logic.new_target(Util.get_path_point_ahead_of_player(self))


func get_item(guaranteed_item: PackedScene = null) -> void:
	if is_network:
		return
	
	if respawn_stage:
		return
	
	if item:
		return
	can_use_item = false
	if guaranteed_item:
		item = guaranteed_item.instantiate()
	else:
		item = Global.sample_item(self).instantiate()
	
	if not item is UsableItem:
		print("ERR: Object not of type UsableItem: ", item)
		return
	
	item.setup(self, world)
	%Items.add_child(item)
	
	%ItemRouletteTimer.start(4)
	if is_player and !finished:
		UI.race_ui.start_roulette()
	
	#else:
		#var item_rank: int = round(remap(rank, 0, world.players_dict.size(), 0, Global.player_count))
		#item = Global.item_dist[item_rank].pick_random().instantiate()
	#if "parent" in item:
		#item.parent = self
	#if not "local" in item or not item.local:
		#world.add_child(item)
	#else:
		#%Items.add_child(item)


func handle_item() -> void:
	if !input.item:
		return

	if prev_input.item:
		return
	
	if in_cannon:
		return
	
	if not can_use_item:
		if not %ItemRouletteTimer.is_stopped():
			# User pressed item button while roulette is running.
			var new_time: float = %ItemRouletteTimer.time_left - 0.5
			if new_time < 0:
				%ItemRouletteTimer.stop()
				_on_item_roulette_timer_timeout()
			else:
				%ItemRouletteTimer.start(new_time)
		return
	
	if not item:
		return
	
	item.use()
	prev_input.item = true


func remove_item() -> void:
	if item:
		item.queue_free()
		item = null
	can_use_item = false
	if is_player:
		UI.race_ui.hide_roulette()
	%ItemRouletteTimer.stop()


func damage(damage_type: DamageType) -> void:
	if in_cannon:
		return
	
	# start_failsafe_timer()

	if cur_damage_type != DamageType.NONE:
		return
	
	if do_damage_type != DamageType.NONE:
		return
	
	match damage_type:
		DamageType.SPIN:
			cur_damage_type = damage_type
			%DamageTimer.start(1.5)
			vani.animation = vani.Type.dmg_spin
		DamageType.SQUISH:
			if !%SquishTimer.is_stopped():
				return
			cur_damage_type = DamageType.SQUISH
			%DamageTimer.start(0.5)
			%SquishTimer.start(3.0)
			var tween := create_tween()
			tween.tween_property(vani, "squish_amount", 1.0, 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	
	stop_boost()

func hide_kart() -> void:
	# TODO: Change colliders!!
	for node in visual_node.get_children():
		if not node is Node3D:
			continue
		var node3d := node as Node3D
		node3d.visible = false
		if node is Decal:
			var decal := node as Decal
			decal.albedo_mix = 0.0
	%Character.visible = true
	audio.engine_sound_enabled = false
	cani.play("running_shoes_run")
	%Character.position.y += chara_running_extra_y
	%Character.get_node("Body").hide_tail = false

func show_kart() -> void:
	for node in visual_node.get_children():
		if not node is Node3D:
			continue
		var node3d := node as Node3D
		node3d.visible = true
		if node is Decal:
			var decal := node as Decal
			decal.albedo_mix = 1.0
	cani.play("sit")
	audio.engine_sound_enabled = true
	%Character.position.y -= chara_running_extra_y
	%Character.get_node("Body").hide_tail = true

func add_targeted(object: Node3D, tex: CompressedTexture2D) -> void:
	if not object in targeted_by_dict:
		targeted_by_dict[object] = tex

func remove_targeted(object: Node3D) -> void:
	if object in targeted_by_dict:
		targeted_by_dict.erase(object)
		UI.race_ui.remove_alert(object)

func water_entered(area: Area3D) -> void:
	in_water = true
	
	if area not in water_bodies:
		water_bodies[area] = true
		audio.water_entered()


func water_exited(area: Area3D) -> void:
	water_bodies.erase(area)
	if water_bodies.size() == 0:
		in_water = false

func _on_damage_timer_timeout() -> void:
	cur_damage_type = DamageType.NONE

func _on_squish_timer_timeout() -> void:
	var tween := create_tween()
	tween.tween_property(vani, "squish_amount", 0.0, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _on_boost_timer_timeout() -> void:
	stop_boost()


func _on_still_turbo_timer_timeout() -> void:
	still_turbo_ready = true

func _on_item_roulette_timer_timeout() -> void:
	if not item:
		print("Error: Roulette stopped but no item assigned!")
		return
	
	if !is_player or is_network:
		can_use_item = true
		return
	
	UI.race_ui.stop_roulette(item.wheel_image)

func _on_roulette_stop() -> void:
	can_use_item = true

func apply_gravity_zone(zone: Node3D, params: GravityZone.GravityZoneParams) -> void:
	gravity_zones[zone] = params

func remove_gravity_zone(zone: Node3D) -> void:
	if zone not in gravity_zones:
		return
	
	gravity_zones.erase(zone)

func setup_replay() -> void:
	is_player = false
	is_network = false
	is_cpu = false
	is_replay = true
	freeze_mode = FREEZE_MODE_STATIC
	freeze = true
	collision_layer = 0
	collision_mask = 0

func apply_drift_tilt() -> void:
	if !drift_tilt:
		visual_node.rotation = Vector3.ZERO
		return
	
	var tilt := 0.0

	if grounded:
		var speed_multi := clampf(remap(cur_speed, 0, max_speed / 2, -0.5, 1), 0, 1)
		speed_multi *= clampf(remap(cur_speed, 0, base_max_speed, 0, 1), 0, 1)
		var steer_multi := remap(turn_speed, -max_turn_speed, max_turn_speed, -1, 1)
		tilt = -steer_multi * speed_multi * drift_tilt_max
	
	visual_node.rotation.z = move_toward(visual_node.rotation.z, tilt, delta * drift_tilt_speed)
