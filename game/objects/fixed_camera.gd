extends Camera3D

const FOV_CHANGE : float = 5.0

@onready var regular_fov : float = fov
@onready var target_fov : float = fov

func _on_player_weapon_drawn() -> void:
	target_fov = regular_fov + 10.0
	
func _on_player_weapon_stowed() -> void:
	target_fov = regular_fov

func _on_player_entered() -> void:
	make_current()

func _process(delta : float) -> void:
	fov = lerp(fov, target_fov, FOV_CHANGE * delta)
