extends RigidBody3D

class_name Kart

var input: KartInput = preload("res://scenes/kart/managers/kart_input.gd").new(self);
var physics: KartPhysics = preload("res://scenes/kart/managers/kart_physics.gd").new(self);

@onready var front_right: Marker3D = %FrontRight
@onready var front_left: Marker3D = %FrontLeft
@onready var back_right: Marker3D = %BackRight
@onready var back_left: Marker3D = %BackLeft

@export var float_height: float = 1.0

func _ready() -> void:
	physics.ready()

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	input.poll_inputs();
	physics.integrate_forces(state)

	if Global.debug:
		print("===")
		print(physics.cur_physics.gravity_velocity)
		print(physics.cur_physics.contacts[KartPhysics.ContactType.FLOOR].size() if KartPhysics.ContactType.FLOOR in physics.cur_physics.contacts else 0)
		print("floor dist: ", physics.cur_physics.floor_distance)
		print("floor normal: ", physics.cur_physics.floor_normal)
