extends Control

@onready var anim_player : AnimationPlayer = $AnimationPlayer
@onready var audio_bgm : AudioStreamPlayer = $Audio_BGM

enum State {ANIMATING, WAITING, FADING_OUT}

var current_state : int = State.ANIMATING

func _process(delta : float) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		match current_state:
			State.ANIMATING:
				anim_player.seek(11.5)
				current_state = State.WAITING
			State.WAITING:
				anim_player.play("fade_out")
				current_state = State.FADING_OUT

func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	audio_bgm.play()
	anim_player.play("game_over")

func _on_animation_player_animation_finished(anim_name : String) -> void:
	match anim_name:
		"game_over":
			current_state = State.WAITING
		"fade_out":
			get_tree().change_scene_to_file("res://scenes/game.tscn")
