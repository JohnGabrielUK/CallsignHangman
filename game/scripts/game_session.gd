extends Node

enum ScientistState {ALIVE, DEAD, RESCUED}

var scientist_states : Array
var player_tagalong : int
var intro_played : bool
var microwave_warning_played : bool
var microwave_active : bool
var player_blood : Vector3
var player_arm : int
var ending : String

var madtalk
var player
var anim_player

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
			anim_player.play("fade_out_keep_ambience")
			await anim_player.animation_finished
			scientist_in_pod()
			anim_player.play("fade_in_keep_ambience")
		
		"save_scientist":
			anim_player.play("fade_out_keep_ambience")
			await anim_player.animation_finished
			get_tree().call_group("scientist", "queue_free")
			anim_player.play("fade_in_keep_ambience")
		
		"kill_scientist":
			get_tree().call_group("scientist", "queue_free")
			anim_player.play("fade_in_keep_ambience")
		
		"final":
			# called after last message
			# arg == "saved" in `If The Player Chooses to Save the Scientist`,
			# arg == "killed_last" in `If The Player Chooses to Kill the Scientist`,
			# arg == "killed_all" in `If All Scientists Are Killed`
			# arg == "killed_some" in `If At Least One Scientist is Extracted And The Rest Killed`
			if arg != "killed_all":
				ending = arg
				anim_player.play("fade_out_slow")
				await anim_player.animation_finished
				get_tree().change_scene_to_file("res://scenes/credits.tscn")
			else:
				anim_player.play("fade_out")
				await anim_player.animation_finished
				get_tree().change_scene_to_file("res://scenes/game_over.tscn")

func get_scientists_saved() -> int:
	var result : int = 0
	for state in scientist_states:
		if state == ScientistState.RESCUED:
			result += 1
	return result

func no_more_to_save() -> bool:
	var result : bool = true
	for state in scientist_states:
		if state == ScientistState.ALIVE:
			result = false
	return result

func is_scientist_alive(scientist_id : int) -> bool:
	return scientist_states[scientist_id] == ScientistState.ALIVE

func is_scientist_following_player() -> bool:
	return player_tagalong != -1

func scientist_met(scientist_id : int) -> void:
	match scientist_id:
		0: madtalk.start_dialog("scientist_a_found")
		1: madtalk.start_dialog("scientist_b_found")
		2: madtalk.start_dialog("scientist_c_found")

func scientist_dead(scientist_id : int) -> void:
	scientist_states[scientist_id] = ScientistState.DEAD
	if player_tagalong == scientist_id:
		player_tagalong = -1
	if no_more_to_save():
		if get_scientists_saved() > 0:
			madtalk.start_dialog("some_killed")
		else:
			madtalk.start_dialog("all_killed")

func scientist_rescued(scientist_id : int) -> void:
	scientist_states[scientist_id] = ScientistState.RESCUED
	if player_tagalong == scientist_id:
		player_tagalong = -1
	if get_scientists_saved() != 3:
		match scientist_id:
			0: madtalk.start_dialog("scientist_a_pod")
			1: madtalk.start_dialog("scientist_b_pod")
			2: madtalk.start_dialog("scientist_c_pod")
	else:
		madtalk.start_dialog("last_pod")

func scientist_in_pod() -> void:
	get_tree().call_group("scientist", "queue_free")
	if get_scientists_saved() == 1:
		madtalk.start_dialog("one_escapes")
	elif no_more_to_save():
		madtalk.start_dialog("some_killed")

func scientist_following_player(scientist_id : int) -> void:
	player_tagalong = scientist_id

func terminal_activated(terminal_id : String) -> void:
	match terminal_id:
		"cafeteria_a":
			madtalk.start_dialog("terminal_message_a")
		"cafeteria_b":
			madtalk.start_dialog("terminal_message_b")
		"cafeteria_c":
			madtalk.start_dialog("terminal_message_c")
		"terminal_message_d":
			madtalk.start_dialog("terminal_message_d")
		"log_a":
			madtalk.start_dialog("log_a")
		"log_b":
			madtalk.start_dialog("log_b")
		"microwave_terminal":
			if GameSession.microwave_active:
				GameSession.microwave_active = false
				madtalk.start_dialog("microwaves_deactivated")
			else:
				madtalk.start_dialog("microwaves_already_off")

func room_entered(which : String) -> void:
	if which == "Entrance" and not intro_played:
		madtalk.start_dialog("intro")
		intro_played = true
	elif which == "RoomTwodoors" and not microwave_warning_played:
		madtalk.start_dialog("before_microwave")
		microwave_warning_played = true

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
	intro_played = false
	microwave_warning_played = false
	microwave_active = true
	player_blood = Vector3(10.0, 0.0, 0.0)
	player_arm = Constants.ArmType.HUMAN

func _ready() -> void:
	new_game()
