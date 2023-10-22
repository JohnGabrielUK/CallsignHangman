extends Control

@onready var sfx_voice_clips : AudioStreamPlayer = $HUD/Dialog/SFXVoiceClips
@onready var audio_ambience : AudioStreamPlayer = $Audio_Ambience
@onready var anim_player : AnimationPlayer = $AnimationPlayer

func _process(delta : float) -> void:
	if Input.is_action_just_pressed("interact"):
		sfx_voice_clips.stop()
		%MadTalk.dialog_acknowledge()

func _ready() -> void:
	audio_ambience.play()
	anim_player.play("fade_in")
	await get_tree().create_timer(3.0).timeout
	%MadTalk.start_dialog("briefing")

func _on_mad_talk_voice_clip_requested(speaker_id, clip_path):
	sfx_voice_clips.volume_db = -5.0 if speaker_id == "katrina" else 0.0
	if ResourceLoader.exists(clip_path):
		sfx_voice_clips.stream = load(clip_path)
		sfx_voice_clips.play()

func _on_sfx_voice_clips_finished() -> void:
		%MadTalk.dialog_acknowledge()

func _on_animation_player_animation_finished(anim_name : String) -> void:
	match anim_name:
		"fade_out":
			get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_mad_talk_dialog_finished(sheet_name, sequence_id):
	anim_player.play("fade_out")
