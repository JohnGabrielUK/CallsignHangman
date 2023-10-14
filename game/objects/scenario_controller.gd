extends Node

enum ScientistState {ALIVE, DEAD, RESCUED}

var scientist_states : Array = [ScientistState.ALIVE]

func _on_scientist_dead(scientist_id : int) -> void:
	scientist_states[scientist_id] = ScientistState.DEAD

func _on_scientist_rescued(scientist_id : int) -> void:
	scientist_states[scientist_id] = ScientistState.RESCUED

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
