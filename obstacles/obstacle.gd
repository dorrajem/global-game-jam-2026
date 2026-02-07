extends StaticBody3D
class_name Obstacle

# Optional: Add rotation or movement for visual interest
@export var rotate_speed: float = 0.0
@export var bob_height: float = 0.0
@export var bob_speed: float = 1.0

var initial_y: float
var time: float = 0.0

func _ready():
	add_to_group("obstacle")
	initial_y = global_position.y
	
	# Randomize starting time for variety
	time = randf() * TAU

func _process(delta: float):
	time += delta
	
	# Optional rotation
	if rotate_speed != 0.0:
		rotate_y(rotate_speed * delta)
	
	# Optional bobbing motion
	if bob_height != 0.0:
		var new_pos = global_position
		new_pos.y = initial_y + sin(time * bob_speed) * bob_height
		global_position = new_pos
