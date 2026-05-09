extends Control

signal party_member_selected(member: Resource)

@export var members_container: VBoxContainer
@export var member_detail_panel: Panel
@export var member_name_label: Label
@export var member_level_label: Label
@export var member_description_label: Label
@export var member_portrait: TextureRect
@export var hp_progress: ProgressBar
@export var mp_progress: ProgressBar
@export var hp_label: Label
@export var mp_label: Label
@export var stats_grid: GridContainer
@export var equipment_container: VBoxContainer
@export var equipment_slots: GridContainer
@export var skills_list: VBoxContainer
@export var no_member_label: Label

@onready var equip_select: Control = $EquipmentSelection

var party_members: Array[Object] = []
var selected_member_index: int = -1
var member_buttons: Array[Button] = []
var equipment_slot_buttons: Array[Button] = []

const EQUIPMENT_SLOTS = ["head", "body", "legs", "weapon_left", "weapon_right", "shield", "accessory_1", "accessory_2"]
const SLOT_DISPLAY_NAMES = {
	"head": "Head",
	"body": "Body",
	"legs": "Legs",
	"weapon_left": "Weapon (L)",
	"weapon_right": "Weapon (R)",
	"shield": "Shield",
	"accessory_1": "Accessory 1",
	"accessory_2": "Accessory 2"
}

func _ready() -> void:
	_refresh_party_display()
	_update_detail_panel()
	if not party_members.is_empty():
		_select_member(0)

func _refresh_party_display() -> void:
	for btn in member_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	member_buttons.clear()
	
	party_members = PlayerStats.party
	if party_members.is_empty():
		return
	
	for i in range(party_members.size()):
		var member: Resource = party_members[i]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(192, 60)
		btn.text = member.get("name") if member.has_meta("name") or "name" in member else "Member " + str(i + 1)
		btn.name = "MemberBtn" + str(i)
		
		if member.portrait:
			var portrait = member.get("portrait")
			if portrait:
				btn.flat = true
				btn.icon = AtlasTexture.new()
				btn.icon.atlas = portrait
				btn.icon.region = member.portrait_rect
		
		btn.pressed.connect(_on_member_button_pressed.bind(i))
		if $"../../../..".pending_item != null:
			party_member_selected.connect(_on_member_button_pressed.bind(party_members[selected_member_index]))
		members_container.add_child(btn)
		member_buttons.append(btn)
		
		var npr = NinePatchRect.new()
		npr.custom_minimum_size = Vector2(btn.size.x, btn.size.y)
		npr.texture = load("res://assets/ui/button.png")
		npr.patch_margin_left = 5
		npr.patch_margin_right = 5
		npr.patch_margin_top = 5
		npr.patch_margin_bottom = 5
		npr.z_index = -1
		btn.add_child(npr)

func _on_member_button_pressed(index: int) -> void:
	_select_member(index)

func _select_member(index: int) -> void:
	if index < 0 or index >= party_members.size():
		return
	
	selected_member_index = index
	var member: Resource = party_members[index]
	
	for i in range(member_buttons.size()):
		if is_instance_valid(member_buttons[i]):
			member_buttons[i].button_pressed = (i == index)
	
	_update_detail_panel()
	party_member_selected.emit(member)

func _update_detail_panel() -> void:
	if selected_member_index < 0 or selected_member_index >= party_members.size():
		no_member_label.visible = true
		member_name_label.visible = false
		member_level_label.visible = false
		member_description_label.visible = false
		member_portrait.visible = false
		hp_progress.visible = false
		mp_progress.visible = false
		hp_label.visible = false
		mp_label.visible = false
		stats_grid.visible = false
		equipment_container.visible = false
		skills_list.visible = false
		return
	
	no_member_label.visible = false
	member_name_label.visible = true
	member_level_label.visible = true
	member_description_label.visible = true
	member_portrait.visible = true
	hp_progress.visible = true
	mp_progress.visible = true
	hp_label.visible = true
	mp_label.visible = true
	stats_grid.visible = true
	equipment_container.visible = true
	skills_list.visible = true
	
	var member: Entity = party_members[selected_member_index]
	
	var member_name = member.get("name") if "name" in member else "Member " + str(selected_member_index + 1)
	member_name_label.text = member_name
	var member_level = member.get("level") if "level" in member else 1
	member_level_label.text = "Level " + str(member_level)
	
	var member_desc = member.get("description") if "description" in member else "Member " + str(selected_member_index + 1) + " has no description."
	member_description_label.text = member_desc
	
	var portrait = member.get("portrait") if "portrait" in member else null
	if portrait:
		member_portrait.texture = AtlasTexture.new()
		member_portrait.texture.atlas = portrait
		member_portrait.texture.region = member.portrait_rect
	else:
		member_portrait.texture = null
	
	var current_hp = member.get("hp") if "hp" in member else 100
	var max_hp = member.get_max_stat(&"hp")
	var current_mp = member.get("mp") if "mp" in member else 50
	var max_mp = member.get_max_stat(&"mp")
	
	hp_progress.max_value = max_hp
	hp_progress.value = current_hp
	hp_label.text = str(current_hp) + "/" + str(max_hp)
	
	mp_progress.max_value = max_mp
	mp_progress.value = current_mp
	mp_label.text = str(current_mp) + "/" + str(max_mp)
	
	_update_stats_grid(member)
	update_equipment_grid(member)
	_update_skills_list(member)

func _update_stats_grid(member) -> void:
	# Clear existing stat labels
	for child in stats_grid.get_children():
		child.queue_free()
	
	var stat_names = [&"hp", &"mp", &"atk", &"def", &"speed", &"magic"]
	
	for stat_name in stat_names:
		var label = Label.new()
		label.text = stat_name.to_upper() + ": " + str(member.get_base_stat(stat_name))
		stats_grid.add_child(label)

func update_equipment_grid(member) -> void:
	for child in equipment_slots.get_children():
		child.queue_free()
	equipment_slot_buttons.clear()
	
	var member_entity: Entity = member as Entity
	if not member_entity:
		return
	
	var equipped = member_entity.equipped
	
	for slot_name in EQUIPMENT_SLOTS:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(192, 40)
		btn.name = "EquipSlot_" + slot_name
		
		var item = equipped.get(slot_name, null) as Item
		var item_name = item.item_name if item else "Empty"
		var slot_display = SLOT_DISPLAY_NAMES.get(slot_name, slot_name.capitalize())
		
		btn.text = slot_display + ":\n" + item_name
		
		if item and item.icon:
			btn.icon = item.icon
		
		equipment_slots.add_child(btn)
		btn.pressed.connect(on_equipment_slot_pressed.bind(slot_name))
		equipment_slot_buttons.append(btn)

func on_equipment_slot_pressed(slot: String) -> void:
	var member: Entity = party_members[selected_member_index] as Entity
	equip_select.setup(member, slot)
	$MarginContainer.visible = false

func _on_equip_button_pressed() -> void:
	var member: Entity = party_members[selected_member_index] as Entity
	var target_slot = "weapon_left"
	for slot in EQUIPMENT_SLOTS:
		if not member.equipped.get(slot, null):
			target_slot = slot
			break
	
	equip_select.setup(member, target_slot)
	$MarginContainer.visible = false

func _update_skills_list(member: Resource) -> void:
	for child in skills_list.get_children():
		child.queue_free()
	
	var skills_dict = member.get("skills") if "skills" in member else {}
	var default_attack = member.get("default_attack") if "default_attack" in member else null
	
	if default_attack:
		var label = Label.new()
		label.text = "Default Attack: " + (default_attack.get("skill_name") if "skill_name" in default_attack else "Attack")
		skills_list.add_child(label)
	
	var sorted_levels = skills_dict.keys()
	sorted_levels.sort()
	
	for level in sorted_levels:
		var skills_at_level = skills_dict[level]
		if skills_at_level is Array:
			for skill in skills_at_level:
				if skill and "skill_name" in skill:
					var label = Label.new()
					label.text = "Lv." + str(level) + ": " + skill.get("skill_name")
					skills_list.add_child(label)

func refresh() -> void:
	_refresh_party_display()
	_update_detail_panel()
