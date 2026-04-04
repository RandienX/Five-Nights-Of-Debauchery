class_name BattleSelectionManager
extends Node

## Manages selection across buttons, skills, and items using ID-based navigation
## Replaces the old $TheMove cursor system with proper ID tracking
## Selection glows yellow like skills do

signal selection_changed(selection_type: String, index: int)

enum SelectionType {
	ACTIONS,    # Fight, Skills, Defend, Item, Run buttons
	SKILLS,     # Skill grid
	ITEMS       # Item grid
}

var current_selection_type: SelectionType = SelectionType.ACTIONS
var action_index: int = 0
var skill_index: int = 0
var item_index: int = 0

const ACTION_COUNT: int = 5
var _action_buttons: Array[Button] = []

var battle_root: Node2D = null
var action_selector: BattleActionSelector = null
var skill_manager: SkillManager = null
var item_manager: ItemManager = null

func _ready() -> void:
	pass

func setup(root: Node2D, selector: BattleActionSelector, skil_mgr: SkillManager, item_mgr: ItemManager):
	battle_root = root
	action_selector = selector
	skill_manager = skil_mgr
	item_manager = item_mgr
	
	if battle_root and battle_root.has_node("Control/gui/HBoxContainer2/actions"):
		var actions_container = battle_root.get_node("Control/gui/HBoxContainer2/actions")
		_action_buttons = [
			actions_container.get_node_or_null("FightButton/fight"),
			actions_container.get_node_or_null("SkillsButton/skills"),
			actions_container.get_node_or_null("DefendButton/defend"),
			actions_container.get_node_or_null("ItemButton/item"),
			actions_container.get_node_or_null("RunButton/run")
		]

## Switches between selection types (actions <-> skills <-> items)
func switch_selection_type(new_type: SelectionType):
	if new_type == current_selection_type:
		return
	
	current_selection_type = new_type
	
	match new_type:
		SelectionType.ACTIONS:
			if action_selector:
				action_selector.selected_action_index = action_index
				action_selector.update_visual_selection()
		SelectionType.SKILLS:
			if skill_manager:
				skill_manager.current_skill_index = skill_index
				skill_manager.update_skill_selection()
		SelectionType.ITEMS:
			if item_manager:
				item_manager.current_item_index = item_index
				item_manager.update_item_selection()
	
	selection_changed.emit(_get_type_name(new_type), _get_current_index())

## Navigates within the current selection type
func navigate(direction: int):
	match current_selection_type:
		SelectionType.ACTIONS:
			_navigate_actions(direction)
		SelectionType.SKILLS:
			_navigate_skills(direction)
		SelectionType.ITEMS:
			_navigate_items(direction)

func _navigate_actions(direction: int):
	var new_index = wrapi(action_index + direction, 0, ACTION_COUNT)
	if new_index != action_index:
		action_index = new_index
		if action_selector:
			action_selector.selected_action_index = action_index
			action_selector.update_visual_selection()
		selection_changed.emit("actions", action_index)

func _navigate_skills(direction: int):
	if not skill_manager or skill_manager.skill_boxes.is_empty():
		return
	
	var new_index = skill_index + direction
	
	# Loop around if needed
	if new_index < 0:
		new_index = skill_manager.skill_boxes.size() - 1
	elif new_index >= skill_manager.skill_boxes.size():
		new_index = 0
	
	# Skip unaffordable skills when navigating
	var attempts = 0
	while attempts < skill_manager.skill_boxes.size():
		if skill_manager.skill_affordable[new_index]:
			break
		new_index += direction
		if new_index < 0:
			new_index = skill_manager.skill_boxes.size() - 1
		elif new_index >= skill_manager.skill_boxes.size():
			new_index = 0
		attempts += 1
	
	# Only update if we found an affordable skill
	if skill_manager.skill_affordable[new_index]:
		skill_index = new_index
		skill_manager.current_skill_index = skill_index
		skill_manager.update_skill_selection()
		selection_changed.emit("skills", skill_index)

func _navigate_items(direction: int):
	if not item_manager or item_manager.item_boxes.is_empty():
		return
	
	var new_index = item_index + direction
	
	# Loop around if needed
	if new_index < 0:
		new_index = item_manager.item_boxes.size() - 1
	elif new_index >= item_manager.item_boxes.size():
		new_index = 0
	
	# Skip items with 0 quantity when navigating
	var attempts = 0
	while attempts < item_manager.item_boxes.size():
		if item_manager.item_amounts[new_index] > 0:
			break
		new_index += direction
		if new_index < 0:
			new_index = item_manager.item_boxes.size() - 1
		elif new_index >= item_manager.item_boxes.size():
			new_index = 0
		attempts += 1
	
	# Only update if we found an available item
	if item_manager.item_amounts[new_index] > 0:
		item_index = new_index
		item_manager.current_item_index = item_index
		item_manager.update_item_selection()
		selection_changed.emit("items", item_index)

## Confirms the current selection
func confirm_selection():
	match current_selection_type:
		SelectionType.ACTIONS:
			if action_selector:
				action_selector.confirm_selection()
		SelectionType.SKILLS:
			if skill_manager:
				skill_manager.select_skill()
		SelectionType.ITEMS:
			if item_manager:
				item_manager.select_item()

## Gets the current index based on selection type
func _get_current_index() -> int:
	match current_selection_type:
		SelectionType.ACTIONS:
			return action_index
		SelectionType.SKILLS:
			return skill_index
		SelectionType.ITEMS:
			return item_index
	return 0

## Gets the type name as string
func _get_type_name(type: SelectionType) -> String:
	match type:
		SelectionType.ACTIONS:
			return "actions"
		SelectionType.SKILLS:
			return "skills"
		SelectionType.ITEMS:
			return "items"
	return "unknown"

## Resets all selections to default
func reset_all_selections():
	action_index = 0
	skill_index = 0
	item_index = 0
	current_selection_type = SelectionType.ACTIONS
	
	if action_selector:
		action_selector.reset_selection()
