extends Area3D

signal player_entered

func _on_body_entered(body : Node3D) -> void:
	if body is Player:
		emit_signal("player_entered")
