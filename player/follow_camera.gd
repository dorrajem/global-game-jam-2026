class_name FollowCamera
extends Camera3D

@export var target: Node3D
@export var follow_distance: float = 8.0
@export var follow_height: float = 4.0
@export var follow_smoothness: float = 5.0
@export var look_ahead_distance: float = 3.0

var base_fov : float = 62.5
var max_fov : float = 95.0
var fov_change_speed : float = 10.0
var max_speed : float = 20.0

func _ready():
	if not target:
		target = get_parent()
	fov = base_fov

func _process(delta: float):
	if not target:
		return
	
	# Calculate target position behind and above the player
	var target_position = target.global_position
	target_position.z -= follow_distance  # Behind the player
	target_position.y += follow_height      # Above the player
	
	# Smooth follow
	global_position = global_position.lerp(target_position, follow_smoothness * delta)
	
	# velocity = fov
	var current_speed = target.velocity.length()
	var target_fov = base_fov + (max_fov - base_fov) * (min(current_speed, 100.0) / 100.0)
	fov = lerpf(fov, target_fov, fov_change_speed * delta)
	
	# Look at point slightly ahead of player
	var look_target = target.global_position
	look_target.z += look_ahead_distance
	look_at(look_target)
