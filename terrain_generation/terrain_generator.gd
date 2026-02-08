@tool
class_name TerrainGenerator
extends Node3D

# Terrain settings
@export_group('Terrain Settings')
@export var chunk_length: float = 50.0
@export var chunk_width: float = 20.0
@export var chunks_ahead: int = 3
@export var chunks_behind: int = 1

# Height variation
@export_group('Height Settings')
@export var min_height: float = 0.0
@export var max_height: float = 6.0
@export var height_smoothness: float = 0.3

# fence/wall settings
@export_group("Fence/Wall Setting")
@export var enable_walls : bool = true
@export var wall_height : float = 3.0
@export var wall_thickness : float = 0.5
@export var use_fence_instances : bool = false
@export var fence_scenes : Array[PackedScene] = []
@export var fence_spacing : float = 4.0
@export var wall_material : Material

# Spawning settings
@export_group("Spawning Settings")
@export var spawn_enemies: bool = true
@export var enemies_per_chunk_min: int = 2
@export var enemies_per_chunk_max: int = 4
@export var spawn_flying_enemies: bool = true
@export var flying_enemies_per_chunk_min: int = 1
@export var flying_enemies_per_chunk_max: int = 2
@export var spawn_obstacles: bool = true
@export var obstacles_per_chunk: int = 3
@export var spawn_powerups: bool = true
@export var powerups_per_chunk_min: int = 1
@export var powerups_per_chunk_max: int = 2

# Prefabs
@export_group("Prefabs")
@export var obstacle_scenes: Array[PackedScene] = []
@export var enemy_scenes: Array[PackedScene] = []
@export var flying_enemy_scenes: Array[PackedScene] = []
@export var powerup_scenes: Array[PackedScene] = []

# Material
@export_group("Materials")
@export var terrain_material: Material

# Internal state
var active_chunks: Array[TerrainChunk] = []
var chunk_pool: Array[TerrainChunk] = []
var current_chunk_index: int = 0
var player: CharacterBody3D = null
var noise: FastNoiseLite
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	# Initialize noise
	rng.randomize()
	noise = FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.1
	noise.fractal_octaves = 3
	
	# Find player
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	
	# Generate initial chunks
	for i: int in range(chunks_ahead + chunks_behind + 1):
		_create_chunk(i - chunks_behind)

func _process(delta: float) -> void:
	if not player:
		return
	
	var player_chunk_index = int(player.global_position.z / chunk_length)
	
	if current_chunk_index < player_chunk_index + chunks_ahead:
		_advance_chunks()
	
	# Remove old chunks
	while active_chunks.size() > 0:
		var oldest = active_chunks[0]
		if oldest.chunk_index < player_chunk_index - chunks_behind:
			_recycle_chunk(oldest)
			active_chunks.remove_at(0)
		else:
			break

func _advance_chunks():
	current_chunk_index += 1
	_create_chunk(current_chunk_index + chunks_ahead)

func _create_chunk(chunk_index: int):
	var chunk: TerrainChunk
	
	if chunk_pool.size() > 0:
		chunk = chunk_pool.pop_back()
		_reset_chunk(chunk)
	else:
		chunk = TerrainChunk.new()
		_initialize_chunk(chunk)
	
	chunk.chunk_index = chunk_index
	chunk.z_position = chunk_index * chunk_length
	
	_generate_chunk_mesh(chunk)
	
	# create walls/fences along edges
	if enable_walls:
		_create_walls(chunk)
	
	# Spawn objects
	if spawn_obstacles:
		_spawn_obstacles(chunk)
	if spawn_enemies:
		_spawn_enemies(chunk)
	if spawn_flying_enemies:
		_spawn_flying_enemies(chunk)
	if spawn_powerups:
		_spawn_powerups(chunk)
	
	active_chunks.append(chunk)

func _initialize_chunk(chunk: TerrainChunk):
	chunk.static_body = StaticBody3D.new()
	add_child(chunk.static_body)
	
	chunk.mesh_instance = MeshInstance3D.new()
	chunk.static_body.add_child(chunk.mesh_instance)
	
	if not terrain_material:
		var default_mat: StandardMaterial3D = StandardMaterial3D.new()
		default_mat.albedo_color = Color(0.269, 0.163, 0.19, 1.0)
		default_mat.roughness = 1.0
		chunk.mesh_instance.material_override = default_mat
	else:
		chunk.mesh_instance.material_override = terrain_material
	
	chunk.mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	chunk.mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	
	chunk.collision_shape = CollisionShape3D.new()
	chunk.static_body.add_child(chunk.collision_shape)
	chunk.static_body.collision_layer = 2

func _reset_chunk(chunk: TerrainChunk):
	for obj: Node3D in chunk.objects:
		if is_instance_valid(obj):
			obj.queue_free()
	chunk.objects.clear()

func _generate_chunk_mesh(chunk: TerrainChunk):
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	
	var segments_x: int = 10
	var segments_z: int = 20
	var segment_width: float = chunk_width / float(segments_x)
	var segment_length: float = chunk_length / float(segments_z)
	
	# Generate vertices
	for z: int in range(segments_z + 1):
		for x: int in range(segments_x + 1):
			var pos_x: float = (float(x) * segment_width) - (chunk_width / 2.0)
			var pos_z: float = float(z) * segment_length
			
			var world_x: float = pos_x
			var world_z: float = chunk.z_position + pos_z
			
			var height = noise.get_noise_2d(world_x * height_smoothness, world_z * height_smoothness)
			height = remap(height, -1.0, 1.0, min_height, max_height)
			
			vertices.append(Vector3(pos_x, height, pos_z))
			normals.append(Vector3.UP)
			uvs.append(Vector2(float(x) / float(segments_x), float(z) / float(segments_z)))
	
	# Generate indices
	for z: int in range(segments_z):
		for x: int in range(segments_x):
			var top_left: int = z * (segments_x + 1) + x
			var top_right: int = top_left + 1
			var bottom_left: int = (z + 1) * (segments_x + 1) + x
			var bottom_right: int = bottom_left + 1
			
			indices.append(top_left)
			indices.append(top_right)
			indices.append(bottom_left)
			
			indices.append(top_right)
			indices.append(bottom_right)
			indices.append(bottom_left)
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	
	var array_mesh: ArrayMesh = ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	chunk.mesh_instance.mesh = array_mesh
	
	# Create collision
	var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	var faces: PackedVector3Array = PackedVector3Array()
	
	for i: int in range(0, indices.size(), 3):
		faces.append(vertices[indices[i]])
		faces.append(vertices[indices[i + 1]])
		faces.append(vertices[indices[i + 2]])
	
	shape.set_faces(faces)
	chunk.collision_shape.shape = shape
	
	chunk.static_body.global_position = Vector3(0, 0, chunk.z_position)

func _get_height_at_position(x_pos: float, z_pos: float) -> float:
	var height = noise.get_noise_2d(x_pos * height_smoothness, z_pos * height_smoothness)
	return remap(height, -1.0, 1.0, min_height, max_height)

func _create_walls(chunk : TerrainChunk):
	if use_fence_instances and fence_scenes:
		_create_fence_instances(chunk)
	else:
		_create_solid_walls(chunk)

func _create_fence_instances(chunk: TerrainChunk):
	# Create fence posts along left and right edges
	var num_posts = int(chunk_length / fence_spacing)
	
	for i in range(num_posts):
		var z_offset = float(i) * fence_spacing
		var z_pos = chunk.z_position + z_offset
		
		# Left fence
		var left_x = -chunk_width / 2.0
		var left_height = _get_height_at_position(left_x, z_pos)
		var left_normal = _get_terrain_normal_at_position(left_x, z_pos)
		var left_fence
		left_fence = fence_scenes[randi_range(3, 4)].instantiate()
		add_child(left_fence)
		left_fence.global_position = Vector3(left_x, left_height, z_pos)
		# Align fence to terrain normal
		left_fence.global_transform.basis = _align_to_normal(left_normal)
		chunk.objects.append(left_fence)
		
		# Right fence
		var right_x = chunk_width / 2.0
		var right_height = _get_height_at_position(right_x, z_pos)
		var right_normal = _get_terrain_normal_at_position(right_x, z_pos)
		var right_fence
		right_fence = fence_scenes[randi_range(3, 4)].instantiate()
		add_child(right_fence)
		right_fence.global_position = Vector3(right_x, right_height, z_pos)
		# Align fence to terrain normal
		right_fence.global_transform.basis = _align_to_normal(right_normal)
		chunk.objects.append(right_fence)

func _get_terrain_normal_at_position(x_pos: float, z_pos: float) -> Vector3:
	# Sample nearby points to calculate normal
	var sample_distance = 0.5
	
	var center = _get_height_at_position(x_pos, z_pos)
	var right = _get_height_at_position(x_pos + sample_distance, z_pos)
	var forward = _get_height_at_position(x_pos, z_pos + sample_distance)
	
	# Calculate tangent vectors
	var tangent_x = Vector3(sample_distance, right - center, 0).normalized()
	var tangent_z = Vector3(0, forward - center, sample_distance).normalized()
	
	# Cross product gives us the normal
	var normal = tangent_z.cross(tangent_x).normalized()
	
	return normal

func _align_to_normal(normal: Vector3) -> Basis:
	# Create a basis that aligns the up vector (Y) with the terrain normal
	var up = normal
	var right = Vector3.FORWARD.cross(up)
	
	# Handle edge case where normal is pointing straight up/down
	if right.length() < 0.001:
		right = Vector3.RIGHT.cross(up)
	
	right = right.normalized()
	var forward = up.cross(right).normalized()
	
	return Basis(right, up, forward)

func _create_solid_walls(chunk : TerrainChunk):
	# create two solid walls left and right that follow terrain height
	_create_wall_side(chunk, -chunk_width / 2.0, true) # left
	_create_wall_side(chunk, chunk_width / 2.0, false) # right

func _create_wall_side(chunk : TerrainChunk, x_position : float, is_left : bool):
	var segments : int = 20
	var heights : Array[float] = []
	
	for i in range(segments + 1):
		var z_offset = (float(i) / float(segments)) * chunk_length
		var z_pos = chunk.z_position + z_offset
		var height = _get_height_at_position(x_position, z_pos)
		heights.append(height)
	
	var wall_mesh = _create_wall_mesh(heights, is_left)
	var wall_instance = MeshInstance3D.new()
	wall_instance.mesh = wall_mesh
	
	if wall_material:
		wall_instance.material_override = wall_material
	else:
		var default_wall_material = StandardMaterial3D.new()
		default_wall_material.albedo_color = Color(0.3, 0.25, 0.2)
		default_wall_material.roughness = 0.8
		wall_instance.material_override = default_wall_material
	
	wall_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	
	# position wall
	var wall_node = Node3D.new()
	wall_node.position = Vector3(x_position, 0, chunk.z_position)
	add_child(wall_node)
	wall_node.add_child(wall_instance)
	
	var wall_body = StaticBody3D.new()
	wall_node.add_child(wall_body)
	
	var wall_collision = CollisionShape3D.new()
	var wall_shape = BoxShape3D.new()
	wall_shape.size = Vector3(wall_thickness, wall_height * 2, chunk_length)
	wall_collision.shape = wall_shape
	wall_collision.position = Vector3(0, wall_height, chunk_length / 2.0)
	wall_body.collision_layer = 2
	
	chunk.objects.append(wall_node)

func _create_wall_mesh(heights: Array[float], is_left: bool) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	
	var segments = heights.size() - 1
	var segment_length = chunk_length / float(segments)
	
	# Generate vertices for wall
	for i in range(heights.size()):
		var z_pos = float(i) * segment_length
		var base_height = heights[i]
		
		# Bottom vertex (on terrain)
		vertices.append(Vector3(0, base_height, z_pos))
		# Top vertex (wall height above terrain)
		vertices.append(Vector3(0, base_height + wall_height, z_pos))
		
		# UVs
		var u = float(i) / float(segments)
		uvs.append(Vector2(u, 0))
		uvs.append(Vector2(u, 1))
		
		# Normals (pointing inward to map)
		var normal = Vector3(1, 0, 0) if is_left else Vector3(-1, 0, 0)
		normals.append(normal)
		normals.append(normal)
	
	# Generate indices (two triangles per segment)
	for i in range(segments):
		var base_idx = i * 2
		
		# First triangle
		indices.append(base_idx)
		indices.append(base_idx + 2)
		indices.append(base_idx + 1)
		
		# Second triangle
		indices.append(base_idx + 1)
		indices.append(base_idx + 2)
		indices.append(base_idx + 3)
	
	# Create mesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	return mesh

func _spawn_obstacles(chunk: TerrainChunk):
	if obstacle_scenes.is_empty():
		return
	
	for i: int in range(obstacles_per_chunk):
		var random_scene: PackedScene = obstacle_scenes.pick_random()
		if random_scene:
			var obstacle = random_scene.instantiate()
			
			# Keep well within bounds
			var x_pos: float = rng.randf_range(-chunk_width / 2.0 + 4.0, chunk_width / 2.0 - 4.0)
			var z_pos: float = chunk.z_position + rng.randf_range(10.0, chunk_length - 10.0)
			
			var height: float = _get_height_at_position(x_pos, z_pos)
			
			# Obstacles ON ground (no offset)
			obstacle.global_position = Vector3(x_pos, height, z_pos)
			obstacle.add_to_group("obstacle")
			
			chunk.objects.append(obstacle)
			add_child(obstacle)

func _spawn_enemies(chunk: TerrainChunk):
	if enemy_scenes.is_empty():
		return
	
	var num_enemies = rng.randi_range(enemies_per_chunk_min, enemies_per_chunk_max)
	
	for i: int in range(num_enemies):
		var random_scene = enemy_scenes.pick_random()
		if random_scene:
			var enemy = random_scene.instantiate()
			
			var x_pos: float = rng.randf_range(-chunk_width / 2.0 + 4.0, chunk_width / 2.0 - 4.0)
			var z_pos: float = chunk.z_position + rng.randf_range(15.0, chunk_length - 15.0)
			
			var height: float = _get_height_at_position(x_pos, z_pos)
			
			# Ground enemies ON the ground (just tiny offset for collision)
			enemy.global_position = Vector3(x_pos, height, z_pos)
			enemy.add_to_group("enemy")
			
			chunk.objects.append(enemy)
			add_child(enemy)

func _spawn_flying_enemies(chunk: TerrainChunk):
	if flying_enemy_scenes.is_empty():
		return
	
	var num_flying = rng.randi_range(flying_enemies_per_chunk_min, flying_enemies_per_chunk_max)
	
	for i: int in range(num_flying):
		var random_scene = flying_enemy_scenes.pick_random()
		if random_scene:
			var flying_enemy = random_scene.instantiate()
			
			var x_pos: float = rng.randf_range(-chunk_width / 2.0 + 4.0, chunk_width / 2.0 - 4.0)
			var z_pos: float = chunk.z_position + rng.randf_range(15.0, chunk_length - 15.0)
			
			var height: float = _get_height_at_position(x_pos, z_pos)
			
			# Flying enemies hover SLIGHTLY above ground (3-5 units)
			var hover_height = height + rng.randf_range(3.0, 5.0)
			flying_enemy.global_position = Vector3(x_pos, hover_height, z_pos)
			flying_enemy.add_to_group("enemy")
			flying_enemy.add_to_group("flying_enemy")
			
			chunk.objects.append(flying_enemy)
			add_child(flying_enemy)

func _spawn_powerups(chunk: TerrainChunk):
	if powerup_scenes.is_empty():
		return
	
	var num_powerups = rng.randi_range(powerups_per_chunk_min, powerups_per_chunk_max)
	
	for i: int in range(num_powerups):
		var random_scene = powerup_scenes.pick_random()
		if random_scene:
			var powerup = random_scene.instantiate()
			
			var x_pos: float = rng.randf_range(-chunk_width / 2.0 + 4.0, chunk_width / 2.0 - 4.0)
			var z_pos: float = chunk.z_position + rng.randf_range(15.0, chunk_length - 15.0)
			
			var height: float = _get_height_at_position(x_pos, z_pos)
			
			# Powerups float slightly above ground (2 units)
			powerup.global_position = Vector3(x_pos, height, z_pos)
			powerup.add_to_group("powerup")
			
			chunk.objects.append(powerup)
			add_child(powerup)

func _recycle_chunk(chunk: TerrainChunk):
	_reset_chunk(chunk)
	chunk_pool.append(chunk)
