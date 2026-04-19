## EffectHandler.gd
extends Node

# Signal to tell the UI or objects to play an animation/effect
signal effect_triggered(effect_name: String, target_id: int)

func execute_card_effect(card: CardData, user_id: int) -> void:
	print("EffectHandler: Executing ", card.effect_id, " for Player ", user_id)
	
	match card.effect_id:
		"hand_effect":
			effect_triggered.emit("hand_effect", user_id) 
		"marble_effect":
			effect_triggered.emit("marble_effect", user_id)
		"terrain_effect":
			effect_triggered.emit("terrain_effect", user_id)
		_:
			print("EffectHandler: No logic defined for ", card.effect_id)
