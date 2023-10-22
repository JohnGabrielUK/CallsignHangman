extends CharacterBody3D
class_name SpitSlash

const TURN_SPEED : float = 8.0
const PATROL_SPEED : float = 2.0
const CHASE_SPEED : float = 4.0
const MAX_SLASH_DISTANCE : float = 3.0

@export var DistanceToCheckpoint := 1.0
var distance_to_checkpoint_squared = DistanceToCheckpoint*DistanceToCheckpoint

@export var DistanceToAttackMelee := 1.5
var distance_to_attack_melee_squared := DistanceToAttackMelee*DistanceToAttackMelee

@export var SpeedPatrol := 1.0
@export var SpeedChase := 2.0
const ANIM_WALK_BASE_SPEED := 1.0
var anim_chase_speed := ANIM_WALK_BASE_SPEED * (SpeedChase / SpeedPatrol) # Used to make animation faster

@export var VelocityDamp := 0.2 # 1.0 kills velocity instantly, means no inertia

@export var IdleTime := 2.0
var idle_counter := 0.0

@export var RangedAttackTime := 2.0
var ranged_attack_counter := 0.0

@export var ConfusionTimes = {
	"chase_from_idle": 0.5,
	"change_chase_target": 2.0,
}
var confusion_counter := 0.0

@export var StunTime := 5.0
var stun_counter = 0.0

@export var AnimationHitDelayAttackMelee := 0.55
@export var AnimationHitDelayAttackRanged := 0.4
var attack_hit_counter := 0.0

@export var AnimationDelayAttack := 1.0
var attack_counter := 0.0

@export var HurtTime := 0.3
var hurt_counter := 0.0

@export var DamageMelee := 2.0
@export var DamageRanged := 1.0

@export var MaxHealth := 5.0
var health = MaxHealth

@export var MaxBlood := 5.0
var blood = MaxBlood

@export var ForceChasePlayerStopsChasingScientist := false

@export_node_path var PatrolPoints: NodePath = ""
var patrol_points := []
var next_patrol_point

@onready var anims: AnimationTree = $AnimationTree
@onready var prey_detector: Area3D = $PreyDetector
@onready var attack_melee_area: Area3D = $AttackMeleeArea
@onready var eyes: Marker3D = $model/rig_deform/Skeleton3D/BoneHead/Eyes

@onready var model_with_arm = $model/rig_deform/Skeleton3D/model_with_arm
@onready var model_no_arm = $model/rig_deform/Skeleton3D/model_no_arm

@onready var initial_position = global_position

@onready var navigation_map_rid = NavigationServer3D.get_maps()[0]


enum States {
	IDLE,
	PATROLLING,
	CHASING,
	ATTACK_MELEE,
	ATTACK_RANGE,
	HURT,
	STUNNED,
	DEATH,
	VANISH
} 
var current_state := States.IDLE
var state_before_hurt := States.IDLE

var current_prey: CharacterBody3D = null
var move_target := Vector3.ZERO
var rotation_target_y := 0.0

var is_player_at_sight_range := false
var is_scientist_at_sight_range := false
var bodies_at_sight_range := []

var force_chase_player_requested := false

var vanish_progress := 0.0

func _ready():
	anims.active = true
	var patrol_node = get_node_or_null(PatrolPoints)
	if patrol_node:
		patrol_points = patrol_node.get_children()

func _physics_process(delta):
	anims.active = not MadTalkGlobals.is_during_dialog
	if MadTalkGlobals.is_during_dialog:
		return
	
	# ========================================================================
	# VANISHING
	# Does not involve any calculations
	
	if current_state == States.VANISH:
		# There is no recovery from this state
		vanish_progress -= delta
		model_no_arm.transparency = clamp(1.0 - vanish_progress, 0.0, 1.0)
		model_with_arm.transparency = clamp(1.0 - vanish_progress, 0.0, 1.0)
		if vanish_progress <= 0:
			set_physics_process(false)
			queue_free()
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
			if force_chase_player_requested:
				force_chase_player_requested = false
				assign_prey(GameSession.player)
				change_state_to(States.CHASING)
			
			elif is_player_visible:
				assign_prey(GameSession.player)
				change_state_to(States.CHASING)
			
			else:
				var new_target_assigned := false
				if ((not current_prey) or (not is_prey_visible)) and is_scientist_at_sight_range and (bodies_at_sight_range.size() > 0):
					for body in bodies_at_sight_range:
						var is_body_visible = check_prey_line_of_sight(body)
						if is_body_visible:
							assign_prey(body)
							is_prey_visible = true
							break
				
				if not new_target_assigned:
					if is_prey_visible:
						change_state_to(States.CHASING)
					else:
						idle_counter -= delta
						if idle_counter <= 0:
							find_next_patrol_target()
							change_state_to(States.PATROLLING)
			
		States.PATROLLING:
			if force_chase_player_requested:
				force_chase_player_requested = false
				assign_prey(GameSession.player)
				change_state_to(States.CHASING)
			
			elif is_player_visible:
				assign_prey(GameSession.player)
				change_state_to(States.CHASING)
			else:
				var new_target_assigned := false
				if ((not current_prey) or (not is_prey_visible)) and is_scientist_at_sight_range and (bodies_at_sight_range.size() > 0):
					for body in bodies_at_sight_range:
						var is_body_visible = check_prey_line_of_sight(body)
						if is_body_visible:
							assign_prey(body)
							is_prey_visible = true
							break
				
				if not new_target_assigned:
					if is_prey_visible:
						change_state_to(States.CHASING)
					else:
						var move_target_nav = _find_next_route_target(move_target)
						if move_target_nav:
							must_orient_to_target = true
							var move_delta = move_target_nav - global_position
							if move_delta.length_squared() <= distance_to_checkpoint_squared:
								idle_counter = IdleTime
								change_state_to(States.IDLE)
							else:
								var move_dir = move_delta.normalized()
								velocity = move_dir * SpeedPatrol
		
		States.CHASING:
			
			if force_chase_player_requested:
				force_chase_player_requested = false
				if ForceChasePlayerStopsChasingScientist:
					assign_prey(GameSession.player)
					change_state_to(States.CHASING)
			
			elif confusion_counter > 0:
				confusion_counter -= delta
			
			elif is_player_visible and (current_prey != GameSession.player):
				assign_prey(GameSession.player)
				change_state_to(States.CHASING)
			else:
				must_orient_to_target = true
				move_target = current_prey.global_position
				
				var is_prey_still_visible = check_prey_line_of_sight(current_prey)
				
				var move_delta = move_target - global_position
				if move_delta.length_squared() <= distance_to_attack_melee_squared:
					attack_hit_counter = AnimationHitDelayAttackMelee
					attack_counter = AnimationDelayAttack
					change_state_to(States.ATTACK_MELEE)
				
				else:
					var move_target_nav = _find_next_route_target(move_target)
					if move_target_nav:
						move_delta = move_target_nav - global_position
						var move_dir = move_delta.normalized()
						velocity = move_dir * SpeedChase
		
		States.ATTACK_MELEE:
			if (not current_prey) or (not is_instance_valid(current_prey)):
				idle_counter = IdleTime
				change_state_to(States.IDLE)
			
			else:
				if attack_hit_counter > 0:
					attack_hit_counter -= delta
					if attack_hit_counter <= 0:
						attack_hit_melee(current_prey)
				
				attack_counter -= delta
				if attack_counter <= 0:
					change_state_to(States.CHASING)
		
		States.ATTACK_RANGE:
			pass
		
		States.HURT:
			hurt_counter -= delta
			if hurt_counter <= 0:
				if health <= 0:
					die()
				elif health <= 1.0:
					stun_counter = StunTime
					change_state_to(States.STUNNED)
				else:
					change_state_to(state_before_hurt)
					

		
		States.STUNNED:
			stun_counter -= delta
			if stun_counter <= 0:
				health += 2.0
				change_state_to(States.IDLE)
		
		States.DEATH:
			pass
		

	move_and_slide()
	global_position.y = 0.0 # Should not be needed as linear axis y is locked, but doesn't hurt
	
	# ========================================================================
	# ORIENTATION
	
	if must_orient_to_target:
		var delta_pos = move_target - global_position
		rotation_target_y = atan2(-delta_pos.x, -delta_pos.z)
		rotation.y = lerp_angle(rotation.y, rotation_target_y, delta * TURN_SPEED)
	



func change_state_to(new_state: States):
	# Any cleanup before leaving the state
	if (current_state == States.HURT):
		if (state_before_hurt == States.STUNNED) and (new_state != States.DEATH):
			anims.set("parameters/stun/transition_request", "end")
	
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
			ranged_attack_counter = RangedAttackTime
			anims.set("parameters/walk_speed/scale", anim_chase_speed)
			anims.set("parameters/movement/transition_request", "walk")
			
			get_tree().call_group("game_controller", "on_enemy_aggression")
		
		States.ATTACK_MELEE:
			anims.set("parameters/movement/transition_request", "idle")
			anims.set("parameters/attack_melee/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		
		States.ATTACK_RANGE:
			pass
		
		States.HURT:
			anims.set("parameters/hit/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		
		States.STUNNED:
			anims.set("parameters/stun/transition_request", "start")
		
		States.DEATH:
			# Death always happens with HURT as intermediate state, so
			# we use state_before_hurt instead of current_state
			if state_before_hurt == States.STUNNED:
				anims.set("parameters/stun/transition_request", "dead")
			else:
				anims.set("parameters/movement/transition_request", "dead")
			get_tree().call_group("game_controller", "on_enemy_dead")
		
		
		_:
			pass
	
	print("State: ", States.keys()[new_state])
	current_state = new_state




func assign_prey(new_prey: CharacterBody3D):
	current_prey = new_prey

func find_next_patrol_target():
	if patrol_points.size() > 0:
		var point_list = patrol_points.duplicate()
		if next_patrol_point:
			point_list.erase(next_patrol_point)
		next_patrol_point = point_list[ randi() % point_list.size() ]
		move_target = next_patrol_point.global_position
	
	else:
		move_target = initial_position + Vector3(
			randf_range(-1.0, 1.0)*3.0,
			0.0,
			randf_range(-1.0, 1.0)*3.0
		)


func _find_next_route_target(destination: Vector3):
	# First we project the positions to the navigation map
	var start_point = NavigationServer3D.map_get_closest_point(navigation_map_rid, global_position)
	var target_point = NavigationServer3D.map_get_closest_point(navigation_map_rid, destination)
	var point_list = NavigationServer3D.map_get_path(navigation_map_rid, start_point, target_point, true)
	# The resulting list includes the starting point, so
	# the very next target checkpoint is index 1, not index 0
	if point_list.size() < 2:
		return null # There are no valid checkpoints to go
	else:
		return point_list[1] # We take just the immediate next checkpoint


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


func can_be_shot() -> bool:
	return health > 0.0

func is_alive() -> bool:
	return health > 0.0

func is_harvestable() -> bool:
	return current_state == States.DEATH and blood > 0.0

func is_rippable() -> bool:
	return current_state == States.STUNNED

func get_blood_type() -> int:
	return Constants.BloodType.HEAT_RESISTANT

func harvest(amount: float = 0.0) -> bool:
	match current_state:
		States.DEATH:
			if blood > 0.0:
				blood -= amount
				if blood <= 0:
					vanish()
				return true
			else:
				return false
			
		_:
			return false

func rip() -> void:
	if current_state == States.STUNNED:
		model_no_arm.show()
		model_with_arm.hide()
		die()

func vanish():
	vanish_progress = 1.0
	change_state_to(States.VANISH)

func attack_hit_melee(prey: CharacterBody3D):
	if attack_melee_area.overlaps_body(prey):
		prey.hit(DamageMelee)
		print("ATTACK")

func attack_hit_ranged(prey: CharacterBody3D):
	pass
		


func hit(damage: float = 1.0):
	if (current_state in [States.DEATH, States.VANISH]):
		return
	
	health -= damage
	
	match current_state:
		States.IDLE, States.PATROLLING:
			assign_prey(GameSession.player)
			state_before_hurt = States.CHASING
		States.CHASING:
			assign_prey(GameSession.player)
		_:
			state_before_hurt = current_state
	
	hurt_counter = HurtTime
	change_state_to(States.HURT)


func force_chase_player():
	force_chase_player_requested = true


func die():
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	change_state_to(States.DEATH)


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

