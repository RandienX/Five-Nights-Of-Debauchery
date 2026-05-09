extends Node
class_name DeathManager

var root
var battle

func setup(broot, rbattle):
	root = broot
	battle = rbattle

# === DEATH & VICTORY LOGIC ===

var is_animating_death: bool = false

var game_over_active: bool = false
var game_over_overlay: ColorRect
var game_over_texture: TextureRect
var can_reload = false
	
func check_enemy_death_and_xp():
	if root:
		if not root.are_all_enemies_defeated():
			return
	else:
		return
	
	var total_xp = 0        
	var total_currency = 0

	# Calculate XP and currency rewards from all enemy slots (using override values if set)
	for slot in root.battle.enemies:
		if slot and slot.enemy:
			total_xp += slot.get_xp_reward()
			total_currency += slot.get_currency_reward()

	if battle:
		total_currency += battle.currency_reward
	print("Total Currency From Battle", total_currency)
	PlayerStats.add_currency(total_currency, PlayerStats.CurrencyType.GOLD)

	for actor in root.initiative:
		if actor.role == Entity.Role.PARTY:
			actor.xp += total_xp
			root.get_node("Control/enemy_ui/CenterContainer/output").text = actor.name + " gained " + str(total_xp) + " XP! "
			while actor.xp >= actor.xp_to_level_up:
				actor.xp -= actor.xp_to_level_up
				actor.level += 1
				actor.xp_to_level_up = ceil(actor.xp_to_level_up * actor.level_up_xp_multiplier)
				for stat in ["hp", "mp", "atk", "def", "speed"]:
					actor.max_stats[stat] += int(actor.level_up_gains[stat] if actor.level_up_gains.has(stat) else 1)
					actor.base_stats[stat] += int(actor.level_up_gains[stat] if actor.level_up_gains.has(stat) else 1)
				actor.hp = actor.max_stats["hp"]
				actor.mp = actor.max_stats["mp"]
				root.get_node("Control/enemy_ui/CenterContainer/output").text = actor.name + " leveled up to " + str(actor.level) + "! "
				await get_tree().create_timer(1.0).timeout
				
	
	# Add currency reward to player
	if total_currency > 0:
		PlayerStats.add_currency(total_currency, PlayerStats.CurrencyType.GOLD)
		root.get_node("Control/enemy_ui/CenterContainer/output").text += "Gained " + str(total_currency) + " gold!"
		
	await end_battle_victory()

func end_battle_victory() -> void:
	await root.get_tree().create_timer(1.0).timeout
	Global.loading = true
	root.get_tree().change_scene_to_file(Global.current_scene)
	Global.loading = false

func animate_enemy_death(e: Entity) -> void:
	if is_animating_death: return
	is_animating_death = true
	var slot = root.get_enemy_index(e)
	if slot < 0:
		is_animating_death = false
		return
	var node = get_node_or_null("Control/enemy_ui/enemies/enemy" + str(slot + 1))
	if not node:
		is_animating_death = false
		return
	var orig = node.position
	var mat = node.material
	for i in range(20):
		if mat: mat.set("shader_parameter/flash_intensity", float(i)/20.0)
		await get_tree().create_timer(0.05).timeout
	var jitter = 3.0
	for i in range(30):
		node.position.y = orig.y + i*2
		node.position.x = orig.x + randf_range(-jitter, jitter)
		jitter *= 0.95
		await get_tree().create_timer(0.03).timeout
	for i in range(20):
		if mat: mat.set("shader_parameter/opacity", 1.0 - float(i)/20.0)
		await get_tree().create_timer(0.05).timeout
	node.visible = false
	node.position = orig
	if mat:
		mat.set("shader_parameter/flash_intensity", 0.0)
		mat.set("shader_parameter/opacity", 1.0)
	move_flash_to_next_enemy(slot)
	is_animating_death = false

func move_flash_to_next_enemy(slot: int):
	for i in range(1, 5):
		var next_slot = wrapi(slot + i, 0, 5)
		var enemy_at_slot = root.get_enemy(next_slot)
		if enemy_at_slot and enemy_at_slot.hp > 0:
			root.selected_enemy = next_slot
			return
	root.selected_enemy = -1

func death(obj: Entity):
	for i in range(root.initiative.size()-1, -1, -1):
		if root.initiative[i] == obj:
			root.initiative.remove_at(i)
			if root.attack_executor.attack_array.has(obj): root.attack_executor.attack_array.erase(obj)
			if obj.role == Entity.Role.PARTY and root.planning_phase and root.action_history.has(obj):

				root.action_history.erase(obj)
				root.current_party_plan_index -= 1
	if obj.role == Entity.Role.PARTY:
		check_party_wipe()

func check_party_wipe() -> void:
	var alive = false
	for p in root.party:
		if p.hp > 0:
			print("!!!")
			alive = true
			break
	if not alive:
		trigger_game_over()

func trigger_game_over() -> void:
	game_over_active = true
	root.state = root.states.Waiting
	root.get_node("WhoMoves").visible = false
	
	var gitgud = preload("res://scenes/ui/game_over.tscn").instantiate()
	gitgud.z_index = 999
	root.add_child(gitgud)
	root.get_node("AudioStreamPlayer").autoplay = false
	root.get_node("AudioStreamPlayer").playing = false
	gitgud.get_node("AnimationPlayer").play("gitgud")
	
	await root.get_tree().create_timer(1.5).timeout
	can_reload = true
