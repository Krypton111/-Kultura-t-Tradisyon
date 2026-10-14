extends RefCounted
class_name KitchenTaskModel

const INTRO_DIALOGUE: Array[Dictionary] = [
	{
		"speaker": "Lola Nena",
		"text": "Migs, just in time! I need to start preparing lunch."
	},
	{
		"speaker": "Migs",
		"text": "What are you going to cook, Lola?"
	},
	{
		"speaker": "Lola Nena",
		"text": "I’m making sinigang today, but there’s a lot to prepare. Will you help me get the ingredients ready?"
	},
	{
		"speaker": "Migs",
		"text": "Of course, Lola! Just tell me what to do first."
	}
]

const HERITAGE_COMPLETED_META := "living_room_heritage_completed"
const KITCHEN_INTRO_COMPLETED_META := "kitchen_task_intro_completed"


func can_start(hud: Node, lola: Sprite2D) -> bool:
	if hud == null or lola == null or not lola.visible:
		return false
	if not bool(hud.get_meta(HERITAGE_COMPLETED_META, false)):
		return false
	return not bool(hud.get_meta(KITCHEN_INTRO_COMPLETED_META, false))


func mark_completed(hud: Node) -> void:
	if hud != null:
		hud.set_meta(KITCHEN_INTRO_COMPLETED_META, true)

func get_intro_dialogue() -> Array[Dictionary]:
	return INTRO_DIALOGUE.duplicate(true)
