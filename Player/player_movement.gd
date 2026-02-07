extends CharacterBody3D

@export var base_speed : float = 10.0      # Normal forward speed
@export var steer_speed : float = 6.0      # How fast it turns left/right
@export var dash_speed : float = 25.0      # Speed during dash
@export var dash_duration : float = 0.15   # How long dash lasts (seconds)
@export var dash_cooldown : float = 0.8    # Time between dashes (seconds)

# Internal state variables
var current_speed : float = 0.0
var dash_timer : float = 0.0
var cooldown_timer : float = 0.0

func ready():
	# Start with the base speed
	current_speed = base_speed
	print("Initial speed set to: ", current_speed)


func physics_process(delta):
	# Handle timers
	update_timers(delta)
	
	# Get input for steering (-1 for left, 1 for right, 0 for none)
	var steer_input = Input.get_axis("move_right", "move_left")
	# Invert if needed: For "move_left" as left key, "move_right" as right key
	# This makes pressing right = turn right, pressing left = turn left
	steer_input = -steer_input
	
	# Handle dash input (Spacebar by default)
	if Input.is_action_just_pressed("dash") and cooldown_timer <= 0:
		activate_dash()
	
	# Apply movement based on current state
	apply_movement(delta, steer_input)

func update_timers(delta):
	# Update dash effect timer
	if dash_timer > 0:
		dash_timer -= delta
		if dash_timer <= 0:
			# Dash ended, return to normal speed
			current_speed = base_speed
	
	# Update cooldown timer
	if cooldown_timer > 0:
		cooldown_timer -= delta

func activate_dash():
	dash_timer = dash_duration
	cooldown_timer = dash_cooldown
	current_speed = dash_speed
	# Optional: Add visual/audio effects here
	# e.g., $Particles.emitting = true

func apply_movement(delta, steer_input):
	# 1. Calculate forward direction (always moving in -Z direction of the sphere)
	var forward_dir = -global_transform.basis.z
	
	# 2. Apply steering rotation
	if steer_input != 0:
		rotate_y(steer_input * steer_speed * delta)
	
	# 3. Set velocity - always move forward at current speed
	velocity = forward_dir * current_speed
	
	# 4. Let Godot handle collisions and slopes
	move_and_slide()
	
	# 5. (Optional) Visual rolling effect for the mesh
	apply_visual_roll(delta)

func apply_visual_roll(delta):
	# This rotates the visual mesh to look like it's rolling
	var mesh = $MeshInstance3D  # Adjust if your mesh has a different path
	if mesh and velocity.length() > 0.1:
		var roll_speed = current_speed * delta
		# Roll around local X-axis based on forward movement
		mesh.rotate_x(roll_speed)
		# Add slight tilt when steering for a more dynamic look
		if Input.is_action_pressed("move_left"):
			mesh.rotate_z(0.02)
		elif Input.is_action_pressed("move_right"):
			mesh.rotate_z(-0.02)

# Optional: Add this for debug info in the Output panel
func _process(delta):
	print("Speed: ", current_speed, " | Dash Timer: ", dash_timer, " | Cooldown: ", cooldown_timer)
