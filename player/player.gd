class_name Player
extends CharacterBody3D


# Movement settings
@export var forward_speed: float = 25.0
@export var max_lateral_speed: float = 15.0
@export var acceleration: float = 25.0
@export var friction: float = 8.0
@export var gravity: float = 30.0
@export var slope_speed_multiplier : float = 1.5
@export var air_control : float = 0.3

# Dash settings
@export var dash_speed: float = 100.0
@export var dash_duration: float = 0.3
@export var dash_cooldown: float = 0.5

# Vision/Mask settings
@export var max_vision: float = 100.0
@export var vision_loss_per_hit: float = 20.0
@export var vision_regen_rate: float = 1.5

@onready var hit_box: Area3D = $HitBox

# State variables
var current_vision: float = 100.0
var lateral_velocity: float = 0.0
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO
var is_invulnerable: bool = false
var invulnerable_timer: float = 0.0
var slope_velocity_bonus : float = 0.0
var is_dead : bool = false

# References
var current_target: Node3D = null

signal vision_changed(new_vision: float, max_vision: float)
signal player_died
signal enemy_killed(enemy: Node3D)

func _ready():
	is_dead = false
	# Initialize
	current_vision = max_vision
	vision_changed.emit(current_vision, max_vision)
	add_to_group("player")

func _physics_process(delta: float):
	if is_dead:
		return
	# Update timers
	if dash_timer > 0:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false
	
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
	
	if invulnerable_timer > 0:
		invulnerable_timer -= delta
		if invulnerable_timer <= 0:
			is_invulnerable = false
	
	# Regenerate vision slowly
	if not is_dashing and not is_invulnerable:
		take_damage(vision_regen_rate * delta)
		#vision_changed.emit(current_vision, max_vision)
	
	# Handle movement
	if is_dashing:
		_handle_dash_movement(delta)
	else:
		_handle_normal_movement(delta)
	
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
		if global_position.y <= -.0:
			player_died.emit()
	else:
		var floor_normal = get_floor_normal()
		var slope_angle = floor_normal.angle_to(Vector3.UP)
		
		if slope_angle > 0.1:
			var slope_factor = floor_normal.dot(Vector3(0, 0, 1))
			slope_velocity_bonus = slope_factor * slope_speed_multiplier
		else:
			slope_velocity_bonus = 0.0
		velocity.y = -0.5  # Small downward force to keep grounded
	
	move_and_slide()
	_check_collisions()

func _handle_normal_movement(delta: float):
	# Constant forward movement
	var current_forward_speed = forward_speed + slope_velocity_bonus
	velocity.z = current_forward_speed
	
	# Get input for lateral movement
	var input_dir: float = 0.0
	if Input.is_action_pressed("move_right"):
		input_dir -= 1.0
	if Input.is_action_pressed("move_left"):
		input_dir += 1.0
	
	var control_factor = air_control if not is_on_floor() else 1.0
	
	# Apply momentum-based lateral movement
	if input_dir != 0.0:
		lateral_velocity += input_dir * acceleration * delta * control_factor
		lateral_velocity = clamp(lateral_velocity, -max_lateral_speed, max_lateral_speed)
	else:
		# Apply friction when no input
		if abs(lateral_velocity) > 0.1:
			var friction_amount = friction * delta
			if not is_on_floor():
				friction_amount *= 0.3
			if lateral_velocity > 0:
				lateral_velocity = max(0, lateral_velocity - friction_amount)
			else:
				lateral_velocity = min(0, lateral_velocity + friction_amount)
		else:
			lateral_velocity = 0.0
	
	velocity.x = lateral_velocity

func _handle_dash_movement(delta: float):
	# During dash, move in the dash direction
	velocity = dash_direction * dash_speed + Vector3(0, 2, 0)
	if velocity.y < 5.0:
		velocity.y = 5.0

func try_dash(target: Node3D):
	if dash_cooldown_timer > 0 or is_dashing:
		return false
	
	if target and is_instance_valid(target):
		# Calculate dash direction toward target
		dash_direction = (target.global_position - global_position).normalized()
		
		# Start dash
		is_dashing = true
		dash_timer = dash_duration
		dash_cooldown_timer = dash_cooldown
		current_target = target
		
		# Spawn dash VFX
		VFXManager.spawn_dash_effect(global_position)
		
		return true
	
	return false

func _check_collisions():
	# check for overlapping bodies
	for i : int in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if collider:
			_handle_collision_with(collider)

func _handle_collision_with(body : Node):
	if body.is_in_group("enemy"):
		if is_dashing and body == current_target:
			VFXManager.spawn_hit_effect(body.global_position)
			VFXManager.screen_shake(0.5, 0.2)
			enemy_killed.emit(body)
			if body.has_method("queue_free"):
				body.queue_free()
			current_target = null
		elif not is_invulnerable and not is_dashing:
			take_damage(vision_loss_per_hit)

func take_damage(damage: float = 0.0):
	if is_invulnerable or is_dashing:
		return
	
	# Lose vision instead of HP
	current_vision -= damage
	vision_changed.emit(current_vision, max_vision)
	
	print("Player took damage! Vision: ", current_vision, "/", max_vision)
	
	# Visual feedback
	if (damage == vision_loss_per_hit):
		VFXManager.spawn_hit_effect(global_position)
		VFXManager.screen_shake(0.3, 0.1)
	
	# Check for death
	if current_vision <= 0:
		die()

func heal_vision(amount: float):
	current_vision = min(current_vision + amount, max_vision)
	vision_changed.emit(current_vision, max_vision)
	print("Vision healed! Current: ", current_vision, "/", max_vision)

func apply_speed_boost(multiplier: float, duration: float):
	var original_speed = forward_speed
	forward_speed *= multiplier
	print("Speed boost active! ", forward_speed, " for ", duration, "s")
	await get_tree().create_timer(duration).timeout
	forward_speed = original_speed
	print("Speed boost ended")

func apply_invulnerability(duration: float):
	is_invulnerable = true
	invulnerable_timer = duration
	print("Invulnerability active for ", duration, "s")

func die():
	if is_dead:
		return
	
	is_dead = true
	print("Player died!")
	player_died.emit()
	# Don't disable physics - let GameManager handle restart
	velocity = Vector3.ZERO

func _on_hit_box_body_entered(body: Node3D) -> void:
	_handle_collision_with(body)
