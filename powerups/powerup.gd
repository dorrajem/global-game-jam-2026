@tool
class_name Powerup
extends Area3D

enum PowerupType { HEAL, SPEED_BOOST, INVULNERABILITY }

@export var powerup_type: PowerupType = PowerupType.HEAL
@export var heal_amount: float = 30.0
@export var speed_multiplier: float = 1.5
@export var effect_duration: float = 1.5
@export var rotation_speed: float = 2.0

@onready var timer: Timer = $ReactionVignette/Timer

signal powerup_pickup(powerup : String)

var mesh_instance: MeshInstance3D

func _ready():
	add_to_group("powerup")
	body_entered.connect(_on_body_entered)
	powerup_pickup.connect(_on_pickup_overlay)

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
		#queue_free()

func _apply_effect(player: Node3D):
	match powerup_type:
		PowerupType.HEAL:
			if player.has_method("heal_vision"):
				player.heal_vision(heal_amount)
				powerup_pickup.emit("heal")
				print("Powerup: Healed player for ", heal_amount)

		PowerupType.SPEED_BOOST:
			if player.has_method("apply_speed_boost"):
				player.apply_speed_boost(speed_multiplier, effect_duration)
				powerup_pickup.emit("speed")
				print("Powerup: Speed boost applied (", speed_multiplier, "x for ", effect_duration, "s)")

		PowerupType.INVULNERABILITY:
			if player.has_method("apply_invulnerability"):
				player.apply_invulnerability(effect_duration)
				powerup_pickup.emit("invul")
				print("Powerup: Invulnerability applied for ", effect_duration, "s")

func _setup_visual():
	if not mesh_instance:
		return

	var material = StandardMaterial3D.new()

	match powerup_type:
		PowerupType.HEAL:
			material.albedo_color = Color("00ff48")
			material.emission_enabled = true
			material.emission = Color("00ff48")
			material.emission_energy = 7.5

		PowerupType.SPEED_BOOST:
			material.albedo_color = Color("8062ff")
			material.emission_enabled = true
			material.emission = Color("8062ff")
			material.emission_energy = 7.5

		PowerupType.INVULNERABILITY:
			material.albedo_color = Color("ffb861")
			material.emission_enabled = true
			material.emission = Color("ffb861")
			material.emission_energy = 7.5

	mesh_instance.set_surface_override_material(0, material)

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node

	for child in node.get_children():
		var result = _find_mesh_instance(child)
		if result:
			return result

	return null

func _on_pickup_overlay(type: String):
	var rect = get_tree().get_first_node_in_group("overlay")
	if not rect:
		print("Error: No node found in group 'overlay'")
		return

	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.visible = true 
	
	var target_color: Color
	var duration : float
	
	match type:
		"heal":
			rect.texture = preload("res://assets/overlays/heal overlay.png")
			target_color = Color.GREEN
			duration = 1.0
		"invul":
			rect.texture = preload("res://assets/overlays/shield overlay.png")
			target_color = Color.YELLOW
			duration = effect_duration
		"speed":
			rect.texture = preload("res://assets/overlays/speed overlay.png")
			target_color = Color.MEDIUM_PURPLE
			duration = 1.0
	
	var tween = create_tween()
	await tween.tween_property(rect, "modulate", target_color, duration).finished
	var tween2 = create_tween()
	await tween2.tween_property(rect, "modulate:a", 0.0, 0.5).finished
	tween.kill()
	queue_free()
