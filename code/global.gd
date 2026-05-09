extends Node

#--Battle Variables--
enum effect {Heal, Mana_Heal, Blind, Poison, Bleed, Power, Tough, Focus, Defend, Kill, Absorb, Revive, Sick, Weak, Slow, Sleep, Burn, Freeze, Paralyzed, Shock, Confuse}
enum AI {Dumb, Casual, Violent, Defensive, Intelligent, Flexible}
var battle_ref: Node = null

var battle_current = null
var shop_current: ShopData = null

#--Saved Variables--
var time_played: float = 0.0
var current_scene: String = "res://scenes/maps/1ab.tscn"
var scene_data: Dictionary = {}

var loading = false

func _process(delta: float) -> void:
	time_played += delta

# === Save Data Management ===
func get_save_data() -> Dictionary:
	# Delegate to PlayerStats for comprehensive save data
	if PlayerStats:
		var stats = PlayerStats
		return stats.get_save_data()
	
	# Fallback if PlayerStats is not available
	return {"inventory": {}, "current_scene": current_scene, "player_position": PlayerStats.player_position}

func load_save_data(data: Dictionary, scenes_data: Dictionary) -> void:
	loading = true
	
	# Load PlayerStats data (inventory, party, currency, stats, position)
	if data.has("player_stats") or data.has("inventory") or data.has("party"):
		PlayerStats.load_save_data(data)
	
	# Load current scene and player position if specified
	if data.has("current_scene"):
		var vector = str_to_var("Vector2" + data["player_position"])
		PlayerStats.player_position = vector
		get_tree().change_scene_to_file(data["current_scene"])
		scene_data = scenes_data
		await get_tree().create_timer(0.03).timeout
	
	loading = false


func set_scene_data(data: Object):
	var is_room = scene_data.find_key(data.room_name)
	if is_room:
		scene_data.merge({data.room_name: {"textboxes_deactivated": data.textboxes_deactivated}}, true)
	else:
		scene_data.assign({data.room_name: {"textboxes_deactivated": data.textboxes_deactivated}})

func get_scenes_data():
	return scene_data

func reload_last_save() -> void:
	Save.load_game(SaveManager.last_slot)

# === Item Usage ===
func use_item(item: Resource, target: Object) -> bool:
	if not item or not target or not is_instance_valid(target):
		return false
	if item.type != 2: 
		return false

	if not PlayerStats.has_item(item):
		return false

	if item.consume_effects_given:
		for effect_key in item.consume_effects_given.keys():
			var effect_data = item.consume_effects_given[effect_key]
			if effect_key == BattleEffect.StatusEffect.Revive:
				if target.hp <= 0:
					target.hp = 1
				elif target.hp > 0:
					if target.role == Entity.Role.PARTY:
						target.hp = target.max_stats["hp"]
					elif target.role == Entity.Role.ENEMY:
						target.hp = target.max_stats["hp"]
			if effect_data is Array and effect_data.size() >= 2:
				var level = effect_data[0]
				var duration = effect_data[1]
				apply_effect(target, effect_key, level, duration)

	if item.heal_amount > 0 and target.hp < target.max_stats["hp"] and target.hp > 0:
		target.hp = min(target.hp + item.heal_amount, target.max_stats["hp"])
	
	if item.mana_amount > 0 and target.mp < target.max_stats["mp"]:
		target.mp = min(target.mp + item.mana_amount, target.max_stats["mp"])

	if item.heals_effects:
		for effect_key in item.heals_effects:
			if target.effects.has(effect_key):
				target.effects.erase(effect_key)

	PlayerStats.remove_item(item, 1)

	if battle_ref and battle_ref.has_method("update_effect_ui"):
		battle_ref.update_effect_ui(target)

	return true

func apply_effect(target: Object, effect: int, level: int, duration: int):
	if not target.effects.has(effect):
		target.effects[effect] = [0, 0]
	target.effects[effect][0] = max(target.effects[effect][0], level)
	target.effects[effect][1] = max(target.effects[effect][1], duration)

	if battle_ref and battle_ref.has_method("apply_effect_duration"):
		battle_ref.apply_effect_duration(target, effect, level, duration)

# === Tools ===
func lower_font(target: Label):
	target.theme.default_font_size = 48
	for i in range(48): 
		if target.theme.default_font.get_string_size(target.text, target.horizontal_alignment, -1, target.theme.default_font_size).x > target.custom_minimum_size.x:
			target.theme.default_font_size -= 1
		else:
			return

# === Mics ===
func load_battle(battle: Battle):
	battle_current = battle
	get_tree().change_scene_to_file("res://scenes/ui/battle_engine_stuff/battle_engine.tscn")
