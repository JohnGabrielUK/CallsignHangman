extends CharacterBody3D

const TURN_SPEED : float = 4.0
const PATROL_SPEED : float = 2.0
const CHASE_SPEED : float = 4.0
const MAX_INTEREST : float = 10.0
const MAX_COOLDOWN : float = 4.0
const MAX_SLASH_DISTANCE : float = 3.0

enum State {PATROLLING, CHASING_PLAYER, CHASING_SCIENTIST, SPITTING, SLASHING, HARVESTING, HURT, STUNNED, LOSING_ARM, DYING, DEAD}

@onready var current_state : int = State.PATROLLING
var target : Node3D
var last_seen_position : Vector3
var interest : float = MAX_INTEREST
var attack_cooldown : float = MAX_COOLDOWN

func get_player_if_seen() -> Node3D:
	return null

func get_scientist_if_seen() -> Node3D:
	return null

func patrol(delta : float) -> void:
	pass

func slash() -> void:
	pass

func spit() -> void:
	pass

func _physics_process_patrolling(delta : float) -> void:
	var player : Node3D = get_player_if_seen()
	var scientist : Node3D = get_scientist_if_seen()
	# A monster will always choose a player over a scientist as a target
	if player != null:
		target = player
		last_seen_position = player.global_position
		interest = MAX_INTEREST
		current_state = State.CHASING_PLAYER
	elif scientist != null:
		target = scientist
		last_seen_position = scientist.global_position
		interest = MAX_INTEREST
		current_state = State.CHASING_SCIENTIST
	else:
		patrol(delta)
		pass

func _physics_process_chasing_player(delta) -> void:
	var player : Node3D = get_player_if_seen()
	if player != null:
		# Maybe shoot/slash
		interest = MAX_INTEREST
		attack_cooldown -= delta
		if attack_cooldown <= 0.0:
			attack_cooldown = MAX_COOLDOWN
			var distance_to_player : float = global_position.distance_to(player.global_position)
			if distance_to_player < MAX_SLASH_DISTANCE:
				slash()
			else:
				spit()
	else:
		interest -= delta
		if interest <= 0.0:
			target = null
			current_state = State.PATROLLING
