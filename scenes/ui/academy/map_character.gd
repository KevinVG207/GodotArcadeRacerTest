extends CharacterBody3D

class_name MapCharacter

@onready var nav_agent: NavigationAgent3D = $NavAgent
var gravity := Vector3.DOWN * 500.0
var move_speed := 100.0
var cur_speed := 0.0
var accel := 300.0

var cur_dir := Vector3.ZERO
var first := true
var dir_smoothing := 0.6
var target_pos:= Vector3.ZERO
var meeting_up := false
var meeting_partner: MapCharacter


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("F12"):
		_on_idle_timer_timeout()


func _ready():
	move_speed *= randf_range(0.8, 1.2)
	var col := Color(randf(), randf(), randf())
	$NavAgent.debug_use_custom = true
	$NavAgent.debug_path_custom_color = col
	$MeshInstance3D.mesh.material.albedo_color = col
	if randf() <= 0.5:
		start_idling()
	else:
		_on_idle_timer_timeout()

func start_idling(minimum: float = 5):
	$IdleTimer.start(max(0, randf_range(minimum, 60)))

func set_next_target():
	# print("Requesting next path position")
	target_pos = nav_agent.get_next_path_position()

func check_for_meetup():
	if meeting_up:
		return
	
	if !$MeetTimer.is_stopped():
		return
	
	var should_start_timer := false
	
	for character: MapCharacter in get_parent().get_children():
		if character == self:
			continue
		
		if !character.get_node("IdleTimer").is_stopped():
			continue
		
		if character.meeting_up:
			continue
		
		var dist: float = character.global_position.distance_to(global_position)
		var dp: float = velocity.normalized().dot(character.velocity.normalized())
		if dp < 0.5 and dist < 15 and dist > 2:
			var random = randi_range(0, 20)
			if random > 1:
				should_start_timer = true
				continue
			
			do_meetup(character)
			return
	
	if should_start_timer:
		$MeetTimer.start(10)
		#print("MeetTimer ", self)

func do_meetup(other: MapCharacter):
	meeting_up = true
	meeting_partner = other
	other.meeting_up = true
	other.meeting_partner = self
	nav_agent.target_position = other.global_position
	other.nav_agent.target_position = global_position
	$StopTimer.stop()
	other.get_node("StopTimer").stop()
	#print("Meeting", " ", self, " ", other)
	
	#var cam: Camera3D = get_parent().get_parent().cam
	#cam.global_position = ((global_position + other.global_position)/2) + Vector3.UP * 15
	#cam.rotation_degrees.x = -90
	#cam.rotation_degrees.y = 0
	#cam.rotation_degrees.z = 0


func _physics_process(delta):
	var target_speed := 0.0
	
	if meeting_up:
		nav_agent.target_position = meeting_partner.global_position
		set_next_target()
		if global_position.distance_to(nav_agent.target_position) < 2:
			_on_nav_agent_target_reached()
		nav_agent.path_postprocessing = 0
	else:
		nav_agent.path_postprocessing = 1
	
	if !nav_agent.is_navigation_finished() and $IdleTimer.is_stopped():
		check_for_meetup()

		var local_dest := target_pos - global_position
		var dir := local_dest.normalized()
		
		if first:
			first = false
			cur_dir = dir
		
		if cur_dir.angle_to(dir) > PI * (2.0/3.0):
			cur_dir = dir
		
		cur_dir = cur_dir.move_toward(dir, delta * dir_smoothing).normalized()
		target_speed = move_speed
	
	cur_speed = move_toward(cur_speed, target_speed, delta * accel)
	velocity = cur_dir * cur_speed
	velocity += gravity
	velocity *= delta
	
	move_and_slide()


func _on_idle_timer_timeout() -> void:
	# Choose a position to go to, and set the random stop timer.
	nav_agent.target_position = NavigationServer3D.map_get_random_point(get_parent().get_parent().get_node("NavigationRegion3D").get_navigation_map(), 1, true)
	$StopTimer.start(randf_range(10, 120))
	set_next_target()


func _on_nav_agent_target_reached() -> void:
	# Start idling
	$StopTimer.stop()
	start_idling()
	meeting_up = false
	meeting_partner = null


func _on_stop_timer_timeout() -> void:
	# Start idling
	start_idling()


func _on_nav_agent_waypoint_reached(details: Dictionary) -> void:
	call_deferred("set_next_target")
