extends StaticBody3D

@export var terminal_id : String

func interact(by_whom : Node3D) -> void:
	GameSession.terminal_activated(terminal_id)
