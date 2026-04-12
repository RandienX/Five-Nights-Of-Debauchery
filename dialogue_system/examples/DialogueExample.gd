## Example: How to use the dialogue system in your game
## 95% of cases: Just connect signals and override Registry hooks
## 5% of cases: Register custom conditions/actions

extends Node

@export var dialogue_data: DialogueData
@export var textbox_ui: Control  # Your UI node with a Label

var engine: DialogueEngine

func _ready() -> void:
	# === STEP 1: Setup engine ===
	engine = DialogueEngine.new()
	add_child(engine)
	
	# Connect to UI (only code you need!)
	engine.text_displayed.connect(_on_text_displayed)
	engine.dialogue_ended.connect(_on_dialogue_ended)
	
	# === STEP 2: Override Registry hooks for YOUR game ===
	DialogueRegistry.on_has_item = func(item_id: String, amount: int) -> bool:
		# Replace with your inventory system
		print("Checking if player has %d x %s" % [amount, item_id])
		return true  # TODO: return PlayerInventory.has(item_id, amount)
	
	DialogueRegistry.on_check_variable = func(var_name: String, op: String, value) -> bool:
		# Replace with your variable system
		var current = GameVariables.get(var_name, 0)
		match op:
			">": return current > value
			"<": return current < value
			">=": return current >= value
			"<=": return current <= value
			"==": return current == value
			"!=": return current != value
		return false
	
	DialogueRegistry.on_get_party_level = func(member: String) -> int:
		# Replace with your party system
		return Party.get_member_level(member)
	
	DialogueRegistry.on_set_variable = func(var_name: String, value) -> void:
		GameVariables.set(var_name, value)
	
	DialogueRegistry.on_give_item = func(item_id: String, amount: int) -> void:
		PlayerInventory.add(item_id, amount)
	
	# === STEP 3: Start dialogue (e.g., on NPC interaction) ===
	# Uncomment to test:
	# start_conversation()

func start_conversation() -> void:
	if dialogue_data:
		engine.start(dialogue_data)

func _on_text_displayed(text: String, speaker: String) -> void:
	# Update your textbox UI here
	if textbox_ui:
		var label = textbox_ui.get_node_or_null("Label")
		if label:
			label.text = text
		
		var speaker_label = textbox_ui.get_node_or_null("SpeakerLabel")
		if speaker_label and not speaker.is_empty():
			speaker_label.text = speaker

func _on_dialogue_ended() -> void:
	# Hide textbox or cleanup
	if textbox_ui:
		textbox_ui.visible = false

# === Input handling (call next() on click/key) ===
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if engine and engine._data != null:
			engine.next()
	elif event.is_action_pressed("ui_accept"):
		if engine and engine._data != null:
			engine.next()

# === OPTIONAL: Register custom condition/action (5% edge cases) ===
func _setup_custom_logic() -> void:
	# Custom condition example
	DialogueRegistry.register_condition("quest_completed", func(args: Array) -> bool:
		if args.size() < 1: return false
		return QuestSystem.is_completed(args[0])
	)
	
	# Custom action example
	DialogueRegistry.register_action("spawn_enemy", func(args: Array) -> void:
		if args.size() < 1: return
		EnemySpawner.spawn(args[0], args[1] if args.size() > 1 else Vector3.ZERO)
	)
