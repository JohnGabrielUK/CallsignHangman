extends Node3D

const _Player : PackedScene = preload("res://objects/player.tscn")
const _Scientist : PackedScene = preload("res://objects/scientist.tscn")

func spawn_player(which_spawn : int) -> void:
	for player_spawn_point in get_tree().get_nodes_in_group("player_spawn_point"):
		if player_spawn_point.spawn_id == which_spawn:
			var player : Node3D = _Player.instantiate()
			add_child(player)
			player.global_position = player_spawn_point.global_position + player_spawn_point.point_towards
			player.look_at(player_spawn_point.global_position + (player_spawn_point.point_towards * 2), Vector3(0, 1, 0), true)
			# Spawn scientist if they're following player
			if GameSession.is_scientist_following_player():
				var scientist : Node3D = _Scientist.instantiate()
				add_child(scientist)
				scientist.global_position = player_spawn_point.global_position
				scientist.id = GameSession.player_tagalong
				scientist.look_at(player_spawn_point.global_position + player_spawn_point.point_towards, Vector3(0, 1, 0), true)
				scientist.follow_player_from_spawn(player)

func spawn_scientists() -> void:
	get_tree().call_group("scientist_spawn_point", "spawn_scientist")
