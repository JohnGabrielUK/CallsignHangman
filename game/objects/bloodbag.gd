extends Area3D

const HEAL_AMOUNT : float = 3.0
const SPIN_AMOUNT : float = 1.0

func _on_body_entered(body) -> void:
	if body is Player:
		body.add_blood(HEAL_AMOUNT, Constants.BloodType.HUMAN)
		queue_free()

func _physics_process(delta : float) -> void:
	rotate_y(SPIN_AMOUNT * delta)
