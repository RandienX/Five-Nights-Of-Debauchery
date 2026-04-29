extends Control

## Modern Inventory System - Full item management with categories, details, and usage

signal item_selected(item: Resource, amount: int)
signal item_used(item: Resource)
signal back_pressed()
signal equip_item_requested(item: Item)

enum ItemTypes { WEAPON = 0, ARMOR = 1, CONSUMABLE = 2, KEY = 3, ACCESSORY = 4 }

@onready var category_tabs: TabContainer = $MarginContainer/VBoxContainer/CategoryTabs
@onready var items_grid: GridContainer = $MarginContainer/VBoxContainer/HSplitContainer/ItemsPanel/ItemsGrid
@onready var item_detail_panel: Panel = $MarginContainer/VBoxContainer/HSplitContainer/DetailPanel
@onready var item_icon: TextureRect = $MarginContainer/VBoxContainer/HSplitContainer/DetailPanel/VBoxContainer/ItemIcon
@onready var item_name_label: Label = $MarginContainer/VBoxContainer/HSplitContainer/DetailPanel/VBoxContainer/ItemNameLabel
@onready var item_type_label: Label = $MarginContainer/VBoxContainer/HSplitContainer/DetailPanel/VBoxContainer/ItemTypeLabel
@onready var item_description: TextEdit = $MarginContainer/VBoxContainer/HSplitContainer/DetailPanel/VBoxContainer/ItemDescription
@onready var item_amount_label: Label = $MarginContainer/VBoxContainer/HSplitContainer/DetailPanel/VBoxContainer/ItemAmountLabel
@onready var item_stats_label: Label = $MarginContainer/VBoxContainer/HSplitContainer/DetailPanel/VBoxContainer/ItemStatsLabel
@onready var use_button: Button = $MarginContainer/VBoxContainer/HSplitContainer/DetailPanel/VBoxContainer/UseButton
@onready var no_item_label: Label = $MarginContainer/VBoxContainer/HSplitContainer/DetailPanel/VBoxContainer/NoItemLabel

var current_category: int = ItemTypes.WEAPON
var inventory_items: Dictionary = {}  # Item resource -> amount
var selected_item: Resource = null
var selected_item_amount: int = 0
var item_buttons: Array[Button] = []

const CATEGORY_TABS = ["WeaponsTab", "ArmorTab", "ConsumablesTab", "KeyItemsTab", "AccessoriesTab"]

func _ready() -> void:
	_setup_category_tabs()
	_refresh_inventory()
	_update_detail_panel()

func _setup_category_tabs() -> void:
	# TabContainer already has tabs defined in scene, just connect signals
	category_tabs.tab_changed.connect(_on_tab_changed)
	
	# Select first category by default
	current_category = 0
	_refresh_inventory()

func _on_tab_changed(tab_index: int) -> void:
	current_category = tab_index
	_refresh_inventory()
	_update_detail_panel()

func _refresh_inventory() -> void:
	# Clear existing item buttons
	for btn in item_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	item_buttons.clear()
	
	# Get inventory from PlayerStats
	inventory_items = PlayerStats.get_inventory()
	
	if inventory_items.is_empty():
		return
	
	# Filter items by current category and create buttons
	for item_res in inventory_items:
		var amount = inventory_items[item_res]
		
		if not item_res or not is_instance_valid(item_res):
			continue
		if not (item_res is Item):
			continue
		if amount <= 0:
			continue
		
		var item: Item = item_res as Item
		if item.type != current_category:
			continue
		
		# Create item button
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(180, 80)
		btn.name = "ItemBtn" + item.item_name
		
		# Create button content with icon and text
		var hbox = HBoxContainer.new()
		
		if item.icon:
			var icon_rect = TextureRect.new()
			icon_rect.texture = item.icon
			icon_rect.custom_minimum_size = Vector2(48, 48)
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			hbox.add_child(icon_rect)
		
		var vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = SIZE_EXPAND_FILL
		
		var name_label = Label.new()
		name_label.text = item.item_name
		name_label.add_theme_font_size_override("font_size", 16)
		vbox.add_child(name_label)
		
		var amount_label = Label.new()
		amount_label.text = "x" + str(amount)
		vbox.add_child(amount_label)
		
		hbox.add_child(vbox)
		btn.add_child(hbox)
		
		btn.pressed.connect(_on_item_button_pressed.bind(item, amount))
		items_grid.add_child(btn)
		item_buttons.append(btn)

func _on_item_button_pressed(item: Resource, amount: int) -> void:
	selected_item = item
	selected_item_amount = amount
	_update_detail_panel()
	item_selected.emit(item, amount)

func _update_detail_panel() -> void:
	if not selected_item:
		no_item_label.visible = true
		item_icon.visible = false
		item_name_label.visible = false
		item_type_label.visible = false
		item_description.visible = false
		item_amount_label.visible = false
		item_stats_label.visible = false
		use_button.visible = false
		return
	
	no_item_label.visible = false
	item_icon.visible = true
	item_name_label.visible = true
	item_type_label.visible = true
	item_description.visible = true
	item_amount_label.visible = true
	item_stats_label.visible = true
	use_button.visible = true
	
	var item: Item = selected_item as Item
	
	# Update icon
	if item.icon:
		item_icon.texture = item.icon
	else:
		item_icon.texture = null
	
	# Update name and type
	item_name_label.text = item.item_name
	var type_names = ["Weapon", "Armor", "Consumable", "Key Item", "Accessory"]
	item_type_label.text = type_names[item.type] if item.type < type_names.size() else "Unknown"
	
	# Update description
	item_description.text = item.description if item.description else "No description available."
	
	# Update amount
	item_amount_label.text = "Quantity: x" + str(selected_item_amount)
	
	# Update stats
	var stats_text = ""
	if not item.item_bonuses.is_empty():
		stats_text = "Stats:\n"
		for stat in item.item_bonuses:
			var value = item.item_bonuses[stat]
			if value != 0:
				var sign = "+" if value > 0 else ""
				stats_text += "  " + stat.to_upper() + ": " + sign + str(value) + "\n"
	item_stats_label.text = stats_text if not stats_text.is_empty() else "No stat bonuses"
	
	# Update use button visibility based on item type
	if item.type == ItemTypes.CONSUMABLE:
		use_button.text = "Use"
		use_button.visible = item.can_use_outside_battle
	elif item.type == ItemTypes.WEAPON or item.type == ItemTypes.ARMOR or item.type == ItemTypes.ACCESSORY:
		use_button.text = "Equip"
		use_button.visible = true
	else:
		use_button.visible = false

func _on_use_button_pressed() -> void:
	if not selected_item:
		return
	
	var item: Item = selected_item as Item
	
	if item.type == ItemTypes.CONSUMABLE:
		# Use consumable item
		if item.can_use_outside_battle:
			PlayerStats.use_item_on_party(item)
			item_used.emit(item)
			_refresh_inventory()
			_update_detail_panel()
	elif item.type == ItemTypes.WEAPON or item.type == ItemTypes.ARMOR or item.type == ItemTypes.ACCESSORY:
		# Show party selection for equipping
		emit_signal("equip_item_requested", item)

func refresh() -> void:
	_refresh_inventory()
	_update_detail_panel()

func _on_back_button_pressed() -> void:
	back_pressed.emit()
