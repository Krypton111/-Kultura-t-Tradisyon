extends Control
## Backyard object collection and seed-preparation flow.

const DIALOGUE_SCENE_PATH := "res://game_scenes/UI scenes/dialogue.tscn"
const LIVING_ROOM_SCENE_PATH := "res://game_scenes/levels/living_room.tscn"
const BASKET_TEXTURE: Texture2D = preload("res://GAME ASSETS/Backyard/outside scene/basket close up.png")
const CUPS_TEXTURE: Texture2D = preload("res://GAME ASSETS/Backyard/outside scene/cups close up.png")
const BASKET_WITH_SEEDS_TEXTURE: Texture2D = preload("res://GAME ASSETS/Backyard/outside scene/basket with seeds close up.png")
const CUPS_WITH_SEEDS_TEXTURE: Texture2D = preload("res://GAME ASSETS/Backyard/outside scene/cups with seeds close up.png")

const BASKET_ITEM_ID := "basket_close_up"
const CUPS_ITEM_ID := "cups_close_up"
const BASKET_WITH_SEEDS_ITEM_ID := "basket_with_seeds_close_up"
const CUPS_WITH_SEEDS_ITEM_ID := "cups_with_seeds_close_up"

var _hud: Node
var _game_state: Node
var _salakot_popup: Control
var _drop_target: Control
var _popup_status: Label
var _baskets_sprite: Sprite2D
var _cups_sprite: Sprite2D
var _yellow_seeds_sprite: Sprite2D
var _green_seeds_sprite: Sprite2D
var _tasks_enabled := false
var _collection_in_progress: Dictionary = {}
var _used_seed_targets: Dictionary = {}


func _ready() -> void:
	_hud = get_node_or_null("/root/HUD")
	_game_state = get_node_or_null("/root/GameState")
	_baskets_sprite = get_node_or_null("Baskets") as Sprite2D
	_cups_sprite = get_node_or_null("Cups") as Sprite2D
	_yellow_seeds_sprite = get_node_or_null("YellowSeeds") as Sprite2D
	_green_seeds_sprite = get_node_or_null("GreenSeeds") as Sprite2D
	if _hud == null or _game_state == null:
		return

	_restore_task_objects()
	_used_seed_targets = {
		"yellow_seeds": bool(_game_state.get_state("backyard_yellow_seeds_used", false)),
		"green_seeds": bool(_game_state.get_state("backyard_green_seeds_used", false))
	}

	if bool(_game_state.get_state("backyard_salakot_used", false)):
		_enable_backyard_tasks()
		return

	await get_tree().process_frame
	var has_salakot := bool(_game_state.get_state("salakot_reward_received", false)) and bool(_hud.call("has_inventory_item", "salakot"))
	var chores_explained := bool(_game_state.get_state("backyard_chore_instructions_given", false))

	if chores_explained and has_salakot:
		var route_three_lines: Array[Dictionary] = [
			{"speaker": "Migs", "text": "It’s hot outside, and the Sun is blocking my view."},
			{"speaker": "Migs", "text": "Do I have anything to help with the Sun?"}
		]
		_show_dialogue(route_three_lines, Callable(self, "_show_salakot_popup"))
		return

	if has_salakot:
		var route_two_lines: Array[Dictionary] = [
			{"speaker": "Migs", "text": "It’s too hot out here, and the Sun is blocking my sight! I should head back inside."},
			{"speaker": "Migs", "text": "I do have my salakot to help with the Sun, but Lola hasn’t asked me to do anything outside yet. There’s no reason for me to stay out here."}
		]
		_show_dialogue(route_two_lines, Callable(self, "_return_to_living_room"))
		return

	var route_one_lines: Array[Dictionary] = [
		{"speaker": "Migs", "text": "It’s too hot out here, and the Sun is blocking my sight! I should head back inside."}
	]
	_show_dialogue(route_one_lines, Callable(self, "_return_to_living_room"))


func _restore_task_objects() -> void:
	if _baskets_sprite != null and bool(_game_state.get_state("backyard_basket_collected", false)):
		_baskets_sprite.visible = false
	if _cups_sprite != null and bool(_game_state.get_state("backyard_cups_collected", false)):
		_cups_sprite.visible = false
	if _yellow_seeds_sprite != null and bool(_game_state.get_state("backyard_yellow_seeds_used", false)):
		_yellow_seeds_sprite.visible = false
	if _green_seeds_sprite != null and bool(_game_state.get_state("backyard_green_seeds_used", false)):
		_green_seeds_sprite.visible = false


func _show_dialogue(lines: Array[Dictionary], finished_callback: Callable = Callable()) -> void:
	var packed := load(DIALOGUE_SCENE_PATH) as PackedScene
	if packed == null or _hud == null:
		push_warning("Backyard: could not load the dialogue scene.")
		if finished_callback.is_valid():
			finished_callback.call()
		return
	var dialogue := packed.instantiate() as Control
	if dialogue == null:
		return
	_hud.set("navigation_locked", true)
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
	var popup_size := Vector2(590, 320)
	var panel := Panel.new()
	panel.name = "GoldenHourPanel"
	panel.position = (viewport_size - popup_size) * 0.5
	panel.size = popup_size
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.30, 0.205, 0.125, 0.99)
	panel_style.border_color = Color(0.82, 0.63, 0.34, 1.0)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(18)
	panel_style.shadow_color = Color(0.08, 0.045, 0.02, 0.45)
	panel_style.shadow_size = 12
	panel_style.shadow_offset = Vector2(0, 5)
	panel.add_theme_stylebox_override("panel", panel_style)
	_salakot_popup.add_child(panel)

	var top_rule := ColorRect.new()
	top_rule.position = Vector2(26, 18)
	top_rule.size = Vector2(popup_size.x - 52, 3)
	top_rule.color = Color(0.91, 0.73, 0.44, 0.95)
	top_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(top_rule)

	var heading := Label.new()
	heading.position = Vector2(30, 30)
	heading.size = Vector2(popup_size.x - 60, 36)
	heading.text = "A Little Relief from the Sun"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color", Color(0.98, 0.86, 0.64, 1.0))
	heading.add_theme_font_size_override("font_size", 24)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(heading)

	var question := Label.new()
	question.position = Vector2(38, 75)
	question.size = Vector2(popup_size.x - 76, 65)
	question.text = "The afternoon sun is fierce. Maybe something in my bag could help..."
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	question.add_theme_color_override("font_color", Color(0.98, 0.93, 0.83, 1.0))
	question.add_theme_font_size_override("font_size", 17)
	question.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(question)

	_drop_target = Panel.new()
	_drop_target.name = "MysteriousItemDropArea"
	_drop_target.position = Vector2((popup_size.x - 270.0) * 0.5, 153)
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
	_popup_status.size = Vector2(popup_size.x - 50, 34)
	_popup_status.text = "What could help Migs?"
	_popup_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_popup_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_popup_status.add_theme_color_override("font_color", Color(0.91, 0.78, 0.57, 1.0))
	_popup_status.add_theme_font_size_override("font_size", 15)
	_popup_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_popup_status)

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

	var success_lines: Array[Dictionary] = [
		{"speaker": "Migs", "text": "My salakot! That should shield my eyes from the Sun. Now I can see where I’m going."}
	]
	_show_dialogue(success_lines, Callable(self, "_on_sun_puzzle_dialogue_finished"))


func _on_sun_puzzle_dialogue_finished() -> void:
	if _hud != null:
		_hud.set("navigation_locked", false)
	_enable_backyard_tasks()


func _enable_backyard_tasks() -> void:
	_tasks_enabled = true
	if _hud == null:
		return
	_hud.call("set_inventory_drop_rect", Rect2())
	_refresh_seed_drop_targets()


func _refresh_seed_drop_targets() -> void:
	if _hud == null:
		return
	var targets: Dictionary = {}
	if _yellow_seeds_sprite != null and _yellow_seeds_sprite.visible and not bool(_used_seed_targets.get("yellow_seeds", false)):
		targets["yellow_seeds"] = _sprite_opaque_bounds_in_viewport(_yellow_seeds_sprite)
	if _green_seeds_sprite != null and _green_seeds_sprite.visible and not bool(_used_seed_targets.get("green_seeds", false)):
		targets["green_seeds"] = _sprite_opaque_bounds_in_viewport(_green_seeds_sprite)
	_hud.call("set_inventory_drop_targets", targets)
	if _hud.has_signal("inventory_item_dropped_on_target"):
		var target_callable := Callable(self, "_on_inventory_item_dropped_on_target")
		if not _hud.is_connected("inventory_item_dropped_on_target", target_callable):
			_hud.connect("inventory_item_dropped_on_target", target_callable)


func is_hovering_room_interactable(mouse_position: Vector2) -> bool:
	if not _tasks_enabled or (_hud != null and bool(_hud.get("navigation_locked"))):
		return false
	for sprite in [_baskets_sprite, _cups_sprite]:
		if sprite == null or not sprite.visible:
			continue
		if _sprite_pixel_hit(sprite, mouse_position):
			return true
	return false


func _input(event: InputEvent) -> void:
	if not _tasks_enabled or not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	if _hud != null and bool(_hud.get("navigation_locked")):
		return

	var mouse_position := get_global_mouse_position()
	for sprite in [_cups_sprite, _baskets_sprite]:
		if sprite == null or not sprite.visible:
			continue
		if _sprite_pixel_hit(sprite, mouse_position):
			if sprite == _cups_sprite:
				_collect_backyard_item(sprite, CUPS_ITEM_ID, "Cups", CUPS_TEXTURE, "backyard_cups_collected")
			else:
				_collect_backyard_item(sprite, BASKET_ITEM_ID, "Basket", BASKET_TEXTURE, "backyard_basket_collected")
			get_viewport().set_input_as_handled()
			return


func _collect_backyard_item(sprite: Sprite2D, item_id: String, display_name: String, inventory_texture: Texture2D, state_key: String) -> void:
	if bool(_collection_in_progress.get(item_id, false)) or not sprite.visible:
		return
	_collection_in_progress[item_id] = true
	_game_state.set_state(state_key, true)
	var fade_out := create_tween()
	fade_out.tween_property(sprite, "modulate:a", 0.0, 0.42)
	await fade_out.finished
	sprite.visible = false
	sprite.modulate.a = 1.0
	if _hud != null and _hud.has_method("add_inventory_item"):
		_hud.call("add_inventory_item", item_id, display_name, inventory_texture)
	_collection_in_progress[item_id] = false


func _on_inventory_item_dropped_on_target(item_id: String, target_id: String) -> void:
	if not _tasks_enabled or _hud == null:
		return

	if target_id == "yellow_seeds" and item_id == CUPS_ITEM_ID:
		if _transform_inventory_item(CUPS_ITEM_ID, CUPS_WITH_SEEDS_ITEM_ID, "Cups with Seeds", CUPS_WITH_SEEDS_TEXTURE):
			_used_seed_targets["yellow_seeds"] = true
			_game_state.set_state("backyard_yellow_seeds_used", true)
			await _fade_seed_pile(_yellow_seeds_sprite)
			_refresh_seed_drop_targets()
		return

	if target_id == "green_seeds" and item_id == BASKET_ITEM_ID:
		if _transform_inventory_item(BASKET_ITEM_ID, BASKET_WITH_SEEDS_ITEM_ID, "Basket with Seeds", BASKET_WITH_SEEDS_TEXTURE):
			_used_seed_targets["green_seeds"] = true
			_game_state.set_state("backyard_green_seeds_used", true)
			await _fade_seed_pile(_green_seeds_sprite)
			_refresh_seed_drop_targets()
		return

	_show_hint("That doesn’t seem to be the right match.")


func _transform_inventory_item(old_item_id: String, new_item_id: String, display_name: String, new_texture: Texture2D) -> bool:
	if _hud == null or not _hud.has_method("transform_inventory_item"):
		return false
	return bool(_hud.call("transform_inventory_item", old_item_id, new_item_id, display_name, new_texture))


func _fade_seed_pile(sprite: Sprite2D) -> void:
	if sprite == null or not sprite.visible:
		return
	var fade := create_tween()
	fade.tween_property(sprite, "modulate:a", 0.0, 0.35)
	await fade.finished
	sprite.visible = false
	sprite.modulate.a = 1.0


func _sprite_pixel_hit(sprite: Sprite2D, viewport_position: Vector2) -> bool:
	if sprite.texture == null or not sprite.visible:
		return false
	var local_position := sprite.to_local(viewport_position)
	var rect := sprite.get_rect()
	if not rect.has_point(local_position):
		return false
	var texture_image := sprite.texture.get_image()
	if texture_image == null or texture_image.is_empty():
		return true
	var uv := (local_position - rect.position) / rect.size
	var px := clampi(int(uv.x * texture_image.get_width()), 0, texture_image.get_width() - 1)
	var py := clampi(int(uv.y * texture_image.get_height()), 0, texture_image.get_height() - 1)
	return texture_image.get_pixel(px, py).a > 0.12


func _sprite_opaque_bounds_in_viewport(sprite: Sprite2D) -> Rect2:
	if sprite.texture == null:
		return Rect2()
	var image := sprite.texture.get_image()
	if image == null or image.is_empty():
		return Rect2()
	var used_rect := image.get_used_rect()
	if used_rect.size == Vector2i.ZERO:
		return Rect2()
	var local_rect := Rect2(sprite.get_rect().position + Vector2(used_rect.position), Vector2(used_rect.size))
	var canvas_transform := sprite.get_global_transform_with_canvas()
	var top_left := canvas_transform * local_rect.position
	var bottom_right := canvas_transform * (local_rect.position + local_rect.size)
	return Rect2(top_left, bottom_right - top_left)


func _show_hint(message: String) -> void:
	var hint := Label.new()
	hint.name = "BackyardTaskHint"
	hint.position = Vector2(350, 565)
	hint.size = Vector2(450, 42)
	hint.text = message
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.98, 0.86, 0.64, 1.0))
	hint.add_theme_font_size_override("font_size", 18)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.z_index = 500
	add_child(hint)
	var tween := create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(hint, "modulate:a", 0.0, 0.45)
	tween.tween_callback(hint.queue_free)


func _exit_tree() -> void:
	if _hud != null and is_instance_valid(_hud):
		if _hud.has_method("set_inventory_drop_targets"):
			_hud.call("set_inventory_drop_targets", {})
		if _hud.has_method("set_inventory_drop_rect"):
			_hud.call("set_inventory_drop_rect", Rect2())
