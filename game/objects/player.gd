extends CharacterBody3D
class_name Player

const TURN_SPEED : float = 4.0
const MOVE_SPEED : float = 3.0

enum State {NORMAL, WEAPON_DRAWN}
enum Arm {NONE}

@onready var current_state : int = State.NORMAL
@onready var current_arm : int = Arm.NONE

func _physics_process_normal(delta : float) -> void:
	var turn_amount : float = Input.get_axis("left", "right")
	if turn_amount != 0.0:
		rotate_y(-turn_amount * TURN_SPEED * delta)
	var move_amount : float = Input.get_axis("up", "down")
	if move_amount != 0.0:
		move_and_collide(-Vector3.FORWARD.rotated(Vector3.UP, rotation.y) * MOVE_SPEED * delta)

func _physics_process(delta : float) -> void:
	match current_state:
		State.NORMAL: _physics_process_normal(delta)
