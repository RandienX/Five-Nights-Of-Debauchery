extends Control

var party_member: Party
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

func setup(data: Party) -> void:
	party_member = data
	$Sprite2D.texture = load(data.face_path)
	$Sprite2D.region_rect = data.face_part_rect

func _process(_delta: float) -> void:
	if not party_member: return
	hp_label.text = str(party_member.hp, "/", party_member.max_stats["hp"])
	mp_label.text = str(party_member.mp, "/", party_member.max_stats["mp"])
	hp_bar.max_value = party_member.max_stats["hp"]
	mp_bar.max_value = party_member.max_stats["mp"]
	hp_bar.value = party_member.hp
	mp_bar.value = party_member.mp

func update_effects_ui() -> void:
	for child in effect_container.get_children():
		child.queue_free()
	
	if not party_member or not party_member.effects: return
	
	for effect in party_member.effects.keys():
		var data = party_member.effects[effect]
		if data is Array and data.size() >= 2 and data[1] > 0:
			var icon = create_effect_icon(effect)
			if icon:
				effect_container.add_child(icon)

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
