class_name DialogueUI
extends Control

## Simple dialogue UI with typewriter effect
## Connect to DialogueRunner signals

@export_group("Layout")
@export var text_label: RichTextLabel
@export var choices_container: VBoxContainer
@export var portrait_texture: Sprite2D

@export_group("Typewriter")
@export var chars_per_second: float = 30.0
@export var auto_advance_after_typing: bool = true
@export var auto_advance_delay: float = 1.0

var player

var runner: DialogueRunner
var is_typing: bool = false
var full_text: String = ""
var current_index: int = 0
var type_timer: Timer
var auto_advance_timer: Timer

func _ready() -> void:
	_setup_timers()
	_hide_ui()

func _setup_timers() -> void:
	type_timer = Timer.new()
	type_timer.wait_time = 1.0 / chars_per_second
	type_timer.timeout.connect(_on_type_tick)
	add_child(type_timer)
	
	auto_advance_timer = Timer.new()
	auto_advance_timer.one_shot = true
	auto_advance_timer.timeout.connect(_on_auto_advance)
	add_child(auto_advance_timer)

func connect_to_runner(dialogue_runner: DialogueRunner) -> void:
	runner = dialogue_runner
	
	runner.dialogue_started.connect(_on_dialogue_started)
	runner.node_entered.connect(display_node)
	runner.text_displayed.connect(_on_text_displayed)
	runner.choice_available.connect(_on_choice_available)
	runner.dialogue_ended.connect(_on_dialogue_ended)

func _hide_ui() -> void:
	visible = false
	if choices_container:
		for child in choices_container.get_children():
			child.queue_free()

func _show_ui() -> void:
	visible = true

func _on_dialogue_started(_data: DialogueData) -> void:
	_show_ui()

func display_node(node: DialogueNode) -> void:
	# Clear previous choices
	if choices_container:
		for child in choices_container.get_children():
			child.queue_free()

	# Update portrait
	if portrait_texture and node.portrait:
		portrait_texture.texture = node.portrait
		portrait_texture.visible = true
	elif portrait_texture:
		portrait_texture.visible = false

	# Start typewriter effect
	_on_text_displayed(node.text)

func _on_text_displayed(text: String) -> void:
	full_text = text
	current_index = 0
	text_label.text = ""
	is_typing = true
	type_timer.start()

func _on_type_tick() -> void:
	if current_index < full_text.length():
		text_label.text += full_text[current_index]
		current_index += 1
	else:
		_finish_typing()

func _finish_typing() -> void:
	is_typing = false
	type_timer.stop()
	text_label.text = full_text
	
	if auto_advance_after_typing and runner and runner.current_node:
		if not runner.current_node.has_choices():
			auto_advance_timer.start(auto_advance_delay)

func _on_auto_advance() -> void:
	if runner and runner.is_running:
		runner.advance()

func _on_choice_available(choice: DialogueChoice) -> void:
	if not choices_container:
		return
	var button = Button.new()
	button.text = choice.text
	button.pressed.connect(_on_choice_pressed.bind(choice))
	choices_container.add_child(button)

func _on_choice_pressed(choice: DialogueChoice) -> void:
	if runner and runner.is_running:
		runner.select_choice(choice)

func _on_dialogue_ended(_node: DialogueNode) -> void:
	_hide_ui()

# Input handling for skipping typewriter or advancing
func _unhandled_input(event: InputEvent) -> void:
	if not visible or not runner or not runner.is_running:
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_advance_input()
	elif event is InputEventKey and event.pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE):
		_handle_advance_input()

func _handle_advance_input() -> void:
	if is_typing:
		# Skip typewriter
		_finish_typing()
	else:
		# Advance dialogue if no choices shown
		if runner.current_node and not runner.current_node.has_choices():
			runner.advance()
