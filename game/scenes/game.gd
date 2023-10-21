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
@onready var sfx_voice_clips : AudioStreamPlayer = $HUD/Dialog/SFXVoiceClips
@onready var audio_ambience : AudioStreamPlayer = $Audio_Ambience
@onready var audio_bgm : AudioStreamPlayer = $Audio_BGM

var current_room : Node3D
var current_ambience : String = ""

var current_state : int
var room_to_load : String
var spawn_id_to_use : int

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
	# Get started
	current_state = GameState.IN_GAME
	get_tree().paused = false
	anim_player.play("fade_in" if ambience_change else "fade_in_keep_ambience")
	await get_tree().create_timer(0.05).timeout # janky hack, m8
	get_tree().call_group("camera", "check_for_player")
	GameSession.room_entered(room_to_load)

func change_room(room : String, spawn_id : int) -> void:
	get_tree().paused = true
	if current_ambience != ROOM_AMBIENCE[room]:
		anim_player.play("fade_out")
	else:
		anim_player.play("fade_out_keep_ambience")
	await anim_player.animation_finished
	current_room.queue_free()
	load_room(room, spawn_id)

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

func _on_mad_talk_voice_clip_requested(speaker_id, clip_path):
	sfx_voice_clips.stream = load(clip_path)
	sfx_voice_clips.play()
