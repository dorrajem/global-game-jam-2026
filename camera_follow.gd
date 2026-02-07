extends Camera3D

# Reference to the player node
@export var player_path : NodePath
@onready var player = get_node(player_path) if player_path else null

# Camera offset from player
@export var offset : Vector3 = Vector3(0, 5, 8)  # Behind and above the player

# Camera smoothing
@export var follow_smoothness : float = 10.0  # Higher = snappier follow
@export var rotation_smoothness : float = 5.0  # How smoothly camera rotates

# Look ahead settings
@export var look_ahead_distance : float = 3.0  # How far ahead to look

func _ready():
	# Auto-find player if not set
	if not player:
		player = get_tree().get_first_node_in_group("player")
	
	if not player:
		push_error("Camera: No player found! Add player to 'player' group or set player_path")

func _physics_process(delta):
	if not player:
		return
	
	# Calculate target position (player position + offset)
	var target_pos = player.global_position + offset
	
	# Smoothly move camera to target position
	global_position = global_position.lerp(target_pos, follow_smoothness * delta)
	
	# Calculate look-at point (slightly ahead of player for better view)
	var player_forward = -player.global_transform.basis.z
	var look_point = player.global_position + player_forward * look_ahead_distance
	
	# Smoothly rotate camera to look at the point
	var current_look = -global_transform.basis.z
	var target_look = (look_point - global_position).normalized()
	var new_look = current_look.lerp(target_look, rotation_smoothness * delta).normalized()
	
	# Apply the new look direction
	look_at(global_position + new_look * 10, Vector3.UP)
