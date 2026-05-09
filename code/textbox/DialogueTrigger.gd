extends Area2D
## DialogueTriggerArea2D
## Place this node in your scene, assign a DialogueData resource,
## and it will automatically show the dialogue when the player enters.

@export var dialogue_data: DialogueData
@export var textbox_node: CanvasLayer
@export var once_per_session: bool = true
@export var require_input_to_finish: bool = true
@export var require_input_to_start: bool = false

var _has_triggered: bool = false
var _dialogue_runner: DialogueRunner
var _ui_instance: Control

# Reference to your player or input handler
# Optional: if null, we assume global input is handled elsewhere
@export_node_path("Node") var player_node_path: NodePath
var _player: Node


func _ready() -> void:
	if player_node_path:
		_player = get_node_or_null(player_node_path)
	
	# Validate data early
	if not dialogue_data:
		push_warning("DialogueTriggerArea2D: No DialogueData assigned!")
	else:
		var validation_errors = dialogue_data.validate()
		if not validation_errors.is_empty():
			for err in validation_errors:
				push_error("DialogueTriggerArea2D: %s" % err)
				

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("use") and require_input_to_start:
		if _player in get_overlapping_bodies():
			if once_per_session and _has_triggered:
				return
			_has_triggered = true
			_start_dialogue()

func _on_body_entered(body: Node) -> void:
	if _player and body != _player:
		return
	
	if (once_per_session and _has_triggered) or require_input_to_start:
		return
	
	_has_triggered = true
	_start_dialogue()

func _start_dialogue() -> void:
	if not dialogue_data or dialogue_data.nodes.is_empty():
		push_error("DialogueTriggerArea2D: Cannot start - invalid dialogue data")
		return
	
	# Create UI if needed
	if not _ui_instance:
		_ui_instance = preload("res://scenes/ui/textbox/textbox.tscn").instantiate()
		textbox_node.add_child(_ui_instance)
		_ui_instance.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Create runner
	_dialogue_runner = DialogueRunner.new()
	textbox_node.add_child(_dialogue_runner)
	
	# Connect signals
	_dialogue_runner.dialogue_started.connect(_on_dialogue_started)
	_dialogue_runner.node_entered.connect(_on_node_displayed)
	_dialogue_runner.dialogue_ended.connect(_on_dialogue_ended)
	
	_ui_instance.connect_to_runner(_dialogue_runner)
	
	# Start dialogue
	_dialogue_runner.start(dialogue_data, DialogueConditionEvaluator.new())
	
	if name in get_tree().root.get_child(-1).textboxes_deactivated:
		_on_dialogue_ended()

func _on_dialogue_started(_data: Object) -> void:
	# Disable player movement if you have a player reference
	if _player:
		_player.stop_move = true
		_player.can_menu = false
	
	_ui_instance.visible = true

func _on_node_displayed(node: DialogueNode) -> void:
	_ui_instance.display_node(node)

func _on_dialogue_ended(node: DialogueNode = DialogueNode.new()) -> void:
	_ui_instance.visible = false
	
	# Re-enable player movement
	if _player:
		_player.stop_move = false
		_player.can_menu = true
	
	if once_per_session:
		get_tree().root.get_child(-1).textboxes_deactivated.append(self.name)
	
	# Clean up
	if _dialogue_runner:
		_dialogue_runner.queue_free()
		_dialogue_runner = null


func _input(event: InputEvent) -> void:
	if not _dialogue_runner or not _dialogue_runner.is_running:
		return
	
	if require_input_to_finish:
		if event.is_action_pressed("use") or event is InputEventMouseButton and event.pressed:
			_dialogue_runner.advance()
