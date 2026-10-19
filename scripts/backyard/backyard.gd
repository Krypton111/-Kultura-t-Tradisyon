extends Control
## Handles the first outdoor visit and the salakot interaction.

const DIALOGUE_SCENE_PATH := "res://game_scenes/UI scenes/dialogue.tscn"
const LIVING_ROOM_SCENE_PATH := "res://game_scenes/levels/living_room.tscn"

const POPUP_POSITION := Vector2(300, 145)
const POPUP_SIZE := Vector2(540, 270)

var _hud: Node
var _game_state: Node
var _salakot_popup: Control
var _drop_target: Control
var _popup_status: Label


func _ready() -> void:
	_hud = get_node_or_null("/root/HUD")
	_game_state = get_node_or_null("/root/GameState")
	if _hud == null or _game_state == null:
		return

	# If Migs already used the salakot to shield his eyes, let him continue
	# exploring the backyard normally on later visits.
	if bool(_game_state.get_state("backyard_salakot_used", false)):
		return

	await get_tree().process_frame
	if not bool(_game_state.get_state("salakot_reward_received", false)) or not _hud.call("has_inventory_item", "salakot"):
		var lines: Array[Dictionary] = [
			{"speaker": "Migs", "text": "It’s too hot out here, and the Sun is blocking my sight! I can barely see anything."}
		]
		_show_dialogue(lines, Callable(self, "_return_to_living_room"))
	else:
		var lines: Array[Dictionary] = [
			{"speaker": "Migs", "text": "It’s so hot outside, and the Sun is blocking my view."},
			{"speaker": "Migs", "text": "Do I have anything to help with the Sun?"}
		]
		_show_dialogue(lines, Callable(self, "_show_salakot_popup"))


func _show_dialogue(lines: Array[Dictionary], finished_callback: Callable = Callable()) -> void:
	var packed := load(DIALOGUE_SCENE_PATH) as PackedScene
	if packed == null or _hud == null:
		push_warning("Backyard: could not load the dialogue scene.")
		return
	var dialogue := packed.instantiate() as Control
	if dialogue == null:
		return
	_hud.add_child(dialogue)
	if finished_callback.is_valid():
		dialogue.sequence_finished.connect(finished_callback)
	dialogue.call("start_custom_sequence", lines)


func _return_to_living_room() -> void:
	if _hud != null:
		_hud.set("navigation_locked", false)
		_hud.call("_change_scene", LIVING_ROOM_SCENE_PATH)


func _show_salakot_popup() -> void:
	if is_instance_valid(_salakot_popup) or _hud == null:
		return

	_hud.set("navigation_locked", true)
	_salakot_popup = Control.new()
	_salakot_popup.name = "SalakotSunPopup"
	_salakot_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_salakot_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_salakot_popup.z_index = 1100
	_hud.add_child(_salakot_popup)

	var dimmer := ColorRect.new()
	dimmer.name = "PopupDimmer"
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.04, 0.035, 0.025, 0.28)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_salakot_popup.add_child(dimmer)

	var panel := Panel.new()
	panel.name = "QuestionPanel"
	panel.position = POPUP_POSITION
	panel.size = POPUP_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.16, 0.13, 0.09, 0.98)
	panel_style.border_color = Color(0.78, 0.65, 0.40, 1.0)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", panel_style)
	_salakot_popup.add_child(panel)

	var question := Label.new()
	question.name = "Question"
	question.position = Vector2(28, 20)
	question.size = Vector2(484, 88)
	question.text = "Is there something I can use to protect myself from the Sun?\nDrag the salakot from your inventory into the box below."
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	question.add_theme_color_override("font_color", Color(0.98, 0.94, 0.82, 1.0))
	question.add_theme_font_size_override("font_size", 19)
	question.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(question)

	_drop_target = ColorRect.new()
	_drop_target.name = "SalakotDropTarget"
	_drop_target.position = Vector2(145, 125)
	_drop_target.size = Vector2(250, 62)
	_drop_target.color = Color(0.77, 0.64, 0.37, 0.32)
	_drop_target.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_drop_target)

	var target_label := Label.new()
	target_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	target_label.text = "DROP SALAKOT HERE"
	target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	target_label.add_theme_color_override("font_color", Color(1.0, 0.91, 0.69, 1.0))
	target_label.add_theme_font_size_override("font_size", 17)
	target_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drop_target.add_child(target_label)

	_popup_status = Label.new()
	_popup_status.position = Vector2(20, 198)
	_popup_status.size = Vector2(500, 40)
	_popup_status.text = "Choose the salakot in the inventory on the left."
	_popup_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_popup_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_popup_status.add_theme_color_override("font_color", Color(0.98, 0.94, 0.82, 1.0))
	_popup_status.add_theme_font_size_override("font_size", 15)
	_popup_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_popup_status)

	_hud.call("set_inventory_drop_rect", _drop_target.get_global_rect())
	if _hud.has_signal("inventory_item_dropped"):
		var drop_callable := Callable(self, "_on_inventory_item_dropped")
		if not _hud.is_connected("inventory_item_dropped", drop_callable):
			_hud.connect("inventory_item_dropped", drop_callable)


func _on_inventory_item_dropped(item_id: String) -> void:
	if not is_instance_valid(_salakot_popup):
		return
	if item_id != "salakot":
		if is_instance_valid(_popup_status):
			_popup_status.text = "That item will not block the Sun. Try the salakot."
		return

	if _game_state != null:
		_game_state.set_state("backyard_salakot_used", true)
	if _hud != null:
		_hud.call("set_inventory_drop_rect", Rect2())
	if is_instance_valid(_salakot_popup):
		_salakot_popup.queue_free()
	_salakot_popup = null
	_drop_target = null
	_popup_status = null

	var lines: Array[Dictionary] = [
		{"speaker": "Migs", "text": "The salakot should help shield my eyes from the Sun. Now I can see where I’m going!"}
	]
	_show_dialogue(lines)


func is_hovering_room_interactable(mouse_position: Vector2) -> bool:
	if is_instance_valid(_salakot_popup):
		return false
	return false
