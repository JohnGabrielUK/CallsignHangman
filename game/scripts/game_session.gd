extends Node

enum ScientistState {ALIVE, DEAD, RESCUED}

var scientist_states : Array
var player_tagalong : int


func _on_mad_talk_activate_custom_effect(effect_id: String, data: Array):
	# data is an Array of strings, in this project we only use data[0]
	# You **CAN** await inside of here, and the dialog will pause
	# and wait for that before continuing
	
	var arg: String = data[0] if data.size() > 0 else ""
	match effect_id:
		"map_fix":
			# called when katrina talks about the fix for the scientists and tells stickyman to check the map
			pass
		
		"post_escape_pod":
			# called after each of the dialogues where a scientist reaches a pod.
			# arg contains "A", "B" or "C"
			pass
		
		"save_scientist":
			# called immediately after selecting the menu option, before showing the first message of the saved the scientist route
			# (remember, await works)
			pass
		
		"kill_scientist":
			# called when that option is selected in the menu, before first message, etc. same as above
			# (remember, await works)
			pass
		
		"final":
			# called after last message
			# arg == "saved" in `If The Player Chooses to Save the Scientist`,
			# arg == "killed_last" in `If The Player Chooses to Kill the Scientist`,
			# arg == "killed_all" in `If All Scientists Are Killed`
			# arg == "killed_some" in `If At Least One Scientist is Extracted And The Rest Killed`
			pass

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
