extends Area3D

@export var ForwardSpeed := 7.0
@export var Gravity := -9.8

var velocity := Vector3.ZERO

func _ready():
	set_physics_process(false)

func setup():
	velocity = -global_transform.basis.z*ForwardSpeed
	set_physics_process(true)


func _physics_process(delta):
	velocity.y += Gravity*delta
	var next_global_position = global_position + velocity*delta
	look_at(next_global_position, Vector3.UP)
	global_position = next_global_position
	if global_position.y < -10:
		queue_free()



func _on_body_entered(body):
	if (body is Player) or (body is Scientist):
		body.hit(1.0)
	queue_free()
