extends MarginContainer
class_name SkillBox

var name_label: Label
var mana_label: Label
var hitbox: Area2D

var skill: Skill
var skill_index: int = 0
var affordable: bool = true
var party_mode = false

func _ready() -> void:
	name_label = $HSplitContainer/name
	mana_label = $HSplitContainer/mana_cost
	hitbox = $skill_hitbox
	
	custom_minimum_size = Vector2(370, 70)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	$skill_hitbox/NinePatchRect.visible = false
	Global.lower_font(name_label)

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
	
	if hitbox:
		hitbox.set_collision_layer_value(1, affordable)
		hitbox.set_collision_mask_value(1, affordable)
		
	$skill_hitbox/NinePatchRect/Desc.text = skill.desc
	$skill_hitbox/NinePatchRect.size.x = $skill_hitbox/NinePatchRect/Desc.size.x
	$skill_hitbox/NinePatchRect.size.y = $skill_hitbox/NinePatchRect/Desc.size.y + 16

func set_collisions(enabled: bool):
	if hitbox:
		hitbox.set_collision_layer_value(1, enabled)
		hitbox.set_collision_mask_value(1, enabled)
			

func _on_button_pressed() -> void:
	if party_mode:
		if $skill_hitbox/NinePatchRect.visible == false:
			if affordable:
				$skill_hitbox/NinePatchRect.visible = true
				$skill_hitbox/NinePatchRect.global_position = get_global_mouse_position()
		else:
			$skill_hitbox/NinePatchRect.visible = false

func _on_button_mouse_exited() -> void:
	$skill_hitbox/NinePatchRect.visible = false
