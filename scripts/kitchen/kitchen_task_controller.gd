extends Node
## Coordinates the kitchen task introduction.
## The model owns task dialogue/prerequisites; the existing dialogue scene is the view.

const KitchenTaskModelScript = preload("res://scripts/kitchen/kitchen_task_model.gd")
const DIALOGUE_SCENE_PATH := "res://game_scenes/UI scenes/dialogue.tscn"

var task_model = KitchenTaskModelScript.new()
var _dialogue_view: Control


func _ready() -> void:
	# Let the kitchen scene controller finish setting Lola's visibility first.
	await get_tree().process_frame
	_try_start_task_introduction()


func _try_start_task_introduction() -> void:
	var hud := get_node_or_null("/root/HUD")
	var kitchen := get_parent()
	var lola := kitchen.get_node_or_null("LolaNenaStanding") as Sprite2D if kitchen != null else null

	if not task_model.can_start(hud, lola):
		return

	var dialogue_scene := load(DIALOGUE_SCENE_PATH) as PackedScene
	if dialogue_scene == null:
		push_warning("Kitchen task: could not load the dialogue scene.")
		return

	_dialogue_view = dialogue_scene.instantiate() as Control
	if _dialogue_view == null:
		push_warning("Kitchen task: dialogue scene root must be a Control.")
		return

	_dialogue_view.sequence_finished.connect(_on_introduction_finished)
	hud.add_child(_dialogue_view)
	_dialogue_view.call("start_custom_sequence", task_model.get_intro_dialogue())


func _on_introduction_finished() -> void:
	var hud := get_node_or_null("/root/HUD")
	task_model.mark_completed(hud)
	_dialogue_view = null
