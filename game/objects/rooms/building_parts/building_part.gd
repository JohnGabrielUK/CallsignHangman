@tool
extends MeshInstance3D

@export var WallLightsColor: Color = Color.WHITE:
	set(value):
		WallLightsColor = value
		_update_wall_lights()
@export var DoorLightColors: Array[Color] = []:
	set(value):
		DoorLightColors = value
		_update_door_lights()

var wall_material: StandardMaterial3D
var door_materials := []

func _ready():
	wall_material = get_surface_override_material(1).duplicate()
	set_surface_override_material(1, wall_material)
	
	# Populate door materials into door_materials
	door_materials.clear()
	for child in get_children():
		if (child is MeshInstance3D) and ("Door" in child.name):
			child = child as MeshInstance3D
			var mat = child.get_surface_override_material(1).duplicate()
			child.set_surface_override_material(1, mat)
			door_materials.append(mat)
	
	_update_wall_lights()
	_update_door_lights()


func _update_wall_lights():
	if wall_material:
		wall_material.emission = WallLightsColor
	

func _update_door_lights():
	if door_materials and (door_materials.size() > 0):
		for i in range(DoorLightColors.size()):
			if i >= door_materials.size():
				break
			if door_materials[i]:
				(door_materials[i] as StandardMaterial3D).emission = DoorLightColors[i]
