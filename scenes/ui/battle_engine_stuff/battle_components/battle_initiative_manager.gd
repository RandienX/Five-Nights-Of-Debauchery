extends RefCounted
class_name BattleInitiativeManager

# Manages turn order and initiative for battle
var initiative: Array[Object]
var initiative_who: int = -1
var party: Array

func _init(party_members: Array) -> void:
	party = party_members

func setup_initiative(battle: Resource) -> Array[Object]:
	var speed: Dictionary[int, Object] = {}
	
	# Add enemies to initiative
	for e in range(5):
		if battle.get('enemy_pos'+str(e+1)):
			var enemy = battle.get('enemy_pos'+str(e+1))
			var ai = enemy.ai
			var speed_mult = get_effect_multiplier(enemy, Global.effect.Speed)
			var slow_mult = get_effect_multiplier(enemy, Global.effect.Slow)
			var total_mult = speed_mult * slow_mult
			var rng = randi_range(ceili(ai * 0.75 * total_mult), floori(ai * 1.25 * total_mult))
			while rng in speed: 
				rng += 1
			speed[rng] = enemy
	
	# Add party members to initiative
	for p in party:
		var ai = p.max_stats["ai"]
		var speed_mult = get_effect_multiplier(p, Global.effect.Speed)
		var slow_mult = get_effect_multiplier(p, Global.effect.Slow)
		var total_mult = speed_mult * slow_mult
		var rng = randi_range(ceili(ai * 0.75 * total_mult), floori(ai * 1.25 * total_mult))
		while rng in speed: 
			rng += 1
		speed[rng] = p
	
	# Sort by speed (highest first)
	var keys = speed.keys()
	keys.sort()
	var rev: Array[Object] = []
	for k in range(keys.size()-1, -1, -1):
		rev.append(speed[keys[k]])
	
	initiative = rev
	return initiative

func get_party_members_from_initiative() -> Array[Object]:
	var party_members: Array[Object] = []
	for actor in initiative:
		if actor is Party:
			party_members.append(actor)
	return party_members

func advance_initiative_step() -> int:
	initiative_who += 1
	if initiative_who >= initiative.size():
		initiative_who = -1
	return initiative_who

func get_current_actor() -> Object:
	if initiative_who >= 0 and initiative_who < initiative.size():
		return initiative[initiative_who]
	return null

func remove_from_initiative(obj: Object) -> void:
	for i in range(initiative.size()-1, -1, -1):
		if initiative[i] == obj:
			initiative.remove_at(i)
			break

func get_effect_multiplier(target: Object, effect: Global.effect) -> float:
	if not target or not target.has_key("effects"):
		return 1.0
	
	if effect in target.effects:
		var level = target.effects[effect]
		match effect:
			Global.effect.Speed:
				return 1.0 + (level * 0.25)
			Global.effect.Slow:
				return 1.0 / (1.0 + (level * 0.25))
	return 1.0
