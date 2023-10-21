extends CharacterBody3D

const TURN_SPEED : float = 8.0
const PATROL_SPEED : float = 2.0
const CHASE_SPEED : float = 4.0
const MAX_SLASH_DISTANCE : float = 3.0

@export var DistanceToCheckpoint := 1.0
var distance_to_checkpoint_squared = DistanceToCheckpoint*DistanceToCheckpoint

@export var DistanceToAttack := 1.5
var distance_to_attack_squared := DistanceToAttack*DistanceToAttack

@export var SpeedPatrol := 1.0
@export var SpeedChase := 2.0
const ANIM_WALK_BASE_SPEED := 1.0
var anim_chase_speed := ANIM_WALK_BASE_SPEED * (SpeedChase / SpeedPatrol) # Used to make animation faster

@export var VelocityDamp := 0.2 # 1.0 kills velocity instantly, means no inertia

@export var IdleTime := 2.0
var idle_counter := 0.0

@export var ConfusionTimes = {
	"chase_from_idle": 0.5,
	"change_chase_target": 2.0,
}
var confusion_counter := 0.0

@export var AnimationHitDelayAttackMelee := 0.55
@export var AnimationHitDelayAttackRanged := 0.4
var attack_hit_counter := 0.0

@export var AnimationDelayAttack := 1.0
var attack_counter := 0.0

@onready var anims: AnimationTree = $AnimationTree
@onready var prey_detector: Area3D = $PreyDetector
@onready var eyes: Marker3D = $rig_deform/Skeleton3D/BoneHead/Eyes

enum States {
	IDLE,
	PATROLLING,
	CHASING,
	ATTACK_MELEE,
	ATTACK_RANGE,
	HURT,
	STUNNED,
	DEATH
} 
var current_state := States.IDLE

var current_prey: CharacterBody3D = null
var move_target := Vector3.ZERO
var rotation_target_y := 0.0

var is_player_at_sight_range := false
var is_scientist_at_sight_range := false
var bodies_at_sight_range := []

func _ready():
	anims.active = true

func _physics_process(delta):
	if MadTalkGlobals.is_during_dialog:
		return
	
	# ========================================================================
	# ENVIRONMENT AWARENESS
	
	var is_player_visible := false
	var is_prey_visible := false
	
	if is_player_at_sight_range:
		# Check if vision is obstructed
		# is_player_visible requires is_player_at_sight_range
		is_player_visible = check_prey_line_of_sight(GameSession.player)
	
	if current_prey:
		if current_prey == GameSession.player:
			is_prey_visible = is_player_visible # to avoid double raycasting
		else:
			is_prey_visible = check_prey_line_of_sight(current_prey)
		
		
	
	# ========================================================================
	# MOVEMENT
	
	var must_orient_to_target := false
	
	# Velocity always damps
	velocity = lerp(velocity, Vector3.ZERO, VelocityDamp)
	
	# State machine
	match current_state:
		States.IDLE:
			# Player is always priority
			if is_player_visible:
				assign_prey(GameSession.player)
				change_state_to(States.CHASING)
			else:
				idle_counter -= delta
				if idle_counter <= 0:
					find_next_patrol_target()
					change_state_to(States.PATROLLING)
		
		States.PATROLLING:
			if is_player_visible:
				assign_prey(GameSession.player)
				change_state_to(States.CHASING)
			else:
				must_orient_to_target = true
				var move_delta = move_target - global_position
				if move_delta.length_squared() <= distance_to_checkpoint_squared:
					idle_counter = IdleTime
					change_state_to(States.IDLE)
				else:
					var move_dir = move_delta.normalized()
					velocity = move_dir * SpeedPatrol
		
		States.CHASING:
			if is_player_visible and (current_prey != GameSession.player):
				assign_prey(GameSession.player)
				change_state_to(States.CHASING)
			else:
				must_orient_to_target = true
				move_target = current_prey.global_position
				var move_delta = move_target - global_position
				if move_delta.length_squared() <= distance_to_attack_squared:
					attack_hit_counter = AnimationHitDelayAttackMelee
					attack_counter = AnimationDelayAttack
					change_state_to(States.ATTACK_MELEE)
				else:
					var move_dir = move_delta.normalized()
					velocity = move_dir * SpeedChase
		
		States.ATTACK_MELEE:
			if attack_hit_counter > 0:
				attack_hit_counter -= delta
				if attack_hit_counter <= 0:
					attack_hit_melee()
			
			attack_counter -= delta
			if attack_counter <= 0:
				change_state_to(States.CHASING)
	
	move_and_slide()
	
	# ========================================================================
	# ORIENTATION
	
	if must_orient_to_target:
		var delta_pos = move_target - global_position
		rotation_target_y = atan2(-delta_pos.x, -delta_pos.z)
		rotation.y = lerp_angle(rotation.y, rotation_target_y, delta * TURN_SPEED)
	
	# ========================================================================
	# ANIMATION


func change_state_to(new_state: States):
	# Any cleanup before leaving the state
	match current_state:
		_:
			pass
	
	# Any setup when entering a state
	match new_state:
		States.IDLE:
			anims.set("parameters/movement/transition_request", "idle")
		
		States.PATROLLING:
			anims.set("parameters/walk_speed/scale", ANIM_WALK_BASE_SPEED)
			anims.set("parameters/movement/transition_request", "walk")
		
		States.CHASING:
			# Confusion time depends on previous state:
			match current_state:
				States.CHASING:
					confusion_counter = ConfusionTimes["change_chase_target"]
				_:
					confusion_counter = ConfusionTimes["chase_from_idle"]
			anims.set("parameters/walk_speed/scale", anim_chase_speed)
			anims.set("parameters/movement/transition_request", "walk")
		
		States.ATTACK_MELEE:
			anims.set("parameters/movement/transition_request", "idle")
			anims.set("parameters/attack_melee/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		
		
		_:
			pass
	
	print("State: ", States.keys()[new_state])
	current_state = new_state


func assign_prey(new_prey: CharacterBody3D):
	current_prey = new_prey

func find_next_patrol_target():
	pass
	# TODO
	move_target = global_position + Vector3(
		randf_range(-1.0, 1.0)*5.0,
		0.0,
		randf_range(-1.0, 1.0)*5.0
	)


func check_prey_line_of_sight(prey) -> bool:
	# ONLY CALL IN PHYSICS FRAME!
	# Returns true if there is valid line of sight to the prey
	
	if not (prey is Player or prey is Scientist):
		return false
	
	var start_pos = eyes.global_position
	var end_pos = prey.eyes.global_position
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(start_pos, end_pos)
	var result = space_state.intersect_ray(query)
	
	if result.size() == 0:
		# Didn't collide with anything, not even prey itself
		# This **IS VALID** because the model's head might move
		# outside the collision shape in some animations (e.g. running)
		return true
	
	if result["collider"] == prey:
		# Collided with prey, nothing else in the way
		return true
	
	return false


func attack_hit_melee():
	print("ATTACK")


func _update_prey_list():
	bodies_at_sight_range = prey_detector.get_overlapping_bodies()
	var player_found := false
	var scientist_found := false
	for body in bodies_at_sight_range:
		if body is Player:
			player_found = true
		elif body is Scientist:
			scientist_found = true
		
	is_player_at_sight_range = player_found
	is_scientist_at_sight_range = scientist_found

func _on_prey_detector_body_entered(_body):
	_update_prey_list()

func _on_prey_detector_body_exited(_body):
	_update_prey_list()


#
#const MAX_INTEREST : float = 10.0
#const MAX_COOLDOWN : float = 4.0
#
#enum State {
#	PATROLLING, 
#	CHASING_PLAYER, 
#	CHASING_SCIENTIST, 
#	SPITTING, 
#	SLASHING, 
#	HARVESTING, 
#	HURT, 
#	STUNNED, 
#	LOSING_ARM, 
#	DYING, 
#	DEAD
#}
#
#
#@onready var anim_player : AnimationPlayer = $AnimationPlayer
#
#@onready var current_state : int = State.PATROLLING
#var target : Node3D
#var last_seen_position : Vector3
#var interest : float = MAX_INTEREST
#var attack_cooldown : float = MAX_COOLDOWN
#
#func get_arm_type() -> int:
#	return Constants.ArmType.HEAVY
#
#func can_be_ripped() -> bool:
#	return true
#	#return current_state == State.STUNNED
#
#func get_player_if_seen() -> Node3D:
#	return null
#
#func get_scientist_if_seen() -> Node3D:
#	return null
#
#func patrol(delta : float) -> void:
#	pass
#
#func slash() -> void:
#	pass
#
#func spit() -> void:
#	pass
#
#func ripped(by_whom : Node3D) -> void:
#	current_state = State.LOSING_ARM
#	anim_player.play("ripped")
#
#func _physics_process_patrolling(delta : float) -> void:
#	var player : Node3D = get_player_if_seen()
#	var scientist : Node3D = get_scientist_if_seen()
#	# A monster will always choose a player over a scientist as a target
#	if player != null:
#		target = player
#		last_seen_position = player.global_position
#		interest = MAX_INTEREST
#		current_state = State.CHASING_PLAYER
#	elif scientist != null:
#		target = scientist
#		last_seen_position = scientist.global_position
#		interest = MAX_INTEREST
#		current_state = State.CHASING_SCIENTIST
#	else:
#		patrol(delta)
#		pass
#
#func _physics_process_chasing_player(delta) -> void:
#	var player : Node3D = get_player_if_seen()
#	if player != null:
#		# Maybe shoot/slash
#		interest = MAX_INTEREST
#		attack_cooldown -= delta
#		if attack_cooldown <= 0.0:
#			attack_cooldown = MAX_COOLDOWN
#			var distance_to_player : float = global_position.distance_to(player.global_position)
#			if distance_to_player < MAX_SLASH_DISTANCE:
#				slash()
#			else:
#				spit()
#	else:
#		interest -= delta
#		if interest <= 0.0:
#			target = null
#			current_state = State.PATROLLING
#
#func _on_animation_player_animation_finished(anim_name : String) -> void:
#	match anim_player:
#		"ripped":
#			current_state = State.DEAD


