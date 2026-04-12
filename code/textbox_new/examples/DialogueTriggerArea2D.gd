extends Area2D
## DialogueTriggerArea2D
## Place this node in your scene, assign a DialogueData resource,
## and it will automatically show the dialogue when the player enters.

@export var dialogue_data: DialogueData
@export var once_per_session: bool = true
@export var require_input_to_finish: bool = true

var _has_triggered: bool = false
var _dialogue_runner: DialogueRunner
var _ui_instance: Control

# Reference to your player or input handler
# Optional: if null, we assume global input is handled elsewhere
@export_node_path("Node") var player_node_path: NodePath
var _player: Node


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
	if player_node_path:
		_player = get_node_or_null(player_node_path)
	
	# Validate data early
	if not dialogue_data:
		push_warning("DialogueTriggerArea2D: No DialogueData assigned!")
	elif not dialogue_data.validate():
		push_error("DialogueTriggerArea2D: DialogueData validation failed!")


func _on_body_entered(body: Node) -> void:
	# Check if it's the player (if player_node_path is set)
	if _player and body != _player:
		return
	
	if once_per_session and _has_triggered:
		return
	
	_has_triggered = true
	_start_dialogue()


func _start_dialogue() -> void:
	if not dialogue_data or dialogue_data.nodes.is_empty():
		push_error("DialogueTriggerArea2D: Cannot start - invalid dialogue data")
		return
	
	# Create UI if needed
	if not _ui_instance:
		_ui_instance = preload("res://code/textbox_new/DialogueUI.tscn").instantiate()
		add_child(_ui_instance)
		_ui_instance.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Create runner
	_dialogue_runner = DialogueRunner.new()
	add_child(_dialogue_runner)
	
	# Connect signals
	_dialogue_runner.dialogue_started.connect(_on_dialogue_started)
	_dialogue_runner.node_displayed.connect(_on_node_displayed)
	_dialogue_runner.dialogue_ended.connect(_on_dialogue_ended)
	_dialogue_runner.choice_made.connect(_on_choice_made)
	
	# Start dialogue
	_dialogue_runner.start(dialogue_data)


func _on_dialogue_started() -> void:
	# Disable player movement if you have a player reference
	if _player and _player.has_method("set_input_enabled"):
		_player.set_input_enabled(false)
	
	_ui_instance.visible = true


func _on_node_displayed(node: DialogueNode) -> void:
	_ui_instance.display_node(node)


func _on_dialogue_ended() -> void:
	_ui_instance.visible = false
	
	# Re-enable player movement
	if _player and _player.has_method("set_input_enabled"):
		_player.set_input_enabled(true)
	
	# Clean up
	if _dialogue_runner:
		_dialogue_runner.queue_free()
		_dialogue_runner = null


func _on_choice_made(choice_index: int) -> void:
	if _dialogue_runner:
		_dialogue_runner.select_choice(choice_index)


func _input(event: InputEvent) -> void:
	if not _dialogue_runner or not _dialogue_runner.is_running():
		return
	
	if require_input_to_finish:
		if event.is_action_pressed("ui_accept") or event is InputEventMouseButton and event.pressed:
			_dialogue_runner.advance()
