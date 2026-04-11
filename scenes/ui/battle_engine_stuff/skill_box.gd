extends MarginContainer
class_name SkillBox

signal skill_selected(skill: Skill, index: int)

var name_label: Label
var mana_label: Label
var can_select

var skill: Skill
var skill_index: int = 0
var affordable: bool = true
var party_mode = false

func _ready() -> void:
	name_label = $HSplitContainer/name
	mana_label = $HSplitContainer/mana_cost
	
	custom_minimum_size = Vector2(370, 70)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	$NinePatchRect.visible = false
	
	if party_mode:
		$Button.disabled = true

func setup(skill_: Skill, index: int, is_affordable: bool):
	skill = skill_
	skill_index = index
	affordable = is_affordable
	
	if name_label and skill:
		name_label.text = skill.name
	
	if mana_label and skill:
		if affordable:
			mana_label.text = str(skill.mana_cost) + " MP"
			modulate = Color(1, 1, 1)
		else:
			mana_label.text = str(skill.mana_cost) + " MP"
			modulate = Color(0.5, 0.5, 0.5)
	Global.lower_font(name_label)

func _on_button_pressed() -> void:
	if party_mode:
		if $NinePatchRect.visible == false:
			if affordable:
				$NinePatchRect.visible = true
				$NinePatchRect.global_position = get_global_mouse_position() - Vector2(10, 10)
		else:
			$NinePatchRect.visible = false

func _on_nine_patch_rect_focus_exited() -> void:
	$NinePatchRect.visible = false

func _on_fight_button_pressed() -> void:
	if can_select:
		skill_selected.emit(skill, skill_index)
