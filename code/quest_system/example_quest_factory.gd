@icon("res://icon.svg")
class_name ExampleQuestFactory
extends RefCounted
## Utility class to create example quests programmatically
## Use this as a reference for creating quests via code or in editor

static func create_fetch_quest() -> Quest:
	var quest = Quest.new()
	quest.quest_name = "The Slime Hunter"
	quest.description = "Hunt down the slimes that have been terrorizing the village. Bring back their cores as proof."
	quest.category = "Main"
	quest.priority = 10
	
	# Step 1: Gather evidence
	var step1 = QuestStep.new()
	step1.step_name = "Track the Slimes"
	step1.description = "Find evidence of slime activity"
	
	var point1 = QuestPoint.new()
	point1.point_name = "Find slime evidence"
	point1.logic_gate = QuestPoint.LogicGate.AND
	
	# Condition 1: Have slime cores
	var cond1 = QuestPointCondition.new()
	cond1.type = QuestPointCondition.ConditionType.HAS_ITEM
	cond1.target_key = "slime_core"
	cond1.progress_target = 3
	cond1.description = "Collect slime cores"
	point1.conditions.append(cond1)
	
	# Condition 2: Visit location
	var cond2 = QuestPointCondition.new()
	cond2.type = QuestPointCondition.ConditionType.VISITED_LOCATION
	cond2.target_key = "slime_forest"
	cond2.progress_target = 1
	cond2.description = "Visit the Slime Forest"
	point1.conditions.append(cond2)
	
	step1.points.append(point1)
	quest.steps.append(step1)
	
	# Step 2: Hunt slimes
	var step2 = QuestStep.new()
	step2.step_name = "Hunt the Slimes"
	step2.description = "Defeat the slimes"
	
	var point2 = QuestPoint.new()
	point2.point_name = "Defeat slimes"
	point2.logic_gate = QuestPoint.LogicGate.AND
	
	var cond3 = QuestPointCondition.new()
	cond3.type = QuestPointCondition.ConditionType.KILLED_ENEMY
	cond3.target_key = "slime"
	cond3.progress_target = 5
	cond3.description = "Defeat slimes"
	point2.conditions.append(cond3)
	
	step2.points.append(point2)
	quest.steps.append(step2)
	
	# Rewards
	var reward1 = QuestEffect.new()
	reward1.type = QuestEffect.EffectType.ADD_CURRENCY
	reward1.params = {"amount": 100, "currency_type": "gold"}
	reward1.description = "100 Gold"
	quest.rewards.append(reward1)
	
	var reward2 = QuestEffect.new()
	reward2.type = QuestEffect.EffectType.ADD_ITEM
	reward2.params = {"item_resource": "res://resources/items/health_potion.tres", "count": 3}
	reward2.description = "3 Health Potions"
	quest.rewards.append(reward2)
	
	return quest

static func create_delivery_quest() -> Quest:
	var quest = Quest.new()
	quest.quest_name = "A Simple Delivery"
	quest.description = "Deliver this package to the merchant in the next town."
	quest.category = "Side"
	quest.priority = 5
	
	var step1 = QuestStep.new()
	step1.step_name = "Deliver the Package"
	
	var point1 = QuestPoint.new()
	point1.point_name = "Talk to merchant"
	point1.logic_gate = QuestPoint.LogicGate.AND
	
	var cond1 = QuestPointCondition.new()
	cond1.type = QuestPointCondition.ConditionType.TALKED_TO_NPC
	cond1.target_key = "town_merchant"
	cond1.progress_target = 1
	point1.conditions.append(cond1)
	
	var cond2 = QuestPointCondition.new()
	cond2.type = QuestPointCondition.ConditionType.DONE_THING
	cond2.target_key = "delivered_package"
	cond2.progress_target = 1
	point1.conditions.append(cond2)
	
	step1.points.append(point1)
	quest.steps.append(step1)
	
	var reward = QuestEffect.new()
	reward.type = QuestEffect.EffectType.ADD_CURRENCY
	reward.params = {"amount": 50, "currency_type": "gold"}
	quest.rewards.append(reward)
	
	return quest

static func create_boss_quest() -> Quest:
	var quest = Quest.new()
	quest.quest_name = "The Dark Lord's Return"
	quest.description = "The Dark Lord has awakened. Defeat him and save the world!"
	quest.category = "Main"
	quest.priority = 100
	
	var step1 = QuestStep.new()
	step1.step_name = "Prepare for Battle"
	
	var point1 = QuestPoint.new()
	point1.point_name = "Gather the legendary items"
	point1.logic_gate = QuestPoint.LogicGate.AND
	
	# Need multiple items (AND gate)
	for item_name in ["legendary_sword", "holy_shield", "hero_armor"]:
		var cond = QuestPointCondition.new()
		cond.type = QuestPointCondition.ConditionType.HAS_ITEM
		cond.target_key = item_name
		cond.progress_target = 1
		point1.conditions.append(cond)
	
	step1.points.append(point1)
	quest.steps.append(step1)
	
	var step2 = QuestStep.new()
	step2.step_name = "Confront the Dark Lord"
	
	var point2 = QuestPoint.new()
	point2.point_name = "Defeat the Dark Lord"
	point2.logic_gate = QuestPoint.LogicGate.AND
	
	var cond = QuestPointCondition.new()
	cond.type = QuestPointCondition.ConditionType.BATTLE_WON
	cond.target_key = "dark_lord_battle"
	cond.progress_target = 1
	point2.conditions.append(cond)
	
	step2.points.append(point2)
	quest.steps.append(step2)
	
	# Big reward
	var reward = QuestEffect.new()
	reward.type = QuestEffect.EffectType.ADD_CURRENCY
	reward.params = {"amount": 1000, "currency_type": "gold"}
	quest.rewards.append(reward)
	
	var effect = QuestEffect.new()
	effect.type = QuestEffect.EffectType.SET_FLAG
	effect.params = {"flag_name": "defeated_dark_lord", "value": true}
	quest.rewards.append(effect)
	
	return quest

static func create_achievement_first_blood() -> Achievement:
	var achievement = Achievement.new()
	achievement.achievement_name = "First Blood"
	achievement.description = "Defeat your first enemy"
	achievement.category = "Combat"
	
	var step = QuestStep.new()
	step.step_name = "Defeat an enemy"
	
	var point = QuestPoint.new()
	point.point_name = "Get your first kill"
	point.logic_gate = QuestPoint.LogicGate.AND
	
	var cond = QuestPointCondition.new()
	cond.type = QuestPointCondition.ConditionType.KILLED_ENEMY
	cond.target_key = "any"  # Special case - would need custom handling
	cond.progress_target = 1
	point.conditions.append(cond)
	
	step.points.append(point)
	achievement.steps.append(step)
	
	return achievement

static func create_achievement_collector() -> Achievement:
	var achievement = Achievement.new()
	achievement.achievement_name = "Collector"
	achievement.description = "Collect 100 different items"
	achievement.category = "Collection"
	achievement.icon = null  # Set in editor
	
	var step = QuestStep.new()
	step.step_name = "Build your collection"
	
	var point = QuestPoint.new()
	point.point_name = "Collect items"
	point.logic_gate = QuestPoint.LogicGate.AND
	
	var cond = QuestPointCondition.new()
	cond.type = QuestPointCondition.ConditionType.HAS_ITEM
	cond.target_key = "unique_items_count"
	cond.progress_target = 100
	cond.description = "Unique items collected"
	point.conditions.append(cond)
	
	step.points.append(point)
	achievement.steps.append(step)
	
	return achievement

static func create_achievement_speedster() -> Achievement:
	var achievement = Achievement.new()
	achievement.achievement_name = "Need for Speed"
	achievement.description = "Complete a battle in under 3 turns"
	achievement.category = "Combat"
	achievement.is_secret = true
	
	var step = QuestStep.new()
	step.step_name = "Win quickly"
	
	var point = QuestPoint.new()
	point.point_name = "Fast victory"
	point.logic_gate = QuestPoint.LogicGate.AND
	
	var cond = QuestPointCondition.new()
	cond.type = QuestPointCondition.ConditionType.CUSTOM
	cond.target_key = "battle_won_under_3_turns"
	cond.progress_target = 1
	cond.description = "Win battle in < 3 turns"
	point.conditions.append(cond)
	
	step.points.append(point)
	achievement.steps.append(step)
	
	return achievement
