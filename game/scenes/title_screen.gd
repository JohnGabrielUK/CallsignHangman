extends Control

enum State {INTRO, WAITING}

@onready var audio_bgm : AudioStreamPlayer = $Audio_BGM
@onready var anim_player : AnimationPlayer = $AnimationPlayer

var current_state : int = State.INTRO

func _process(delta : float) -> void:
	if current_state == State.INTRO and Input.is_action_just_pressed("ui_accept"):
		anim_player.seek(53.0, true)
		current_state = State.WAITING
	elif current_state == State.WAITING and Input.is_action_just_pressed("ui_accept"):
		anim_player.play("fade_out")

func _ready() -> void:
	await get_tree().create_timer(3.0).timeout
	audio_bgm.play()
	anim_player.play("intro")

func _on_animation_player_animation_finished(anim_name):
	match anim_name:
		"intro":
			current_state = State.WAITING
		"fade_out":
			get_tree().change_scene_to_file("res://scenes/game.tscn")
