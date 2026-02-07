class_name Powerup
extends Area3D

enum PowerupType { HEAL, SPEED_BOOST, INVULNERABILITY }

@export var powerup_type: PowerupType = PowerupType.HEAL
@export var heal_amount: float = 30.0
@export var speed_multiplier: float = 1.5
@export var effect_duration: float = 5.0
@export var rotation_speed: float = 2.0

var mesh_instance: MeshInstance3D

func _ready():
	add_to_group("powerup")
	body_entered.connect(_on_body_entered)

	# Find mesh for rotation
	mesh_instance = _find_mesh_instance(self)

	# Set up visual based on type
	_setup_visual()

func _process(delta: float):
	# Rotate powerup for visual appeal
	if mesh_instance:
		mesh_instance.rotate_y(rotation_speed * delta)

func _on_body_entered(body: Node3D):
	# Check if it's the player (by group or class)
	if body.is_in_group("player") or body.name == "Player":
		_apply_effect(body)
		# Optional: Add pickup sound/effect here
		# AudioManager.play_sound("powerup_pickup")
		VFXManager.spawn_powerup_effect(global_position)
		queue_free()

func _apply_effect(player: Node3D):
	match powerup_type:
		PowerupType.HEAL:
			if player.has_method("heal_vision"):
				player.heal_vision(heal_amount)
				print("Powerup: Healed player for ", heal_amount)

		PowerupType.SPEED_BOOST:
			if player.has_method("apply_speed_boost"):
				player.apply_speed_boost(speed_multiplier, effect_duration)
				print("Powerup: Speed boost applied (", speed_multiplier, "x for ", effect_duration, "s)")

		PowerupType.INVULNERABILITY:
			if player.has_method("apply_invulnerability"):
				player.apply_invulnerability(effect_duration)
				print("Powerup: Invulnerability applied for ", effect_duration, "s")

func _setup_visual():
	if not mesh_instance:
		return

	var material = StandardMaterial3D.new()

	match powerup_type:
		PowerupType.HEAL:
			material.albedo_color = Color.GREEN
			material.emission_enabled = true
			material.emission = Color.GREEN
			material.emission_energy = 1.5

		PowerupType.SPEED_BOOST:
			material.albedo_color = Color.YELLOW
			material.emission_enabled = true
			material.emission = Color.YELLOW
			material.emission_energy = 1.5

		PowerupType.INVULNERABILITY:
			material.albedo_color = Color.CYAN
			material.emission_enabled = true
			material.emission = Color.CYAN
			material.emission_energy = 1.5

	mesh_instance.set_surface_override_material(0, material)

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node

	for child in node.get_children():
		var result = _find_mesh_instance(child)
		if result:
			return result

	return null
