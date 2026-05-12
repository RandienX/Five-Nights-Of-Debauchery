extends Resource
class_name QuestCondition
## Condition for a quest point - evaluates whether a specific requirement is met

enum ConditionType {
	HAS_ITEM,           ## Check if player has item (target_key = item resource path or name)
	HAS_STATUS,         ## Check if entity has status effect (target_key = effect enum value as string)
	DONE_THING,         ## Generic action completed (target_key = action identifier)
	DONE_DIALOGUE,      ## Dialogue tree/node completed (target_key = dialogue ID)
	KILLED_ENEMY,       ## Enemy type defeated (target_key = enemy resource path or name)
	TALKED_TO_NPC,      ## NPC interaction completed (target_key = NPC node name or ID)
	BATTLE_WON,         ## Battle completed (target_key = battle resource path or ID)
	CUSTOM,             ## Custom condition evaluated via signal/Callable
}

@export_group("Condition Definition")
@export var type: ConditionType = ConditionType.HAS_ITEM
@export var target_key: String = ""  ## Identifier for what to check (item name, dialogue ID, etc.)
@export var progress_current: float = 0.0  ## Current progress (updated dynamically)
@export var progress_target: float = 1.0   ## Required progress to complete

@export_group("Metadata")
@export var description: String = ""  ## Human-readable description for UI
@export var hide_in_ui: bool = false  ## If true, don't show this condition in progress UI

func get_progress_percent() -> float:
	if progress_target == 0: return 1.0
	return clamp(progress_current / progress_target, 0.0, 1.0)

func is_complete() -> bool:
	return progress_current >= progress_target

func duplicate_state() -> QuestCondition:
	var new_cond = duplicate()
	new_cond.progress_current = progress_current
	return new_cond
	
## Evaluate this condition against current game state
func evaluate() -> bool:
	match type:
		ConditionType.HAS_ITEM:
			return _evaluate_has_item()
		ConditionType.HAS_STATUS:
			return _evaluate_has_status()
		ConditionType.DONE_THING:
			return _evaluate_done_thing()
		ConditionType.DONE_DIALOGUE:
			return _evaluate_done_dialogue()
		ConditionType.KILLED_ENEMY:
			return _evaluate_killed_enemy()
		ConditionType.TALKED_TO_NPC:
			return _evaluate_talked_to_npc()
		ConditionType.BATTLE_WON:
			return _evaluate_battle_won()
		ConditionType.CUSTOM:
			return _evaluate_custom()
	return false

## Get current progress as a ratio (0.0 to 1.0+)
func get_progress_ratio() -> float:
	if progress_target <= 0:
		return 1.0 if evaluate() else 0.0
	return min(progress_current / progress_target, 1.0)

func _evaluate_has_item() -> bool:
	if not PlayerStats:
		return false
	var item = _find_item_resource(target_key)
	if item:
		var count = PlayerStats.get_item_count(item)
		progress_current = float(count)
		return count >= int(progress_target)
	return false

func _evaluate_has_status() -> bool:
	# Check if any party member has the status effect
	if not PlayerStats or PlayerStats.party.is_empty():
		return false
	
	var effect_enum_value = _get_effect_enum_value(target_key)
	if effect_enum_value == -1:
		return false
	
	for member in PlayerStats.party:
		if member is Entity and member.effects.has(effect_enum_value):
			progress_current = 1.0
			return true
	progress_current = 0.0
	return false

func _evaluate_done_thing() -> bool:
	# Check Global.scene_data or custom tracking
	if Global and Global.scene_data[load(Global.current_scene).room_name].has("done_things"):
		var done_things: Dictionary = Global.scene_data[load(Global.current_scene).room_name]["done_things"]
		if done_things.has(target_key):
			progress_current = done_things[target_key] if done_things[target_key] is float else 1.0
			return progress_current >= progress_target
	return false

func _evaluate_done_dialogue() -> bool:
	if Global and Global.scene_data[load(Global.current_scene).room_name].has("completed_dialogues"):
		var dialogues: Array = Global.scene_data[load(Global.current_scene).room_name]["completed_dialogues"]
		if target_key in dialogues:
			progress_current = 1.0
			return true
	return false

func _evaluate_killed_enemy() -> bool:
	if Global and Global.enemies_killed:
		var kills: Dictionary = Global.enemies_killed
		if kills.has(target_key):
			progress_current = float(kills[target_key])
			return progress_current >= progress_target
	return false

func _evaluate_talked_to_npc() -> bool:
	if Global and Global.scene_data[load(Global.current_scene).room_name].has("talked_to_npcs"):
		var npcs: Array = Global.scene_data[load(Global.current_scene).room_name]["talked_to_npcs"]
		if target_key in npcs:
			progress_current = 1.0
			return true
	return false

func _evaluate_battle_won() -> bool:
	if Global and Global.battles_won.has(target_key):
		var battles: int = Global.battles_won[target_key]
		progress_current = float(battles)
		return true
	return false

func _evaluate_custom() -> bool:
	# Emit signal for external evaluation
	QuestSystem.emit_signal("custom_condition_evaluated", self)
	return progress_current >= progress_target

## Helper to find item resource by key
func _find_item_resource(key: String) -> Resource:
	if not PlayerStats:
		return null
	# Try direct inventory lookup first
	for item in PlayerStats.inventory.keys():
		if item is Item:
			if item.resource_path.ends_with(key) or item.item_name == key:
				return item
	# Try loading from path
	if key.begins_with("res://"):
		return load(key)
	return null

## Helper to convert string to Global.effect enum value
func _get_effect_enum_value(key: String) -> int:
	if not Global:
		return -1
	key = key.to_lower()
	for effect_value in Global.effect.values():
		var effect_name = Global.effect.keys()[effect_value].to_lower()
		if effect_name == key or effect_name.replace("_", "") == key.replace("_", ""):
			return effect_value
	return -1

## Reset progress (for quest restarts)
func reset_progress():
	progress_current = 0.0
