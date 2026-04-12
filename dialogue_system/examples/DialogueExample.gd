extends Node

## Example demonstrating how to set up and use the dialogue system.
## Attach this script to a Node in your scene.


@export var example_dialogue: DialogueData  ## Assign your DialogueData resource here
@export var debug_mode: bool = true

var dialogue_engine: DialogueEngine


func _ready() -> void:
	# Create the dialogue engine
	dialogue_engine = DialogueEngine.new()
	dialogue_engine.debug_mode = debug_mode
	add_child(dialogue_engine)
	
	# Connect to signals for UI integration
	dialogue_engine.dialogue_started.connect(_on_dialogue_started)
	dialogue_engine.node_displayed.connect(_on_node_displayed)
	dialogue_engine.choices_available.connect(_on_choices_available)
	dialogue_engine.dialogue_ended.connect(_on_dialogue_ended)
	dialogue_engine.action_executed.connect(_on_action_executed)
	dialogue_engine.execution_error.connect(_on_execution_error)
	
	# Set up game-specific callbacks (context)
	var callbacks: Dictionary = {
		# Item system callbacks
		"has_item_callback": Callable(self, "_check_has_item"),
		"give_item_callback": Callable(self, "_give_item"),
		"remove_item_callback": Callable(self, "_remove_item"),
		
		# Status effect callbacks
		"has_status_effect_callback": Callable(self, "_check_has_status_effect"),
		"add_status_effect_callback": Callable(self, "_add_status_effect"),
		"remove_status_effect_callback": Callable(self, "_remove_status_effect"),
		
		# Variable system callbacks
		"get_variable_callback": Callable(self, "_get_variable"),
		"set_variable_callback": Callable(self, "_set_variable"),
		
		# Event system callback
		"trigger_event_callback": Callable(self, "_trigger_event"),
	}
	
	# Store initial variables in context
	callbacks["variables"] = {
		"player_name": "Hero",
		"gold": 100,
		"reputation": 50,
		"quest_completed": false,
	}
	
	# Register custom conditions
	DialogueRegistry.register_condition("has_quest", Callable(self, "_check_has_quest"))
	DialogueRegistry.register_condition("is_npc_friend", Callable(self, "_check_npc_friendship"))
	
	# Register custom actions
	DialogueRegistry.register_action("play_sound", Callable(self, "_play_sound"))
	DialogueRegistry.register_action("spawn_enemy", Callable(self, "_spawn_enemy"))
	
	print("=== Dialogue System Example Ready ===")
	print("Call start_dialogue() to begin, or assign example_dialogue and call start_example_dialogue()")


## Start the example dialogue if assigned
func start_example_dialogue() -> void:
	if example_dialogue == null:
		print("Please assign a DialogueData resource to example_dialogue")
		return
	
	start_dialogue(example_dialogue)


## Start a dialogue with the given data
func start_dialogue(data: DialogueData, entry_point: String = "") -> void:
	var callbacks: Dictionary = _create_callbacks()
	var success: bool = dialogue_engine.start(data, entry_point, callbacks)
	
	if not success:
		print("Failed to start dialogue!")


## Advance dialogue (call on user input)
func advance_dialogue() -> void:
	if dialogue_engine.get_is_running() and dialogue_engine.get_is_waiting():
		dialogue_engine.next()


## Create callbacks dictionary with all game-specific functions
func _create_callbacks() -> Dictionary:
	return {
		"has_item_callback": Callable(self, "_check_has_item"),
		"give_item_callback": Callable(self, "_give_item"),
		"remove_item_callback": Callable(self, "_remove_item"),
		"has_status_effect_callback": Callable(self, "_check_has_status_effect"),
		"add_status_effect_callback": Callable(self, "_add_status_effect"),
		"remove_status_effect_callback": Callable(self, "_remove_status_effect"),
		"get_variable_callback": Callable(self, "_get_variable"),
		"set_variable_callback": Callable(self, "_set_variable"),
		"trigger_event_callback": Callable(self, "_trigger_event"),
		"variables": dialogue_engine.context.get("variables", {}),
	}


# =====================
# Signal Handlers (UI Integration Points)
# =====================

func _on_dialogue_started(data: DialogueData) -> void:
	print("=== Dialogue Started: %s ===" % data.title)


func _on_node_displayed(node: DialogueNodeData, index: int, data: DialogueData) -> void:
	print("\n[Node %d - %s]" % [index, node.speaker if node.speaker != "" else "Unknown"])
	print("%s" % node.text)
	
	# In a real game, your UI would:
	# - Display the text (possibly with typewriter effect)
	# - Show speaker name and portrait
	# - Enable "Next" button if waiting for input


func _on_choices_available(choices: Array[DialogueNodeData.DialogueChoice]) -> void:
	print("\n--- Choices Available ---")
	for i in range(choices.size()):
		var choice: DialogueNodeData.DialogueChoice = choices[i]
		print("[%d] %s" % [i, choice.text])
	print("-------------------------")
	print("Call select_choice(index) to make a selection")
	
	# In a real game, your UI would:
	# - Create buttons for each choice
	# - Disable the "Next" button
	# - Wait for player selection


func _on_dialogue_ended(data: DialogueData) -> void:
	print("\n=== Dialogue Ended: %s ===" % data.title)


func _on_action_executed(action_id: String, arguments: Array) -> void:
	print("[Action Executed] %s with args: %s" % [action_id, arguments])


func _on_execution_error(message: String) -> void:
	push_error("[Dialogue Error] %s" % message)


# =====================
# Game-Specific Callback Implementations
# =====================

## Check if player has an item
func _check_has_item(item_id: String, amount: int = 1) -> bool:
	# Replace with your actual inventory system
	print("  [Game] Checking for item: %s x%d" % [item_id, amount])
	
	# Example: pretend we always have these items
	var fake_inventory: Dictionary = {
		"sword": 1,
		"potion": 5,
		"key": 1,
	}
	
	return fake_inventory.get(item_id, 0) >= amount


## Give item to player
func _give_item(item_id: String, amount: int) -> void:
	print("  [Game] Gave player: %s x%d" % [item_id, amount])
	# Add to your inventory system


## Remove item from player
func _remove_item(item_id: String, amount: int) -> void:
	print("  [Game] Removed from player: %s x%d" % [item_id, amount])
	# Remove from your inventory system


## Check if player has a status effect
func _check_has_status_effect(effect_id: String) -> bool:
	print("  [Game] Checking for status effect: %s" % effect_id)
	# Check your status effect system
	return false  # Example: no effects active


## Add status effect to player
func _add_status_effect(effect_id: String, duration: float) -> void:
	print("  [Game] Added status effect: %s (duration: %s)" % [effect_id, duration])
	# Add to your status effect system


## Remove status effect from player
func _remove_status_effect(effect_id: String) -> void:
	print("  [Game] Removed status effect: %s" % effect_id)
	# Remove from your status effect system


## Get a game variable
func _get_variable(var_name: String) -> Variant:
	# First check engine's context variables
	var ctx_value: Variant = dialogue_engine.get_variable(var_name)
	if ctx_value != null:
		return ctx_value
	
	# Replace with your actual variable system
	print("  [Game] Getting variable: %s" % var_name)
	return null


## Set a game variable
func _set_variable(var_name: String, value: Variant) -> void:
	print("  [Game] Setting variable: %s = %s" % [var_name, value])
	dialogue_engine.set_variable(var_name, value)
	# Also update your game's variable system


## Trigger a game event
func _trigger_event(event_name: String, extra_args: Array) -> void:
	print("  [Game] Triggered event: %s with args: %s" % [event_name, extra_args])
	# Handle your game events (cutscenes, quests, etc.)


# =====================
# Custom Condition Examples
# =====================

## Custom condition: Check if player has a specific quest
func _check_has_quest(arguments: Array, context: Dictionary) -> bool:
	if arguments.is_empty():
		return false
	
	var quest_id: String = str(arguments[0])
	print("  [Custom] Checking quest: %s" % quest_id)
	
	# Replace with your quest system
	var active_quests: Array = ["quest_intro", "quest_find_item"]
	return quest_id in active_quests


## Custom condition: Check NPC friendship level
func _check_npc_friendship(arguments: Array, context: Dictionary) -> bool:
	if arguments.size() < 2:
		return false
	
	var npc_id: String = str(arguments[0])
	var min_level: int = int(arguments[1])
	
	print("  [Custom] Checking %s friendship >= %d" % [npc_id, min_level])
	
	# Replace with your reputation/friendship system
	var friendship_levels: Dictionary = {
		"merchant": 3,
		"guard": 1,
		"blacksmith": 5,
	}
	
	return friendship_levels.get(npc_id, 0) >= min_level


# =====================
# Custom Action Examples
# =====================

## Custom action: Play a sound
func _play_sound(arguments: Array, context: Dictionary) -> void:
	if arguments.is_empty():
		return
	
	var sound_name: String = str(arguments[0])
	print("  [Custom] Playing sound: %s" % sound_name)
	# Use AudioStreamPlayer to play sound


## Custom action: Spawn an enemy
func _spawn_enemy(arguments: Array, context: Dictionary) -> void:
	if arguments.is_empty():
		return
	
	var enemy_type: String = str(arguments[0])
	var count: int = 1
	if arguments.size() > 1:
		count = int(arguments[1])
	
	print("  [Custom] Spawning %d x %s" % [count, enemy_type])
	# Instantiate enemy prefab(s)


# =====================
# Input Handling (for testing)
# =====================

func _input(event: InputEvent) -> void:
	if not dialogue_engine.get_is_running():
		return
	
	# Press SPACE or click to advance
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		if dialogue_engine.get_is_waiting() and not dialogue_engine.get_current_node().node_type == DialogueNodeData.NodeType.CHOICE:
			advance_dialogue()
	
	# Press number keys to select choices
	if event is InputEventKey and event.pressed:
		if event.keycode >= KEY_0 and event.keycode <= KEY_9:
			var choice_index: int = event.keycode - KEY_0
			if dialogue_engine.get_is_waiting():
				var current_node: DialogueNodeData = dialogue_engine.get_current_node()
				if current_node and current_node.node_type == DialogueNodeData.NodeType.CHOICE:
					if choice_index < current_node.choices.size():
						dialogue_engine.select_choice(choice_index)
