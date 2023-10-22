extends StaticBody3D

@export var destination_room : String
@export var destination_spawn_id : int

@onready var audio_open : AudioStreamPlayer3D = $Audio_Open

func interact(by_whom : Node3D) -> void:
	get_tree().call_group("game_controller", "change_room", destination_room, destination_spawn_id)
	audio_open.play()
