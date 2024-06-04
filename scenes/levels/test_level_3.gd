extends Node3D

var checkpoints: Array = []
var players: Array = []

func _ready():
	players.append($Vehicle3)
	$PlayerCamera.target = $Vehicle3
	
	# Setup checkpoints
	for checkpoint in $Checkpoints.get_children():
		checkpoints.append(checkpoint)

func _process(_delta):
	# Player checkpoints
	for player: Vehicle3 in players:
		update_checkpoint(player)

func update_checkpoint(player: Vehicle3):
	while true:
		var next_idx = player.check_idx+1 % len(checkpoints)
		if dist_to_checkpoint(player, next_idx) > 0:
			player.check_idx = next_idx
			if next_idx == 0:
				player.lap += 1
		else:
			break
	
	while true:
		var prev_idx = (player.check_idx - 1) % len(checkpoints)
		if prev_idx < 0:
			prev_idx += len(checkpoints)
		if dist_to_checkpoint(player, player.check_idx) < 0:
			player.check_idx = prev_idx
			if prev_idx == len(checkpoints):
				player.lap -= 1
		else:
			break
		

func dist_to_checkpoint(player: Vehicle3, checkpoint_idx: int) -> float:
	var checkpoint = checkpoints[checkpoint_idx % len(checkpoints)] as Node3D
	return checkpoint.transform.basis.z.dot(player.transform.origin - checkpoint.transform.origin)
