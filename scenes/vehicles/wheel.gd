extends Node3D

# We assume the wheel model has a radius of 1m

@onready var parent: Vehicle4 = get_parent().get_parent().get_parent().get_parent()
@onready var radius := scale.x
var anchor := Vector3.ZERO
@onready var initial_rotation := rotation_degrees
var initial_scale := Vector3.ZERO

@export var steer := false
var cur_steer_deg := 0.0
var steer_multi := 300.0
var cur_rot := 0.0

@export var drive := true

var mesh1: MeshInstance3D = null
var mesh2: MeshInstance3D = null

func _ready() -> void:
	anchor = position
	initial_scale = scale
	
	var sphere = SphereMesh.new()
	sphere.radial_segments = 4
	sphere.rings = 4
	sphere.radius = 0.05
	sphere.height = 0.05 * 2
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1, 0, 0)
	material.flags_unshaded = true
	material.no_depth_test = true
	sphere.surface_set_material(0, material)
	mesh1 = MeshInstance3D.new()
	mesh1.mesh = sphere
	mesh1.global_position = global_position
	mesh2 = MeshInstance3D.new()
	mesh2.mesh = sphere
	mesh2.global_position = global_position
	get_parent_node_3d().add_child.call_deferred(mesh1)
	get_parent_node_3d().add_child.call_deferred(mesh2)
	mesh1.visible = false
	mesh2.visible = false

func _process(delta: float) -> void:
	# Roll over the ground.
	var new_rot := initial_rotation
	
	var cur_speed := parent.cur_speed
	
	scale = initial_scale
	if !parent.started and drive:
		var multi := clampf(parent.countdown_gauge / parent.countdown_gauge_max, 0, 1.5)
		cur_speed = parent.base_max_speed * multi
		scale = initial_scale * max(remap(multi, 0, 1.5, 1.0, 1.1), 1.0)
	
	var new_radius := radius * parent.visual_node.scale.y
	var dist_travelled := parent.cur_speed * delta
	var circum := 2.0 * PI * new_radius
	var degrees := 360 * (dist_travelled/circum)
	
	cur_rot += degrees
	cur_rot = fmod(cur_rot, 360)
	
	new_rot.x -= cur_rot
	# Do a raycast in the direction of the parent down.
	var parent_up := get_parent_node_3d().transform.basis.y.normalized()
	
	var new_anchor = anchor
	var start_pos: Vector3 = get_parent_node_3d().to_global(new_anchor) + (-parent_up * new_radius * 0.75)
	var end_pos: Vector3 = get_parent_node_3d().to_global(new_anchor) + (-parent_up * new_radius * 1.25)
	
	mesh1.global_position = start_pos
	mesh2.global_position = end_pos
	
	#var local_pos = parent.to_local(end_pos)
	#local_pos.y += radius
	#position = local_pos
	
	var param := PhysicsRayQueryParameters3D.create(start_pos, end_pos, 1, [self])
	var result := parent.world.space_state.intersect_ray(param)
	var point := end_pos
	if result:
		point = result.position
	
	point = get_parent_node_3d().to_local(point)
	point.y += radius
	#point.y *= parent.visual_node.scale.y

	
	# TODO: This does not work with other gravities than down!5
	#if point.y < position.y:
		#position.y = move_toward(position.y, point.y, abs(delta * parent.gravity.y * 0.05))
	#else:
		#position.y = point.y
	position.y = move_toward(position.y, point.y, abs(delta * parent.gravity.y * 0.03))
	
	mesh2.global_position = get_parent_node_3d().to_global(point)

	if steer:
		var target_rot: float
		if parent.is_network and parent.network.prev_input:
			target_rot = parent.max_turn_speed * parent.network.prev_input.steer * 0.3
		else:
			target_rot = parent.turn_speed * 0.3

		if parent.cur_speed < -0.1:
			target_rot *= -1.0
		cur_steer_deg = move_toward(cur_steer_deg, target_rot, delta * steer_multi)
		new_rot.y += cur_steer_deg
	
	rotation_degrees = new_rot
