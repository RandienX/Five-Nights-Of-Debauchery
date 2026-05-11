@icon("res://icon.svg")
class_name QuestEffect
extends Resource
## Effect applied when quest completes or at specific milestones

enum EffectType {
	ADD_QUEST,      ## Start another quest (params: quest_resource)
	ADD_STATUS,     ## Apply status to party (params: effect_type, level, duration)
	START_DIALOGUE, ## Trigger dialogue tree (params: dialogue_id)
	START_BATTLE,   ## Initiate battle (params: battle_resource)
	ADD_ITEM,       ## Give item to player (params: item_resource, count)
	ADD_CURRENCY,   ## Add gold/currency (params: amount, currency_type)
	SAVE_GAME,      ## Auto-save game (params: slot_index, auto_name)
	CUTSCENE,       ## Play cutscene (params: scene_path)
	CHANGE_SCENE,   ## Load new scene (params: scene_path, spawn_position)
	AWAIT,          ## Wait for input/trigger (params: trigger_id)
	CUSTOM,         ## Custom effect via signal/Callable (params: custom_data)
	REMOVE_ITEM,    ## Remove item from inventory (params: item_resource, count)
	REMOVE_STATUS,  ## Remove status from party (params: effect_type)
	TELEPORT,       ## Teleport player (params: scene_path, position_vector)
	SET_FLAG,       ## Set a game flag (params: flag_name, value)
}

@export_group("Effect Definition")
@export var type: EffectType = EffectType.ADD_ITEM
@export var params: Dictionary = {}  ## Type-specific parameters

@export_group("Metadata")
@export var description: String = ""  ## Human-readable description
@export var execute_immediately: bool = false  ## If true, execute when quest starts

## Execute this effect
func execute() -> bool:
	match type:
		EffectType.ADD_QUEST:
			return _execute_add_quest()
		EffectType.ADD_STATUS:
			return _execute_add_status()
		EffectType.START_DIALOGUE:
			return _execute_start_dialogue()
		EffectType.START_BATTLE:
			return _execute_start_battle()
		EffectType.ADD_ITEM:
			return _execute_add_item()
		EffectType.ADD_CURRENCY:
			return _execute_add_currency()
		EffectType.SAVE_GAME:
			return _execute_save_game()
		EffectType.CUTSCENE:
			return _execute_cutscene()
		EffectType.CHANGE_SCENE:
			return _execute_change_scene()
		EffectType.AWAIT:
			return _execute_await()
		EffectType.CUSTOM:
			return _execute_custom()
		EffectType.REMOVE_ITEM:
			return _execute_remove_item()
		EffectType.REMOVE_STATUS:
			return _execute_remove_status()
		EffectType.TELEPORT:
			return _execute_teleport()
		EffectType.SET_FLAG:
			return _execute_set_flag()
	return false

func _execute_add_quest() -> bool:
	if not QuestSystem:
		return false
	var quest_res = params.get("quest_resource")
	if quest_res is Quest:
		QuestSystem.add_quest(quest_res)
		return true
	elif quest_res is String:
		var loaded = load(quest_res) if quest_res.begins_with("res://") else null
		if loaded is Quest:
			QuestSystem.add_quest(loaded)
			return true
	return false

func _execute_add_status() -> bool:
	if not PlayerStats or PlayerStats.party.is_empty():
		return false
	
	var effect_type = params.get("effect_type", -1)
	var level = params.get("level", 1)
	var duration = params.get("duration", 3)
	
	if effect_type == -1 and params.has("effect_name"):
		effect_type = _get_effect_enum_value(params["effect_name"])
	
	for member in PlayerStats.party:
		if member is Entity:
			member.apply_effect(effect_type, level, duration)
	return true

func _execute_start_dialogue() -> bool:
	var dialogue_id = params.get("dialogue_id", "")
	if dialogue_id.is_empty():
		return false
	
	# Emit signal for dialogue system to handle
	if QuestSystem:
		QuestSystem.emit_signal("dialogue_requested", dialogue_id)
	return true

func _execute_start_battle() -> bool:
	var battle_res = params.get("battle_resource")
	if not battle_res:
		return false
	
	if battle_res is Battle:
		Global.load_battle(battle_res)
		return true
	elif battle_res is String and battle_res.begins_with("res://"):
		var loaded = load(battle_res)
		if loaded is Battle:
			Global.load_battle(loaded)
			return true
	return false

func _execute_add_item() -> bool:
	if not PlayerStats:
		return false
	
	var item_res = params.get("item_resource")
	var count = params.get("count", 1)
	
	if item_res is Item:
		PlayerStats.add_item(item_res, count)
		return true
	elif item_res is String:
		var loaded = load(item_res) if item_res.begins_with("res://") else null
		if loaded is Item:
			PlayerStats.add_item(loaded, count)
			return true
	return false

func _execute_add_currency() -> bool:
	if not PlayerStats:
		return false
	
	var amount = params.get("amount", 0)
	var currency_type = params.get("currency_type", "gold")
	
	if currency_type == "gold":
		PlayerStats.gold += amount
		return true
	# Extend for other currencies
	return false

func _execute_save_game() -> bool:
	if not SaveManager:
		return false
	
	var slot = params.get("slot", 0)
	var auto_name = params.get("auto_name", true)
	
	var save_name = ""
	if auto_name:
		save_name = "Quest Reward Save - " + Time.get_datetime_string_from_system(true, true)
	
	SaveManager.save_game(slot, save_name)
	return true

func _execute_cutscene() -> bool:
	var scene_path = params.get("scene_path", "")
	if scene_path.is_empty():
		return false
	
	# Emit signal for cutscene system
	if QuestSystem:
		QuestSystem.emit_signal("cutscene_requested", scene_path)
	return true

func _execute_change_scene() -> bool:
	var scene_path = params.get("scene_path", "")
	var position = params.get("spawn_position", "Vector2(0, 0)")
	
	if scene_path.is_empty():
		return false
	
	Global.current_scene = scene_path
	PlayerStats.player_position = str_to_var(position) if position is String else position
	
	if QuestSystem:
		QuestSystem.emit_signal("scene_change_requested", scene_path)
	return true

func _execute_await() -> bool:
	var trigger_id = params.get("trigger_id", "")
	if trigger_id.is_empty():
		return true  # No await needed
	
	# Emit signal and wait for external trigger
	if QuestSystem:
		QuestSystem.emit_signal("await_trigger", trigger_id)
	return true  # Returns true but actual completion is async

func _execute_custom() -> bool:
	# Emit signal for external handling
	if QuestSystem:
		QuestSystem.emit_signal("custom_effect_executed", self)
	return true

func _execute_remove_item() -> bool:
	if not PlayerStats:
		return false
	
	var item_res = params.get("item_resource")
	var count = params.get("count", 1)
	
	if item_res is Item:
		PlayerStats.remove_item(item_res, count)
		return true
	elif item_res is String:
		var loaded = load(item_res) if item_res.begins_with("res://") else null
		if loaded is Item:
			PlayerStats.remove_item(loaded, count)
			return true
	return false

func _execute_remove_status() -> bool:
	if not PlayerStats or PlayerStats.party.is_empty():
		return false
	
	var effect_type = params.get("effect_type", -1)
	if effect_type == -1 and params.has("effect_name"):
		effect_type = _get_effect_enum_value(params["effect_name"])
	
	for member in PlayerStats.party:
		if member is Entity and member.effects.has(effect_type):
			member.effects.erase(effect_type)
	return true

func _execute_teleport() -> bool:
	var scene_path = params.get("scene_path", "")
	var position = params.get("position", "Vector2(0, 0)")
	
	if scene_path.is_empty():
		return false
	
	Global.current_scene = scene_path
	PlayerStats.player_position = str_to_var(position) if position is String else position
	
	if QuestSystem:
		QuestSystem.emit_signal("scene_change_requested", scene_path)
	return true

func _execute_set_flag() -> bool:
	var flag_name = params.get("flag_name", "")
	var value = params.get("value", true)
	
	if flag_name.is_empty():
		return false
	
	# Store in Global.scene_data
	if not Global.scene_data.has("flags"):
		Global.scene_data["flags"] = {}
	Global.scene_data["flags"][flag_name] = value
	return true

func _get_effect_enum_value(key: String) -> int:
	if not Global:
		return -1
	key = key.to_lower()
	for effect_value in Global.effect.values():
		var effect_name = Global.effect.keys()[effect_value].to_lower()
		if effect_name == key or effect_name.replace("_", "") == key.replace("_", ""):
			return effect_value
	return -1

## Serialize effect for save data
func to_dict() -> Dictionary:
	return {
		"type": type,
		"params": params,
		"description": description,
		"execute_immediately": execute_immediately
	}

## Deserialize effect from save data
static func from_dict(data: Dictionary) -> QuestEffect:
	var effect = QuestEffect.new()
	effect.type = data.get("type", 0)
	effect.params = data.get("params", {})
	effect.description = data.get("description", "")
	effect.execute_immediately = data.get("execute_immediately", false)
	return effect
