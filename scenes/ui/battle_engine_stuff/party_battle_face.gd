extends Control

## Party Battle Face UI Component
## Displays a party member's battle stats using the partyBattleFace.tscn scene
## Supports both direct Party resource and BattleTypes.BattleActor wrapper

var party_member: Party
var battle_actor: BattleTypes.BattleActor  # Optional reference to battle actor
var effect_container: GridContainer
var hp_label: Label
var mp_label: Label
var hp_bar: ProgressBar
var mp_bar: ProgressBar
const EFFECT_ATLAS_PATH = "res://assets/battleui/status_effects.png"
const EFFECT_TILE_SIZE = 64
const EFFECT_COLS = 4

func _ready() -> void:
	hp_label = $MarginContainer/GridContainer/HPAMOUNT
	mp_label = $MarginContainer/GridContainer/MPAMOUNT
	hp_bar = $MarginContainer/GridContainer/HPAMOUNT/ProgressBar
	mp_bar = $MarginContainer/GridContainer/MPAMOUNT/ProgressBar
	
	if get_node_or_null("EffectContainer") != null:
		effect_container = GridContainer.new()
		effect_container.name = "EffectContainer"
		effect_container.columns = 4
		effect_container.add_theme_constant_override("h_separation", 4)
		effect_container.add_theme_constant_override("v_separation", 4)
		effect_container.custom_minimum_size = Vector2(128, 64)
		$MarginContainer/GridContainer.add_child(effect_container)
	else:
		effect_container = $EffectContainer

## Setup with a Party resource directly
func setup(data: Party) -> void:
	party_member = data
	$Sprite2D.texture = load(data.face_path)
	$Sprite2D.region_rect = data.face_part_rect

## Setup with a BattleTypes.BattleActor (for battle engine integration)
func setup_from_actor(actor: BattleTypes.BattleActor) -> void:
	battle_actor = actor
	if actor and actor.resource is Party:
		party_member = actor.resource as Party
		$Sprite2D.texture = load(party_member.face_path)
		$Sprite2D.region_rect = party_member.face_part_rect

func _process(_delta: float) -> void:
	if battle_actor:
		# Use battle actor data (updated during battle)
		hp_label.text = str(battle_actor.current_hp, "/", battle_actor.max_hp)
		mp_label.text = str(battle_actor.current_mp, "/", battle_actor.max_mp)
		hp_bar.max_value = battle_actor.max_hp
		mp_bar.max_value = battle_actor.max_mp
		hp_bar.value = battle_actor.current_hp
		mp_bar.value = battle_actor.current_mp
	elif party_member:
		# Use direct party resource data
		hp_label.text = str(party_member.hp, "/", party_member.max_stats["hp"])
		mp_label.text = str(party_member.mp, "/", party_member.max_stats["mp"])
		hp_bar.max_value = party_member.max_stats["hp"]
		mp_bar.max_value = party_member.max_stats["mp"]
		hp_bar.value = party_member.hp
		mp_bar.value = party_member.mp

## Updates status effects display from BattleTypes.BattleActor
func update_effects_ui() -> void:
	for child in effect_container.get_children():
		child.queue_free()
	
	# Try to get effects from battle actor first
	if battle_actor and battle_actor.status_effects:
		for effect in battle_actor.status_effects:
			if effect.duration > 0:
				var icon = create_effect_icon_from_name(effect.id)
				if icon:
					effect_container.add_child(icon)
	# Fallback to party member effects
	elif party_member and party_member.effects:
		for effect in party_member.effects.keys():
			var data = party_member.effects[effect]
			if data is Array and data.size() >= 2 and data[1] > 0:
				var icon = create_effect_icon(effect)
				if icon:
					effect_container.add_child(icon)

## Creates an effect icon from an effect ID string
func create_effect_icon_from_name(effect_id: String) -> TextureRect:
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(EFFECT_TILE_SIZE, EFFECT_TILE_SIZE)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	var atlas = AtlasTexture.new()
	atlas.atlas = load(EFFECT_ATLAS_PATH)
	
	# Map effect ID to atlas position (simple hash-based mapping)
	var hash_val = effect_id.hash() % 16  # Assuming 16 effects in atlas (4x4)
	var x = (hash_val % EFFECT_COLS) * EFFECT_TILE_SIZE
	var y = floori(hash_val / EFFECT_COLS) * EFFECT_TILE_SIZE
	atlas.region = Rect2(x, y, EFFECT_TILE_SIZE, EFFECT_TILE_SIZE)
	icon.texture = atlas
	return icon

func create_effect_icon(effect: int) -> TextureRect:
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(EFFECT_TILE_SIZE, EFFECT_TILE_SIZE)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	var atlas = AtlasTexture.new()
	atlas.atlas = load(EFFECT_ATLAS_PATH)
	var x = (effect % EFFECT_COLS) * EFFECT_TILE_SIZE
	var y = floori(effect / EFFECT_COLS) * EFFECT_TILE_SIZE
	atlas.region = Rect2(x, y, EFFECT_TILE_SIZE, EFFECT_TILE_SIZE)
	icon.texture = atlas
	return icon