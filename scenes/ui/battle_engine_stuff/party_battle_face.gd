extends Control

## Party Battle Face UI Component
## Displays a party member's battle stats using the partyBattleFace.tscn scene
## Supports both direct Entity resource and BattleTypes.BattleActor wrapper

var party_member: Entity
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

## Setup with an Entity resource directly
func setup(data: Entity) -> void:
	party_member = data
	$Sprite2D.texture = party_member.portrait
	$Sprite2D.region_rect = party_member.portrait_rect

func _process(_delta: float) -> void:
	if party_member:
		# Use direct party resource data
		hp_label.text = str(party_member.hp, "/", party_member.get_max_stat(&"hp"))
		mp_label.text = str(party_member.mp, "/", party_member.get_max_stat(&"mp"))
		hp_bar.max_value = party_member.get_max_stat(&"hp")
		mp_bar.max_value = party_member.get_max_stat(&"mp")
		hp_bar.value = party_member.hp
		mp_bar.value = party_member.mp                
		if party_member.portrait:
			$Sprite2D.texture = party_member.portrait
			$Sprite2D.region_rect = party_member.portrait_rect

## Updates status effects display from BattleTypes.BattleActor
func update_effects_ui() -> void:
	print("party_battle_face.gd: update_effects_ui: START - party_member=%s" % (party_member.name if party_member else "null"))
	for child in effect_container.get_children():
		child.queue_free()
	
	if party_member:
		# Use new status system API
		var active_status_ids = party_member.get_active_status_ids()
		print("party_battle_face.gd: update_effects_ui: active_status_count=%d, statuses=%s" % [active_status_ids.size(), active_status_ids])
		for status_id in party_member.get_active_status_ids():
			var stacks = party_member.get_status_stacks(status_id)
			var duration = party_member.get_status_duration(status_id)
			var status_data = party_member._statuses.get(status_id)
			
			print("party_battle_face.gd: update_effects_ui: processing status=%s, stacks=%d, duration=%d" % [status_id, stacks, duration])

			if status_data and status_data.has("definition"):
				var status_def = status_data["definition"] as StatusDefinition

				# Create icon using status definition's icon if available
				var icon: TextureRect
				if status_def.icon != null:
					print("party_battle_face.gd: update_effects_ui: creating icon for status=%s" % status_id)
					icon = create_effect_icon_from_texture(status_def.icon)

				if icon:
					# Add stack count label if stacked
					if stacks > 1:
						var stack_label = Label.new()
						stack_label.text = "x" + str(stacks)
						stack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
						stack_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
						stack_label.add_theme_color_override("font_shadow_color", Color.BLACK)
						stack_label.add_theme_constant_override("shadow_offset_x", 1)
						stack_label.add_theme_constant_override("shadow_offset_y", 1)
						stack_label.add_theme_font_size_override("font_size", 8)
						icon.add_child(stack_label)
						stack_label.set_anchors_preset(Control.PRESET_FULL_RECT)

						# Add duration tooltip
						icon.tooltip_text = "%s\nDuration: %d turn(s)" % [status_def.name if not status_def.name.is_empty() else status_id, duration]

						effect_container.add_child(icon)
						print("party_battle_face.gd: update_effects_ui: added icon for status=%s with stacks=%d" % [status_id, stacks])
	
	print("party_battle_face.gd: update_effects_ui: END")

## Creates an effect icon from a Texture2D resource
func create_effect_icon_from_texture(tex: Texture2D) -> TextureRect:
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(EFFECT_TILE_SIZE, EFFECT_TILE_SIZE)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = tex
	return icon
