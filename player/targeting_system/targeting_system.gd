class_name TargetingSystem
extends Node3D

# references
@export var player : Player
@export var camera : Camera3D
@export var max_target_distance : float = 30.0
@export var target_indicator : Node3D

# state
var current_target : Node3D = null
var all_enemies : Array[Node3D] = []

signal target_changed(new_target : Node3D)

func _ready() -> void:
	if not player:
		player = get_tree().get_first_node_in_group("player")
	if not camera:
		camera = get_viewport().get_camera_3d()
	if not target_indicator:
		target_indicator = $TargetIndicator
	
	# setup timer to update enemy list
	var update_timer = Timer.new()
	add_child(update_timer)
	update_timer.timeout.connect(_update_enemy_list)
	update_timer.wait_time = 0.5
	update_timer.start()

func _process(delta: float) -> void:
	if not player or not camera:
		return
	
	# get mouse position
	var mouse_pos = get_viewport().get_mouse_position()
	
	# find closest enemy to cursor
	_find_target_at_cursor(mouse_pos)
	
	# update target indicator
	if target_indicator and current_target:
		target_indicator.visible = true
		target_indicator.global_position = current_target.global_position
	elif target_indicator:
		target_indicator.visible = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("dash") and current_target:
		if player:
			player.try_dash(current_target)

func _update_enemy_list():
	all_enemies = []
	var enemies = get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy is Node3D:
			all_enemies.append(enemy)

func _find_target_at_cursor(cursor_pos : Vector2):
	var closest_enemy : Node3D = null
	var closest_distance : float = INF
	
	for enemy in all_enemies:
		if not is_instance_valid(enemy):
			continue
		
		# check if enemy is in range
		var distance = player.global_position.distance_to(enemy.global_position)
		if distance > max_target_distance:
			continue
		
		# project enemy position to screen
		var screen_pos = camera.unproject_position(enemy.global_position)
		
		# calculate distance from cursor
		var cursor_distance = cursor_pos.distance_to(screen_pos)
		
		if cursor_distance < closest_distance:
			closest_distance = cursor_distance
			closest_enemy = enemy
		
	# only update if changed
	if closest_enemy != current_target:
		current_target = closest_enemy
		target_changed.emit(current_target)
