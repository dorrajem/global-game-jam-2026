class_name Enemy
extends CharacterBody3D

# movement settings
@export var move_speed : float = 3.0
@export var detection_range : float = 10.0
@export var attack_range : float = 2.0
@export var wander_radius : float = 5.0

# visual settings
@export var target_highlight_color = Color(1.0, 0.0, 0.0, 0.5)





# state
enum State { IDLE, WANDER, CHASE, ATTACK }
var current_state : State = State.IDLE
var player : Node3D = null
var spawn_position : Vector3
var wander_target : Vector3
var state_timer : float = 0.0
var mesh_instance : MeshInstance3D = null
var original_material : Material = null
var is_targeted : bool = false

# adding audio 
@onready var audio_stream: AudioStreamPlayer3D = $AudioStreamPlayer3D

func _ready() -> void:
	spawn_position = global_position
	add_to_group("enemy")
	
	
	# find player
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	
	# find mesh instance for highlighting
	mesh_instance = _find_mesh_instance(self)
	if mesh_instance and mesh_instance.get_surface_override_material_count() > 0:
		original_material = mesh_instance.get_surface_override_material(0)
		
	
	
	# connect to targeting system
	var targeting_system : TargetingSystem = get_tree().get_first_node_in_group("targeting_system")
	if targeting_system:
		targeting_system.target_changed.connect(_on_target_change)
	
	_change_state(State.WANDER)
	


func _physics_process(delta: float) -> void:
	state_timer -= delta
	
	if not player:
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# state machine
	match current_state:
		State.IDLE:
			if state_timer <= 0:
				_change_state(State.WANDER)
		
		State.WANDER:
			_wander(delta)
			if distance_to_player < detection_range:
				_change_state(State.CHASE)
		
		State.CHASE:
			_chase_player(delta)
			if distance_to_player > detection_range * 1.5:
				_change_state(State.WANDER)
			elif distance_to_player < attack_range:
				_change_state(State.ATTACK)
		
		State.ATTACK:
			_attack_player()
			if distance_to_player > attack_range * 1.2:
				_change_state(State.CHASE)
	
	move_and_slide()

func _find_mesh_instance(node : Node):
	if node is MeshInstance3D:
		return node
	
	for child in node.get_children():
		var result = _find_mesh_instance(child)
		if result:
			return result
	
	return null

func _on_target_change(new_target : Node3D):
	is_targeted = (new_target == self)
	_update_highlight()

func _update_highlight():
	if not mesh_instance:
		return
	
	if is_targeted:
		 # create highlight material
		var highlight_material = StandardMaterial3D.new()
		highlight_material.albedo_color = target_highlight_color
		highlight_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		highlight_material.emission_enabled = true
		highlight_material.emission = target_highlight_color
		highlight_material.emission_energy_multiplier = 0.5
		mesh_instance.set_surface_override_material(0, highlight_material)
	else:
		mesh_instance.set_surface_override_material(0, original_material)

func _change_state(new_state : State):
	current_state = new_state
	
	match new_state:
		State.IDLE:
			state_timer = randf_range(1.0, 3.0)
			velocity = Vector3.ZERO
			audio_stream.play(0.1)
			
		
		State.WANDER:
			_set_new_wander_target()
			state_timer = randf_range(3.0, 6.0)
			audio_stream.play(0.10) 
			
		
		State.CHASE:
			print(self.global_position)
			if(global_position.x >=0): 
				audio_stream.position.x = global_position.x + 5
				print('left')
			else:
				audio_stream.position.x = global_position.x - 5
				print('right')
			audio_stream.play(0.10) 
		
		State.ATTACK:
			state_timer = 1.0 # attack cooldown

func _wander(delta : float):
	var direction = (wander_target - global_position).normalized()
	velocity.x = direction.x * move_speed * 0.5
	velocity.z = direction.z * move_speed * 0.5
	
	# check if reached wander target
	if global_position.distance_to(wander_target) <= 1.0 or state_timer <= 0:
		_change_state(State.IDLE)

func _chase_player(delta : float):
	var direction = (player.global_position - global_position).normalized()
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed

func _attack_player():
	velocity = Vector3.ZERO
	# damage is calculated based on the player collision and not here
	if state_timer <= 0:
		_change_state(State.CHASE)

func _set_new_wander_target():
	var random_offset : Vector3 = Vector3(randf_range(-wander_radius, wander_radius), 0, randf_range(-wander_radius, wander_radius))
	wander_target = spawn_position + random_offset
