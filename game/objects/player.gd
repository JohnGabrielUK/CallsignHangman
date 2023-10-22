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
const MAX_BLOOD : float = 10.0
const HARVEST_AMOUNT : float = 1.0
const BLOOD_DRAIN_RATE : float = 0.1
const MICROWAVE_DAMAGE_RATE : float = 2.5

enum State {NORMAL, DRAWING_WEAPON, WEAPON_DRAWN, HOLSTERING_WEAPON, SHOOTING, KNIFE_ATTACK, HARVEST_START, HARVESTING, HARVEST_END, RIPPING, HIT, DYING, DEAD}

@onready var raycast_interactable : RayCast3D = $RayCast_Interactable
@onready var raycast_rippable : RayCast3D = $RayCast_Rippable
@onready var raycast_harvestable : RayCast3D = $RayCast_Harvestable
@onready var anim_player : AnimationPlayer = $AnimationPlayer
@onready var eyes: Marker3D = $rig_deform/Skeleton3D/BoneHead/Eyes
@onready var raycasts_gun : Node3D = $RayCasts_Gun

@onready var current_state : int = State.NORMAL
@onready var current_arm : int = Constants.ArmType.NONE

var harvest_target : Node3D

var bloods : Vector3 = GameSession.player_blood

func get_blood_amount() -> float:
	return bloods.x + bloods.y + bloods.z

func get_dominant_blood_type() -> int:
	if bloods.y > bloods.x + bloods.z: return Constants.BloodType.HEAT_RESISTANT
	if bloods.z > bloods.x + bloods.y: return Constants.BloodType.SOMETHING_ELSE
	return Constants.BloodType.HUMAN

func add_blood(amount : float, type : int) -> void:
	match type:
		Constants.BloodType.HUMAN: bloods.x += amount
		Constants.BloodType.HEAT_RESISTANT: bloods.y += amount
		Constants.BloodType.SOMETHING_ELSE: bloods.z += amount
	if get_blood_amount() > MAX_BLOOD:
		var blood_divisor : float = get_blood_amount() / MAX_BLOOD
		bloods.x /= blood_divisor
		bloods.y /= blood_divisor
		bloods.z /= blood_divisor

func remove_blood(amount : float) -> void:
	var total_blood : float = get_blood_amount()
	var blood_ratio = bloods / total_blood
	bloods -= amount * blood_ratio

func check_for_microwave_damage(delta : float) -> void:
	var room_has_microwaves : bool = get_tree().get_nodes_in_group("microwaves").size() != 0
	var microwaves_disabled : bool = !GameSession.microwave_active
	var player_immune : bool = get_dominant_blood_type() == Constants.BloodType.HEAT_RESISTANT
	if room_has_microwaves and not (microwaves_disabled or player_immune):
		remove_blood(MICROWAVE_DAMAGE_RATE * delta)

func can_interact() -> bool:
	return raycast_interactable.is_colliding()

func can_harvest() -> bool:
	var candidate : Node3D = raycast_harvestable.get_collider()
	if candidate != null:
		return candidate.is_harvestable()
	else:
		return false

func can_rip() -> bool:
	var candidate : Node3D = raycast_rippable.get_collider()
	if candidate != null:
		return candidate.is_rippable()
	else:
		return false

func get_gunfire_target() -> Node3D:
	var friendly_target : Node3D = null
	for raycast in raycasts_gun.get_children():
		if raycast.is_colliding():
			var target = raycast.get_collider()
			if target.is_in_group("enemy") and target.can_be_shot():
				return target
			if target.is_in_group("ally"):
				friendly_target = target
	return friendly_target

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
	var candidate : Node3D = raycast_harvestable.get_collider()
	if candidate and candidate.is_harvestable():
		harvest_target = candidate
		switch_animation_if_not_current("harvest_start", 0.25)
		current_state = State.HARVEST_START

func try_to_rip() -> void:
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

func hit(damage: float = 1.0):
	pass

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
	elif Input.is_action_pressed("harvest"):
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
		var target : Node3D = get_gunfire_target()
		if target != null:
			target.hit(1.0)

func _physics_process_harvesting(delta : float) -> void:
	var harvest_amount : float = HARVEST_AMOUNT * delta
	var harvest_successful : bool = harvest_target.harvest(harvest_amount)
	if harvest_successful:
		add_blood(harvest_amount, harvest_target.get_blood_type())
	if not harvest_successful or !Input.is_action_pressed("harvest"):
		anim_player.play("harvest_end")
		current_state = State.HARVEST_END

func _physics_process(delta : float) -> void:
	if MadTalkGlobals.is_during_dialog:
		current_state = State.NORMAL
		switch_animation_if_not_current("idle", 0.25)
		if Input.is_action_just_pressed("interact"):
			GameSession.madtalk.dialog_acknowledge()
		return
	get_tree().call_group("game_controller", "set_prompts_visible", can_interact(), can_harvest(), can_rip())
	match current_state:
		State.NORMAL: _physics_process_normal(delta)
		State.WEAPON_DRAWN: _physics_process_weapon_drawn(delta)
		State.HARVESTING: _physics_process_harvesting(delta)
	check_for_microwave_damage(delta)
	remove_blood(BLOOD_DRAIN_RATE * delta)
	GameSession.player_blood = bloods
	print(snapped(bloods.x, 0.1), "\t", snapped(bloods.y, 0.1), "\t", snapped(bloods.z, 0.1), "\t", snapped(get_blood_amount(), 0.1), "\t", get_dominant_blood_type())

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
		"harvest_start":
			switch_animation_if_not_current("harvest", 0.0)
			current_state = State.HARVESTING
		"harvest_end":
			switch_animation_if_not_current("idle", 0.0)
			current_state = State.NORMAL
