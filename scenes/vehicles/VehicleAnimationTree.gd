extends AnimationTree

class_name VehicleAnimationTree

@onready var vehicle: Vehicle4 = get_parent()

const Type = {
	idle = "RESET",
	dmg_spin = "dmg_spin",
}

var sm: AnimationNodeStateMachinePlayback = self.get("parameters/playback")
var animation:
	set(value):
		sm.travel(value)
	get:
		return sm.get_current_node()

const CHARGEUP_BLEND := "parameters/Rest/Chargeup/blend_amount"
const CHARGEUP_SPEED := "parameters/Rest/ChargeupSpeed/scale"
const SQUISH_BLEND := "parameters/Rest/Squish/blend_amount"
var squish_amount: float = 0.0
const SCALE_BLEND := "parameters/Rest/Scale/blend_amount"
var scale: float = 1.0

var wheelie_amount := deg_to_rad(25)
var wheelie_up_ticks := 15

var secs_since_physics_tick := 0.0
var ratio_of_tick_since_last_physics := 0.0

#func _ready():
	#animation = Type.idle

func _physics_process(delta: float) -> void:
	secs_since_physics_tick += delta
	ratio_of_tick_since_last_physics = secs_since_physics_tick / (1.0 / Engine.physics_ticks_per_second)

func _process(_delta: float) -> void:
	blend_chargeup()
	rotate_wheelie()
	self.set(SQUISH_BLEND, squish_amount)
	self.set(SCALE_BLEND, scale - 1.0)
	
	secs_since_physics_tick = 0.0
	ratio_of_tick_since_last_physics = 0.0

func blend_chargeup() -> void:
	if vehicle.started:
		self.set(CHARGEUP_BLEND, 0)
		self.set(CHARGEUP_SPEED, 0)
		return
	var ratio := clampf(vehicle.countdown_gauge / vehicle.countdown_gauge_max, 0 , 1)
	var blend := remap(ratio, 0, 1, 0, 0.25)
	self.set(CHARGEUP_BLEND, blend)
	var speed := clampf(remap(ratio, 0, 1, 0, 10), 0, 2.0)
	self.set(CHARGEUP_SPEED, speed)
	
func rotate_wheelie() -> void:
	if !vehicle.in_wheelie:
		vehicle.wheelie_node.rotation.x = 0
		return
	
	if vehicle.wheelie_ticks_left > vehicle.wheelie_ticks - wheelie_up_ticks:
		# Wheelie going up
		var ticks_going_up := absf(vehicle.wheelie_ticks_left - vehicle.wheelie_ticks - ratio_of_tick_since_last_physics)
		var ratio_going_up := ticks_going_up / wheelie_up_ticks
		var rads_going_up := clampf(wheelie_amount * ratio_going_up, 0, wheelie_amount)
		vehicle.wheelie_node.rotation.x = -rads_going_up
	else :
		# Wheelie going down
		var down_length := float(vehicle.wheelie_ticks - wheelie_up_ticks)
		var ticks_going_down: float = down_length - vehicle.wheelie_ticks_left + ratio_of_tick_since_last_physics
		var ratio_going_down := 1.0 - (ticks_going_down / down_length)
		var rads_going_down := clampf(wheelie_amount * ratio_going_down, 0, wheelie_amount)
		vehicle.wheelie_node.rotation.x = -rads_going_down
		return
