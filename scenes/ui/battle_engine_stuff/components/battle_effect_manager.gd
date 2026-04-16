extends RefCounted
class_name EffectManager

var root
# === EFFECT SYSTEM ===

const EFFECT_ATLAS_PATH = "res://assets/battleui/status_effects.png"
const EFFECT_TILE_SIZE = 64
const EFFECT_COLS = 4

var effect_durations: Dictionary = {}  # {target: {effect: [level, duration]}}

func setup(battleroot):
root = battleroot

func get_effect_level(target: Object, effect: BattleEffect.StatusEffect) -> int:
if target.effects.has(effect) and target.effects[effect].size() >= 1:
return target.effects[effect][0]
return 0

func get_effect_duration(target: Object, effect: BattleEffect.StatusEffect) -> int:
if target.effects.has(effect) and target.effects[effect].size() >= 2:
return target.effects[effect][1]
return 0

func get_effect_multiplier(target: Object, effect: BattleEffect.StatusEffect) -> float:
var level = get_effect_level(target, effect)
if level <= 0: return 1.0

match effect:
BattleEffect.StatusEffect.Power:
return 1.0 + (level * 0.25)
BattleEffect.StatusEffect.Tough:
return 1.0 + (level * 0.25)
BattleEffect.StatusEffect.Focus:
return 1.0 + (level * 0.05)
BattleEffect.StatusEffect.Speed:
return 1.0 + (level * 0.1)
BattleEffect.StatusEffect.Slow:
return 1.0 - (level * 0.1)
BattleEffect.StatusEffect.Blind:
return 1.0 - (level * 0.2)
BattleEffect.StatusEffect.Absorb:
return 1.0 + (level * 0.2)
BattleEffect.StatusEffect.Weak:
return 1.0 - (level * 0.2)
BattleEffect.StatusEffect.Sick:
return 1.0 - (level * 0.2)
return 1.0

func remove_effect(target: Object, effect: BattleEffect.StatusEffect):
if target.effects.has(effect):
target.effects.erase(effect)
if effect_durations.has(target) and effect_durations[target].has(effect):
effect_durations[target].erase(effect)

var party_container = root.get_node("Control/gui/HBoxContainer2/party")
if target is Party:
for i in range(party_container.get_child_count()):
var ui = party_container.get_child(i)
if ui.has_method("update_effects_ui"):
ui.update_effects_ui()
else:
var slot = 0
for i in range(5):
if root.battle.get('enemy_pos'+str(i+1)) == target:
slot = i + 1
break
if slot > 0:
var node = root.get_node_or_null("Control/enemy_ui/enemies/enemy" + str(slot))
if node:
var container = node.get_node_or_null("EffectContainer")
if container:
for child in container.get_children():
child.queue_free()

func apply_effects(target: Object, atk: Skill):
if atk.effects:
for effect in atk.effects.keys():
var level = atk.effects[effect][0]
var duration = atk.effects[effect][1]
apply_effect(target, effect, level, duration)

func apply_effect(target: Object, effect: BattleEffect.StatusEffect, level: int, duration: int):
if not target.effects.has(effect):
target.effects[effect] = [0, 0]

target.effects[effect][0] = max(target.effects[effect][0], level)
target.effects[effect][1] = max(target.effects[effect][1], duration)

if not effect_durations.has(target):
effect_durations[target] = {}
if not effect_durations[target].has(effect):
effect_durations[target][effect] = [level, duration]
else:
effect_durations[target][effect][0] = max(effect_durations[target][effect][0], level)
effect_durations[target][effect][1] = max(effect_durations[target][effect][1], duration)

func apply_effect_duration(target: Object, effect: BattleEffect.StatusEffect, level: int, duration: int):
if not target.effects.has(effect):
target.effects[effect] = [0, 0]
target.effects[effect][0] = max(target.effects[effect][0], level)
target.effects[effect][1] = max(target.effects[effect][1], duration)

if not effect_durations.has(target):
effect_durations[target] = {}
if not effect_durations[target].has(effect):
effect_durations[target][effect] = [level, duration]
else:
effect_durations[target][effect][0] = max(effect_durations[target][effect][0], level)
effect_durations[target][effect][1] = max(effect_durations[target][effect][1], duration)

# Check for absorption effect
if effect == BattleEffect.StatusEffect.Absorb:
apply_absorption_bonus(target, level)

update_effect_ui(target)

func apply_absorption_bonus(target: Object, level: int):
var bonus = floor(target.max_stats["hp"] * 0.1 * level)
target.max_stats["hp"] += bonus
target.hp = min(target.hp + bonus, target.max_stats["hp"])

func remove_absorption_bonus(target: Object, level: int):
var bonus = floor(target.max_stats["hp"] * 0.1 * level)
target.max_stats["hp"] -= bonus
target.hp = min(target.hp, target.max_stats["hp"])

func update_effects():
var targets_to_clean = []
for target in effect_durations.keys():
if not is_instance_valid(target):
targets_to_clean.append(target)
continue

var effects_to_remove = []
for effect in effect_durations[target].keys():
var data = effect_durations[target][effect]
var level = data[0]

match effect:
BattleEffect.StatusEffect.Heal:
if target.hp > 0:
target.hp = min(target.hp + floor(target.max_stats["hp"] * 0.05 * level), target.max_stats["hp"])
BattleEffect.StatusEffect.Mana_Heal:
if target.mp > 0:
target.mp = min(target.mp + floor(target.max_stats["mp"] * 0.05 * level), target.max_stats["mp"])
BattleEffect.StatusEffect.Revive:
if target.hp <= 0:
target.hp = floor(target.max_stats["hp"] * 0.5)
effects_to_remove.append(effect)
continue
BattleEffect.StatusEffect.Poison:
var dmg = floor(target.max_stats["hp"] * 0.1 * level)
target.hp -= dmg
BattleEffect.StatusEffect.Bleed:
var dmg = floor(target.max_stats["hp"] * 0.15 * level)
target.hp -= dmg

data[1] -= 1
if data[1] <= 0:
effects_to_remove.append(effect)
if effect == BattleEffect.StatusEffect.Absorb:
remove_absorption_bonus(target, level)

for effect in effects_to_remove:
effect_durations[target].erase(effect)
if target.effects.has(effect):
target.effects.erase(effect)

if effect_durations[target].is_empty():
targets_to_clean.append(target)

for target in targets_to_clean:
if effect_durations.has(target):
effect_durations.erase(target)

for actor in root.initiative:
if is_instance_valid(actor):
update_effect_ui(actor)

func update_effect_ui(actor: Object) -> void:
var container: GridContainer = null
if actor is Party:
var party_container = root.get_node("Control/gui/HBoxContainer2/party")
for i in range(party_container.get_child_count()):
var ui = party_container.get_child(i)
if ui.has_method("setup") and ui.party_member == actor:
container = ui.effect_container
break
else:
var slot = 0
for i in range(5):
if root.battle.get('enemy_pos'+str(i+1)) == actor:
slot = i + 1
break
if slot > 0:
var node = root.get_node_or_null("Control/enemy_ui/enemies/enemy" + str(slot))
if node:
container = node.get_node_or_null("EffectContainer")

if container:
for child in container.get_children():
child.queue_free()

if actor.effects:
for effect in actor.effects.keys():
var data = actor.effects[effect]
if data is Array and data.size() >= 2 and data[1] > 0:
var icon = create_effect_icon(effect)
if icon:
container.add_child(icon)

func create_effect_icon(effect: BattleEffect.StatusEffect) -> TextureRect:
var icon = TextureRect.new()
icon.custom_minimum_size = Vector2(EFFECT_TILE_SIZE, EFFECT_TILE_SIZE)
icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

var atlas = AtlasTexture.new()
atlas.atlas = load(EFFECT_ATLAS_PATH)
var x = (effect as int % EFFECT_COLS) * EFFECT_TILE_SIZE
var y = floori((effect as int) / EFFECT_COLS) * EFFECT_TILE_SIZE
atlas.region = Rect2(x, y, EFFECT_TILE_SIZE, EFFECT_TILE_SIZE)
icon.texture = atlas
return icon

func apply_damage_over_time():
for actor in root.initiative:
if not is_instance_valid(actor): continue

# Poison damage
var poison_level = get_effect_level(actor, BattleEffect.StatusEffect.Poison)
if poison_level > 0:
var poison_dmg = floor(actor.max_stats["hp"] * 0.1 * poison_level)
actor.hp -= poison_dmg
root.get_node("Control/enemy_ui/CenterContainer/output").text = actor.name + " takes " + str(poison_dmg) + " poison damage!"
await root.get_tree().create_timer(0.5).timeout

# Bleed damage (stronger, not healable by items)
var bleed_level = get_effect_level(actor, BattleEffect.StatusEffect.Bleed)
if bleed_level > 0:
var bleed_dmg = floor(actor.max_stats["hp"] * 0.15 * bleed_level)
actor.hp -= bleed_dmg
root.get_node("Control/enemy_ui/CenterContainer/output").text = actor.name + " takes " + str(bleed_dmg) + " bleed damage!"
await root.get_tree().create_timer(0.5).timeout

func check_instakill(attacker: Object, target: Object) -> bool:
var kill_level = get_effect_level(attacker, BattleEffect.StatusEffect.Kill)
if kill_level > 0:
if target is Enemy and target.is_boss:
return false
var kill_chance = 0.01 * kill_level  # 1% per level
if randf() < kill_chance:
return true
return false

func get_effect_name_with_level(effect: BattleEffect.StatusEffect, level: int) -> String:
return BattleEffect.new().get_status_effect_name(effect, level)
