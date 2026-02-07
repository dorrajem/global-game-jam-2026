class_name VisionMaskUI
extends Control

# references
@onready var top_mask: ColorRect = $TopMask
@onready var bottom_mask: ColorRect = $BottomMask
@onready var score_label: Label = $ScoreLabel

# settings
@export var min_mask_height : float = 0.0 # full vision
@export var max_mask_height_percent : float = 0.48 # zero vision (almost)
@export var animation_speed : float = 5.0

# state
var current_vision : float = 50.0
var max_vision : float = 100.0
var target_mask_height : float = 0.0

func _ready() -> void:
	# find player and conncet signals
	await get_tree().process_frame
	var player : CharacterBody3D = get_tree().get_first_node_in_group("player")
	if player:
		player.visibility_changed.connect(_on_vision_changed)
	
	# initialize mask
	_update_mask_positions(0.0)

func _process(delta: float) -> void:
	# smoothly animate mask height
	if top_mask and bottom_mask:
		var current_height : float = top_mask.size.y
		var new_height : float = lerp(current_height, target_mask_height, animation_speed * delta)
		_update_mask_positions(new_height)

func _on_vision_changed(new_vision : float, new_max_vision : float):
	current_vision = new_vision
	max_vision = new_max_vision
	
	# calculate mask height based on vision percentage
	var vision_percent : float = current_vision / max_vision
	var screen_height : float = get_viewport_rect().size.y
	
	# inverted: less vision = more mask
	target_mask_height = (1.0 - vision_percent) * (screen_height * max_mask_height_percent)

func _update_mask_positions(height : float):
	if top_mask:
		top_mask.size.y = height
		top_mask.position.y = 0
	if bottom_mask:
		bottom_mask.size.y = height
		var screen_height : float = get_viewport_rect().size.y
		bottom_mask.position.y = screen_height - height
