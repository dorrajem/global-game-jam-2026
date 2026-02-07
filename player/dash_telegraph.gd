class_name DashTelegraph
extends Node3D

# This creates a visual line showing where the player will dash

@export var player: Player
@export var targeting_system: TargetingSystem
@export var line_color: Color = Color.RED
@export var line_width: float = 0.1

var line_mesh: ImmediateMesh
var mesh_instance: MeshInstance3D

func _ready():
	# Create immediate mesh for drawing lines
	line_mesh = ImmediateMesh.new()
	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = line_mesh
	add_child(mesh_instance)
	
	# Create material for the line
	var material = StandardMaterial3D.new()
	material.albedo_color = line_color
	material.emission_enabled = true
	material.emission = line_color
	material.emission_energy = 2.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.material_override = material
	
	# Find references if not assigned
	if not player:
		player = get_tree().get_first_node_in_group("player") as Player
	if not targeting_system:
		targeting_system = get_tree().get_first_node_in_group("targeting_system") as TargetingSystem

func _process(_delta: float):
	if not player or not targeting_system:
		return
	
	line_mesh.clear_surfaces()
	
	var target = targeting_system.get_current_target()
	
	if target and is_instance_valid(target) and not player.is_dashing:
		# Draw line from player to target
		_draw_line(player.global_position, target.global_position)

func _draw_line(from: Vector3, to: Vector3):
	line_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	line_mesh.surface_add_vertex(from)
	line_mesh.surface_end()
	line_mesh.surface_add_vertex(to)
