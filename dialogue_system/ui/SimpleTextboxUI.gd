extends Control

## Simple textbox UI for displaying dialogue.
## Connect this to a DialogueEngine's signals.


@export var engine: DialogueEngine  ## Reference to DialogueEngine (auto-find if not set)

# UI Controls
@onready var speaker_label: Label = $MarginContainer/VBoxContainer/SpeakerLabel
@onready var text_label: Label = $MarginContainer/VBoxContainer/TextLabel
@onready var portrait_texture: TextureRect = $MarginContainer/VBoxContainer/Portrait
@onready var choices_container: VBoxContainer = $MarginContainer/VBoxContainer/ChoicesContainer
@onready var next_button: Button = $MarginContainer/VBoxContainer/NextButton

# Typewriter effect
var typewriter_enabled: bool = true
var typewriter_speed: float = 0.03  # Seconds per character
var full_text: String = ""
var displayed_text: String = ""
var typewriter_timer: Timer = null
var is_typing: bool = false

# State
var current_node: DialogueNodeData = null
var waiting_for_choice: bool = false


func _ready() -> void:
	# Auto-find engine if not assigned
	if engine == null:
		engine = get_node_or_null("../DialogueEngine") as DialogueEngine
	
	if engine != null:
		_connect_to_engine()
	
	# Create typewriter timer
	typewriter_timer = Timer.new()
	typewriter_timer.one_shot = false
	typewriter_timer.timeout.connect(_on_typewriter_tick)
	add_child(typewriter_timer)
	
	# Hide choices initially
	choices_container.visible = false
	next_button.pressed.connect(_on_next_pressed)
	
	hide()


func _connect_to_engine() -> void:
	engine.dialogue_started.connect(_on_dialogue_started)
	engine.node_displayed.connect(_on_node_displayed)
	engine.choices_available.connect(_on_choices_available)
	engine.dialogue_ended.connect(_on_dialogue_ended)


## Start displaying a node's text with typewriter effect
func display_node(node: DialogueNodeData) -> void:
	current_node = node
	
	# Update speaker and portrait
	speaker_label.text = node.speaker if node.speaker != "" else ""
	speaker_label.visible = node.speaker != ""
	portrait_texture.texture = node.portrait
	portrait_texture.visible = node.portrait != null
	
	# Reset text
	full_text = node.text
	displayed_text = ""
	text_label.text = ""
	
	# Clear previous choices
	_clear_choices()
	waiting_for_choice = false
	
	# Show/hide next button based on node type
	next_button.visible = (node.node_type != DialogueNodeData.NodeType.CHOICE)
	
	# Start typewriter effect or show full text immediately
	if typewriter_enabled and not full_text.is_empty():
		_start_typewriter()
	else:
		text_label.text = full_text


func _start_typewriter() -> void:
	is_typing = true
	typewriter_timer.wait_time = typewriter_speed
	typewriter_timer.start()


func _on_typewriter_tick() -> void:
	if displayed_text.length() < full_text.length():
		displayed_text += full_text[displayed_text.length()]
		text_label.text = displayed_text
	else:
		_finish_typewriter()


func _finish_typewriter() -> void:
	is_typing = false
	typewriter_timer.stop()
	text_label.text = full_text


## Skip to full text immediately
func skip_typewriter() -> void:
	if is_typing:
		displayed_text = full_text
		text_label.text = full_text
		_finish_typewriter()


## Display choice buttons
func display_choices(choices: Array) -> void:
	_clear_choices()
	
	for i in range(choices.size()):
		var choice_data = choices[i]
		var button: Button = Button.new()
		button.text = choice_data.text
		button.custom_minimum_size.x = 300
		button.pressed.connect(_make_choice.bind(i))
		choices_container.add_child(button)
	
	choices_container.visible = true
	next_button.visible = false
	waiting_for_choice = true


func _clear_choices() -> void:
	for child in choices_container.get_children():
		child.queue_free()
	choices_container.visible = false


func _make_choice(index: int) -> void:
	if engine != null and waiting_for_choice:
		engine.select_choice(index)


func _on_next_pressed() -> void:
	if engine == null:
		return
	
	# If typing, skip to end
	if is_typing:
		skip_typewriter()
		return
	
	# Otherwise advance dialogue
	if not waiting_for_choice:
		engine.next()


# =====================
# Signal Handlers
# =====================

func _on_dialogue_started(_data: DialogueData) -> void:
	show()


func _on_node_displayed(node: DialogueNodeData, _index: int, _data: DialogueData) -> void:
	display_node(node)


func _on_choices_available(choices: Array) -> void:
	display_choices(choices)


func _on_dialogue_ended(_data: DialogueData) -> void:
	hide()


# =====================
# Input Handling
# =====================

func _input(event: InputEvent) -> void:
	if not visible or engine == null or not engine.get_is_running():
		return
	
	# Click or space to advance
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_next_pressed()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_on_next_pressed()
	
	# Escape to stop dialogue
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		engine.stop()
