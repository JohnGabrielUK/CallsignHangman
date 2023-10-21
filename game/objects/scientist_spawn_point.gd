extends Node3D

const _Scientist : PackedScene = preload("res://objects/scientist.tscn")

@export var scientist_id : int

func spawn_scientist() -> void:
	if GameSession.player_tagalong != scientist_id and GameSession.is_scientist_alive(scientist_id):
		var scientist : Node3D = _Scientist.instantiate()
		get_parent().add_child(scientist)
		scientist.id = scientist_id
		scientist.global_position = global_position
