extends NinePatchRect

var party_member: Party
@export var party_name: String

@onready var hp = $MarginContainer/HSplitContainer/VBoxContainer/Health
@onready var mana = $MarginContainer/HSplitContainer/VBoxContainer/Mana
@onready var faceset = $MarginContainer/HSplitContainer/faceset
@onready var member_name = $MarginContainer/HSplitContainer/VBoxContainer/Name/Name
@onready var member_level = $MarginContainer/HSplitContainer/VBoxContainer/Name/Level

func _physics_process(delta: float) -> void:
	if party_member:
		hp.get_node("Amount").text = str(party_member.hp) + "/" + str(party_member.max_stats["hp"])
		hp.get_node("ProgressBar").value = party_member.hp
		hp.get_node("ProgressBar").max_value = party_member.max_stats["hp"]
		mana.get_node("Amount").text = str(party_member.mp) + "/" + str(party_member.max_stats["mp"])
		mana.get_node("ProgressBar").value = party_member.mp
		mana.get_node("ProgressBar").max_value = party_member.max_stats["mp"]
		faceset.texture = load(party_member.face_path)
		faceset.region_rect = party_member.face_part_rect
		member_name.text = party_member.name
		member_level.text = "LV: " + str(party_member.level) + "   XP: " + str(party_member.xp) + "/" + str(party_member.xp_to_level_up)

func _on_button_pressed() -> void:
	if party_member:
		$"../../..".party_member_clicked(party_member)
