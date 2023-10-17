extends CharacterBody3D
class_name Player

const TURN_SPEED : float = 4.0
const MOVE_SPEED : float = 3.0
const TURN_WITH_WEAPON_SPEED : float = 2.0
const MOVE_WITH_WEAPON_SPEED : float = 2.0
const INTERACT_DISTANCE : float = 2.0

enum State {NORMAL, DRAWING_WEAPON, WEAPON_DRAWN, HOLSTERING_WEAPON, SHOOTING, KNIFE_ATTACK, RIPPING, HIT, DYING, DEAD}

@onready var raycast_interactable : RayCast3D = $RayCast_Interactable
@onready var anim_player : AnimationPlayer = $AnimationPlayer

@onready var current_state : int = State.NORMAL
@onready var current_arm : int = Constants.ArmType.NONE

func try_to_interact() -> void:
	if raycast_interactable.is_colliding():
		var candidate = raycast_interactable.get_collider()
		candidate.interact(self)

func try_to_harvest() -> void:
	for candidate in get_tree().get_nodes_in_group("rippable"):
		if candidate.can_be_ripped() and candidate.global_position.distance_to(global_position) < INTERACT_DISTANCE:
			candidate.ripped(self)
			current_arm = candidate.get_arm_type()
			current_state = State.RIPPING
			anim_player.play("rip_arm")

func _physics_process_normal(delta : float) -> void:
	var turn_amount : float = Input.get_axis("left", "right")
	if turn_amount != 0.0:
		rotate_y(-turn_amount * TURN_SPEED * delta)
	var move_amount : float = Input.get_axis("up", "down")
	if move_amount != 0.0:
		move_and_collide(-Vector3.FORWARD.rotated(Vector3.UP, rotation.y) * MOVE_SPEED * delta)
		if anim_player.current_animation != "run":
			anim_player.play("run", 0.25)
	elif anim_player.current_animation != "idle":
		anim_player.play("idle", 0.25)
	if Input.is_action_just_pressed("interact"):
		try_to_interact()
	elif Input.is_action_just_pressed("harvest"):
		try_to_harvest()
	elif Input.is_action_just_pressed("draw_weapon"):
		anim_player.play("draw_weapon")
		current_state = State.DRAWING_WEAPON

func _physics_process_weapon_drawn(delta : float) -> void:
	var turn_amount : float = Input.get_axis("left", "right")
	if turn_amount != 0.0:
		rotate_y(-turn_amount * TURN_WITH_WEAPON_SPEED * delta)
	var move_amount : float = Input.get_axis("up", "down")
	if move_amount != 0.0:
		move_and_collide(-Vector3.FORWARD.rotated(Vector3.UP, rotation.y) * MOVE_WITH_WEAPON_SPEED * delta)
		if anim_player.current_animation != "run_with_weapon":
			anim_player.play("run_with_weapon", 0.25)
	elif anim_player.current_animation != "idle_with_weapon":
		anim_player.play("idle_with_weapon", 0.25)
	if Input.is_action_just_pressed("draw_weapon"):
		anim_player.play("holster_weapon")
		current_state = State.HOLSTERING_WEAPON
	elif Input.is_action_just_pressed("attack"):
		anim_player.play("shoot")
		current_state = State.SHOOTING
		

func _physics_process(delta : float) -> void:
	match current_state:
		State.NORMAL: _physics_process_normal(delta)
		State.WEAPON_DRAWN: _physics_process_weapon_drawn(delta)

func _ready() -> void:
	anim_player.play("idle")

func _on_animation_player_animation_finished(anim_name : String) -> void:
	match anim_name:
		"rip_arm":
			current_state = State.NORMAL
		"draw_weapon":
			anim_player.play("idle_with_weapon")
			current_state = State.WEAPON_DRAWN
		"holster_weapon":
			anim_player.play("idle")
			current_state = State.NORMAL
		"shoot":
			anim_player.play("idle_with_weapon")
			current_state = State.WEAPON_DRAWN
