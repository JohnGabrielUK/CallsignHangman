extends Area3D

const HEAL_AMOUNT : float = 3.0
const SPIN_AMOUNT : float = 1.0

@onready var sfx_pick = $SFXPick

var active := true

func _on_body_entered(body) -> void:
	if active and (body is Player):
		body.add_blood(HEAL_AMOUNT, Constants.BloodType.HUMAN)
		sfx_pick.play()
		hide()
		active = false

func _physics_process(delta : float) -> void:
	rotate_y(SPIN_AMOUNT * delta)


func _on_sfx_pick_finished():
	queue_free()
