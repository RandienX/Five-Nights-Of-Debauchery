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
@export var auto_advance_after_typing: bool = false
@export var auto_advance_delay: float = 1.0

var player

var runner: DialogueRunner
var is_typing: bool = false
var full_text: String = ""
var current_index: int = 0
var type_timer: Timer
var auto_advance_timer: Timer
var voiceline_player: AudioStreamPlayer

# Choice navigation
var choice_buttons: Array[Button] = []
var current_choice_index: int = 0
var is_choosing: bool = false

func _ready() -> void:
	_setup_timers()
	_hide_ui()
	voiceline_player = $"../AudioStreamPlayer"

func _setup_timers() -> void:
	type_timer = Timer.new()
	type_timer.wait_time = 1.0 / (chars_per_second * (chars_per_second / Settings.text_speed))
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

func _on_dialogue_started(_data: Object) -> void:
	_show_ui()

func display_node(node: DialogueNode) -> void:
	# Clear previous choices
	if choices_container:
		for child in choices_container.get_children():
			child.queue_free()
	choices_container.visible = false
	choice_buttons.clear()
	current_choice_index = 0
	is_choosing = false

	# Update portrait
	if portrait_texture and node.portrait:
		portrait_texture.texture = node.portrait
		portrait_texture.visible = true
	elif portrait_texture:
		portrait_texture.visible = false
		
	# Play voiceline if available
	if voiceline_player and node.voiceline:
		voiceline_player.stream = node.voiceline
		voiceline_player.play()
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
		else:
		# Choices are available, enable navigation mode
			is_choosing = true
			if not choice_buttons.is_empty():
				_update_choice_selection()

func _on_auto_advance() -> void:
	if runner and runner.is_running:
		runner.advance()

func _on_choice_available(choice: DialogueChoice) -> void:
	if not choices_container:
		return
	var button = Button.new()
	button.text = choice.text
	button.pressed.connect(_on_choice_pressed.bind(choice))
	button.set_meta("choice", choice)
	choices_container.add_child(button)
	choice_buttons.append(button)
	choices_container.visible = true
	
func _update_choice_selection():
	# Update visual selection of choice buttons (similar to SkillManager.navigate_skills)
	for i in range(choice_buttons.size()):
		var button = choice_buttons[i]
		if i == current_choice_index:
			button.grab_focus()
			button.modulate = Color(1, 1, 0.5)  # Yellow highlight
		else:
			button.modulate = Color(1, 1, 1)

func _navigate_choices(direction: int):
	if choice_buttons.is_empty():
		return

	var new_index = current_choice_index + direction

	# Loop around if needed
	if new_index < 0:
		new_index = choice_buttons.size() - 1
	elif new_index >= choice_buttons.size():
		new_index = 0

	current_choice_index = new_index
	_update_choice_selection()
		
func _on_choice_pressed(choice: DialogueChoice) -> void:
	if runner and runner.is_running:
		is_choosing = false
		choice_buttons.clear()
		current_choice_index = 0
		runner.select_choice(choice)

func _on_dialogue_ended(_node: DialogueNode) -> void:
	if voiceline_player:
		voiceline_player.stop()
	_hide_ui()

# Input handling for skipping typewriter or advancing
func _input(event: InputEvent) -> void:
	if not visible or not runner or not runner.is_running:
		return
		
	if is_choosing and not choice_buttons.is_empty():
		if event is InputEventKey and event.pressed:
			if event.is_action("up"):
				_navigate_choices(-1)
				get_viewport().set_input_as_handled()
				return
		elif event.is_action("down"):
			_navigate_choices(1)
			get_viewport().set_input_as_handled()
			return
		elif event.is_action("use") or event.keycode == KEY_SPACE:
			# Select current choice
			if current_choice_index >= 0 and current_choice_index < choice_buttons.size():
				var selected_button = choice_buttons[current_choice_index]
				var selected_choice = selected_button.get_meta("choice")
				_on_choice_pressed(selected_choice)
				get_viewport().set_input_as_handled()
				return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:	if current_index < full_text.length():
		if current_index < full_text.length():
			while current_index < full_text.length():
				_on_type_tick()
			_finish_typing()
		else:
			_handle_advance_input()
	elif event is InputEventKey and event.pressed and event.is_action("use"):
		if current_index < full_text.length():
			while current_index < full_text.length():
				_on_type_tick()
			_finish_typing()
		else:
			_handle_advance_input()

func _handle_advance_input() -> void:
	if is_typing:
		# Skip typewriter
		_finish_typing()
	else:
		# Advance dialogue if no choices shown
		if runner.current_node and not runner.current_node.has_choices():
			runner.advance()
