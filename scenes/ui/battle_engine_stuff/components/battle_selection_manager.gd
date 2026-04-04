extends Node
class_name BattleSelectionManager

var root
var action_selector: BattleActionSelector
var skill_manager
var item_manager

# Action button selection
var action_buttons: Array[Button] = []
var current_action_index: int = 0
var action_funcs: Array[Callable] = []

# Skill selection (delegates to skill_manager)
# Item selection (delegates to item_manager)

enum SelectionType { ACTIONS, SKILLS, ITEMS }
var current_selection_type: SelectionType = SelectionType.ACTIONS

func setup(battleroot):
root = battleroot
# Get action buttons
action_buttons = [
root.get_node("Control/gui/HBoxContainer2/actions/FightButton/fight"),
root.get_node("Control/gui/HBoxContainer2/actions/SkillsButton/skills"),
root.get_node("Control/gui/HBoxContainer2/actions/DefendButton/defend"),
root.get_node("Control/gui/HBoxContainer2/actions/ItemButton/item"),
root.get_node("Control/gui/HBoxContainer2/actions/RunButton/run")
]
action_funcs = [
root._on_fight_button_pressed,
root._on_skills_button_pressed,
root._on_defend_button_pressed,
root._on_item_button_pressed,
root._on_run_button_pressed
]
update_action_selection()

func update_action_selection():
for i in range(action_buttons.size()):
if i == current_action_index:
action_buttons[i].modulate = Color(1, 1, 0.5)  # Yellow highlight
else:
action_buttons[i].modulate = Color(1, 1, 1)

func navigate_actions(direction: int):
current_action_index = wrapi(current_action_index + direction, 0, action_buttons.size())
update_action_selection()

func confirm_action_selection():
if current_action_index < action_funcs.size():
action_funcs[current_action_index].call()

func navigate_skills(direction: int):
if root.has_method("navigate_skills"):
root.navigate_skills(direction)

func navigate_items(direction: int):
if root.has_method("navigate_items"):
root.navigate_items(direction)
