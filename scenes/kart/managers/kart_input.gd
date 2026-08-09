extends Node

class_name KartInput

var kart: Kart;

var cur_input := Inputs.new();
var prev_input := Inputs.new();

class Inputs:
	var accel := false
	var brake := false
	var steer := 0.0
	var item := false
	var tilt := 0.0
	var mirror := false
	var rewind := false

	func to_dict() -> Dictionary:
		return {
			"accel": accel,
			"brake": brake,
			"steer": steer,
			"item": item,
			"tilt": tilt,
			"mirror": mirror,
			"rewind": rewind
		}
	
	static func from_dict(dict: Dictionary) -> Inputs:
		var out := Inputs.new()
		out.accel = dict.accel
		out.brake = dict.brake
		out.steer = dict.steer
		out.item = dict.item
		out.tilt = dict.tilt
		out.mirror = dict.mirror
		out.rewind = dict.rewind
		return out

func _init(_kart: Kart) -> void:
	self.kart = _kart;

func poll_inputs() -> void:
	prev_input = cur_input;
	cur_input = Inputs.new();
	
	# TODO: Add CPU input
	if false:
		return
	
	if get_window() and !get_window().has_focus():
		return
	
	set_controller_inputs();
	return

func set_controller_inputs() -> void:
	cur_input.accel = Input.is_action_pressed("accelerate")
	cur_input.brake = Input.is_action_pressed("brake") or Input.is_action_pressed("brake2")
	cur_input.steer = Input.get_axis("right", "left")
	cur_input.item = Input.is_action_pressed("item")
	cur_input.tilt = Input.get_axis("down", "up")
	cur_input.rewind = Input.is_action_pressed("rewind")
