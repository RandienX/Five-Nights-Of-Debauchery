extends Control

@onready var member_display_top = $VBoxContainer/PartyMember
@export var party_member: Party

func _ready() -> void:
	member_display_top.party_member = party_member 
	overview()

func _process(delta: float) -> void:
	$VBoxContainer/HSplitContainer/StatChanges/VBoxContainer/LV.text = "LV: " + str(party_member.level) + " -> " + str(party_member.level+1)
	$VBoxContainer/HSplitContainer/StatChanges/VBoxContainer/HP.text = "HP: " + str(party_member.max_stats["hp"]) + " -> " + str(int(party_member.max_stats["hp"] + party_member.level_up["hp"]))
	$VBoxContainer/HSplitContainer/StatChanges/VBoxContainer/MP.text = "MP: " + str(party_member.max_stats["mp"]) + " -> " + str(int(party_member.max_stats["mp"] + party_member.level_up["mp"]))
	$VBoxContainer/HSplitContainer/StatChanges/VBoxContainer/STR.text = "STR: " + str(party_member.max_stats["atk"]) + " -> " + str(int(party_member.max_stats["atk"] + party_member.level_up["atk"]))
	$VBoxContainer/HSplitContainer/StatChanges/VBoxContainer/DEF.text = "DEF: " + str(party_member.max_stats["def"]) + " -> " + str(int(party_member.max_stats["def"] + party_member.level_up["def"]))
	$VBoxContainer/HSplitContainer/StatChanges/VBoxContainer/SPD.text = "SPD: " + str(party_member.max_stats["ai"]) + " -> " + str(int(party_member.max_stats["ai"] + party_member.level_up["ai"]))

func overview():
	clear(1)
	$VBoxContainer/HSplitContainer/Categories/VBoxContainer/DisplayCategory/Overview/HSplitContainer/TextureRect.texture = party_member.overview_model
	$VBoxContainer/HSplitContainer/Categories/VBoxContainer/DisplayCategory/Overview/HSplitContainer/Describtion.text = party_member.overview
func skills():
	clear(2)
	var skill_box = $VBoxContainer/HSplitContainer/Categories/VBoxContainer/DisplayCategory/Skills/SkillBox
	
	for c in skill_box.get_children():
		c.queue_free()
	
	for s in range(party_member.skills.size()):
		var skill = load("res://scenes/ui/battle_engine_stuff/skill_box.tscn").instantiate()
		skill.party_mode = true
		skill_box.scale = Vector2(0.36, 0.36)
		skill_box.add_child(skill)
		if party_member.level >= s:
			skill.setup(party_member.skills[s], s, true)
		else:
			skill.setup(party_member.skills[s], s, false)
func equipment():
	clear(3)

func clear(id):
	if id == 1:
		$VBoxContainer/HSplitContainer/Categories/VBoxContainer/DisplayCategory/Overview.visible = true
		$VBoxContainer/HSplitContainer/Categories/VBoxContainer/DisplayCategory/Skills.visible = false
		$VBoxContainer/HSplitContainer/Categories/VBoxContainer/DisplayCategory/Equipment.visible = false
	if id == 2:
		$VBoxContainer/HSplitContainer/Categories/VBoxContainer/DisplayCategory/Overview.visible = false
		$VBoxContainer/HSplitContainer/Categories/VBoxContainer/DisplayCategory/Skills.visible = true
		$VBoxContainer/HSplitContainer/Categories/VBoxContainer/DisplayCategory/Equipment.visible = false
	if id == 3:
		$VBoxContainer/HSplitContainer/Categories/VBoxContainer/DisplayCategory/Overview.visible = false
		$VBoxContainer/HSplitContainer/Categories/VBoxContainer/DisplayCategory/Skills.visible = false
		$VBoxContainer/HSplitContainer/Categories/VBoxContainer/DisplayCategory/Equipment.visible = true
