extends Node
class_name GameManager

# References
@export var player: Player
@export var ui_layer: Control

# UI elements
var score_label: Label
var game_over_panel: Panel
var restart_button: Button

# Game state
var score: int = 0
var game_active: bool = false
var distance_traveled: float = 0.0

signal game_started
signal game_over

func _ready():
	self.add_to_group("enemy")
	# Find player if not assigned
	if not player:
		await get_tree().process_frame
		player = get_tree().get_first_node_in_group("player") as Player
	
	if player:
		player.player_died.connect(_on_player_died)
		player.enemy_killed.connect(_on_enemy_killed)
	
	# Find UI elements
	if ui_layer:
		score_label = ui_layer.get_node_or_null("ScoreLabel")
		game_over_panel = ui_layer.get_node_or_null("GameOverPanel")
		restart_button = ui_layer.get_node_or_null("GameOverPanel/RestartButton")
		
		if restart_button:
			restart_button.pressed.connect(_on_restart_pressed)
		
		if game_over_panel:
			game_over_panel.visible = false
	
	start_game()

func _process(delta: float):
	if not game_active or not player:
		return
	
	# Track distance
	distance_traveled = player.global_position.z
	
	# Update score based on distance
	var new_score = int(distance_traveled / 10.0)
	if new_score > score:
		score = new_score
		_update_score_display()

func start_game():
	game_active = true
	score = 0
	distance_traveled = 0.0
	_update_score_display()
	
	if game_over_panel:
		game_over_panel.visible = false
	
	game_started.emit()

func _on_player_died():
	game_active = false
	_show_game_over()
	game_over.emit()

func _on_enemy_killed(enemy: Node3D):
	# Award points for killing enemies
	score += 10
	_update_score_display()

func _show_game_over():
	if game_over_panel:
		game_over_panel.visible = true
		
		# Update final score in game over panel
		var final_score_label = game_over_panel.get_node_or_null("FinalScoreLabel")
		if final_score_label:
			final_score_label.text = "Final Score: " + str(score)

func _update_score_display():
	if score_label:
		score_label.text = "Score: " + str(score)

func _on_restart_pressed():
	get_tree().reload_current_scene()
