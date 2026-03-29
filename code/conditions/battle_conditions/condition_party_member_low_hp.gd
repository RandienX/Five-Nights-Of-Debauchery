extends RefCounted
class_name BattleConditionPartyMemberHP

@export var party_member_index: int = 0  # Index in Global.party
@export var threshold_percent: float = 25.0  # HP threshold percentage

# Checks if a specific party member's HP is below threshold
func check(battle_engine: Node) -> bool:
	if party_member_index >= Global.party.size():
		return false
	
	var member = Global.party[party_member_index]
	var max_hp = member.max_stats["hp"]
	if max_hp <= 0:
		return false
	
	var current_percent = (member.hp / max_hp) * 100.0
	return current_percent <= threshold_percent
