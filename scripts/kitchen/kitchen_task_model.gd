extends RefCounted
class_name KitchenTaskModel
## Data and rules for preparing Lola Nena's sinigang ingredients.
## The controller/view never decides whether the task is complete.

const HERITAGE_COMPLETED_META := "living_room_heritage_completed"
const KITCHEN_INTRO_COMPLETED_META := "kitchen_task_intro_completed"
const KITCHEN_TASK_COMPLETED_META := "kitchen_ingredient_task_completed"
const KITCHEN_PROGRESS_META := "kitchen_ingredient_progress"
const RECIPE_TEXTURE_PATH := "res://GAME ASSETS/Kitchen/lola's recipe.png"

const INTRO_DIALOGUE: Array[Dictionary] = [
	{"speaker": "Lola Nena", "text": "Migs, just in time! I need to start preparing lunch."},
	{"speaker": "Migs", "text": "What are you going to cook, Lola?"},
	{"speaker": "Lola Nena", "text": "I’m making sinigang today, but there’s a lot to prepare. Will you help me get the ingredients ready?"},
	{"speaker": "Migs", "text": "Of course, Lola! Just tell me what to do first."}
]

const INGREDIENTS: Array[Dictionary] = [
	{"id": "bangus", "name": "Bangus", "instruction": "Prepare the bangus"},
	{"id": "kamatis", "name": "Kamatis", "instruction": "Wash the tomatoes"},
	{"id": "kangkong", "name": "Kangkong", "instruction": "Wash the kangkong"},
	{"id": "radish", "name": "Labanos (radish)", "instruction": "Wash the radish"},
	{"id": "talong", "name": "Talong", "instruction": "Wash the eggplant"},
	{"id": "peppers", "name": "Siling haba", "instruction": "Prepare the peppers"},
	{"id": "sinigang_mix", "name": "Sinigang mix", "instruction": "Set aside the sinigang mix"},
	{"id": "condiments", "name": "Seasonings", "instruction": "Gather the seasonings"},
	{"id": "water", "name": "Water", "instruction": "Measure the water using the cup"}
]


func can_start(hud: Node, lola: Sprite2D) -> bool:
	if hud == null or lola == null or not lola.visible:
		return false
	if not bool(hud.get_meta(HERITAGE_COMPLETED_META, false)):
		return false
	return not bool(hud.get_meta(KITCHEN_INTRO_COMPLETED_META, false))


func mark_intro_completed(hud: Node) -> void:
	if hud != null:
		hud.set_meta(KITCHEN_INTRO_COMPLETED_META, true)


func get_intro_dialogue() -> Array[Dictionary]:
	return INTRO_DIALOGUE.duplicate(true)


func get_ingredients() -> Array[Dictionary]:
	return INGREDIENTS.duplicate(true)


func get_progress(hud: Node) -> Dictionary:
	if hud == null:
		return {}
	var stored: Variant = hud.get_meta(KITCHEN_PROGRESS_META, {})
	return stored.duplicate(true) if stored is Dictionary else {}


func is_ingredient_prepared(hud: Node, ingredient_id: String) -> bool:
	return bool(get_progress(hud).get(ingredient_id, false))


func prepare_ingredient(hud: Node, ingredient_id: String) -> bool:
	if hud == null or bool(hud.get_meta(KITCHEN_TASK_COMPLETED_META, false)):
		return false
	var known_id := false
	for ingredient in INGREDIENTS:
		if str(ingredient.get("id", "")) == ingredient_id:
			known_id = true
			break
	if not known_id:
		return false
	var progress := get_progress(hud)
	if bool(progress.get(ingredient_id, false)):
		return false
	progress[ingredient_id] = true
	hud.set_meta(KITCHEN_PROGRESS_META, progress)
	return true


func get_prepared_count(hud: Node) -> int:
	var progress := get_progress(hud)
	var count := 0
	for ingredient in INGREDIENTS:
		if bool(progress.get(str(ingredient.get("id", "")), false)):
			count += 1
	return count


func is_task_completed(hud: Node) -> bool:
	return hud != null and bool(hud.get_meta(KITCHEN_TASK_COMPLETED_META, false))
