extends MeshInstance3D

var textures = [
	preload("res://vfx/gunshots/Spark1_I.jpg"),
	preload("res://vfx/gunshots/Spark2_I.jpg"),
	preload("res://vfx/gunshots/Spark3_I.jpg"),
	preload("res://vfx/gunshots/Spark4_I.jpg"),
]

@onready var anims = $AnimationPlayer

func fire():
	material_override.albedo_texture = textures[ randi() % textures.size() ] 
	anims.play("Fire")

