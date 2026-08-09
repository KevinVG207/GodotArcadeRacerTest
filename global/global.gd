extends Node

signal goto_lobby_screen
signal goto_settings_screen

signal camera_switched

var args: Dictionary[String, String] = {}

var debug := true;

var default_player_count: int = 1
var player_count: int = default_player_count:
	set(value):
		player_count = value
		setup_items()

var cpu_enabled: bool = true

var extraPing: int = 0
func get_extra_ping() -> float:
	return clampf(RandomNumberGenerator.new().randf_range(Global.extraPing, Global.extraPing / 4.0), 0, 2000)

var unique_string = OS.get_unique_id()

var menu_start_cam: String = "%CamInitial"

var rebind_popup: RebindPopup = null

var menu_ignore_input: bool = false

const MODE1_OFFLINE = 0
const MODE1_ONLINE = 1

const MODE2_RACE = 0
const MODE2_TIMETRIALS = 1
const MODE2_BATTLE = 2
const MODE2_MISSION = 3

var MODE1: int = MODE1_OFFLINE
var MODE2: int = MODE2_RACE

var save_on_exit := true

var trick_col_to_node = {
	"trick": "NormalBoostTimer",
	"small_trick": "SmallBoostTimer"
}

var items: Array[PackedScene] = [
	load("res://scenes/items2/usable/carrot/1Carrot.tscn"),
	load("res://scenes/items2/usable/carrot/3Carrots.tscn"),
	load("res://scenes/items2/usable/book/Book.tscn"),
	load("res://scenes/items2/usable/horseshoe_gray/HorseShoeGray.tscn"),
	load("res://scenes/items2/usable/horseshoe_red/HorseShoeRed.tscn"),
	load("res://scenes/items2/usable/juice/GreenJuice.tscn"),
	load("res://scenes/items2/usable/donut/Donut.tscn"),
	load("res://scenes/items2/usable/shoes/Shoes.tscn"),
	load("res://scenes/items2/usable/expander/Expander.tscn")
]

var item_distributions: Dictionary[PackedScene, Curve] = {}

var physical_items: Dictionary[String, PackedScene] = {
	"DraggedBook": load("res://scenes/items2/physical/book/DraggedBook.tscn"),
	"ThrownBook": load("res://scenes/items2/physical/book/ThrownBook.tscn"),
	"DraggedHorseShoeGray": load("res://scenes/items2/physical/horseshoe_gray/DraggedHorseShoeGray.tscn"),
	"ThrownHorseShoeGray": load("res://scenes/items2/physical/horseshoe_gray/ThrownHorseShoeGray.tscn"),
	"DraggedHorseShoeRed": load("res://scenes/items2/physical/horseshoe_red/DraggedHorseShoeRed.tscn"),
	"ThrownHorseShoeRed": load("res://scenes/items2/physical/horseshoe_red/ThrownHorseShoeRed.tscn"),
	"DraggedJuice": load("res://scenes/items2/physical/juice/DraggedJuice.tscn"),
	"ThrownJuice": load("res://scenes/items2/physical/juice/ThrownJuice.tscn"),
	"JuiceSpill": load("res://scenes/items2/physical/juice/JuiceSpill.tscn"),
	"DonutLogic": load("res://scenes/items2/physical/donut/DonutLogic.tscn"),
	"ShoesLogic": load("res://scenes/items2/physical/shoes/ShoesLogic.tscn"),
	"Expander": load("res://scenes/items2/physical/expander/Expander.tscn")
}

var item_tex: Array = []

var heads: Dictionary = {
	"special-week": "res://assets/character/head.tscn",
	"nice-nature": "res://assets/character/_nice-nature/head.tscn"
}

var selected_replay: String = ""
#var selected_replay: String = "user://replays/Wicked_Woods/1738524227.sav"
#var selected_replay: String = "user://replays/1test/1738524048.sav"

var fade_to_black_scene = preload("res://scenes/ui/transition/fade_to_black.tscn")

var final_lobby: DomainRoom.Lobby = null

func _enter_tree() -> void:
	process_mode = PROCESS_MODE_ALWAYS

func _ready() -> void:
	print("VERSION: ", Util.version)
	
	for arg in OS.get_cmdline_args():
		if arg.contains("="):
			var key_value = arg.split("=")
			args[key_value[0].trim_prefix("--")] = key_value[1]
		else:
			args[arg.trim_prefix("--")] = ""
	
	RPCClient.error_received.connect(_on_network_error)
	
func _process(_delta: float) -> void:
	var viewport := get_viewport()
	var new_scale := float(viewport.size.x) / 1280.0
	if get_window().content_scale_factor != new_scale:
		get_window().content_scale_factor = new_scale

func setup_items() -> void:
	print("Setting up items...")
	item_distributions.clear()
	
	for item in items:
		var scene = item.instantiate() as UsableItem
		item_distributions[item] = scene.probability
		item_tex.append(scene.wheel_image)
	
	UI.race_ui.setup()

func sample_item(player: Vehicle4) -> PackedScene:
	var distributions := make_item_distributions(player)
	
	var rnd = RandomNumberGenerator.new()
	var choice := rnd.rand_weighted(distributions)
	
	if choice == -1:
		print("WARN: Failed to sample item")
		return items[0]

	return item_distributions.keys()[choice]

func make_item_distributions(player: Vehicle4) -> Array[float]:
	var distributions: Array[float] = []
	for item in item_distributions:
		var offset := float(player.rank) / player_count
		var weight := maxf(0, item_distributions[item].sample(offset))
		distributions.append(weight)
	return distributions

#func _ready():
	#var gravity := Vector3(0, -1, 0)
	#var vel := Vector3(1, -1, -1)
	#var wall_normal := Vector3(0, -1, 1).normalized()
	#var on_grav_plane := vel.slide(gravity)
	#var wall_on_grav_plane := wall_normal.slide(gravity)
	#var tmp := on_grav_plane.project(wall_on_grav_plane.normalized())
#
	#print(on_grav_plane)
	#print(wall_on_grav_plane)
	#print(on_grav_plane - tmp)
	#
	#get_tree().quit()
	#setup_items()


func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("SHUTTING DOWN")
		Network.reset()
		if save_on_exit:
			Config.save_config(Config.make_config())
		get_tree().quit()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("_F11") and get_window().has_focus():
		if Config.window_mode > 0:
			Config.window_mode = 0
		else:
			Config.window_mode = 2
		Config.update_config()
	
	# If a rebind popup is active, reroute all relevant input there.
	if rebind_popup:
		if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
			rebind_popup.handle_input(event)
		return

var error_code: int = DomainError.GENERIC_ERROR
func _on_network_error(code: int) -> void:
	error_code = code
	multiplayer.multiplayer_peer = null
	UI.change_scene("res://scenes/ui/network_error/network_error_screen.tscn", false, fade_to_black_scene)
