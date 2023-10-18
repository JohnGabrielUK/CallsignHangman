extends Node

enum ScientistState {ALIVE, DEAD, RESCUED}

var scientist_states : Array
var player_tagalong : int

func is_scientist_alive(scientist_id : int) -> bool:
	return scientist_states[scientist_id] == ScientistState.ALIVE

func is_scientist_following_player() -> bool:
	return player_tagalong != -1

func scientist_dead(scientist_id : int) -> void:
	scientist_states[scientist_id] = ScientistState.DEAD
	if player_tagalong == scientist_id:
		player_tagalong = -1

func scientist_rescued(scientist_id : int) -> void:
	scientist_states[scientist_id] = ScientistState.RESCUED
	if player_tagalong == scientist_id:
		player_tagalong = -1

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
