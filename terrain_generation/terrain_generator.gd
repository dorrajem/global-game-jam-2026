@tool
class_name TerrainGenerator
extends Node3D

# terrain settings
@export_group('Terrain Settings')
@export var chunk_length : float = 50.0
@export var chunk_width : float = 20.0
@export var chunks_ahead : int = 3
@export var chunks_behind : int = 1

# height variation
@export_group('Height Settings')
@export var min_height : float = 0.0
@export var max_height : float = 32.0
@export var height_smoothness : float = 0.3

# obstacle settings
@export_group("Obstacle Settings")
@export var obstacle_density : float = 0.15
@export var min_obstacly_distance : float = 3.0

# prefabs
@export_group("Prefabs")
@export var obstacle_scenes : Array[PackedScene] = []
@export var enemy_scenes : Array[PackedScene] = []
@export var powerup_scenes : Array[PackedScene] = []

# material
@export_group("Materials")
@export var terrain_material : Material

# interntal state
var active_chunks : Array[TerrainChunk] = []
var chunk_pool : Array[TerrainChunk] = []
var current_chunk_index : int = 0
var player : CharacterBody3D = null
var noise : FastNoiseLite
var rng : RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	# initialize noise for height variation
	rng.randomize()
	noise = FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.1
	noise.fractal_octaves = 3
	
	# find player
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	
	# generate initial chunks
	for i : int in range(chunks_ahead + chunks_behind + 1):
		_create_chunk(i - chunks_behind)

func _process(delta: float) -> void:
	if not player:
		return
	
	# check if we need to spawn new chunks
	var player_chunk_index = int(player.global_position.z / chunk_length)
	#var furthest_chunk_z = current_chunk_index * chunk_length
	
	if current_chunk_index < player_chunk_index + chunks_ahead:
		_advance_chunks()
	
	# remove old chunks
	while active_chunks.size() > 0:
		var oldest = active_chunks[0]
		if oldest.chunk_index < player_chunk_index - chunks_behind:
			_recycle_chunk(oldest)
			active_chunks.remove_at(0)
		else:
			break

func _advance_chunks():
	# add new chunk ahead
	current_chunk_index += 1
	_create_chunk(current_chunk_index + chunks_ahead)

func _create_chunk(chunk_index : int):
	var chunk : TerrainChunk
	
	# try to reuse from pool
	if chunk_pool.size() > 0:
		chunk = chunk_pool.pop_back()
		_reset_chunk(chunk)
	else:
		chunk = TerrainChunk.new()
		_initialize_chunk(chunk)
	
	chunk.chunk_index = chunk_index
	chunk.z_position = chunk_index * chunk_length
	
	# generate terrain mesh
	_generate_chunk_mesh(chunk)
	
	# spawn objects
	_spawn_obstacles(chunk)
	_spawn_enemies(chunk)
	_spawn_powerups(chunk)
	
	active_chunks.append(chunk)

func _initialize_chunk(chunk : TerrainChunk):
	# create static body for collision
	chunk.static_body = StaticBody3D.new()
	add_child(chunk.static_body)
	
	# create mesh instance
	chunk.mesh_instance = MeshInstance3D.new()
	chunk.static_body.add_child(chunk.mesh_instance)
	
	# DEBUG CUBE
	#var debug_cube = MeshInstance3D.new()
	#var cube_mesh = BoxMesh.new()
	#cube_mesh.size = Vector3(1, 10, 1)
	#debug_cube.mesh = cube_mesh
	#var red_mat = StandardMaterial3D.new()
	#red_mat.albedo_color = Color.RED
	#red_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	#debug_cube.material_override = red_mat
	#chunk.static_body.add_child(debug_cube)
	
	if not terrain_material:
		# create a default bright green material
		var default_mat : StandardMaterial3D = StandardMaterial3D.new()
		default_mat.albedo_color = Color(0.269, 0.163, 0.19, 1.0)
		default_mat.roughness = 1.0
		chunk.mesh_instance.material_override = default_mat
	else:
		chunk.mesh_instance.material_override = terrain_material
	
	# cast shadows
	chunk.mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	
	# create collision shape
	chunk.collision_shape = CollisionShape3D.new()
	chunk.static_body.add_child(chunk.collision_shape)

func _reset_chunk(chunk : TerrainChunk):
	# remove all spawned objects
	for obj : Node3D in chunk.objects:
		if is_instance_valid(obj):
			obj.queue_free()
	chunk.objects.clear()

func _generate_chunk_mesh(chunk : TerrainChunk):
	var arrays : Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	var verticies : PackedVector3Array = PackedVector3Array()
	var normals : PackedVector3Array = PackedVector3Array()
	var uvs : PackedVector2Array = PackedVector2Array()
	var indices : PackedInt32Array = PackedInt32Array()
	
	# generate a simple plane with height variations
	var segments_x : int = 10
	var segments_z : int = 20
	var segment_width : float = chunk_width / float(segments_x)
	var segment_length : float = chunk_length / float(segments_z)
	
	# generate vertecies
	for z : int in range(segments_z + 1):
		for x : int in range(segments_x + 1):
			var pos_x : float = (float(x) * segment_width) - (chunk_width / 2.0)
			var pos_z : float = float(z) * segment_length
			
			# use noise for height variations
			var world_x : float = pos_x
			var world_z : float = chunk.z_position + pos_z
			
			var height = noise.get_noise_2d(world_x * height_smoothness, world_z * height_smoothness)
			height = remap(height, -1.0, 1.0, min_height, max_height)
			
			var vertex = Vector3(pos_x, height, pos_z)
			var uv = Vector2(float(x) / segments_x, float(z) / segments_z)
			
			# add vertex
			verticies.append(Vector3(pos_x, height, pos_z))
			normals.append(Vector3.UP)
			uvs.append(Vector2(float(x) / float(segments_x), float(z) / float(segments_z)))
	
	# generate indices
	for z : int in range(segments_z):
		for x : int in range(segments_x):
			var top_left : int = z * (segments_x + 1) + x
			var top_right : int = top_left + 1
			var bottom_left : int = (z + 1) * (segments_x + 1) + x
			var bottom_right : int = bottom_left + 1
			
			# first triangle (top-left, top_right, bottom_left)
			indices.append(top_left)
			indices.append(top_right)
			indices.append(bottom_left)

			# first triangle (top-right, bottom_right, bottom_left)
			indices.append(top_right)
			indices.append(bottom_right)
			indices.append(bottom_left)
			
	#build the mesh
	arrays[Mesh.ARRAY_VERTEX] = verticies
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	
	var array_mesh : ArrayMesh = ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	chunk.mesh_instance.mesh = array_mesh
	
	# create collision shape
	var shape : ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	var faces : PackedVector3Array = PackedVector3Array()
	
	# convert indices to face data for collision
	for i : int in range(0, indices.size(), 3):
		faces.append(verticies[indices[i]])
		faces.append(verticies[indices[i + 1]])
		faces.append(verticies[indices[i + 2]])
		
	shape.set_faces(faces)
	chunk.collision_shape.shape = shape
	
	# position the chunk
	chunk.static_body.global_position = Vector3(0, 0, chunk.z_position)

func _spawn_obstacles(chunk : TerrainChunk):
	if obstacle_scenes.is_empty():
		return
	
	var num_obstacles : int = int(chunk_length / min_obstacly_distance * obstacle_density)
	
	for i : int in range(num_obstacles):
		var random_scene : PackedScene = obstacle_scenes.pick_random()
		if random_scene:
			var obstacle = random_scene.instantiate()
			add_child(obstacle)
			
			# random position within chunk
			var x_pos : float = rng.randf_range(-chunk_width / 2.0 + 2.0, chunk_width / 2.0 - 2.0)
			var z_pos : float = chunk.z_position + rng.randf_range(5.0, chunk_length - 5.0)
			
			# get height at this position
			var height : float = noise.get_noise_2d(x_pos * height_smoothness, z_pos * height_smoothness)
			height = remap(height, -1.0, 1.0, min_height, max_height)
			
			obstacle.global_position = Vector3(x_pos, height, z_pos)
			obstacle.add_to_group("obstacle")
			
			chunk.objects.append(obstacle)

func _spawn_enemies(chunk : TerrainChunk):
	if enemy_scenes.is_empty():
		return
	
	var num_enemies = rng.randi_range(2, 5)
	
	for i : int in range(num_enemies):
		var random_scene = enemy_scenes.pick_random()
		if random_scene:
			var enemy = random_scene.instantiate()
			add_child(enemy)
			
			# random position within chunk
			var x_pos : float = rng.randf_range(-chunk_width / 2.0 + 2.0, chunk_width / 2.0 - 2.0)
			var z_pos : float = chunk.z_position + rng.randf_range(10.0, chunk_length - 10.0)
			
			# get height at this position
			var height : float = noise.get_noise_2d(x_pos * height_smoothness, z_pos * height_smoothness)
			height = remap(height, -1.0, 1.0, min_height, max_height)
			
			enemy.global_position = Vector3(x_pos, height, z_pos)
			enemy.add_to_group("enemy")
			
			chunk.objects.append(enemy)

func _spawn_powerups(chunk : TerrainChunk):
	if powerup_scenes.is_empty():
		return
	
	# spawn 0-2 powerups per chunk
	var num_powerups = rng.randi_range(0, 2)
	
	for i : int in range(num_powerups):
		var random_scene = powerup_scenes.pick_random()
		if random_scene:
			var powerup = random_scene.instantiate()
			add_child(powerup)
			
			# random position within chunk
			var x_pos : float = rng.randf_range(-chunk_width / 2.0 + 2.0, chunk_width / 2.0 - 2.0)
			var z_pos : float = chunk.z_position + rng.randf_range(10.0, chunk_length - 10.0)
			
			# get height at this position
			var height : float = noise.get_noise_2d(x_pos * height_smoothness, z_pos * height_smoothness)
			height = remap(height, -1.0, 1.0, min_height, max_height)
			
			powerup.global_position = Vector3(x_pos, height, z_pos)
			powerup.add_to_group("powerup")
			
			chunk.objects.append(powerup)

func _recycle_chunk(chunk : TerrainChunk):
	_reset_chunk(chunk)
	chunk_pool.append(chunk)
