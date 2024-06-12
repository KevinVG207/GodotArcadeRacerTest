extends Control

class_name RaceUI

func update_speed(speed):
	$Speed.text = str(int(speed))

func update_countdown(cd):
	$Countdown.text = str(cd)

func set_max_laps(laps):
	$LapCountContainer/MarginContainer/MaxLaps.text = "/%d" % int(max(laps, 0))

func set_cur_lap(lap):
	$LapCountContainer/CurLap.text = "Lap %d" % int(max(lap, 0))

func finished():
	$Finished.visible = true

func race_over():
	$RaceOver.visible = true
