extends Control
class_name Menu

var layer_down = 0
@onready var categories = $MarginContainer/HSplitContainer/categories
@onready var display = $MarginContainer/HSplitContainer/display_category

var pending_item: Item = null  # For item usage from inventory

func _ready() -> void:
		pass # Replace with function body.

func open_party_for_item(item: Item) -> void:
	"""Open party menu for item target selection"""
	pending_item = item
	for c in display.get_children():
		c.queue_free()
	var party_scene = load("res://scenes/ui/game_menu/party/party.tscn").instantiate()
	display.add_child(party_scene)
	
	if party_scene.has_signal("party_member_selected"):
		party_scene.party_member_selected.connect(_on_party_member_selected_for_item)

func _on_party_member_selected_for_item(member: Resource) -> void:
	"""Handle party member selection for item usage"""
	if pending_item and member:
		var entity_member = member as Entity
		if entity_member:
			PlayerStats.use_item(pending_item, entity_member)
			open_inventory()

func open_inventory() -> void:
	"""Open the inventory menu"""
	for c in display.get_children():
		c.queue_free()

	var inv_scene = load("res://scenes/ui/game_menu/inventory/inventory.tscn").instantiate()
	display.add_child(inv_scene)
