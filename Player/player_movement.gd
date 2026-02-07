class_name Player
extends CharacterBody3D


# Movement settings
@export var forward_speed: float = 10.0
@export var max_lateral_speed: float = 8.0
@export var acceleration: float = 15.0
@export var friction: float = 10.0
@export var gravity: float = 20.0

# Dash settings
@export var dash_speed: float = 25.0
@export var dash_duration: float = 0.3
@export var dash_cooldown: float = 0.5

# Vision/Mask settings
@export var max_vision: float = 100.0
@export var vision_loss_per_hit: float = 20.0
@export var vision_regen_rate: float = 5.0

# State variables
var current_vision: float = 100.0
var lateral_velocity: float = 0.0
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO
var is_invulnerable: bool = false
var invulnerable_timer: float = 0.0

# Powerup state
var has_speed_boost: bool = false
var speed_boost_timer: float = 0.0

# References
var current_target: Node3D = null

signal vision_changed(new_vision: float, max_vision: float)
signal player_died
signal enemy_killed(enemy: Node3D)
signal powerup_collected(powerup_type: String)

func _ready():
	# Initialize
	current_vision = max_vision
	vision_changed.emit(current_vision, max_vision)
	
	# Make sure player is in the player group
	add_to_group("player")

func _physics_process(delta: float):
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
			_end_invulnerability_visual()
	
	if speed_boost_timer > 0:
		speed_boost_timer -= delta
		if speed_boost_timer <= 0:
			has_speed_boost = false
	
	# Regenerate vision slowly
	if current_vision < max_vision and not is_dashing:
		current_vision = min(current_vision + vision_regen_rate * delta, max_vision)
		vision_changed.emit(current_vision, max_vision)
	
	# Handle movement
	if is_dashing:
		_handle_dash_movement(delta)
	else:
		_handle_normal_movement(delta)
	
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.1  # Small downward force to keep grounded
	
	move_and_slide()

func _handle_normal_movement(delta: float):
	# Constant forward movement
	velocity.z = forward_speed
	
	# Get input for lateral movement
	var input_dir: float = 0.0
	if Input.is_action_pressed("move_right"):
		input_dir -= 1.0
	if Input.is_action_pressed("move_left"):
		input_dir += 1.0
	
	# Apply momentum-based lateral movement
	if input_dir != 0.0:
		lateral_velocity += input_dir * acceleration * delta
		lateral_velocity = clamp(lateral_velocity, -max_lateral_speed, max_lateral_speed)
	else:
		# Apply friction when no input
		if abs(lateral_velocity) > 0.1:
			var friction_amount = friction * delta
			if lateral_velocity > 0:
				lateral_velocity = max(0, lateral_velocity - friction_amount)
			else:
				lateral_velocity = min(0, lateral_velocity + friction_amount)
		else:
			lateral_velocity = 0.0
	
	velocity.x = lateral_velocity

func _handle_dash_movement(delta: float):
	# During dash, move in the dash direction
	velocity = dash_direction * dash_speed

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
		#VFXManager.spawn_dash_effect(global_position)
		
		return true
	
	return false

func take_damage(damage: float = 0.0):
	if is_invulnerable or is_dashing:
		return
	
	# Lose vision instead of HP
	current_vision -= vision_loss_per_hit
	vision_changed.emit(current_vision, max_vision)
	
	# Visual feedback
	#VFXManager.spawn_hit_effect(global_position)
	#VFXManager.screen_shake(0.3, 0.15)
	
	# Check for death
	if current_vision <= 0:
		die()

# ============================================
# POWERUP METHODS
# ============================================

func heal_vision(amount: float):
	current_vision = min(current_vision + amount, max_vision)
	vision_changed.emit(current_vision, max_vision)
	
	print("🟢 HEAL: Vision restored +", amount, " (", current_vision, "/", max_vision, ")")
	powerup_collected.emit("heal")
	
	# Optional: Visual feedback
	_show_heal_visual()
	#VFXManager.spawn_heal_effect(global_position)

func apply_speed_boost(multiplier: float, duration: float):
	# Store original speeds
	var original_forward = forward_speed
	var original_dash = dash_speed
	var original_lateral = max_lateral_speed
	
	# Apply boost
	forward_speed *= multiplier
	dash_speed *= multiplier
	max_lateral_speed *= multiplier
	
	# Set state
	has_speed_boost = true
	speed_boost_timer = duration
	
	print("🟡 SPEED BOOST: ", multiplier, "x speed for ", duration, " seconds!")
	powerup_collected.emit("speed_boost")
	
	# Visual feedback
	_show_speed_boost_visual()
	#VFXManager.spawn_speed_trail(self)
	
	# Wait for duration
	await get_tree().create_timer(duration).timeout
	
	# Restore original speeds (only if no other boost is active)
	if speed_boost_timer <= 0:
		forward_speed = original_forward
		dash_speed = original_dash
		max_lateral_speed = original_lateral
		has_speed_boost = false
		
		print("Speed boost ended")
		_end_speed_boost_visual()

func apply_invulnerability(duration: float):
	is_invulnerable = true
	invulnerable_timer = duration
	
	print("🔵 INVULNERABILITY: Protected for ", duration, " seconds!")
	powerup_collected.emit("invulnerability")
	
	# Visual feedback
	_show_invulnerability_visual()
	#VFXManager.spawn_shield_effect(self)

# ============================================
# VISUAL FEEDBACK (Optional - implement based on your needs)
# ============================================

func _show_heal_visual():
	# Flash green
	if has_node("Collision/Body"):
		var body = $Collision/Body
		var original_color = body.get_surface_override_material(0).albedo_color if body.get_surface_override_material(0) else Color.WHITE
		
		# Create a quick green flash
		var tween = create_tween()
		var flash_mat = StandardMaterial3D.new()
		flash_mat.albedo_color = Color.GREEN
		flash_mat.emission_enabled = true
		flash_mat.emission = Color.GREEN
		flash_mat.emission_energy = 2.0
		
		body.set_surface_override_material(0, flash_mat)
		
		# Fade back
		tween.tween_property(flash_mat, "emission_energy", 0.0, 0.5)
		await tween.finished
		body.set_surface_override_material(0, null)

func _show_speed_boost_visual():
	# Add yellow glow/trail
	if has_node("Collision/Body"):
		var body = $Collision/Body
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color.YELLOW
		mat.emission_enabled = true
		mat.emission = Color.YELLOW
		mat.emission_energy = 1.0
		body.set_surface_override_material(0, mat)

func _end_speed_boost_visual():
	# Remove glow
	if has_node("Collision/Body"):
		var body = $Collision/Body
		body.set_surface_override_material(0, null)

func _show_invulnerability_visual():
	# Add blue shield effect
	if has_node("Collision/Body"):
		var body = $Collision/Body
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color.CYAN
		mat.emission_enabled = true
		mat.emission = Color.CYAN
		mat.emission_energy = 1.5
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = 0.7
		body.set_surface_override_material(0, mat)

func _end_invulnerability_visual():
	# Remove shield
	if has_node("Collision/Body"):
		var body = $Collision/Body
		body.set_surface_override_material(0, null)

# ============================================
# OTHER METHODS
# ============================================

func die():
	player_died.emit()
	# You can add death animation/effects here
	set_physics_process(false)

func _on_body_entered(body: Node3D):
	if body.is_in_group("enemy"):
		if is_dashing and body == current_target:
			# Kill enemy on dash hit
			#VFXManager.spawn_hit_effect(body.global_position)
			#VFXManager.screen_shake(0.2, 0.1)
			enemy_killed.emit(body)
			body.queue_free()
		elif not is_invulnerable:
			# Take damage from enemy touch
			take_damage()
