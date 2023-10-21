extends CharacterBody3D
class_name Player

const _StepSounds : Array = [
	preload("res://audio/sfx/step1.ogg"),
	preload("res://audio/sfx/step2.ogg"),
	preload("res://audio/sfx/step3.ogg")
]

const _FleetingSound : PackedScene = preload("res://objects/fleeting_sound.tscn")

const TURN_SPEED : float = 4.0
const MOVE_SPEED : float = 3.0
const TURN_WITH_WEAPON_SPEED : float = 2.0
const MOVE_WITH_WEAPON_SPEED : float = 2.0
const INTERACT_DISTANCE : float = 2.0

enum State {NORMAL, DRAWING_WEAPON, WEAPON_DRAWN, HOLSTERING_WEAPON, SHOOTING, KNIFE_ATTACK, RIPPING, HIT, DYING, DEAD}

@onready var raycast_interactable : RayCast3D = $RayCast_Interactable
@onready var anim_player : AnimationPlayer = $AnimationPlayer
@onready var eyes: Marker3D = $rig_deform/Skeleton3D/BoneHead/Eyes

@onready var current_state : int = State.NORMAL
@onready var current_arm : int = Constants.ArmType.NONE

func can_interact() -> bool:
	return raycast_interactable.is_colliding()

func can_harvest() -> bool:
	return false

func make_sound(which : AudioStream, volume : float) -> void:
	var sound : AudioStreamPlayer3D = _FleetingSound.instantiate()
	sound.stream = which
	sound.volume_db = volume
	get_parent().add_child(sound)
	sound.global_position = global_position
	sound.play()

func do_footstep_sound() -> void:
	make_sound(_StepSounds.pick_random(), -10.0)

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
			switch_animation_if_not_current("riparm", 0.25)

func switch_animation_if_not_current(anim_name : String, blend_amount : float) -> void:
	if anim_player.current_animation != anim_name:
		anim_player.play(anim_name, blend_amount)

# The jankiest of janky hacks
func move_and_collide_split(amount : Vector3) -> void:
	move_and_collide(amount * Vector3(1.0, 0.5, 0.0))
	move_and_collide(amount * Vector3(0.0, 0.5, 1.0))

func _physics_process_normal(delta : float) -> void:
	var turn_amount : float = Input.get_axis("left", "right")
	if turn_amount != 0.0:
		rotate_y(-turn_amount * TURN_SPEED * delta)
	var move_amount : float = Input.get_axis("up", "down")
	if move_amount != 0.0:
		move_and_collide_split(-Vector3.FORWARD.rotated(Vector3.UP, rotation.y) * MOVE_SPEED * delta)
		if anim_player.current_animation != "run":
			switch_animation_if_not_current("run", 0.25)
	elif anim_player.current_animation != "idle":
		switch_animation_if_not_current("idle", 0.25)
	if Input.is_action_just_pressed("interact"):
		try_to_interact()
	elif Input.is_action_just_pressed("harvest"):
		try_to_harvest()
	elif Input.is_action_just_pressed("draw_weapon"):
		anim_player.play("aim_start")
		current_state = State.DRAWING_WEAPON

func _physics_process_weapon_drawn(delta : float) -> void:
	var turn_amount : float = Input.get_axis("left", "right")
	if turn_amount != 0.0:
		rotate_y(-turn_amount * TURN_WITH_WEAPON_SPEED * delta)
	if Input.is_action_just_pressed("draw_weapon"):
		anim_player.play("aim_end")
		current_state = State.HOLSTERING_WEAPON
	elif Input.is_action_just_pressed("attack"):
		anim_player.play("shoot_heavy")
		current_state = State.SHOOTING

func _physics_process(delta : float) -> void:
	if MadTalkGlobals.is_during_dialog:
		current_state = State.NORMAL
		switch_animation_if_not_current("idle", 0.25)
		if Input.is_action_just_pressed("interact"):
			GameSession.madtalk.dialog_acknowledge()
		return
	get_tree().call_group("game_controller", "set_prompts_visible", can_interact(), can_harvest())
	match current_state:
		State.NORMAL: _physics_process_normal(delta)
		State.WEAPON_DRAWN: _physics_process_weapon_drawn(delta)

func _ready() -> void:
	GameSession.player = self
	switch_animation_if_not_current("idle", 0.0)

func _on_animation_player_animation_finished(anim_name : String) -> void:
	match anim_name:
		"rip_arm":
			current_state = State.NORMAL
		"aim_start":
			switch_animation_if_not_current("aim", 0.0)
			current_state = State.WEAPON_DRAWN
		"aim_end":
			switch_animation_if_not_current("idle", 0.0)
			current_state = State.NORMAL
		"shoot_heavy":
			switch_animation_if_not_current("aim", 0.0)
			current_state = State.WEAPON_DRAWN
