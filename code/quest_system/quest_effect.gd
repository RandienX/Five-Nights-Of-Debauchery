class_name QuestEffect
extends Resource

enum EffectType {
	ADD_ITEM,
	ADD_CURRENCY,
	ADD_STATUS,
	START_DIALOGUE,
	CHANGE_SCENE,
	SAVE_GAME,
	CUSTOM
}

@export var type: EffectType = EffectType.ADD_ITEM
@export var params: Dictionary = {} # { "item_id": "sword", "amount": 1 }

func execute(owner: Node):
	match type:
		EffectType.ADD_ITEM:
			print("Granting item: ", params.get("item_id"))
			# owner.emit_signal("item_granted", params)
		EffectType.ADD_CURRENCY:
			print("Granting currency: ", params.get("amount"))
		EffectType.SAVE_GAME:
			if owner.has_method("request_save"):
				owner.request_save()
		EffectType.CUSTOM:
			if params.has("callable"):
				params["callable"].call()
