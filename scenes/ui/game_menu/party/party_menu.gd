extends Control

## Modern Party Menu - Displays all party members with detailed stats and equipment management

signal party_member_selected(member: Resource)
signal back_pressed()
signal equip_item_requested(member: Entity, slot: String)

@onready var members_container: VBoxContainer = $MarginContainer/VBoxContainer/MembersContainer
@onready var member_detail_panel: Panel = $MarginContainer/VBoxContainer/MemberDetailPanel
@onready var member_name_label: Label = $MarginContainer/VBoxContainer/MemberDetailPanel/VBoxContainer/MemberNameLabel
@onready var member_level_label: Label = $MarginContainer/VBoxContainer/MemberDetailPanel/VBoxContainer/MemberLevelLabel
@onready var member_portrait: TextureRect = $MarginContainer/VBoxContainer/MemberDetailPanel/VBoxContainer/HBoxContainer/MemberPortrait
@onready var hp_progress: ProgressBar = $MarginContainer/VBoxContainer/MemberDetailPanel/VBoxContainer/HBoxContainer/VBoxContainer/HPProgress
@onready var mp_progress: ProgressBar = $MarginContainer/VBoxContainer/MemberDetailPanel/VBoxContainer/HBoxContainer/VBoxContainer/MPProgress
@onready var hp_label: Label = $MarginContainer/VBoxContainer/MemberDetailPanel/VBoxContainer/HBoxContainer/VBoxContainer/HPLabel
@onready var mp_label: Label = $MarginContainer/VBoxContainer/MemberDetailPanel/VBoxContainer/HBoxContainer/VBoxContainer/MPLabel
@onready var stats_grid: GridContainer = $MarginContainer/VBoxContainer/MemberDetailPanel/VBoxContainer/StatsGrid
@onready var equipment_container: VBoxContainer = $MarginContainer/VBoxContainer/MemberDetailPanel/VBoxContainer/EquipmentContainer
@onready var equipment_slots: GridContainer = $MarginContainer/VBoxContainer/MemberDetailPanel/VBoxContainer/EquipmentContainer/EquipmentSlots
@onready var equip_button: Button = $MarginContainer/VBoxContainer/MemberDetailPanel/VBoxContainer/EquipmentContainer/EquipButton
@onready var skills_list: VBoxContainer = $MarginContainer/VBoxContainer/MemberDetailPanel/VBoxContainer/SkillsList
@onready var no_member_label: Label = $MarginContainer/VBoxContainer/MemberDetailPanel/VBoxContainer/NoMemberLabel

var party_members: Array[Resource] = []
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

func _refresh_party_display() -> void:
	# Clear existing buttons
	for btn in member_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	member_buttons.clear()
	
	# Get party from PlayerStats
	party_members = PlayerStats.get_party_members()
	
	if party_members.is_empty():
		return
	
	# Create a button for each party member
	for i in range(party_members.size()):
		var member: Resource = party_members[i]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(200, 60)
		btn.text = member.get("name", "Unknown") if member.has_meta("name") or "name" in member else "Member " + str(i + 1)
		btn.name = "MemberBtn" + str(i)
		
		# Add icon if portrait exists
		if member.has_meta("portrait") or "portrait" in member:
			var portrait = member.get("portrait", null)
			if portrait:
				btn.icon = portrait
		
		btn.pressed.connect(_on_member_button_pressed.bind(i))
		members_container.add_child(btn)
		member_buttons.append(btn)
	
	# Select first member by default
	if not party_members.is_empty():
		_select_member(0)

func _on_member_button_pressed(index: int) -> void:
	_select_member(index)

func _select_member(index: int) -> void:
	if index < 0 or index >= party_members.size():
		return
	
	selected_member_index = index
	var member: Resource = party_members[index]
	
	# Update button states
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
	member_portrait.visible = true
	hp_progress.visible = true
	mp_progress.visible = true
	hp_label.visible = true
	mp_label.visible = true
	stats_grid.visible = true
	equipment_container.visible = true
	skills_list.visible = true
	
	var member: Resource = party_members[selected_member_index]
	
	# Update name and level
	var member_name = member.get("name", "Unknown") if ("name" in member or member.has_meta("name")) else "Member " + str(selected_member_index + 1)
	member_name_label.text = member_name
	var member_level = member.get("level", 1) if "level" in member else 1
	member_level_label.text = "Level " + str(member_level)
	
	# Update portrait
	var portrait = member.get("portrait", null) if "portrait" in member else null
	if portrait:
		member_portrait.texture = portrait
	else:
		member_portrait.texture = null
	
	# Update HP/MP
	var current_hp = member.get("hp", 100) if "hp" in member else 100
	var max_hp = member.get("max_stats", {}).get("hp", 100) if "max_stats" in member else 100
	var current_mp = member.get("mp", 50) if "mp" in member else 50
	var max_mp = member.get("max_stats", {}).get("mp", 50) if "max_stats" in member else 50
	
	hp_progress.max_value = max_hp
	hp_progress.value = current_hp
	hp_label.text = str(current_hp) + "/" + str(max_hp)
	
	mp_progress.max_value = max_mp
	mp_progress.value = current_mp
	mp_label.text = str(current_mp) + "/" + str(max_mp)
	
	# Update stats grid
	_update_stats_grid(member)
	
	# Update equipment grid
	_update_equipment_grid(member)
	
	# Update skills list
	_update_skills_list(member)

func _update_stats_grid(member: Resource) -> void:
	# Clear existing stat labels
	for child in stats_grid.get_children():
		child.queue_free()
	
	var max_stats = member.get("max_stats", {}) if "max_stats" in member else {}
	var stat_names = ["hp", "mp", "atk", "def", "speed", "magic"]
	
	for stat_name in stat_names:
		var label = Label.new()
		label.text = stat_name.to_upper() + ": " + str(max_stats.get(stat_name, 0))
		stats_grid.add_child(label)

func _update_equipment_grid(member: Resource) -> void:
	# Clear existing equipment slot buttons
	for child in equipment_slots.get_children():
		child.queue_free()
	equipment_slot_buttons.clear()
	
	var member_entity: Entity = member as Entity
	if not member_entity:
		return
	
	var equipped = member_entity.equipped
	
	# Create a button for each equipment slot
	for slot_name in EQUIPMENT_SLOTS:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(140, 50)
		btn.name = "EquipSlot_" + slot_name
		
		var item: Item = equipped.get(slot_name, null)
		var item_name = item.item_name if item else "Empty"
		var slot_display = SLOT_DISPLAY_NAMES.get(slot_name, slot_name.capitalize())
		
		btn.text = slot_display + ":\\n" + item_name
		
		# Add icon if item has one
		if item and item.icon:
			btn.icon = item.icon
		
		btn.pressed.connect(_on_equipment_slot_pressed.bind(slot_name))
		equipment_slots.add_child(btn)
		equipment_slot_buttons.append(btn)

func _on_equipment_slot_pressed(slot: String) -> void:
	if selected_member_index < 0 or selected_member_index >= party_members.size():
		return
	
	var member: Entity = party_members[selected_member_index] as Entity
	if not member:
		return
	
	# Emit signal to open equipment selection for this slot
	equip_item_requested.emit(member, slot)

func _on_equip_button_pressed() -> void:
	if selected_member_index < 0 or selected_member_index >= party_members.size():
		return
	
	var member: Entity = party_members[selected_member_index] as Entity
	if not member:
		return
	
	# Open equipment menu for first slot by default, or show slot selection
	# For now, we'll emit signal for the first empty slot or weapon_left
	var target_slot = "weapon_left"
	for slot in EQUIPMENT_SLOTS:
		if not member.equipped.get(slot, null):
			target_slot = slot
			break
	
	equip_item_requested.emit(member, target_slot)

func _update_skills_list(member: Resource) -> void:
	# Clear existing skill labels
	for child in skills_list.get_children():
		child.queue_free()
	
	var skills_dict = member.get("skills", {}) if "skills" in member else {}
	var default_attack = member.get("default_attack", null) if "default_attack" in member else null
	
	if default_attack:
		var label = Label.new()
		label.text = "Default Attack: " + (default_attack.get("skill_name", "Attack") if "skill_name" in default_attack else "Attack")
		skills_list.add_child(label)
	
	# Sort skills by level
	var sorted_levels = skills_dict.keys()
	sorted_levels.sort()
	
	for level in sorted_levels:
		var skills_at_level = skills_dict[level]
		if skills_at_level is Array:
			for skill in skills_at_level:
				if skill and "skill_name" in skill:
					var label = Label.new()
					label.text = "Lv." + str(level) + ": " + skill.get("skill_name", "Unknown Skill")
					skills_list.add_child(label)

func refresh() -> void:
	_refresh_party_display()
	_update_detail_panel()

func _on_back_button_pressed() -> void:
	back_pressed.emit()
