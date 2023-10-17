extends Node3D

const _Player : PackedScene = preload("res://objects/player.tscn")

func spawn_player(which_spawn : int) -> void:
	for player_spawn_point in get_tree().get_nodes_in_group("player_spawn_point"):
		if player_spawn_point.spawn_id == which_spawn:
			var player : Node3D = _Player.instantiate()
			add_child(player)
			player.global_position = player_spawn_point.global_position
			player.look_at(player_spawn_point.global_position + player_spawn_point.point_towards, Vector3(0, 1, 0), true)
