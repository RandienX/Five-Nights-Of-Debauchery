extends Control

## Equipment Selection Dialog - Allows player to equip/unequip items for party members

signal equipment_changed(member: Entity, slot: String, item: Item)
signal dialog_closed()

@onready var member_name_label: Label = $MarginContainer/VBoxContainer/MemberNameLabel
@onready var slot_label: Label = $MarginContainer/VBoxContainer/SlotLabel
@onready var items_grid: GridContainer = $MarginContainer/VBoxContainer/HSplitContainer/ItemsPanel/ItemsGrid
@onready var current_item_name: Label = $MarginContainer/VBoxContainer/HSplitContainer/CurrentEquipPanel/VBoxContainer/CurrentItemName
@onready var current_item_stats: TextEdit = $MarginContainer/VBoxContainer/HSplitContainer/CurrentEquipPanel/VBoxContainer/CurrentItemStats
@onready var unequip_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/UnequipButton

var target_member: Entity = null
var target_slot: String = ""
var available_items: Array[Item] = []
var current_equipped_item: Item = null

func _ready() -> void:
	visible = false

func setup(member: Entity, slot: String) -> void:
	target_member = member
	target_slot = slot
	
	# Update labels
	member_name_label.text = member.name if member else "Unknown"
	slot_label.text = "Slot: " + _get_slot_display_name(slot)
	
	# Get currently equipped item
	current_equipped_item = member.equipped.get(slot, null) if member else null
	_update_current_equip_display()
	
	# Filter available items for this slot
	_filter_available_items(slot)
	
	# Populate items grid
	_populate_items_grid()
	
	# Show/hide unequip button based on whether something is equipped
	unequip_button.visible = current_equipped_item != null

func _get_slot_display_name(slot: String) -> String:
	match slot:
		"head": return "Head"
		"body": return "Body"
		"legs": return "Legs"
		"weapon_left": return "Weapon (Left)"
		"weapon_right": return "Weapon (Right)"
		"shield": return "Shield"
		"accessory_1": return "Accessory 1"
		"accessory_2": return "Accessory 2"
		_: return slot.capitalize()

func _get_required_item_type(slot: String) -> int:
	# Returns the Item.type enum value required for this slot
	# Weapon slots need weapons (type 0), armor slots need armor (type 1), accessories need accessory (type 4)
	if slot in ["weapon_left", "weapon_right"]:
		return 0  # Weapon
	elif slot in ["head", "body", "legs", "shield"]:
		return 1  # Armor
	elif slot in ["accessory_1", "accessory_2"]:
		return 4  # Accessory
	return -1

func _get_required_armor_type(slot: String) -> int:
	# For armor slots, returns the specific armor_type enum value
	match slot:
		"head": return 0  # Head
		"body": return 1  # Chest
		"legs": return 2  # Legs
		"shield": return 3  # Shield
		_: return -1

func _filter_available_items(slot: String) -> void:
	available_items.clear()
	
	var inventory = PlayerStats.get_inventory()
	var required_item_type = _get_required_item_type(slot)
	var required_armor_type = _get_required_armor_type(slot)
	
	for item_res in inventory:
		var amount = inventory[item_res]
		if amount <= 0:
			continue
		
		var item: Item = item_res as Item
		if not item:
			continue
		
		# Check item type matches slot
		if item.type != required_item_type:
			continue
		
		# For armor slots, check specific armor type
		if required_item_type == 1 and required_armor_type >= 0:
			if item.armor_type != required_armor_type:
				continue
		
		# Check if character can equip this item
		if target_member and not item.can_equip(target_member):
			continue
		
		# Don't show the currently equipped item in the list
		if item == current_equipped_item:
			continue
		
		available_items.append(item)

func _populate_items_grid() -> void:
	# Clear existing items
	for child in items_grid.get_children():
		child.queue_free()
	
	if available_items.is_empty():
		var label = Label.new()
		label.text = "No available items"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		items_grid.add_child(label)
		return
	
	for item in available_items:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(180, 80)
		
		var vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = SIZE_EXPAND_FILL
		
		var name_label = Label.new()
		name_label.text = item.item_name
		name_label.add_theme_font_size_override("font_size", 16)
		vbox.add_child(name_label)
		
		if item.icon:
			var icon_rect = TextureRect.new()
			icon_rect.texture = item.icon
			icon_rect.custom_minimum_size = Vector2(32, 32)
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			vbox.add_child(icon_rect)
		
		btn.add_child(vbox)
		btn.pressed.connect(_on_item_selected.bind(item))
		items_grid.add_child(btn)

func _update_current_equip_display() -> void:
	if current_equipped_item:
		current_item_name.text = current_equipped_item.item_name
		current_item_stats.visible = true
		
		var stats_text = "Stats:\n"
		if not current_equipped_item.item_bonuses.is_empty():
			for stat in current_equipped_item.item_bonuses:
				var value = current_equipped_item.item_bonuses[stat]
				if value != 0:
					var sign = "+" if value > 0 else ""
					stats_text += "  " + stat.to_upper() + ": " + sign + str(value) + "\n"
		else:
			stats_text = "No stat bonuses"
		current_item_stats.text = stats_text
	else:
		current_item_name.text = "None"
		current_item_stats.visible = false

func _on_item_selected(item: Item) -> void:
	if not target_member:
		return
	
	# Add current item back to inventory if exists
	if current_equipped_item:
		PlayerStats.add_item(current_equipped_item, 1)
	
	# Remove new item from inventory
	PlayerStats.remove_item(item, 1)
	
	# Equip the new item
	target_member.equipped[target_slot] = item
	
	# Recalculate stats
	if target_member.has_method("equip_stats_change"):
		target_member.equip_stats_change()
	
	equipment_changed.emit(target_member, target_slot, item)
	dialog_closed.emit()
	queue_free()

func _on_unequip_button_pressed() -> void:
	if not target_member or not current_equipped_item:
		return
	
	# Add current item back to inventory
	PlayerStats.add_item(current_equipped_item, 1)
	
	# Unequip
	target_member.equipped[target_slot] = null
	
	# Recalculate stats
	if target_member.has_method("equip_stats_change"):
		target_member.equip_stats_change()
	
	equipment_changed.emit(target_member, target_slot, null)
	dialog_closed.emit()
	queue_free()

func _on_cancel_button_pressed() -> void:
	dialog_closed.emit()
	queue_free()
