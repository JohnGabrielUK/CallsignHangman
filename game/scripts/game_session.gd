extends Node

enum ScientistState {ALIVE, DEAD, RESCUED}

var scientist_states : Array
var player_tagalong : int

func get_scientists_saved() -> int:
	var result : int = 0
	for state in scientist_states:
		if state == ScientistState.RESCUED:
			result += 1
	return result

func is_scientist_alive(scientist_id : int) -> bool:
	return scientist_states[scientist_id] == ScientistState.ALIVE

func is_scientist_following_player() -> bool:
	return player_tagalong != -1

func scientist_met(scientist_id : int) -> void:
	match scientist_id:
		0: print("Playing scientist_a_found")
		1: print("Playing scientist_b_found")
		2: print("Playing scientist_c_found")

func scientist_dead(scientist_id : int) -> void:
	scientist_states[scientist_id] = ScientistState.DEAD
	if player_tagalong == scientist_id:
		player_tagalong = -1

func scientist_rescued(scientist_id : int) -> void:
	scientist_states[scientist_id] = ScientistState.RESCUED
	if player_tagalong == scientist_id:
		player_tagalong = -1
	if get_scientists_saved() != 3:
		match scientist_id:
			0: print("Playing scientist_a_pod")
			1: print("Playing scientist_b_pod")
			2: print("Playing scientist_c_pod")
		scientist_in_pod()
	else:
		print("Playing last_pod")

func scientist_in_pod() -> void:
	get_tree().call_group("scientist", "queue_free")
	if get_scientists_saved() == 1:
		print("Playing one_escapes")

func scientist_following_player(scientist_id : int) -> void:
	player_tagalong = scientist_id

func evaluate_game_state() -> void:
	var all_dead : bool = true
	var all_rescued : bool = true
	for state in scientist_states:
		if state != ScientistState.DEAD: all_dead = false
		if state != ScientistState.RESCUED: all_rescued = false
	if all_dead:
		pass # Bad ending
		print("All dead.")
	elif all_rescued:
		print("All rescued!")
		pass # Good ending

func new_game() -> void:
	scientist_states = [ScientistState.ALIVE, ScientistState.ALIVE, ScientistState.ALIVE]
	player_tagalong = -1

func _ready() -> void:
	new_game()
