extends Node3D

# We assume the wheel model has a radius of 1m

@onready var parent :Vehicle3 = self.get_parent().get_parent()
@onready var radius := scale.x
var anchor := Vector3.ZERO
@onready var initial_rotation := rotation_degrees

@export var steer := false

func _ready() -> void:
	anchor = position
	print(anchor)

func _process(delta: float) -> void:
	# Do a raycast in the direction of the parent down.
	var parent_up := parent.transform.basis.y
	
	var start_pos: Vector3 = parent.to_global(anchor) + (-parent_up * radius * 0.75)
	var end_pos: Vector3 = parent.to_global(anchor) + (-parent_up * radius * 1.25)
	
	#var local_pos = parent.to_local(end_pos)
	#local_pos.y += radius
	#position = local_pos
	
	var param := PhysicsRayQueryParameters3D.create(start_pos, end_pos, 1, [self])
	var result := get_world_3d().direct_space_state.intersect_ray(param)
	var point := end_pos
	if result:
		point = result.position
	
	point = parent.to_local(point)
	point.y += radius
	
	# TODO: This does not work with other gravities than down!5
	if point.y < position.y:
		position.y = move_toward(position.y, point.y, abs(delta * parent.gravity.y * 0.05))
	else:
		position.y = point.y
	
	if steer:
		var new_rotation = initial_rotation
		new_rotation.y += parent.cur_turn_speed * 0.3
		rotation_degrees = new_rotation 
