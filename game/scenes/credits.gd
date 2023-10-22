extends Control

@onready var label_letter : Label = $Ending/Label_Letter
@onready var label_description : Label = $Ending/Label_Description
@onready var anim_player : AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	match GameSession.ending:
		"saved":
			label_letter.text = "A"
			label_description.text = "All scientists saved...\nat a cost."
		"killed_last":
			label_letter.text = "B"
			label_description.text = "This isn't a job for heroes."
		"killed_some":
			label_letter.text = "C"
			label_description.text = "No sense in asking\nwhat could have been."
	await get_tree().create_timer(1.0).timeout
	anim_player.play("credits")

func _on_animation_player_animation_finished(anim_name):
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
