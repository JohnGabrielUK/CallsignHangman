extends CharacterBody3D
class_name Scientist

const TURN_SPEED : float = 4.0
const MOVE_SPEED : float = 2.75
const FOLLOW_THRESHOLD : float = 1.5

enum State {NOT_YET_MET, FOLLOWING_PLAYER, WAITING}

@onready var current_state : int = State.NOT_YET_MET
var following : Node3D

func interact(by_whom : Node3D) -> void:
	match current_state:
		State.NOT_YET_MET:
			current_state = State.FOLLOWING_PLAYER
			following = by_whom
		State.FOLLOWING_PLAYER:
			current_state = State.WAITING
		State.WAITING:
			current_state = State.FOLLOWING_PLAYER

func _physics_process_following_player(delta : float) -> void:
	look_at(following.global_position, Vector3(0, 1, 0), true)
	if following.global_position.distance_to(global_position) > FOLLOW_THRESHOLD:
		move_and_collide(-Vector3.FORWARD.rotated(Vector3.UP, rotation.y) * MOVE_SPEED * delta)

func _physics_process(delta : float) -> void:
	match current_state:
		State.FOLLOWING_PLAYER: _physics_process_following_player(delta)
