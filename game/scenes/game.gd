extends Node3D

const ROOMS : Dictionary = {
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

enum GameState {IN_GAME, PAUSED, LOADING}

@onready var map : NavigationRegion3D = $Map
@onready var anim_player : AnimationPlayer = $AnimationPlayer
@onready var sfx_voice_clips : AudioStreamPlayer = $HUD/Dialog/SFXVoiceClips

var current_room : Node3D

var current_state : int
var room_to_load : String
var spawn_id_to_use : int

func load_room(room : String, spawn_id : int) -> void:
	room_to_load = room
	spawn_id_to_use = spawn_id
	ResourceLoader.load_threaded_request(ROOMS[room])
	current_state = GameState.LOADING

func start_room() -> void:
	var scene : PackedScene = ResourceLoader.load_threaded_get(ROOMS[room_to_load])
	current_room = scene.instantiate()
	map.add_child(current_room)
	map.bake_navigation_mesh()
	current_room.spawn_player(spawn_id_to_use)
	current_room.spawn_scientists()
	current_state = GameState.IN_GAME
	get_tree().paused = false
	anim_player.play("fade_in")
	await get_tree().create_timer(0.05).timeout # janky hack, m8
	get_tree().call_group("camera", "check_for_player")
	get_tree().call_group("game_session", "room_entered", room_to_load)

func change_room(room : String, spawn_id : int) -> void:
	get_tree().paused = true
	anim_player.play("fade_out")
	await anim_player.animation_finished
	current_room.queue_free()
	load_room(room, spawn_id)

func _physics_process(delta : float) -> void:
	match current_state:
		GameState.LOADING:
			if ResourceLoader.has_cached(ROOMS[room_to_load]):
				start_room()

func _ready() -> void:
	GameSession.madtalk = %MadTalk
	%MadTalk.activate_custom_effect.connect(GameSession._on_mad_talk_activate_custom_effect)
	
	load_room("Entrance", 0)


func _on_mad_talk_voice_clip_requested(speaker_id, clip_path):
	sfx_voice_clips.stream = load(clip_path)
	sfx_voice_clips.play()
