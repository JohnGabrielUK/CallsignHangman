extends TextureRect

@onready var icon_a = $ScientistA
@onready var icon_b = $ScientistB
@onready var icon_c = $ScientistC


func _ready():
	GameSession.minimap = self
	icon_a.hide()
	icon_b.hide()
	icon_c.hide()


func show_scientist(index: int):
	match index:
		0:
			icon_a.show()
		1:
			icon_b.show()
		2:
			icon_c.show()

func hide_scientist(index: int):
	match index:
		0:
			icon_a.hide()
		1:
			icon_b.hide()
		2:
			icon_c.hide()
