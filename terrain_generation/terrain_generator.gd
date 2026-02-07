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
