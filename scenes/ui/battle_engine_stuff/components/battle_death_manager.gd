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

func setup_game_over_ui() -> void:
	game_over_overlay = ColorRect.new()
	game_over_overlay.name = "GameOverOverlay"
	game_over_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_over_overlay.color = Color(0, 0, 0, 0)
	game_over_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(game_over_overlay)

	game_over_texture = TextureRect.new()
	game_over_texture.name = "GameOverTexture"
	game_over_texture.set_anchors_preset(Control.PRESET_CENTER)
	game_over_texture.texture = load("res://assets/ui/game_over.png") if ResourceLoader.exists("res://assets/ui/game_over.png") else null
	game_over_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	game_over_texture.modulate.a = 0
	game_over_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(game_over_texture)
	
func check_enemy_death_and_xp():
	if not root.are_all_enemies_defeated():
		return
	
	var total_xp = 0
	for e in root.enemy_instances:
		if e:
			total_xp += e.xp_reward
	for actor in root.initiative:
		if actor is Party:
			actor.xp += total_xp
			$Control/enemy_ui/CenterContainer/output.text = actor.name + " gained " + str(total_xp) + " XP! "
			while actor.xp >= actor.xp_to_level_up:
				actor.xp -= actor.xp_to_level_up
				actor.level += 1
				actor.xp_to_level_up = ceil(actor.xp_to_level_up * actor.level_up_xp_multilpier)
				for stat in ["hp", "mp", "atk", "def", "ai"]:
					actor.max_stats[stat] += int(actor.level_up[stat] * actor.level)
					actor.base_stats[stat] += int(actor.level_up[stat] * actor.level)
				actor.hp = actor.max_stats["hp"]
				actor.mp = actor.max_stats["mp"]
				$Control/enemy_ui/CenterContainer/output.text = actor.name + " leveled up to " + str(actor.level) + "! "
				await get_tree().create_timer(1.0).timeout
	await end_battle_victory()

func end_battle_victory() -> void:
	await get_tree().create_timer(1.0).timeout
	Global.player_position = root.battle_start_position
	Global.loading = true
	get_tree().change_scene_to_file(Global.current_scene)
	Global.loading = false

func animate_enemy_death(e: Enemy) -> void:
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
	for i in range(1, root.enemy_instances.size()):
		var next = (slot + i) % root.enemy_instances.size()
		if root.enemy_instances[next] and root.enemy_instances[next].hp > 0:
			root.selected_enemy = next
			return
	root.selected_enemy = -1

func death(obj):
	for i in range(root.initiative.size()-1, -1, -1):
		if root.initiative[i] == obj:
			root.initiative.remove_at(i)
			if root.attack_array.has(obj): root.attack_array.erase(obj)
			if obj is Party and root.planning_phase and root.action_history.has(obj):
				root.action_history.erase(obj)
				root.current_party_plan_index -= 1

func check_party_wipe() -> void:
	var alive = false
	for p in Global.party:
		if p.hp > 0:
			alive = true
			break
	if not alive:
		trigger_game_over()

func trigger_game_over() -> void:
	game_over_active = true
	root.state = root.states.Waiting
	$Control/gui/HBoxContainer2.visible = false
	$Control/enemy_ui.visible = false
	$WhoMoves.visible = false
	
	var tween = create_tween()
	tween.tween_property(game_over_overlay, "modulate:a", 1.0, 2.0)
	await tween.finished
	
	if game_over_texture.texture:
		tween = create_tween()
		tween.tween_property(game_over_texture, "modulate:a", 1.0, 1.0)
		await tween.finished
	
	await get_tree().create_timer(1.0).timeout
	can_reload = true
