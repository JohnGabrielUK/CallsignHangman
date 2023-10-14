extends CharacterBody3D
class_name Scientist

signal dead
signal rescued

const TURN_SPEED : float = 4.0
const MOVE_SPEED : float = 2.75
const FOLLOW_THRESHOLD : float = 1.5

enum State {NOT_YET_MET, FOLLOWING_PLAYER, WAITING}

@export var id : int

@onready var current_state : int = State.NOT_YET_MET
var following : Node3D

# I do not use NavigationAgent as I found it to be less reliable, sometimes
# the NPCs getting stuck in polygon edges
# Instead I retrieve a path straight from NavigationServer3D and get
# the next point. This means the scientists won't automatically dodge
# moving obstacles like doors or platforms or other scientists
# We can use NavigationAgent if we find them colliding too much with
# each other
@onready var navigation_map_rid = NavigationServer3D.get_maps()[0]


func rescue() -> void:
	emit_signal("rescued", id)
	queue_free()

func interact(by_whom : Node3D) -> void:
	match current_state:
		State.NOT_YET_MET:
			current_state = State.FOLLOWING_PLAYER
			following = by_whom
		State.FOLLOWING_PLAYER:
			current_state = State.WAITING
		State.WAITING:
			current_state = State.FOLLOWING_PLAYER

func _find_next_route_target():
	# First we project the scientist and player positions to the navigation map
	var start_point = NavigationServer3D.map_get_closest_point(navigation_map_rid, global_position)
	var target_point = NavigationServer3D.map_get_closest_point(navigation_map_rid, following.global_position)
	var point_list = NavigationServer3D.map_get_path(navigation_map_rid, start_point, target_point, true)
	# The resulting list includes the starting point, so
	# the very next target checkpoint is index 1, not index 0
	if point_list.size() < 2:
		return null # There are no valid checkpoints to go
	else:
		return point_list[1] # We take just the immediate next checkpoint
	

func _physics_process_following_player(delta : float) -> void:
	if following.global_position.distance_to(global_position) > FOLLOW_THRESHOLD:
		var next_target = _find_next_route_target()
		# We don't want the scientist to pitch and roll, only yaw, so we use 
		# look_at not to the target point but to a projection of that
		# point in the Y plane of the scientist
		# Fun fact: using rotation.y = atan2(...) instead of look_at also works
		var horizontal_position = next_target
		horizontal_position.y = global_position.y
		look_at(horizontal_position, Vector3(0, 1, 0), true)
		move_and_collide(-Vector3.FORWARD.rotated(Vector3.UP, rotation.y) * MOVE_SPEED * delta)
	else:
		var horizontal_position = following.global_position
		horizontal_position.y = global_position.y
		look_at(horizontal_position, Vector3(0, 1, 0), true)
		

func _physics_process(delta : float) -> void:
	match current_state:
		State.FOLLOWING_PLAYER: _physics_process_following_player(delta)
