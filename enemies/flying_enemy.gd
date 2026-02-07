class_name FlyingEnemy
extends CharacterBody3D

# Movement settings
@export var move_speed: float = 6.0
@export var detection_range: float = 20.0
@export var attack_range: float = 3.0
@export var hover_amplitude: float = 0.3  # SMALL subtle hover (was 2.0)
@export var hover_speed: float = 1.0  # Slow gentle bobbing

# Visual settings
@export var target_highlight_color = Color(1.0, 0.0, 0.0, 0.5)

# State
enum State { IDLE, PATROL, CHASE, ATTACK }
var current_state: State = State.IDLE
var player: Node3D = null
var spawn_position: Vector3
var patrol_target: Vector3
var state_timer: float = 0.0
var hover_time: float = 0.0
var base_hover_height: float = 20.0  # The height we hover at
var mesh_instance: MeshInstance3D = null
var original_material: Material = null
var is_targeted: bool = false

func _ready() -> void:
	spawn_position = global_position
	base_hover_height = spawn_position.y  # Remember starting height
	add_to_group("enemy")
	add_to_group("flying_enemy")
	
	# Find player
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	
	# Find mesh instance
	mesh_instance = _find_mesh_instance(self)
	if mesh_instance and mesh_instance.get_surface_override_material_count() > 0:
		original_material = mesh_instance.get_surface_override_material(0)
	
	# Connect to targeting system
	var targeting_system: TargetingSystem = get_tree().get_first_node_in_group("targeting_system")
	if targeting_system:
		targeting_system.target_changed.connect(_on_target_change)
	
	_change_state(State.PATROL)

func _physics_process(delta: float) -> void:
	state_timer -= delta
	hover_time += delta
	
	if not player:
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# State machine
	match current_state:
		State.IDLE:
			_hover_in_place(delta)
			if state_timer <= 0:
				_change_state(State.PATROL)
		
		State.PATROL:
			_patrol(delta)
			if distance_to_player < detection_range:
				_change_state(State.CHASE)
		
		State.CHASE:
			_chase_player(delta)
			if distance_to_player > detection_range * 1.5:
				_change_state(State.PATROL)
			elif distance_to_player < attack_range:
				_change_state(State.ATTACK)
		
		State.ATTACK:
			_attack_player(delta)
			if distance_to_player > attack_range * 1.5:
				_change_state(State.CHASE)
	
	move_and_slide()

func _hover_in_place(delta: float):
	# Stay in place with subtle bobbing
	var hover_offset = sin(hover_time * hover_speed) * hover_amplitude
	var target_y = base_hover_height + hover_offset
	
	# Smooth vertical movement
	velocity.y = (target_y - global_position.y) * 3.0
	velocity.x = 0
	velocity.z = 0

func _patrol(delta: float):
	# Move toward patrol target but stay at hover height
	var direction_2d = Vector2(patrol_target.x - global_position.x, patrol_target.z - global_position.z)
	
	if direction_2d.length() > 1.0:
		direction_2d = direction_2d.normalized()
		velocity.x = direction_2d.x * move_speed * 0.5
		velocity.z = direction_2d.y * move_speed * 0.5
	else:
		velocity.x = 0
		velocity.z = 0
	
	# Maintain hover height with subtle bobbing
	var hover_offset = sin(hover_time * hover_speed) * hover_amplitude
	var target_y = base_hover_height + hover_offset
	velocity.y = (target_y - global_position.y) * 3.0
	
	# Check if reached patrol target or time expired
	var distance_2d = Vector2(global_position.x, global_position.z).distance_to(
		Vector2(patrol_target.x, patrol_target.z))
	
	if distance_2d < 2.0 or state_timer <= 0:
		_change_state(State.IDLE)

func _chase_player(delta: float):
	# Move toward player horizontally, stay at hover height
	var target_pos = player.global_position
	
	var direction_2d = Vector2(target_pos.x - global_position.x, target_pos.z - global_position.z)
	if direction_2d.length() > 0.1:
		direction_2d = direction_2d.normalized()
		velocity.x = direction_2d.x * move_speed
		velocity.z = direction_2d.y * move_speed
	
	# Stay at current hover height
	var hover_offset = sin(hover_time * hover_speed) * hover_amplitude
	var target_y = base_hover_height + hover_offset
	velocity.y = (target_y - global_position.y) * 3.0

func _attack_player(delta: float):
	# Move toward player to attack
	var direction = (player.global_position - global_position).normalized()
	velocity = direction * move_speed * 0.8
	
	if state_timer <= 0:
		_change_state(State.CHASE)

func _change_state(new_state: State):
	current_state = new_state
	
	match new_state:
		State.IDLE:
			state_timer = randf_range(2.0, 4.0)
		
		State.PATROL:
			_set_new_patrol_target()
			state_timer = randf_range(5.0, 8.0)
		
		State.CHASE:
			pass
		
		State.ATTACK:
			state_timer = 1.0

func _set_new_patrol_target():
	# Patrol in a small area around spawn, stay at same height
	var random_offset = Vector3(
		randf_range(-8.0, 8.0),
		0,  # Don't change height
		randf_range(-8.0, 8.0)
	)
	patrol_target = spawn_position + random_offset
	patrol_target.y = base_hover_height  # Keep at hover height

func _find_mesh_instance(node: Node):
	if node is MeshInstance3D:
		return node
	
	for child in node.get_children():
		var result = _find_mesh_instance(child)
		if result:
			return result
	
	return null

func _on_target_change(new_target: Node3D):
	is_targeted = (new_target == self)
	_update_highlight()

func _update_highlight():
	if not mesh_instance:
		return
	
	if is_targeted:
		var highlight_material = StandardMaterial3D.new()
		highlight_material.albedo_color = target_highlight_color
		highlight_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		highlight_material.emission_enabled = true
		highlight_material.emission = target_highlight_color
		highlight_material.emission_energy_multiplier = 0.5
		mesh_instance.set_surface_override_material(0, highlight_material)
	else:
		mesh_instance.set_surface_override_material(0, original_material)

func _on_visible_on_screen_notifier_3d_screen_exited() -> void:
	queue_free()
