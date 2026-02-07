extends Node3D
class_name VFXManager

# Singleton-style VFX manager
# Usage: VFXManager.spawn_dash_effect(position)

static var instance: VFXManager

# Particle scenes (assign in editor or create procedurally)
@export var dash_particle_scene: PackedScene
@export var hit_particle_scene: PackedScene
@export var powerup_collect_scene: PackedScene

func _ready():
	instance = self
	
	# If particle scenes aren't assigned, create simple ones
	if not dash_particle_scene:
		dash_particle_scene = _create_simple_particles(Color.CYAN)
	if not hit_particle_scene:
		hit_particle_scene = _create_simple_particles(Color.RED)
	if not powerup_collect_scene:
		powerup_collect_scene = _create_simple_particles(Color.GREEN)

static func spawn_dash_effect(pos: Vector3):
	if instance and instance.dash_particle_scene:
		instance._spawn_particle(instance.dash_particle_scene, pos)

static func spawn_hit_effect(pos: Vector3):
	if instance and instance.hit_particle_scene:
		instance._spawn_particle(instance.hit_particle_scene, pos)

static func spawn_powerup_effect(pos: Vector3):
	if instance and instance.powerup_collect_scene:
		instance._spawn_particle(instance.powerup_collect_scene, pos)

func _spawn_particle(scene: PackedScene, pos: Vector3):
	var particle = scene.instantiate()
	add_child(particle)
	particle.global_position = pos
	
	# Auto-remove after particles finish
	if particle is GPUParticles3D:
		particle.emitting = true
		particle.one_shot = true
		await get_tree().create_timer(particle.lifetime).timeout
		particle.queue_free()

func _create_simple_particles(color: Color) -> PackedScene:
	# Create a simple particle system procedurally
	var particles = GPUParticles3D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.amount = 20
	particles.lifetime = 1.0
	particles.explosiveness = 0.8
	
	# Create process material
	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.5
	material.direction = Vector3(0, 1, 0)
	material.spread = 180.0
	material.initial_velocity_min = 2.0
	material.initial_velocity_max = 4.0
	material.gravity = Vector3(0, -9.8, 0)
	material.scale_min = 0.1
	material.scale_max = 0.3
	
	particles.process_material = material
	
	# Create draw pass (simple sphere)
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.1
	sphere_mesh.height = 0.2
	
	var sphere_material = StandardMaterial3D.new()
	sphere_material.albedo_color = color
	sphere_material.emission_enabled = true
	sphere_material.emission = color
	sphere_material.emission_energy = 2.0
	
	sphere_mesh.material = sphere_material
	particles.draw_pass_1 = sphere_mesh
	
	# Pack into scene
	var packed_scene = PackedScene.new()
	packed_scene.pack(particles)
	
	return packed_scene

# Screen shake helper
static func screen_shake(intensity: float = 1.0, duration: float = 0.2):
	if instance:
		instance._do_screen_shake(intensity, duration)

func _do_screen_shake(intensity: float, duration: float):
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
	
	var original_position = camera.position
	var shake_timer = 0.0
	
	while shake_timer < duration:
		shake_timer += get_process_delta_time()
		
		var shake_amount = intensity * (1.0 - shake_timer / duration)
		var offset = Vector3(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		)
		
		camera.position = original_position + offset
		await get_tree().process_frame
	
	camera.position = original_position
