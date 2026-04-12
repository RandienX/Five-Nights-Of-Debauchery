# Example custom condition: Check if it's daytime
static func evaluate(branch: DialogueBranch, evaluator: DialogueConditionEvaluator) -> bool:
	# Replace with your actual game time check
	var hour = Time.get_time_dict_from_system()["hour"]
	return hour >= 6 and hour < 18
