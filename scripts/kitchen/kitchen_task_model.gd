extends RefCounted
class_name KitchenTaskModel
## Data and rules for preparing Lola Nena's sinigang ingredients.
## The controller/view never decides whether the task is complete.

const HERITAGE_COMPLETED_META := "living_room_heritage_completed"
const KITCHEN_INTRO_COMPLETED_META := "kitchen_task_intro_completed"
const KITCHEN_TASK_COMPLETED_META := "kitchen_ingredient_task_completed"
const KITCHEN_PROGRESS_META := "kitchen_ingredient_progress"

func _state() -> Node:
	var scene_tree := Engine.get_main_loop() as SceneTree
	if scene_tree == null:
		return null
	return scene_tree.root.get_node_or_null("GameState")
const RECIPE_TEXTURE_PATH := "res://GAME ASSETS/Kitchen/lola's recipe.png"

const INTRO_DIALOGUE: Array[Dictionary] = [
	{"speaker": "Lola Nena", "text": "Migs, just in time! I need to start preparing lunch."},
	{"speaker": "Migs", "text": "What are you going to cook, Lola?"},
	{"speaker": "Lola Nena", "text": "I’m making sinigang na bangus today, but there’s a lot to prepare. Will you help me get the ingredients ready?"},
	{"speaker": "Lola Nena", "text": "I’ve put my sinigang na bangus recipe on the side of the refrigerator. You can check it to see which ingredients we need before you start gathering them."},
	{"speaker": "Migs", "text": "Got it, Lola! I’ll check the recipe on the refrigerator first so I know what to look for."}
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
	var state := _state()
	if state == null or not bool(state.get_state(HERITAGE_COMPLETED_META, false)):
		return false
	return not bool(state.get_state(KITCHEN_INTRO_COMPLETED_META, false))


func mark_intro_completed(hud: Node) -> void:
	var state := _state()
	if state != null:
		state.set_state(KITCHEN_INTRO_COMPLETED_META, true)


func get_intro_dialogue() -> Array[Dictionary]:
	return INTRO_DIALOGUE.duplicate(true)


func get_ingredients() -> Array[Dictionary]:
	return INGREDIENTS.duplicate(true)


func get_progress(hud: Node) -> Dictionary:
	var state := _state()
	if state == null:
		return {}
	var stored: Variant = state.get_state(KITCHEN_PROGRESS_META, {})
	return stored.duplicate(true) if stored is Dictionary else {}


func is_ingredient_prepared(hud: Node, ingredient_id: String) -> bool:
	return bool(get_progress(hud).get(ingredient_id, false))


func prepare_ingredient(hud: Node, ingredient_id: String) -> bool:
	var state := _state()
	if state == null or bool(state.get_state(KITCHEN_TASK_COMPLETED_META, false)):
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
	state.set_state(KITCHEN_PROGRESS_META, progress)
	return true


func get_prepared_count(hud: Node) -> int:
	var progress := get_progress(hud)
	var count := 0
	for ingredient in INGREDIENTS:
		if bool(progress.get(str(ingredient.get("id", "")), false)):
			count += 1
	return count


func is_task_completed(hud: Node) -> bool:
	var state := _state()
	return state != null and bool(state.get_state(KITCHEN_TASK_COMPLETED_META, false))
