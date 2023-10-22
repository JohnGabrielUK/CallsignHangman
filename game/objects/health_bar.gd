extends Control

const BAR_LENGTH : float = 398.0

@onready var bar_human : ColorRect = $BloodBar_Back/BloodBar_Human
@onready var bar_remo_a : ColorRect = $BloodBar_Back/BloodBar_RemoA
@onready var bar_remo_b : ColorRect = $BloodBar_Back/BloodBar_RemoB
@onready var label_blood_type_value : Label = $Label_BloodType_Value

func update_health_bar(bloods : Vector3, dominant_type : int) -> void:
	bloods *= BAR_LENGTH
	var cursor : float = 0.0
	bar_human.size.x = bloods.x
	bar_remo_a.size.x = bloods.y
	bar_remo_b.size.x = bloods.z
	bar_remo_a.position.x = bloods.x
	bar_remo_b.position.x = bloods.x + bloods.y
	match dominant_type:
		Constants.BloodType.HUMAN: label_blood_type_value.text = "H U M A N (no effect)"
		Constants.BloodType.HEAT_RESISTANT: label_blood_type_value.text = "R E M O  A (radiation resistance)"
		Constants.BloodType.SOMETHING_ELSE: label_blood_type_value.text = "R E M O  B (no effect)"
	if bloods.x + bloods.y + bloods.z < 0.01:
		label_blood_type_value.text = "N/A"
