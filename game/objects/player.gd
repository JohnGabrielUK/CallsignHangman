extends CharacterBody3D
class_name Player

const _StepSounds : Array = [
	preload("res://audio/sfx/step1.ogg"),
	preload("res://audio/sfx/step2.ogg"),
	preload("res://audio/sfx/step3.ogg")
]

const _FleetingSound : PackedScene = preload("res://objects/fleeting_sound.tscn")

const TURN_SPEED : float = 4.0
const RUN_SPEED : float = 3.0
const MOVE_SPEED : float = 1.35
const TURN_WITH_WEAPON_SPEED : float = 2.0
const MOVE_WITH_WEAPON_SPEED : float = 1.35
const INTERACT_DISTANCE : float = 2.0
const MAX_BLOOD : float = 10.0
const HARVEST_AMOUNT : float = 1.0
const BLOOD_DRAIN_RATE : float = 0.05
const MICROWAVE_DAMAGE_RATE : float = 2.5
const GUN_RANGE : float = 10.0
const MELEE_RANGE : float = 2.0

enum State {NORMAL, DRAWING_WEAPON, WEAPON_DRAWN, HOLSTERING_WEAPON, SHOOTING, PISTOL_WHIP, HARVEST_START, HARVESTING, HARVEST_END, RIPPING, HIT, HIT_WHILE_AIMING, ARM_ATTACK, DEAD}

@onready var mesh : MeshInstance3D = $rig_deform/Skeleton3D/Character
@onready var mesh_grab_arm : MeshInstance3D = $rig_deform/Skeleton3D/Character_GrabArm
@onready var mesh_heavy_arm : MeshInstance3D = $rig_deform/Skeleton3D/Character_HeavyArm
@onready var raycast_interactable : RayCast3D = $RayCast_Interactable
@onready var raycast_rippable : RayCast3D = $RayCast_Rippable
@onready var raycast_harvestable : RayCast3D = $RayCast_Harvestable
@onready var anim_player : AnimationPlayer = $AnimationPlayer
@onready var eyes: Marker3D = $rig_deform/Skeleton3D/BoneHead/Eyes
@onready var raycasts_gun : Node3D = $RayCasts_Gun

@onready var current_state : int = State.NORMAL
@onready var current_arm : int = GameSession.player_arm

@onready var sfx_gunshot = $SFXGunshot
@onready var spark_gunshot = $rig_deform/Skeleton3D/BoneGun/Gunshot

var harvest_target : Node3D
var arm_to_get : int

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
	check_for_death()

func check_for_microwave_damage(delta : float) -> void:
	var room_has_microwaves : bool = get_tree().get_nodes_in_group("microwaves").size() != 0
	var microwaves_disabled : bool = !GameSession.microwave_active
	var player_immune : bool = get_dominant_blood_type() == Constants.BloodType.HEAT_RESISTANT
	if room_has_microwaves and not (microwaves_disabled or player_immune):
		remove_blood(MICROWAVE_DAMAGE_RATE * delta)

func check_for_death() -> void:
	if get_blood_amount() <= 0.0 and current_state != State.DEAD:
		anim_player.play("death", 0.25)
		current_state = State.DEAD
		get_tree().call_group("game_controller", "stop_music")

func can_interact() -> bool:
	return raycast_interactable.is_colliding()

func can_harvest() -> bool:
	if current_state != State.NORMAL:
		return false
	var candidate : Node3D = raycast_harvestable.get_collider()
	if candidate != null:
		return candidate.is_harvestable()
	else:
		return false

func can_rip() -> bool:
	if current_state != State.NORMAL:
		return false
	var candidate : Node3D = raycast_rippable.get_collider()
	if candidate != null:
		return candidate.is_rippable()
	else:
		return false

func get_gunfire_target(range : float) -> Node3D:
	var friendly_target : Node3D = null
	for raycast in raycasts_gun.get_children():
		raycast.target_position.z = range
		raycast.force_raycast_update()
		if raycast.is_colliding():
			var target = raycast.get_collider()
			if target.is_in_group("enemy") and target.can_be_shot():
				return target
			if target.is_in_group("friendly"):
				friendly_target = target
	return friendly_target

func make_sound(which : AudioStream, volume : float) -> void:
	var sound : AudioStreamPlayer3D = _FleetingSound.instantiate()
	sound.stream = which
	sound.volume_db = volume
	get_parent().add_child(sound)
	sound.global_position = global_position
	sound.play()

func do_run_step_sound() -> void:
	make_sound(_StepSounds.pick_random(), -10.0)

func do_walk_step_sound() -> void:
	make_sound(_StepSounds.pick_random(), -15.0)

func change_arm_type() -> void:
	current_arm = arm_to_get
	GameSession.player_arm = current_arm
	mesh.visible = current_arm == Constants.ArmType.HUMAN
	mesh_grab_arm.visible = current_arm == Constants.ArmType.GRABBER
	mesh_heavy_arm.visible = current_arm == Constants.ArmType.HEAVY

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
	var candidate : Node3D = raycast_rippable.get_collider()
	if candidate and candidate.is_rippable():
		candidate.rip()
		arm_to_get = candidate.get_arm_type()
		switch_animation_if_not_current("riparm", 0.1)
		current_state = State.RIPPING

func switch_animation_if_not_current(anim_name : String, blend_amount : float) -> void:
	if anim_player.current_animation != anim_name:
		match anim_name:
			"walk": anim_player.speed_scale = 1.9
			"walk_aim": anim_player.speed_scale = 1.0
			"pistol_whip": anim_player.speed_scale = 0.75
			"shoot_heavy": anim_player.speed_scale = 1.25
			"attack_slash": anim_player.speed_scale = 0.85
			"run": anim_player.speed_scale = 1.8
			_: anim_player.speed_scale = 1.5
		anim_player.play(anim_name, blend_amount)

# The jankiest of janky hacks
func move_and_collide_split(amount : Vector3) -> void:
	move_and_collide(amount * Vector3(1.0, 0.5, 0.0))
	move_and_collide(amount * Vector3(0.0, 0.5, 1.0))

func hit(damage: float = 1.0):
	remove_blood(damage)
	current_state = State.HIT_WHILE_AIMING if current_state == State.WEAPON_DRAWN else State.HIT
	anim_player.play("hit", 0.25)

func fire() -> void:
	switch_animation_if_not_current("shoot_heavy", 0.1)
	current_state = State.SHOOTING
	var target : Node3D = get_gunfire_target(GUN_RANGE)
	if target != null:
		target.hit(1.0)
	sfx_gunshot.play()
	spark_gunshot.fire()
	# Waugh, loud noises
	get_tree().call_group("enemy", "force_chase_player")

func pistol_whip() -> void:
	switch_animation_if_not_current("pistol_whip", 0.1)
	current_state = State.PISTOL_WHIP
	var target : Node3D = get_gunfire_target(MELEE_RANGE)
	if target != null:
		target.hit(1.0)

func _physics_process_normal(delta : float) -> void:
	var turn_amount : float = Input.get_axis("left", "right")
	if turn_amount != 0.0:
		rotate_y(-turn_amount * TURN_SPEED * delta)
	var move_amount : float = Input.get_axis("up", "down")
	if move_amount != 0.0:
		if Input.is_action_pressed("run"):
			move_and_collide_split(-Vector3.FORWARD.rotated(Vector3.UP, rotation.y) * RUN_SPEED * delta)
			switch_animation_if_not_current("run", 0.25)
		else:
			move_and_collide_split(-Vector3.FORWARD.rotated(Vector3.UP, rotation.y) * MOVE_SPEED * delta)
			switch_animation_if_not_current("walk", 0.25)
	elif anim_player.current_animation != "idle":
		switch_animation_if_not_current("idle", 0.25)
	if Input.is_action_just_pressed("interact"):
		try_to_interact()
	elif Input.is_action_pressed("harvest"):
		try_to_harvest()
		try_to_rip()
	elif Input.is_action_just_pressed("draw_weapon"):
		anim_player.play("aim_start")
		current_state = State.DRAWING_WEAPON
		get_tree().call_group("fov_camera", "_on_player_weapon_drawn")
	elif Input.is_action_just_pressed("melee") and current_arm == Constants.ArmType.HEAVY:
		switch_animation_if_not_current("attack_slash", 0.1)
		current_state = State.ARM_ATTACK
	elif Input.is_action_just_pressed("melee") and current_arm == Constants.ArmType.GRABBER:
		switch_animation_if_not_current("attack_grab", 0.1)
		current_state = State.ARM_ATTACK

func _physics_process_weapon_drawn(delta : float) -> void:
	var turn_amount : float = Input.get_axis("left", "right")
	if turn_amount != 0.0:
		rotate_y(-turn_amount * TURN_WITH_WEAPON_SPEED * delta)
	var move_amount : float = Input.get_axis("up", "down")
	if move_amount != 0.0:
		move_and_collide_split(-Vector3.FORWARD.rotated(Vector3.UP, rotation.y) * MOVE_SPEED * delta)
		if anim_player.current_animation != "walk_aim":
			switch_animation_if_not_current("walk_aim", 0.25)
	elif anim_player.current_animation != "aim":
		switch_animation_if_not_current("aim", 0.25)
	if Input.is_action_just_pressed("draw_weapon"):
		anim_player.play("aim_end")
		current_state = State.HOLSTERING_WEAPON
		get_tree().call_group("fov_camera", "_on_player_weapon_stowed")
	elif Input.is_action_just_pressed("attack"):
		fire()
	elif Input.is_action_just_pressed("melee"):
		pistol_whip()

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
	get_tree().call_group("health_bar", "update_health_bar", bloods / MAX_BLOOD, get_dominant_blood_type())
	#print(snapped(bloods.x, 0.1), "\t", snapped(bloods.y, 0.1), "\t", snapped(bloods.z, 0.1), "\t", snapped(get_blood_amount(), 0.1), "\t", get_dominant_blood_type())

func _ready() -> void:
	GameSession.player = self
	switch_animation_if_not_current("idle", 0.0)
	
	current_arm = GameSession.player_arm
	mesh.visible = current_arm == Constants.ArmType.HUMAN
	mesh_grab_arm.visible = current_arm == Constants.ArmType.GRABBER
	mesh_heavy_arm.visible = current_arm == Constants.ArmType.HEAVY

func _on_animation_player_animation_finished(anim_name : String) -> void:
	match anim_name:
		"riparm":
			current_state = State.NORMAL
			change_arm_type()
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
		"death":
			get_tree().call_group("game_controller", "player_dead")
		"hit":
			switch_animation_if_not_current("aim" if current_state == State.HIT_WHILE_AIMING else "idle", 0.25)
			current_state = State.WEAPON_DRAWN if current_state == State.HIT_WHILE_AIMING else State.NORMAL
		"pistol_whip":
			switch_animation_if_not_current("aim", 0.0)
			current_state = State.WEAPON_DRAWN
		"attack_slash":
			switch_animation_if_not_current("idle", 0.0)
			current_state = State.NORMAL
		"attack_grab":
			switch_animation_if_not_current("idle", 0.0)
			current_state = State.NORMAL
