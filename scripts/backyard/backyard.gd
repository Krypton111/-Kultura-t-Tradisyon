extends Control
## Handles the three backyard entry routes and the salakot puzzle.

const DIALOGUE_SCENE_PATH := "res://game_scenes/UI scenes/dialogue.tscn"
const LIVING_ROOM_SCENE_PATH := "res://game_scenes/levels/living_room.tscn"

const POPUP_SIZE := Vector2(590, 320)

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

	# Once Migs has solved the sunlight problem, the backyard is available normally.
	if bool(_game_state.get_state("backyard_salakot_used", false)):
		return

	await get_tree().process_frame
	var has_salakot := bool(_game_state.get_state("salakot_reward_received", false)) and bool(_hud.call("has_inventory_item", "salakot"))
	var chores_explained := bool(_game_state.get_state("backyard_chore_instructions_given", false))

	# Route 3: Lola has already explained the chicken chores. Migs can now
	# think about the Sun and solve the salakot puzzle.
	if chores_explained and has_salakot:
		var lines: Array[Dictionary] = [
			{"speaker": "Migs", "text": "It’s hot outside, and the Sun is blocking my view."},
			{"speaker": "Migs", "text": "Do I have anything to help with the Sun?"}
		]
		_show_dialogue(lines, Callable(self, "_show_salakot_popup"))
		return

	# Route 2: Migs has the salakot, but Lola has not asked him to do the chores.
	if has_salakot:
		var lines: Array[Dictionary] = [
			{"speaker": "Migs", "text": "It’s too hot out here, and the Sun is blocking my sight! I should head back inside."},
			{"speaker": "Migs", "text": "I do have my salakot to help with the Sun, but Lola hasn’t asked me to do anything outside yet. There’s no reason for me to stay out here."}
		]
		_show_dialogue(lines, Callable(self, "_return_to_living_room"))
		return

	# Route 1: No salakot yet and Lola has not given the chicken chores.
	var lines: Array[Dictionary] = [
		{"speaker": "Migs", "text": "It’s too hot out here, and the Sun is blocking my sight! I should head back inside."}
	]
	_show_dialogue(lines, Callable(self, "_return_to_living_room"))


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
	_salakot_popup.name = "GoldenHourSunPuzzle"
	_salakot_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_salakot_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_salakot_popup.z_index = 1100
	_hud.add_child(_salakot_popup)

	var dimmer := ColorRect.new()
	dimmer.name = "WarmDimmer"
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.12, 0.075, 0.035, 0.48)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_salakot_popup.add_child(dimmer)

	var viewport_size := get_viewport().get_visible_rect().size
	var panel := Panel.new()
	panel.name = "GoldenHourPanel"
	panel.position = (viewport_size - POPUP_SIZE) * 0.5
	panel.size = POPUP_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.30, 0.205, 0.125, 0.99) # toasted walnut
	panel_style.border_color = Color(0.82, 0.63, 0.34, 1.0) # late-afternoon gold
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(18)
	panel_style.shadow_color = Color(0.08, 0.045, 0.02, 0.45)
	panel_style.shadow_size = 12
	panel_style.shadow_offset = Vector2(0, 5)
	panel.add_theme_stylebox_override("panel", panel_style)
	_salakot_popup.add_child(panel)

	var top_rule := ColorRect.new()
	top_rule.position = Vector2(26, 18)
	top_rule.size = Vector2(POPUP_SIZE.x - 52, 3)
	top_rule.color = Color(0.91, 0.73, 0.44, 0.95)
	top_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(top_rule)

	var heading := Label.new()
	heading.position = Vector2(30, 30)
	heading.size = Vector2(POPUP_SIZE.x - 60, 36)
	heading.text = "A Little Relief from the Sun"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color", Color(0.98, 0.86, 0.64, 1.0))
	heading.add_theme_font_size_override("font_size", 24)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(heading)

	var question := Label.new()
	question.position = Vector2(38, 75)
	question.size = Vector2(POPUP_SIZE.x - 76, 65)
	question.text = "The afternoon sun is fierce. Maybe something in my bag could help..."
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	question.add_theme_color_override("font_color", Color(0.98, 0.93, 0.83, 1.0))
	question.add_theme_font_size_override("font_size", 17)
	question.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(question)

	# An intentionally unlabeled inset lets the player infer which inventory item fits.
	_drop_target = Panel.new()
	_drop_target.name = "MysteriousItemDropArea"
	_drop_target.position = Vector2((POPUP_SIZE.x - 270.0) * 0.5, 153)
	_drop_target.size = Vector2(270, 82)
	_drop_target.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var target_style := StyleBoxFlat.new()
	target_style.bg_color = Color(0.16, 0.115, 0.075, 0.65)
	target_style.border_color = Color(0.88, 0.70, 0.43, 0.9)
	target_style.set_border_width_all(2)
	target_style.set_corner_radius_all(12)
	target_style.set_content_margin_all(8)
	_drop_target.add_theme_stylebox_override("panel", target_style)
	panel.add_child(_drop_target)

	_popup_status = Label.new()
	_popup_status.position = Vector2(25, 250)
	_popup_status.size = Vector2(POPUP_SIZE.x - 50, 34)
	_popup_status.text = "What could help Migs?"
	_popup_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_popup_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_popup_status.add_theme_color_override("font_color", Color(0.91, 0.78, 0.57, 1.0))
	_popup_status.add_theme_font_size_override("font_size", 15)
	_popup_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_popup_status)

	# Wait a frame so the centered panel and inset have their final global rects.
	await get_tree().process_frame
	if is_instance_valid(_drop_target) and _hud.has_method("set_inventory_drop_rect"):
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
			_popup_status.text = "Hmm... I don’t think that will help with the Sun."
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
		{"speaker": "Migs", "text": "My salakot! That should shield my eyes from the Sun. Now I can see where I’m going."}
	]
	_show_dialogue(lines)
