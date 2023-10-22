extends Node3D

const _Rooms : Dictionary = {
	"Cafeteria": "res://objects/rooms/cafeteria.tscn",
	"Corridor1": "res://objects/rooms/corridor1.tscn",
	"Corridor2": "res://objects/rooms/corridor2.tscn",
	"Corridor3": "res://objects/rooms/corridor3.tscn",
	"CorridorCorner1": "res://objects/rooms/corridor_corner1.tscn",
	"CorridorCorner2": "res://objects/rooms/corridor_corner2.tscn",
	"CorridorThreeway1": "res://objects/rooms/corridor_threeway1.tscn",
	"CorridorThreeway2": "res://objects/rooms/corridor_threeway2.tscn",
	"CorridorThreeway3": "res://objects/rooms/corridor_threeway3.tscn",
	"CorridorThreeway4": "res://objects/rooms/corridor_threeway4.tscn",
	"Entrance": "res://objects/rooms/entrance.tscn",
	"EscapePods": "res://objects/rooms/escape_pods.tscn",
	"Lab1": "res://objects/rooms/lab1.tscn",
	"Lab2": "res://objects/rooms/lab2.tscn",
	"Lab3": "res://objects/rooms/lab3.tscn",
	"Room1": "res://objects/rooms/room1.tscn",
	"Room2": "res://objects/rooms/room2.tscn",
	"Room3": "res://objects/rooms/room3.tscn",
	"Room4": "res://objects/rooms/room4.tscn",
	"RoomTwodoors": "res://objects/rooms/room_twodoors.tscn"
}

const _Ambiences : Dictionary = {
	"lab": preload("res://audio/amb/lab.ogg"),
	"microwave": preload("res://audio/amb/microwave.ogg"),
	"ship1": preload("res://audio/amb/ship1.ogg"),
	"ship2": preload("res://audio/amb/ship2.ogg")
}

const _Music : Dictionary = {
	"attack": preload("res://audio/music/attack.ogg"),
	"attack_over": preload("res://audio/music/stinger.ogg"),
	"downtime": preload("res://audio/music/downtime.ogg"),
	"saferoom": preload("res://audio/music/saferoom.ogg")
}

const ROOM_AMBIENCE : Dictionary = {
	"Cafeteria": "ship2",
	"Corridor1": "microwave",
	"Corridor2": "ship1",
	"Corridor3": "ship2",
	"CorridorCorner1": "ship1",
	"CorridorCorner2": "ship2",
	"CorridorThreeway1": "ship1",
	"CorridorThreeway2": "ship2",
	"CorridorThreeway3": "ship2",
	"CorridorThreeway4": "ship2",
	"Entrance": "ship1",
	"EscapePods": "ship1",
	"Lab1": "lab",
	"Lab2": "lab",
	"Lab3": "lab",
	"Room1": "ship1",
	"Room2": "ship2",
	"Room3": "ship2",
	"Room4": "ship2",
	"RoomTwodoors": "ship2"
}

enum GameState {IN_GAME, PAUSED, LOADING}

@onready var map : NavigationRegion3D = $Map
@onready var anim_player : AnimationPlayer = $AnimationPlayer
@onready var anim_player_music : AnimationPlayer = $AnimationPlayer_Music
@onready var sfx_voice_clips : AudioStreamPlayer = $HUD/Dialog/SFXVoiceClips
@onready var audio_ambience : AudioStreamPlayer = $Audio_Ambience
@onready var audio_bgm : AudioStreamPlayer = $Audio_BGM

@onready var label_prompt_interact : RichTextLabel = $HUD/Label_Prompt_Interact
@onready var label_prompt_harvest : RichTextLabel = $HUD/Label_Prompt_Harvest

var current_room : Node3D
var current_ambience : String = ""
var current_music : String = ""

var current_state : int
var room_to_load : String
var spawn_id_to_use : int

func change_music_immediately(new_music : String) -> void:
	if current_music != new_music:
		audio_bgm.stop()
		audio_bgm.stream = _Music[new_music]
		audio_bgm.play()
		current_music = new_music

func on_enemy_aggression() -> void:
	change_music_immediately("attack")

func on_enemy_dead() -> void:
	var all_dead : bool = true
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.is_alive(): all_dead = false
	if all_dead: change_music_immediately("attack_over")

func get_music_for_room(room : String) -> String:
	if room.begins_with("Lab"):
		return "saferoom"
	else:
		return "downtime"

func load_room(room : String, spawn_id : int) -> void:
	room_to_load = room
	spawn_id_to_use = spawn_id
	ResourceLoader.load_threaded_request(_Rooms[room])
	current_state = GameState.LOADING

func start_room() -> void:
	# Set up the room
	var scene : PackedScene = ResourceLoader.load_threaded_get(_Rooms[room_to_load])
	current_room = scene.instantiate()
	map.add_child(current_room)
	map.bake_navigation_mesh()
	current_room.spawn_player(spawn_id_to_use)
	current_room.spawn_scientists()
	# Change ambience, if needed
	var room_ambience = ROOM_AMBIENCE[room_to_load]
	var ambience_change : bool = false
	if current_ambience != room_ambience:
		audio_ambience.stop()
		audio_ambience.stream = _Ambiences[room_ambience]
		audio_ambience.play()
		current_ambience = room_ambience
		ambience_change = true
	# Change music, if needed
	var music_for_room : String = get_music_for_room(room_to_load)
	if music_for_room != current_music:
		audio_bgm.stop()
		audio_bgm.stream = _Music[music_for_room]
		audio_bgm.play()
		anim_player_music.play("fade_in_music")
		current_music = music_for_room
	# Get started
	current_state = GameState.IN_GAME
	get_tree().paused = false
	anim_player.play("fade_in" if ambience_change else "fade_in_keep_ambience")
	await get_tree().create_timer(0.05).timeout # janky hack, m8
	get_tree().call_group("camera", "check_for_player")
	GameSession.room_entered(room_to_load)

func change_room(room : String, spawn_id : int) -> void:
	set_prompts_visible(false, false)
	get_tree().paused = true
	if get_music_for_room(room) != current_music:
		anim_player_music.play("fade_out_music")
	if current_ambience != ROOM_AMBIENCE[room]:
		anim_player.play("fade_out")
	else:
		anim_player.play("fade_out_keep_ambience")
	await anim_player.animation_finished
	current_room.queue_free()
	load_room(room, spawn_id)

func set_prompts_visible(can_interact : bool, can_harvest : bool) -> void:
	label_prompt_interact.visible = can_interact
	label_prompt_harvest.visible = can_harvest

func _physics_process(delta : float) -> void:
	get_tree().call_group("camera", "check_for_player") # Janky hack, m8
	match current_state:
		GameState.LOADING:
			if ResourceLoader.has_cached(_Rooms[room_to_load]):
				start_room()

func _ready() -> void:
	GameSession.madtalk = %MadTalk
	%MadTalk.activate_custom_effect.connect(GameSession._on_mad_talk_activate_custom_effect)
	
	load_room("Entrance", 0)

func _on_mad_talk_voice_clip_requested(speaker_id, clip_path) -> void:
	sfx_voice_clips.volume_db = -5.0 if speaker_id == "katrina" else 0.0
	if ResourceLoader.exists(clip_path):
		sfx_voice_clips.stream = load(clip_path)
		sfx_voice_clips.play()

func _on_sfx_voice_clips_finished() -> void:
	%MadTalk.dialog_acknowledge()

# For stopping voice clips if the player skips the line manually
func _on_mad_talk_dialog_acknowledged() -> void:
	sfx_voice_clips.stop()

func _on_mad_talk_dialog_started(sheet_name, sequence_id):
	set_prompts_visible(false, false)
