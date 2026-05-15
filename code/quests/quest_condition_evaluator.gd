extends RefCounted
class_name QuestConditionEvaluator

## QuestConditionEvaluator - Centralized condition evaluation for quests
##
## Follows the same pattern as DialogueConditionEvaluator for consistency.
## All condition checking goes through this class for easy debugging.
## Connect this to your game's data systems via Callable hooks.

# Signals for custom condition evaluation
signal custom_condition_requested(condition: QuestPointCondition, result_callback: Callable)

# Game state hooks - connect these to your actual game systems
var has_item_func: Callable = Callable()        # func(item_id: String, amount: int) -> bool
var has_status_func: Callable = Callable()      # func(status_id: String) -> bool
var get_variable_func: Callable = Callable()    # func(var_name: String) -> Variant
var is_quest_complete_func: Callable = Callable()   # func(quest_id: String) -> bool
var is_quest_active_func: Callable = Callable()     # func(quest_id: String) -> bool
var has_visited_location_func: Callable = Callable() # func(location_id: String) -> bool
var has_talked_to_npc_func: Callable = Callable()    # func(npc_id: String) -> bool
var has_won_battle_func: Callable = Callable()       # func(battle_id: String) -> bool
var has_done_thing_func: Callable = Callable()       # func(thing_id: String) -> bool
var has_done_dialogue_func: Callable = Callable()    # func(dialogue_id: String) -> bool

# Global tracking data (passed in during evaluation)
var enemies_killed: Dictionary = {}
var battle_won: Dictionary = {}  # Track won battles: { battle_id: true, ... }
var custom_data: Dictionary = {}

## Evaluate a single condition
func evaluate(condition: QuestPointCondition) -> bool:
		if not condition:
				return false

		match condition.type:
				QuestPointCondition.ConditionType.HAS_ITEM:
						return _eval_has_item(condition)

				QuestPointCondition.ConditionType.HAS_STATUS:
						return _eval_has_status(condition)

				QuestPointCondition.ConditionType.DONE_THING:
						return _eval_done_thing(condition)

				QuestPointCondition.ConditionType.DONE_DIALOGUE:
						return _eval_done_dialogue(condition)

				QuestPointCondition.ConditionType.TALKED_TO_NPC:
						return _eval_talked_to_npc(condition)

				QuestPointCondition.ConditionType.KILLED_ENEMY:
						return _eval_killed_enemy(condition)

				QuestPointCondition.ConditionType.BATTLE_WON:
						return _eval_battle_won(condition)

				QuestPointCondition.ConditionType.CUSTOM:
						return _eval_custom(condition)

				_:
						push_warning("[QuestConditionEvaluator] Unknown condition type: %s" % condition.type)
						return false

## Get current progress for a condition (for progress bars)
func get_progress(condition: QuestPointCondition) -> float:
		if not condition:
				return 0.0

		match condition.type:
				QuestPointCondition.ConditionType.HAS_ITEM:
						return _get_item_progress(condition)

				QuestPointCondition.ConditionType.KILLED_ENEMY:
						return _get_kill_progress(condition)

				QuestPointCondition.ConditionType.HAS_STATUS:
						return 1.0 if _eval_has_status(condition) else 0.0

				QuestPointCondition.ConditionType.DONE_THING:
						return 1.0 if _eval_done_thing(condition) else 0.0

				QuestPointCondition.ConditionType.DONE_DIALOGUE:
						return 1.0 if _eval_done_dialogue(condition) else 0.0

				QuestPointCondition.ConditionType.TALKED_TO_NPC:
						return 1.0 if _eval_talked_to_npc(condition) else 0.0

				QuestPointCondition.ConditionType.BATTLE_WON:
						return _get_battle_progress(condition)

				QuestPointCondition.ConditionType.CUSTOM:
						return _get_custom_progress(condition)

				_:
						return condition.progress_current

## Initialize kill baseline when quest starts
func initialize_kill_baseline(condition: QuestPointCondition) -> void:
		if condition.type == QuestPointCondition.ConditionType.KILLED_ENEMY:
				condition._initial_value_count = enemies_killed.get(condition.target_key, 0)
				condition.progress_current = 0.0

## Update all condition progresses in a point
func update_point_conditions(point: QuestPoint) -> void:
		for condition in point.conditions:
				condition.progress_current = get_progress(condition)

## ==================== Internal Evaluation Methods ====================

func _eval_has_item(condition: QuestPointCondition) -> bool:
		if has_item_func.is_valid():
				return has_item_func.call(condition.target_key, int(condition.progress_target))
		# Fallback to PlayerStats
		var player_stats = PlayerStats
		if player_stats and player_stats.has_method("has_item_by_id"):
				var item_resource = _load_resource_by_id(condition.target_key)
				if item_resource:
						return player_stats.has_item_by_id(item_resource, int(condition.progress_target))
		push_warning("[QuestConditionEvaluator] has_item_func not set, cannot check for '%s'" % condition.target_key)
		return false

func _get_item_progress(condition: QuestPointCondition) -> float:
		if has_item_func.is_valid():
				# Assume it returns current amount if called with amount=0 or has a separate getter
				pass
		# Fallback - would need implementation based on your inventory system
		return condition.progress_current

func _eval_has_status(condition: QuestPointCondition) -> bool:
		if has_status_func.is_valid():
				return has_status_func.call(condition.target_key)
		push_warning("[QuestConditionEvaluator] has_status_func not set, cannot check for '%s'" % condition.target_key)
		return false

func _eval_done_thing(condition: QuestPointCondition) -> bool:
		if has_done_thing_func.is_valid():
				return has_done_thing_func.call(condition.target_key)
		# Fallback to root_script custom_data
		var root = Engine.get_main_loop().root
		if root and root.has_node("root_script"):
				var root_script = root.get_node("root_script")
				if root_script and root_script.has_method("get_done_things"):
						return root_script.get_done_things().get(condition.target_key, false)
		# Fallback to custom_data
		return custom_data.get("done_things", {}).get(condition.target_key, false)

func _eval_done_dialogue(condition: QuestPointCondition) -> bool:
		if has_done_dialogue_func.is_valid():
				return has_done_dialogue_func.call(condition.target_key)
		# Fallback to root_script
		var root = Engine.get_main_loop().root
		if root and root.has_node("root_script"):
				var root_script = root.get_node("root_script")
				if root_script and root_script.has_method("has_completed_dialogue"):
						return root_script.has_completed_dialogue(condition.target_key)
		# Fallback to custom_data
		return custom_data.get("completed_dialogues", []).has(condition.target_key)

func _eval_talked_to_npc(condition: QuestPointCondition) -> bool:
		if has_talked_to_npc_func.is_valid():
				return has_talked_to_npc_func.call(condition.target_key)
		# Fallback to root_script
		var root = Engine.get_main_loop().root
		if root and root.has_node("root_script"):
				var root_script = root.get_node("root_script")
				if root_script and root_script.has_method("has_talked_to_npc"):
						return root_script.has_talked_to_npc(condition.target_key)
		# Fallback to custom_data
		return custom_data.get("talked_npcs", []).has(condition.target_key)

func _eval_killed_enemy(condition: QuestPointCondition) -> bool:
		var current_total = enemies_killed.get(condition.target_key, 0)
		var progress: float = 0.0
		if condition.is_absolute:
				progress = float(current_total)
		else:
				var kills_since_start = current_total - condition._initial_value_count
				progress = max(0.0, kills_since_start as float)
		condition.progress_current = progress
		return progress >= condition.progress_target

func _get_kill_progress(condition: QuestPointCondition) -> float:
		var current_total = enemies_killed.get(condition.target_key, 0)
		if condition.is_absolute:
				return float(current_total)
		else:
				var kills_since_start = current_total - condition._initial_value_count
				return max(0.0, kills_since_start as float)

func _eval_battle_won(condition: QuestPointCondition) -> bool:
		if has_won_battle_func.is_valid():
				var result = has_won_battle_func.call(condition.target_key)
				# Update progress based on result
				if condition.is_absolute:
						condition.progress_current = 1.0 if result else 0.0
				else:
						# For delta mode, we need to track baseline
						var battle_state = battle_won.get(condition.target_key, false)
						var current_count = 1 if battle_state else 0
						if typeof(battle_state) == TYPE_INT or typeof(battle_state) == TYPE_FLOAT:
								current_count = battle_state
						var wins_since_start = current_count - condition._initial_value_count
						condition.progress_current = max(0.0, wins_since_start as float)
				return condition.progress_current >= condition.progress_target

		# Check global battle_won dictionary first (same pattern as enemies_killed)
		var battle_state = battle_won.get(condition.target_key, false)
		# Calculate progress: if battle_won is a boolean, convert to 0/1; if it's a count, use directly
		var current_count = 1 if battle_state else 0
		if typeof(battle_state) == TYPE_INT or typeof(battle_state) == TYPE_FLOAT:
				current_count = battle_state

		var progress: float = 0.0
		if condition.is_absolute:
				progress = float(current_count)
		else:
				var wins_since_start = current_count - condition._initial_value_count
				progress = max(0.0, wins_since_start as float)

		condition.progress_current = progress
		return progress >= condition.progress_target

func _eval_visited_location(condition: QuestPointCondition) -> bool:
		if has_visited_location_func.is_valid():
				return has_visited_location_func.call(condition.target_key)
		# Fallback to custom_data
		return custom_data.get("visited_locations", []).has(condition.target_key)

func _eval_custom(condition: QuestPointCondition) -> bool:
		if condition.custom_script.is_empty():
				push_error("[QuestConditionEvaluator] Custom condition has no script path")
				return false

		# Load and execute custom script
		var script = load(condition.custom_script)
		if not script:
				push_error("[QuestConditionEvaluator] Failed to load custom script: %s" % condition.custom_script)
				return false

		# Expect a static function: static func evaluate(condition: QuestPointCondition, evaluator: QuestConditionEvaluator) -> bool
		if script.has_static_method("evaluate"):
				return script.evaluate(condition, self)

		push_error("[QuestConditionEvaluator] Custom script missing static evaluate() function: %s" % condition.custom_script)
		return false

func _get_custom_progress(condition: QuestPointCondition) -> float:
		if condition.custom_script.is_empty():
				return condition.progress_current

		var script = load(condition.custom_script)
		if script and script.has_static_method("get_progress"):
				return script.get_progress(condition, self)

		return condition.progress_current

## Initialize battle won baseline when quest starts (for BATTLE_WON conditions)
func initialize_battle_baseline(condition: QuestPointCondition) -> void:
		if condition.type == QuestPointCondition.ConditionType.BATTLE_WON:
				var battle_state = battle_won.get(condition.target_key, false)
				var initial_count = 1 if battle_state else 0
				if typeof(battle_state) == TYPE_INT or typeof(battle_state) == TYPE_FLOAT:
						initial_count = battle_state
				condition._initial_value_count = initial_count
				condition.progress_current = 0.0

## Get current progress for BATTLE_WON conditions based on global counter delta
func _get_battle_progress(condition: QuestPointCondition) -> float:
		if condition.type != QuestPointCondition.ConditionType.BATTLE_WON:
				return condition.progress_current

		var battle_state = battle_won.get(condition.target_key, false)
		var current_count = 1 if battle_state else 0
		if typeof(battle_state) == TYPE_INT or typeof(battle_state) == TYPE_FLOAT:
				current_count = battle_state

		if condition.is_absolute:
				return float(current_count)
		else:
				var wins_since_start = current_count - condition._initial_value_count
				return max(0.0, wins_since_start as float)

## Helper to load resource by ID (adjust based on your resource loading system)
func _load_resource_by_id(resource_id: String) -> Resource:
		# Try common paths
		var paths = [
		"res://resources/items/%s.tres" % resource_id,
		"res://resources/items/%s.resource" % resource_id,
		"res://items/%s.tres" % resource_id
		]

		for path in paths:
				if ResourceLoader.exists(path):
						return load(path)

		return null
