extends Node

# Attach this to any node in your scene to test if inputs are working
# Check the Output panel when you press keys

func _ready():
	print("=== INPUT TESTER ACTIVE ===")
	print("Checking if input actions exist...")
	
	# Check if actions are defined in Input Map
	var actions_to_check = ["move_left", "move_right", "dash"]
	for action in actions_to_check:
		if InputMap.has_action(action):
			print("✓ Action '", action, "' exists")
			var events = InputMap.action_get_events(action)
			for event in events:
				print("    -> ", event.as_text())
		else:
			print("✗ Action '", action, "' NOT FOUND! Add it to Project Settings → Input Map")

func _process(_delta):
	print(Input.is_action_pressed("move_right"))
	if Input.is_key_pressed(KEY_A):
		print("Raw key: A is pressed")
	if Input.is_key_pressed(KEY_D):
		print("Raw key: D is pressed")
	if Input.is_key_pressed(KEY_LEFT):
		print("Raw key: LEFT ARROW is pressed")
	if Input.is_key_pressed(KEY_RIGHT):
		print("Raw key: RIGHT ARROW is pressed")
	if Input.is_key_pressed(KEY_SPACE):
		print("Raw key: SPACE is pressed")
	
	# Test input actions (these need to be defined in Input Map)
	if Input.is_action_pressed("move_left"):
		print("Action: 'move_left' is pressed")
	
	if Input.is_action_pressed("move_right"):
		print("Action: 'move_right' is pressed")
	
	if Input.is_action_just_pressed("dash"):
		print("Action: 'dash' was just pressed")
	
	# Test get_axis
	if InputMap.has_action("move_left") and InputMap.has_action("move_right"):
		var axis = Input.get_axis("move_left", "move_right")
		if axis != 0:
			print("get_axis result: ", axis)
