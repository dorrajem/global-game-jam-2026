extends CharacterBody3D


@export var max_speed = 18
@export var min_speed = 10


const SPEED = 5.0


func _physics_process(delta: float) -> void:


	# Make the enemy move to front -> to Z 
	var direction := (transform.basis * Vector3(0, 0, 1)).normalized()
	if direction:
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()


func _on_visible_on_screen_notifier_3d_screen_exited() -> void:
	print('exited')
	queue_free()
