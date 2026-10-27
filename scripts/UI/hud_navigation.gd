extends CanvasLayer

const LEFT_NAV_WIDTH := 90.0
const LEFT_NAV_HEIGHT := 800.0
const RIGHT_NAV_WIDTH := 160.0
const RIGHT_NAV_HEIGHT := 300.0
const DOWN_NAV_WIDTH := 450.0
const DOWN_NAV_HEIGHT := 100.0

const LEFT_NAV_POSITION := Vector2(180.0, 265.0)
const RIGHT_NAV_POSITION := Vector2(1104.0, 263.0)
const DOWN_NAV_POSITION := Vector2(566.5, 607.0)

const CURSOR_MAX_SIZE := 96.0
const DOWN_CURSOR_MAX_SIZE := 160.0

const LEFT_CURSOR := preload("res://GAME ASSETS/UI/HUD/left room.png")
const RIGHT_CURSOR := preload("res://GAME ASSETS/UI/HUD/right room.png")
const DOWN_CURSOR := preload("res://GAME ASSETS/UI/HUD/bottom room.png")
const MAGNIFY_CURSOR := preload("res://GAME ASSETS/UI/HUD/magnifying_cursor.png")
const FOOTSTEPS_SFX := preload("res://GAME ASSETS/SFX/footsteps.mp3")
const INVENTORY_ITEM_NAME_FONT: FontFile = preload("res://GAME ASSETS/UI/borgers_script/BorgersScript_PERSONAL_USE_ONLY.otf")
const SETTINGS_MENU_TEXTURE: Texture2D = preload("res://GAME ASSETS/UI/HUD/settings menu.png")
const SLIDER_KNOB_TEXTURE: Texture2D = preload("res://GAME ASSETS/UI/HUD/knob for slider.png")
const INVENTORY_ITEM_FADE_DURATION := 0.45

const LIVING_ROOM := "res://game_scenes/levels/living_room.tscn"
const KITCHEN := "res://game_scenes/levels/kitchen.tscn"
const MIGS_ROOM := "res://game_scenes/levels/migs_room.tscn"
const BACKYARD := "res://game_scenes/levels/backyard.tscn"
const CHICKEN_COOP := "res://game_scenes/levels/chicken coop.tscn"
const JOURNAL_SCENE: PackedScene = preload("res://game_scenes/UI scenes/journal.tscn")

var current_direction := ""
var navigation_locked := false
var left_cursor: Texture2D
var right_cursor: Texture2D
var down_cursor: Texture2D
var magnify_cursor: Texture2D
var visible_cursor_sprite: Sprite2D
var fade_rect: ColorRect
var fade_tween: Tween
var footsteps_player: AudioStreamPlayer
var journal_is_open := false
var _journal_previous_navigation_locked := false
var journal_overlay_instance: Control
var journal_close: Sprite2D
var journal_open: Sprite2D
var camera_icon: Sprite2D
var camera_collected := false
var journal_collected := false
var heritage_entries: Array[Dictionary] = []

var inventory_items: Array[Dictionary] = []
var inventory_fade_in_ids: Array[String] = []
var inventory_slot_nodes: Array[Control] = []
var inventory_page := 0
var inventory_up_button: Button
var inventory_down_button: Button
var inventory_drag_id := ""
var inventory_drag_icon: Sprite2D
var inventory_drop_rect := Rect2()
signal inventory_item_dropped(item_id: String)
signal inventory_item_dropped_on_target(item_id: String, target_id: String)
var inventory_drop_targets: Dictionary = {}
var backyard_modal_open := false

var room_scenes := {
	LIVING_ROOM: preload("res://game_scenes/levels/living_room.tscn"),
	KITCHEN: preload("res://game_scenes/levels/kitchen.tscn"),
	MIGS_ROOM: preload("res://game_scenes/levels/migs_room.tscn"),
	BACKYARD: preload("res://game_scenes/levels/backyard.tscn"),
	CHICKEN_COOP: preload("res://game_scenes/levels/chicken coop.tscn")
}

func _ready() -> void:
	# The persistent HUD must remain responsive while gameplay is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null:
		inventory_items.assign(game_state.get_state("inventory_items", []))
		heritage_entries.assign(game_state.get_state("heritage_entries", []))
		camera_collected = bool(game_state.get_state("camera_collected", false))
		journal_collected = bool(game_state.get_state("journal_collected", false))
	left_cursor = _prepare_cursor(LEFT_CURSOR)
	right_cursor = _prepare_cursor(RIGHT_CURSOR)
	down_cursor = _prepare_cursor(DOWN_CURSOR, DOWN_CURSOR_MAX_SIZE)
	magnify_cursor = _prepare_cursor(MAGNIFY_CURSOR)

	_create_navigation_button("LeftNavigation", LEFT_NAV_POSITION, Callable(self, "_go_left"))
	_create_navigation_button("RightNavigation", RIGHT_NAV_POSITION, Callable(self, "_go_right"))
	_create_navigation_button("DownNavigation", DOWN_NAV_POSITION, Callable(self, "_go_down"))
	# Sprite fallback for HTML5 embeds that ignore native custom cursors.
	visible_cursor_sprite = Sprite2D.new()
	visible_cursor_sprite.name = "VisibleCustomCursorFallback"
	visible_cursor_sprite.centered = true
	visible_cursor_sprite.z_index = 2000
	visible_cursor_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible_cursor_sprite.visible = false
	add_child(visible_cursor_sprite)

	get_viewport().size_changed.connect(_on_viewport_resized)
	_create_fade_overlay()
	_resize_navigation_buttons()
	_create_footsteps_player()
	_setup_journal_toggle()
	_setup_inventory_ui()
	_setup_pause_menu()
	_set_brightness(brightness_level)
	# Apply the saved music level once at startup. Do not traverse the entire
	# scene tree every frame just to reapply an unchanged volume.
	_apply_music_volume_to_all_players()
	var tree := get_tree()
	if not tree.node_added.is_connected(_on_tree_node_added):
		tree.node_added.connect(_on_tree_node_added)


func _setup_inventory_ui() -> void:
	inventory_slot_nodes.clear()
	# Discover item1, item2, item3... from HUD.tscn automatically.
	var slot_candidates: Array[Control] = []
	for child in get_children():
		if child is Control and str(child.name).begins_with("item"):
			var suffix := str(child.name).trim_prefix("item")
			if suffix.is_valid_int():
				slot_candidates.append(child as Control)
	slot_candidates.sort_custom(func(a: Control, b: Control) -> bool:
		return int(str(a.name).trim_prefix("item")) < int(str(b.name).trim_prefix("item"))
	)
	for slot in slot_candidates:
		inventory_slot_nodes.append(slot)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		var slot_callable := Callable(self, "_on_inventory_slot_gui_input").bind(slot)
		if not slot.gui_input.is_connected(slot_callable):
			slot.gui_input.connect(slot_callable)
	_setup_inventory_page_buttons()
	_refresh_inventory_ui()


func _setup_inventory_page_buttons() -> void:
	var up_area := get_node_or_null("up") as Control
	var down_area := get_node_or_null("down") as Control
	if up_area != null:
		inventory_up_button = _make_inventory_arrow_button("InventoryUpButton", up_area, -1)
	if down_area != null:
		inventory_down_button = _make_inventory_arrow_button("InventoryDownButton", down_area, 1)
	_update_inventory_page_buttons()


func _make_inventory_arrow_button(button_name: String, area: Control, page_step: int) -> Button:
	var button := Button.new()
	button.name = button_name
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.text = ""
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for style_name in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	button.pressed.connect(func():
		inventory_page = clampi(inventory_page + page_step, 0, _inventory_page_count() - 1)
		_refresh_inventory_ui()
	)
	area.add_child(button)
	return button


func add_inventory_item(item_id: String, item_name: String, item_texture: Texture2D) -> bool:
	for existing in inventory_items:
		if str(existing.get("id", "")) == item_id:
			return false
	inventory_items.append({"id": item_id, "name": item_name, "texture": item_texture})
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null:
		game_state.set_state("inventory_items", inventory_items)
	inventory_fade_in_ids.append(item_id)
	_refresh_inventory_ui()
	return true


func has_inventory_item(item_id: String) -> bool:
	for item in inventory_items:
		if str(item.get("id", "")) == item_id:
			return true
	return false


func remove_inventory_item(item_id: String) -> bool:
	for i in range(inventory_items.size()):
		if str(inventory_items[i].get("id", "")) == item_id:
			inventory_items.remove_at(i)
			var game_state := get_node_or_null("/root/GameState")
			if game_state != null:
				game_state.set_state("inventory_items", inventory_items)
			inventory_page = clampi(inventory_page, 0, _inventory_page_count() - 1)
			_refresh_inventory_ui()
			return true
	return false


func set_backyard_modal_open(is_open: bool) -> void:
	backyard_modal_open = is_open

func set_inventory_drop_rect(drop_rect: Rect2) -> void:
	inventory_drop_rect = drop_rect


func set_inventory_drop_targets(targets: Dictionary) -> void:
	inventory_drop_targets = targets.duplicate(true)


func transform_inventory_item(old_item_id: String, new_item_id: String, item_name: String, item_texture: Texture2D) -> bool:
	var old_index := -1
	for i in range(inventory_items.size()):
		if str(inventory_items[i].get("id", "")) == old_item_id:
			old_index = i
			break
	if old_index < 0:
		return false
	for existing in inventory_items:
		if str(existing.get("id", "")) == new_item_id:
			return false
	inventory_items[old_index] = {"id": new_item_id, "name": item_name, "texture": item_texture}
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null:
		game_state.set_state("inventory_items", inventory_items)
	inventory_fade_in_ids.append(new_item_id)
	_refresh_inventory_ui()
	return true


func _inventory_page_count() -> int:
	return maxi(1, ceili(float(inventory_items.size()) / float(maxi(1, inventory_slot_nodes.size()))))


func _update_inventory_page_buttons() -> void:
	var page_count := _inventory_page_count()
	if inventory_up_button != null:
		inventory_up_button.visible = inventory_items.size() > inventory_slot_nodes.size() and inventory_page > 0
	if inventory_down_button != null:
		inventory_down_button.visible = inventory_items.size() > inventory_slot_nodes.size() and inventory_page < page_count - 1


func _refresh_inventory_ui() -> void:
	for slot in inventory_slot_nodes:
		for child in slot.get_children():
			child.queue_free()
	for i in range(inventory_slot_nodes.size()):
		if i >= inventory_slot_nodes.size():
			break
		var item_index := inventory_page * inventory_slot_nodes.size() + i
		var slot := inventory_slot_nodes[i]
		slot.visible = true
		if item_index >= inventory_items.size():
			continue
		var item: Dictionary = inventory_items[item_index]
		var icon_rect := TextureRect.new()
		icon_rect.name = "InventoryItemIcon"
		icon_rect.texture = item.get("texture") as Texture2D
		icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		# Give the salakot artwork a little more room than standard inventory icons.
		if str(item.get("id", "")) == "salakot":
			icon_rect.offset_left = 2
			icon_rect.offset_top = 0
			icon_rect.offset_right = -2
			icon_rect.offset_bottom = -18
		else:
			icon_rect.offset_left = 8
			icon_rect.offset_top = 5
			icon_rect.offset_right = -8
			icon_rect.offset_bottom = -20
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon_rect)
		var label := Label.new()
		label.text = str(item.get("name", ""))
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.offset_left = 2
		label.offset_right = -2
		label.offset_top = 54
		label.offset_bottom = 0
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_override("font", INVENTORY_ITEM_NAME_FONT)
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(label)

		# Newly collected ingredients fade in together with their inventory names.
		var item_id := str(item.get("id", ""))
		if inventory_fade_in_ids.has(item_id):
			icon_rect.modulate.a = 0.0
			label.modulate.a = 0.0
			var item_fade_tween := create_tween().set_parallel(true)
			item_fade_tween.tween_property(icon_rect, "modulate:a", 1.0, INVENTORY_ITEM_FADE_DURATION)
			item_fade_tween.tween_property(label, "modulate:a", 1.0, INVENTORY_ITEM_FADE_DURATION)
			inventory_fade_in_ids.erase(item_id)
	_update_inventory_page_buttons()


func _on_inventory_slot_gui_input(event: InputEvent, slot: Control) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var slot_index := inventory_slot_nodes.find(slot)
		var item_index := inventory_page * inventory_slot_nodes.size() + slot_index
		if slot_index >= 0 and item_index < inventory_items.size():
			_begin_inventory_drag(inventory_items[item_index])


func _begin_inventory_drag(item: Dictionary) -> void:
	inventory_drag_id = str(item.get("id", ""))
	if is_instance_valid(inventory_drag_icon):
		inventory_drag_icon.queue_free()

	# Use a Sprite2D rather than a TextureRect so Control anchors/layout cannot
	# stretch the dragged close-up across the screen. Scale the original texture
	# proportionally to a small on-screen preview without downsampling it.
	inventory_drag_icon = Sprite2D.new()
	inventory_drag_icon.name = "InventoryDragIcon"
	inventory_drag_icon.texture = item.get("texture") as Texture2D
	inventory_drag_icon.centered = true
	inventory_drag_icon.z_index = 1200
	inventory_drag_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var source_texture := inventory_drag_icon.texture
	if source_texture != null:
		var largest_dimension := float(maxi(source_texture.get_width(), source_texture.get_height()))
		if largest_dimension > 0.0:
			inventory_drag_icon.scale = Vector2.ONE * (82.0 / largest_dimension)
	add_child(inventory_drag_icon)
	var pickup_tween := create_tween()
	inventory_drag_icon.scale = Vector2.ZERO
	pickup_tween.tween_property(inventory_drag_icon, "scale", Vector2.ONE * (82.0 / maxf(1.0, float(maxi(source_texture.get_width(), source_texture.get_height())))), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) if source_texture != null else pickup_tween.tween_property(inventory_drag_icon, "scale", Vector2.ONE, 0.12)
	_update_inventory_drag_position()


func _update_inventory_drag_position() -> void:
	if not is_instance_valid(inventory_drag_icon):
		return
	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	# HUD is a CanvasLayer, so use viewport mouse coordinates directly.
	inventory_drag_icon.position = mouse_position

func _finish_inventory_drag() -> void:
	if inventory_drag_id == "":
		return
	var item_id := inventory_drag_id
	inventory_drag_id = ""
	if is_instance_valid(inventory_drag_icon):
		inventory_drag_icon.queue_free()
	inventory_drag_icon = null
	var drop_position := get_viewport().get_mouse_position()
	for target_id in inventory_drop_targets.keys():
		var target_rect: Rect2 = inventory_drop_targets[target_id]
		if target_rect.has_point(drop_position):
			inventory_item_dropped_on_target.emit(item_id, str(target_id))
			return
	if inventory_drop_rect.has_point(drop_position):
		inventory_item_dropped.emit(item_id)




func _process(_delta: float) -> void:
	if pause_menu_open:
		return
	_update_journal_hover()
	if is_instance_valid(inventory_drag_icon):
		_update_inventory_drag_position()

	if navigation_locked:
		return

	# The chicken-coop scene owns its bottom return arrow and its cursor.
	# Do not let the persistent HUD clear or overwrite that scene-specific cursor.
	var active_scene := get_tree().current_scene
	if active_scene != null and active_scene.scene_file_path == CHICKEN_COOP:
		return

	_update_cursor(get_viewport().get_mouse_position())
	if is_instance_valid(visible_cursor_sprite) and visible_cursor_sprite.visible:
		visible_cursor_sprite.position = get_viewport().get_mouse_position()

func _setup_journal_toggle() -> void:
	journal_close = get_node_or_null("JournalClose") as Sprite2D
	journal_open = get_node_or_null("JournalOpen") as Sprite2D
	camera_icon = get_node_or_null("Camera") as Sprite2D

	journal_is_open = false
	if journal_close:
		journal_close.visible = false
	if journal_open:
		journal_open.visible = false
	if camera_icon:
		camera_icon.visible = false
	if journal_collected and journal_close != null:
		journal_close.visible = true
	if camera_collected and camera_icon != null:
		camera_icon.visible = true

func reveal_journal() -> void:
	journal_collected = true
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null:
		game_state.set_state("journal_collected", true)
	if journal_close == null or journal_open == null:
		return
	journal_is_open = false
	journal_close.visible = false
	journal_open.visible = false
	_fade_hud_sprite_in(journal_close)

func record_heritage_entry(entry_title: String, entry_text: String, object_name: String = "") -> void:
	for existing in heritage_entries:
		if str(existing.get("title", "")) == entry_title:
			return
	heritage_entries.append({"title": entry_title, "text": entry_text, "object_name": object_name, "photo_path": ""})
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null:
		game_state.set_state("heritage_entries", heritage_entries)


func attach_heritage_photo(entry_title: String, texture_path: String) -> bool:
	if entry_title.is_empty() or texture_path.is_empty():
		return false
	for entry in heritage_entries:
		if str(entry.get("title", "")) == entry_title:
			entry["photo_path"] = texture_path
			var game_state := get_node_or_null("/root/GameState")
			if game_state != null:
				game_state.set_state("heritage_entries", heritage_entries)
			return true
	return false

func record_heritage_entry_with_photo(entry_title: String, entry_text: String, object_name: String, texture_path: String) -> void:
	if entry_title.is_empty():
		return
	var found := false
	for entry in heritage_entries:
		if str(entry.get("title", "")) == entry_title:
			entry["text"] = entry_text
			entry["object_name"] = object_name
			entry["photo_path"] = texture_path
			found = true
			break
	if not found:
		heritage_entries.append({"title": entry_title, "text": entry_text, "object_name": object_name, "photo_path": texture_path})
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null:
		game_state.set_state("heritage_entries", heritage_entries)


func show_journal_notification(item_name: String) -> void:
	if item_name.is_empty():
		return
	var existing := get_node_or_null("JournalNotification")
	if existing != null:
		existing.queue_free()
	var panel := PanelContainer.new()
	panel.name = "JournalNotification"
	panel.position = Vector2(350, 505)
	panel.size = Vector2(500, 54)
	panel.z_index = 1900
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.13, 0.08, 0.94)
	style.border_color = Color(0.78, 0.61, 0.35, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = "Journal updated: " + item_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.98, 0.91, 0.75))
	panel.add_child(label)
	add_child(panel)
	panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.2)
	tween.tween_interval(2.8)
	tween.tween_property(panel, "modulate:a", 0.0, 0.35)
	tween.tween_callback(panel.queue_free)

func reveal_camera() -> void:
	camera_collected = true
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null:
		game_state.set_state("camera_collected", true)
	if camera_icon:
		_fade_hud_sprite_in(camera_icon)

func has_collected_room_items() -> bool:
	return camera_collected and journal_collected

func has_collected_camera() -> bool:
	return camera_collected

func has_collected_journal() -> bool:
	return journal_collected

func _fade_hud_sprite_in(sprite: Sprite2D) -> void:
	if sprite == null:
		return

	sprite.visible = true
	sprite.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 1.0, 0.4)

func _update_journal_hover() -> void:
	if journal_close == null or journal_open == null or journal_is_open:
		return
	if not journal_close.visible and not journal_open.visible:
		return

	var hovering := _is_hovering_journal()
	journal_close.visible = not hovering
	journal_open.visible = hovering

func _is_hovering_camera_target(mouse_position: Vector2) -> bool:
	var camera_controller := get_node_or_null("CameraController")
	if camera_controller == null or not bool(camera_controller.get("camera_mode_active")):
		return false
	var current_scene := get_tree().current_scene
	if current_scene != null and current_scene.has_method("get_heritage_photo_target"):
		var target: Dictionary = current_scene.call("get_heritage_photo_target", mouse_position)
		return not target.is_empty()
	return false


func _is_hovering_room_interactable(mouse_position: Vector2) -> bool:
	var current_scene := get_tree().current_scene
	if current_scene and current_scene.has_method("is_hovering_room_interactable"):
		return current_scene.is_hovering_room_interactable(mouse_position)
	return false


func _is_screen_overlay_open() -> bool:
	# While a full-screen/modal screen is visible, don't show the magnifying
	# cursor for interactables underneath it (for example the recipe or pot).
	var hud := get_node_or_null("/root/HUD")
	if hud != null:
		if hud.find_child("LolaRecipeOverlay", true, false) != null:
			return true
		# Dialogue instances use the generic root name "Control", so detect
		# them by their sequence API instead of relying on a node name.
		for child in hud.find_children("*", "Control", true, false):
			if child.has_method("start_custom_sequence"):
				return true

	var current_scene := get_tree().current_scene
	if current_scene != null and current_scene.find_child("SinigangPotOverlay", true, false) != null:
		return true
	return false

func _is_hovering_journal() -> bool:
	if journal_close == null or journal_open == null:
		return false

	var mouse_position := get_viewport().get_mouse_position()
	var over_close := journal_close.visible and journal_close.get_rect().has_point(journal_close.to_local(mouse_position))
	var over_open := journal_open.visible and journal_open.get_rect().has_point(journal_open.to_local(mouse_position))
	return over_close or over_open

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if journal_is_open:
			_close_journal_overlay()
		elif pause_menu_open:
			_close_pause_menu()
		else:
			_open_pause_menu()
		get_viewport().set_input_as_handled()
		return
	if pause_menu_open:
		return
	# The drawn fallback exists only for the down-navigation cursor. Hide it
	# immediately on click so it does not remain painted over the next scene.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if is_instance_valid(visible_cursor_sprite) and visible_cursor_sprite.visible and visible_cursor_sprite.texture == down_cursor:
			_set_visible_cursor_fallback(null)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if journal_is_open:
				return
		else:
			if inventory_drag_id != "":
				_finish_inventory_drag()
				get_viewport().set_input_as_handled()
				return
	# While the journal overlay is open, let it handle its own controls.
	if journal_is_open:
		return
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	var mouse_position := get_viewport().get_mouse_position()
	var settings_icon := get_node_or_null("Settings") as Sprite2D
	if settings_icon != null and settings_icon.visible and settings_icon.get_rect().has_point(settings_icon.to_local(mouse_position)):
		_open_pause_menu()
		get_viewport().set_input_as_handled()
		return

	# The salakot puzzle is modal: preserve settings and inventory drag handling
	# above, but do not let clicks open the journal or trigger other HUD actions.
	if backyard_modal_open:
		return
	if journal_close == null or journal_open == null:
		return

	var over_close := journal_close.visible and journal_close.get_rect().has_point(journal_close.to_local(mouse_position))
	var over_open := journal_open.visible and journal_open.get_rect().has_point(journal_open.to_local(mouse_position))
	if over_close or over_open:
		_open_journal_overlay()
		get_viewport().set_input_as_handled()

func _open_journal_overlay() -> void:
	if journal_is_open or JOURNAL_SCENE == null:
		return
	var camera_controller := get_node_or_null("CameraController")
	if camera_controller != null and camera_controller.has_method("cancel_camera_mode"):
		camera_controller.call("cancel_camera_mode")

	journal_overlay_instance = JOURNAL_SCENE.instantiate() as Control
	if journal_overlay_instance == null:
		push_warning("The journal scene root must be a Control node.")
		return

	journal_is_open = true
	# Room scripts process clicks in _input(), before the journal can receive GUI input.
	# Lock gameplay interactions for the journal’s entire visible lifetime.
	_journal_previous_navigation_locked = navigation_locked
	navigation_locked = true
	if journal_close:
		journal_close.visible = false
	if journal_open:
		journal_open.visible = true

	journal_overlay_instance.connect("close_requested", Callable(self, "_close_journal_overlay"))
	add_child(journal_overlay_instance)

func _close_journal_overlay() -> void:
	if is_instance_valid(journal_overlay_instance):
		var closing_overlay := journal_overlay_instance
		# Keep gameplay locked until the closing fade finishes, preventing clicks
		# from reaching the room during the final frames of the journal animation.
		var close_tween := create_tween()
		close_tween.tween_property(closing_overlay, "modulate:a", 0.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		await close_tween.finished
		if is_instance_valid(closing_overlay):
			closing_overlay.queue_free()
	journal_overlay_instance = null
	journal_is_open = false
	navigation_locked = _journal_previous_navigation_locked

	if journal_close:
		journal_close.visible = journal_collected
	if journal_open:
		journal_open.visible = false


var pause_menu_open := false
var pause_menu_instance: Control
var brightness_level := 1.0
var sound_volume_level := 1.0
var music_volume_level := 1.0
const SAVE_FILE_PATH := "user://kultura_savegame.json"
const MAIN_MENU_SCENE_PATH := "res://game_scenes/intro.tscn"


func _setup_pause_menu() -> void:
	var settings_icon := get_node_or_null("Settings") as Sprite2D
	if settings_icon != null:
		settings_icon.visible = true


func _open_pause_menu() -> void:
	if pause_menu_open:
		return
	if journal_is_open:
		_close_journal_overlay()
	var camera_controller := get_node_or_null("CameraController")
	if camera_controller != null and camera_controller.has_method("cancel_camera_mode"):
		camera_controller.call("cancel_camera_mode")
	pause_menu_open = true
	navigation_locked = true
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	_set_visible_cursor_fallback(null)
	current_direction = ""
	get_tree().paused = true

	var root := Control.new()
	root.name = "PauseMenu"
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.z_index = 2000
	add_child(root)
	pause_menu_instance = root

	# Use the supplied artwork as the pause screen's full-screen base.
	var background := TextureRect.new()
	background.name = "PauseMenuBackground"
	background.texture = preload("res://GAME ASSETS/UI/HUD/Pause Menu BG.png")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)

	# A light dim keeps the menu labels readable without hiding the artwork.
	var dimmer := ColorRect.new()
	dimmer.name = "PauseMenuDimmer"
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.025, 0.022, 0.018, 0.22)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dimmer)

	var menu_content := Control.new()
	menu_content.name = "PauseMenuContent"
	menu_content.set_anchors_preset(Control.PRESET_CENTER)
	menu_content.position = Vector2(-205, -292)
	menu_content.size = Vector2(410, 584)
	menu_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(menu_content)

	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 12
	layout.offset_top = 12
	layout.offset_right = -12
	layout.offset_bottom = -12
	layout.add_theme_constant_override("separation", 10)
	menu_content.add_child(layout)

	# Keep the artwork clean: no title or paused text over the background.
	layout.alignment = BoxContainer.ALIGNMENT_CENTER

	_add_pause_button(layout, "Resume", _close_pause_menu)
	_add_pause_button(layout, "Save Game", _save_game)
	_add_pause_button(layout, "Load Game", _load_game)
	_add_pause_button(layout, "Achievements", _show_pause_achievements)
	_add_pause_button(layout, "Settings", _show_pause_settings)
	_add_pause_button(layout, "Credits", _show_pause_credits)
	_add_pause_button(layout, "Main Menu", _return_to_main_menu)


func _add_pause_button(parent: Container, label_text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(300, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_color_override("font_color", Color(0.97, 0.94, 0.86))
	button.add_theme_color_override("font_hover_color", Color(0.12, 0.10, 0.08))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.31, 0.25, 0.18, 1.0)
	normal.border_color = Color(0.72, 0.56, 0.32, 1.0)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.83, 0.69, 0.45, 1.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _close_pause_menu() -> void:
	if not pause_menu_open:
		return
	pause_menu_open = false
	get_tree().paused = false
	navigation_locked = false
	if is_instance_valid(pause_menu_instance):
		pause_menu_instance.queue_free()
	pause_menu_instance = null
	_update_cursor(get_viewport().get_mouse_position())


func _save_file_path(slot: int) -> String:
	return "user://kultura_save_slot_%02d.json" % slot


func _save_game() -> void:
	_show_pause_slot_menu(false)


func _load_game() -> void:
	_show_pause_slot_menu(true)



func _show_pause_achievements() -> void:
	if not is_instance_valid(pause_menu_instance):
		return
	for child in pause_menu_instance.get_children():
		child.queue_free()

	var panel := PanelContainer.new()
	panel.name = "AchievementsPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-360, -290)
	panel.size = Vector2(720, 580)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.16, 0.13, 0.10, 0.99)
	panel_style.border_color = Color(0.78, 0.61, 0.35, 1.0)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 22.0
	panel_style.content_margin_right = 22.0
	panel_style.content_margin_top = 18.0
	panel_style.content_margin_bottom = 18.0
	panel.add_theme_stylebox_override("panel", panel_style)
	pause_menu_instance.add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	panel.add_child(layout)

	var heading := Label.new()
	heading.text = "ACHIEVEMENTS"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 32)
	heading.add_theme_color_override("font_color", Color(0.91, 0.76, 0.49))
	layout.add_child(heading)

	var manager := get_node_or_null("/root/AchievementManager")
	var unlocked: Array = manager.call("get_unlocked_ids") if manager != null else []
	var definitions: Array = manager.call("get_definitions") if manager != null else []
	var summary := Label.new()
	summary.text = "%d / %d unlocked in this save" % [unlocked.size(), definitions.size()]
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.add_theme_font_size_override("font_size", 17)
	summary.add_theme_color_override("font_color", Color(0.97, 0.94, 0.86))
	layout.add_child(summary)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	for definition in definitions:
		var achievement_id := str(definition.get("id", ""))
		var is_unlocked := unlocked.has(achievement_id)
		var row := PanelContainer.new()
		var row_style := StyleBoxFlat.new()
		row_style.bg_color = Color(0.24, 0.19, 0.14, 1.0) if is_unlocked else Color(0.12, 0.105, 0.09, 1.0)
		row_style.border_color = Color(0.78, 0.61, 0.35, 1.0) if is_unlocked else Color(0.35, 0.31, 0.26, 1.0)
		row_style.set_border_width_all(1)
		row_style.set_corner_radius_all(6)
		row_style.content_margin_left = 12.0
		row_style.content_margin_right = 12.0
		row_style.content_margin_top = 8.0
		row_style.content_margin_bottom = 8.0
		row.add_theme_stylebox_override("panel", row_style)
		list.add_child(row)

		var row_layout := VBoxContainer.new()
		row_layout.add_theme_constant_override("separation", 3)
		row.add_child(row_layout)

		var title := Label.new()
		title.text = ("✓  " if is_unlocked else "LOCKED  ") + str(definition.get("title", "Achievement"))
		title.add_theme_font_size_override("font_size", 20)
		title.add_theme_color_override("font_color", Color(0.91, 0.76, 0.49) if is_unlocked else Color(0.65, 0.62, 0.56))
		row_layout.add_child(title)

		var description := Label.new()
		description.text = str(definition.get("description", ""))
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.add_theme_font_size_override("font_size", 15)
		description.add_theme_color_override("font_color", Color(0.97, 0.94, 0.86) if is_unlocked else Color(0.58, 0.56, 0.52))
		row_layout.add_child(description)

	var back := _add_pause_button(layout, "Back", Callable(self, "_rebuild_pause_menu"))
	back.custom_minimum_size = Vector2(260, 42)


func _show_pause_slot_menu(load_mode: bool) -> void:
	if not is_instance_valid(pause_menu_instance):
		return
	for child in pause_menu_instance.get_children():
		child.queue_free()

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-300, -300)
	panel.size = Vector2(600, 600)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.16, 0.13, 0.10, 0.99)
	panel_style.border_color = Color(0.78, 0.61, 0.35, 1.0)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", panel_style)
	pause_menu_instance.add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	panel.add_child(layout)

	var heading := Label.new()
	heading.text = "LOAD GAME" if load_mode else "SAVE GAME"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 34)
	heading.add_theme_color_override("font_color", Color(0.91, 0.76, 0.49))
	layout.add_child(heading)

	var hint := Label.new()
	hint.text = "Choose a slot to load." if load_mode else "Choose a slot to save your progress."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", Color(0.97, 0.94, 0.86))
	layout.add_child(hint)

	var slots_grid := GridContainer.new()
	slots_grid.columns = 2
	slots_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slots_grid.add_theme_constant_override("h_separation", 10)
	slots_grid.add_theme_constant_override("v_separation", 8)
	layout.add_child(slots_grid)

	for slot in range(1, 11):
		var has_save := FileAccess.file_exists(_save_file_path(slot))
		var slot_button := _add_pause_button(
			slots_grid,
			"Slot %02d — %s" % [slot, "Saved" if has_save else "Empty"],
			Callable(self, "_on_save_slot_selected").bind(slot) if not load_mode else Callable(self, "_on_load_slot_selected").bind(slot)
		)
		slot_button.custom_minimum_size = Vector2(250, 54)
		if load_mode and not has_save:
			slot_button.disabled = true

	var back := _add_pause_button(layout, "Back", func(): _rebuild_pause_menu())
	back.custom_minimum_size = Vector2(300, 44)


func _on_save_slot_selected(slot: int) -> void:
	if FileAccess.file_exists(_save_file_path(slot)):
		_show_slot_confirmation(
			"Overwrite Save?",
			"Slot %02d already contains saved progress. Are you sure you want to overwrite it?" % slot,
			Callable(self, "_save_game_to_slot").bind(slot),
			false
		)
	else:
		_save_game_to_slot(slot)


func _on_load_slot_selected(slot: int) -> void:
	if not FileAccess.file_exists(_save_file_path(slot)):
		_show_pause_message("No save found", "Slot %02d is empty." % slot)
		return
	_show_slot_confirmation(
		"Load This Save?",
		"Load Slot %02d? Your current unsaved progress will be replaced." % slot,
		Callable(self, "_load_game_from_slot").bind(slot),
		true
	)


func _show_slot_confirmation(title_text: String, message_text: String, confirm_action: Callable, load_mode: bool) -> void:
	if not is_instance_valid(pause_menu_instance):
		return
	for child in pause_menu_instance.get_children():
		child.queue_free()

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-280, -190)
	panel.size = Vector2(560, 380)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.16, 0.13, 0.10, 0.99)
	panel_style.border_color = Color(0.78, 0.61, 0.35, 1.0)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", panel_style)
	pause_menu_instance.add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 18)
	panel.add_child(layout)

	var heading := Label.new()
	heading.text = title_text
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 34)
	heading.add_theme_color_override("font_color", Color(0.91, 0.76, 0.49))
	layout.add_child(heading)

	var message := Label.new()
	message.text = message_text
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.size_flags_vertical = Control.SIZE_EXPAND_FILL
	message.add_theme_font_size_override("font_size", 23)
	message.add_theme_color_override("font_color", Color(0.97, 0.94, 0.86))
	layout.add_child(message)

	var confirm_button := _add_pause_button(layout, "Yes, Load Game" if load_mode else "Yes, Overwrite", func(): confirm_action.call())
	confirm_button.custom_minimum_size = Vector2(300, 48)
	var cancel_button := _add_pause_button(layout, "Cancel", func(): _show_pause_slot_menu(load_mode))
	cancel_button.custom_minimum_size = Vector2(300, 44)


func _save_game_to_slot(slot: int) -> void:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		_show_pause_message("Save unavailable", "Game state could not be found.")
		return
	var save_data: Dictionary = {
		"slot": slot,
		"scene_path": get_tree().current_scene.scene_file_path if get_tree().current_scene != null else LIVING_ROOM,
		"state": _encode_save_value(game_state.call("get_state_snapshot") if game_state.has_method("get_state_snapshot") else game_state.get("_values")),
		"save_version": 2
	}
	var file := FileAccess.open(_save_file_path(slot), FileAccess.WRITE)
	if file == null:
		_show_pause_message("Save failed", "Slot %02d could not be written." % slot)
		return
	file.store_string(JSON.stringify(save_data))
	file.close()
	_show_pause_message("Game saved", "Progress saved to Slot %02d." % slot)


func _clear_transient_ui_for_load() -> void:
	# The HUD is an autoloaded CanvasLayer and survives scene changes. Clear
	# transient UI owned by it before loading a save, or modal content from the
	# previous scene can remain visible above the restored room.
	if is_instance_valid(journal_overlay_instance):
		journal_overlay_instance.queue_free()
	journal_overlay_instance = null
	journal_is_open = false
	_journal_previous_navigation_locked = false
	if journal_open != null:
		journal_open.visible = false
	if journal_close != null:
		journal_close.visible = journal_collected

	# Clear active inventory dragging/drop state so an old interaction cannot
	# leak into the loaded scene.
	inventory_drag_id = ""
	inventory_drop_rect = Rect2()
	inventory_drop_targets.clear()
	if is_instance_valid(inventory_drag_icon):
		inventory_drag_icon.queue_free()
	inventory_drag_icon = null

	# Modal dialogs/notifications may be attached to the persistent HUD instead
	# of the current room. Remove their top-level HUD-owned container while
	# preserving permanent HUD controls and the pause menu (closed separately).
	var transient_tokens := [
		"overlay", "popup", "dialogue", "dialog", "notification",
		"confirmation", "recipe", "journal"
	]
	var transient_roots: Array[Node] = []
	for candidate in find_children("*", "Control", true, false):
		if not is_instance_valid(candidate) or candidate == pause_menu_instance:
			continue
		var candidate_name := str(candidate.name).to_lower()
		var is_transient := candidate.has_method("start_custom_sequence")
		for token in transient_tokens:
			if candidate_name.contains(token):
				is_transient = true
				break
		if not is_transient:
			continue
		var root_child: Node = candidate
		while root_child.get_parent() != null and root_child.get_parent() != self:
			root_child = root_child.get_parent()
		if root_child.get_parent() == self and root_child != pause_menu_instance and not transient_roots.has(root_child):
			transient_roots.append(root_child)

	for transient_root in transient_roots:
		if is_instance_valid(transient_root):
			transient_root.queue_free()

	# Restore interaction flags independently of which modal was open.
	navigation_locked = false
	current_direction = ""
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	_set_visible_cursor_fallback(null)


func _load_game_from_slot(slot: int) -> void:
	var path := _save_file_path(slot)
	if not FileAccess.file_exists(path):
		_show_pause_message("No save found", "Slot %02d is empty." % slot)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_show_pause_message("Load failed", "Slot %02d could not be opened." % slot)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary) or not (parsed.get("state", {}) is Dictionary):
		_show_pause_message("Load failed", "Slot %02d contains an invalid save." % slot)
		return
	var scene_path := str(parsed.get("scene_path", LIVING_ROOM))
	if not ResourceLoader.exists(scene_path):
		scene_path = LIVING_ROOM

	# Fade to black before switching scenes, then fade back in after the new scene is ready.
	if fade_rect == null or not is_instance_valid(fade_rect):
		_create_fade_overlay()
	if fade_tween != null and fade_tween.is_running():
		fade_tween.kill()
	fade_rect.size = Vector2(_screen_width(), _screen_height())
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	fade_tween = create_tween()
	fade_tween.tween_property(fade_rect, "color:a", 1.0, 0.65)
	await fade_tween.finished

	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		fade_tween = create_tween()
		fade_tween.tween_property(fade_rect, "color:a", 0.0, 0.45)
		await fade_tween.finished
		fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_show_pause_message("Load failed", "Game state could not be found.")
		return

	var loaded_state: Dictionary = _decode_save_value(parsed["state"])
	# Restore the complete snapshot against fresh defaults. No progress from the
	# currently running session should survive unless it exists in this save.
	if game_state.has_method("restore_state"):
		game_state.call("restore_state", loaded_state)
	else:
		game_state.set("_values", loaded_state)

	# Remove modal UI and interaction state from the previous session before
	# changing scenes. The HUD is persistent, so scene changes alone cannot clear it.
	_clear_transient_ui_for_load()

	# Rebuild every HUD-owned copy from the restored save, never from the previous run.
	inventory_items.clear()
	inventory_items.assign(game_state.get_state("inventory_items", []))
	heritage_entries.clear()
	heritage_entries.assign(game_state.get_state("heritage_entries", []))
	camera_collected = bool(game_state.get_state("camera_collected", false))
	journal_collected = bool(game_state.get_state("journal_collected", false))
	if journal_close != null:
		journal_close.visible = journal_collected
	if journal_open != null:
		journal_open.visible = false
	if camera_icon != null:
		camera_icon.visible = camera_collected
	_refresh_inventory_ui()

	_close_pause_menu()
	get_tree().paused = false
	navigation_locked = false
	await get_tree().process_frame
	var change_error := get_tree().change_scene_to_file(scene_path)
	if change_error != OK:
		fade_tween = create_tween()
		fade_tween.tween_property(fade_rect, "color:a", 0.0, 0.45)
		await fade_tween.finished
		fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	await get_tree().process_frame
	_set_brightness(brightness_level)
	_apply_music_volume_to_all_players()
	fade_tween = create_tween()
	fade_tween.tween_property(fade_rect, "color:a", 0.0, 0.65)
	await fade_tween.finished
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _encode_save_value(value: Variant) -> Variant:
	if value is Texture2D:
		return {"__saved_texture_path": value.resource_path}
	if value is Array:
		var encoded: Array = []
		for item in value:
			encoded.append(_encode_save_value(item))
		return encoded
	if value is Dictionary:
		var encoded: Dictionary = {}
		for key in value:
			encoded[key] = _encode_save_value(value[key])
		return encoded
	if value is Object:
		return null
	return value


func _decode_save_value(value: Variant) -> Variant:
	if value is Dictionary:
		if value.has("__saved_texture_path"):
			var path := str(value.get("__saved_texture_path", ""))
			return load(path) if not path.is_empty() and ResourceLoader.exists(path) else null
		var decoded: Dictionary = {}
		for key in value:
			decoded[key] = _decode_save_value(value[key])
		return decoded
	if value is Array:
		var decoded: Array = []
		for item in value:
			decoded.append(_decode_save_value(item))
		return decoded
	return value


func _show_pause_settings() -> void:
	if not is_instance_valid(pause_menu_instance):
		return
	for child in pause_menu_instance.get_children():
		child.queue_free()

	# Display the complete authored settings artwork, scaled to fit the viewport.
	var viewport_size := get_viewport().get_visible_rect().size
	var texture_size := Vector2(SETTINGS_MENU_TEXTURE.get_width(), SETTINGS_MENU_TEXTURE.get_height())
	var fit_scale := minf(
		(viewport_size.x * 0.94) / maxf(texture_size.x, 1.0),
		(viewport_size.y * 0.94) / maxf(texture_size.y, 1.0)
	)
	var background_size := texture_size * fit_scale

	var background := TextureRect.new()
	background.name = "SettingsMenuBackground"
	background.texture = SETTINGS_MENU_TEXTURE
	background.anchor_left = 0.5
	background.anchor_top = 0.5
	background.anchor_right = 0.5
	background.anchor_bottom = 0.5
	background.offset_left = -background_size.x * 0.5
	background.offset_top = -background_size.y * 0.5
	background.offset_right = background_size.x * 0.5
	background.offset_bottom = background_size.y * 0.5
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_menu_instance.add_child(background)

	# Each slider has its own editable layout values below. Values are
	# proportions of the scaled settings artwork, so they adapt to resolution.

	var overlay := Control.new()
	overlay.name = "SettingsInteractionOverlay"
	overlay.anchor_left = 0.5
	overlay.anchor_top = 0.5
	overlay.anchor_right = 0.5
	overlay.anchor_bottom = 0.5
	overlay.offset_left = -background_size.x * 0.5
	overlay.offset_top = -background_size.y * 0.5
	overlay.offset_right = background_size.x * 0.5
	overlay.offset_bottom = background_size.y * 0.5
	overlay.mouse_filter = Control.MOUSE_FILTER_PASS
	pause_menu_instance.add_child(overlay)

	# Shorten the knob's travel distance while keeping the slider centered
	# over the existing illustrated track.
	# EDIT THESE VALUES INDEPENDENTLY for each slider:
	# left / width / height control the interactive track area;
	# y controls its vertical center; knob_width / knob_height control its knob.
	var slider_values := [
		{
			"name": "BrightnessSlider", "min": 0.35, "max": 1.0,
			"value": brightness_level, "callback": _set_brightness,
			"left": 0.30, "width": 0.40, "height": 0.065, "y": 0.290,
			"knob_width": 0.055, "knob_height": 0.055
		},
		{
			"name": "SoundVolumeSlider", "min": 0.0, "max": 1.0,
			"value": sound_volume_level, "callback": _set_sound_volume,
			"left": 0.30, "width": 0.40, "height": 0.065, "y": 0.457,
			"knob_width": 0.055, "knob_height": 0.055
		},
		{
			"name": "MusicVolumeSlider", "min": 0.0, "max": 1.0,
			"value": music_volume_level, "callback": _set_music_volume,
			"left": 0.30, "width": 0.40, "height": 0.065, "y": 0.619,
			"knob_width": 0.055, "knob_height": 0.055
		}
	]
	for item in slider_values:
		var slider := HSlider.new()
		slider.name = str(item["name"])
		slider.min_value = float(item["min"])
		slider.max_value = float(item["max"])
		slider.step = 0.01
		slider.value = clampf(float(item["value"]), slider.min_value, slider.max_value)
		var track_left := background_size.x * float(item["left"])
		var track_width := background_size.x * float(item["width"])
		var track_height := background_size.y * float(item["height"])
		slider.position = Vector2(track_left, background_size.y * float(item["y"]) - track_height * 0.5)
		slider.size = Vector2(track_width, track_height)
		slider.focus_mode = Control.FOCUS_NONE
		slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		# Resize this slider's knob separately, allowing independent width/height.
		var knob_image := SLIDER_KNOB_TEXTURE.get_image()
		var knob_texture: Texture2D = SLIDER_KNOB_TEXTURE
		if knob_image != null and not knob_image.is_empty():
			var knob_width_px := maxi(1, roundi(background_size.x * float(item["knob_width"])))
			var knob_height_px := maxi(1, roundi(background_size.y * float(item["knob_height"])))
			knob_image.resize(knob_width_px, knob_height_px, Image.INTERPOLATE_BILINEAR)
			knob_texture = ImageTexture.create_from_image(knob_image)

		slider.add_theme_icon_override("grabber", knob_texture)
		slider.add_theme_icon_override("grabber_highlight", knob_texture)
		slider.add_theme_icon_override("grabber_pressed", knob_texture)
		var empty_style := StyleBoxEmpty.new()
		slider.add_theme_stylebox_override("slider", empty_style)
		slider.add_theme_stylebox_override("grabber_area", empty_style)
		slider.add_theme_stylebox_override("grabber_area_highlight", empty_style)
		slider.value_changed.connect(item["callback"])
		overlay.add_child(slider)

	# Transparent click target over the existing Back artwork.
	var back_button := Button.new()
	back_button.name = "SettingsBackHotspot"
	back_button.text = ""
	back_button.flat = true
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back_button.position = Vector2(background_size.x * 0.34, background_size.y * 0.86)
	back_button.size = Vector2(background_size.x * 0.32, background_size.y * 0.105)
	for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		back_button.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	back_button.pressed.connect(_rebuild_pause_menu)
	overlay.add_child(back_button)


func _add_settings_slider(parent: VBoxContainer, label_text: String, minimum: float, maximum: float, current_value: float, callback: Callable) -> void:
	var setting_group := VBoxContainer.new()
	setting_group.add_theme_constant_override("separation", 2)
	parent.add_child(setting_group)

	var setting_label := Label.new()
	setting_label.text = label_text
	setting_label.add_theme_font_size_override("font_size", 23)
	setting_label.add_theme_color_override("font_color", Color(0.97, 0.94, 0.86))
	setting_group.add_child(setting_label)

	var slider := HSlider.new()
	slider.name = label_text.replace(" ", "") + "Slider"
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 0.01
	slider.value = clampf(current_value, minimum, maximum)
	slider.custom_minimum_size = Vector2(440, 36)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_ALL
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Godot draws slider theme icons at their texture's native size. Downscale
	# the high-resolution knob image before assigning it so it stays compact.
	var knob_texture: Texture2D = SLIDER_KNOB_TEXTURE
	var knob_image := SLIDER_KNOB_TEXTURE.get_image()
	if knob_image != null and not knob_image.is_empty():
		var largest_dimension := maxi(knob_image.get_width(), knob_image.get_height())
		const MAX_KNOB_SIZE := 28
		if largest_dimension > MAX_KNOB_SIZE:
			var scale_factor := float(MAX_KNOB_SIZE) / float(largest_dimension)
			var knob_width := maxi(1, roundi(float(knob_image.get_width()) * scale_factor))
			var knob_height := maxi(1, roundi(float(knob_image.get_height()) * scale_factor))
			knob_image.resize(knob_width, knob_height, Image.INTERPOLATE_BILINEAR)
			knob_texture = ImageTexture.create_from_image(knob_image)

	slider.add_theme_icon_override("grabber", knob_texture)
	slider.add_theme_icon_override("grabber_highlight", knob_texture)
	slider.add_theme_icon_override("grabber_pressed", knob_texture)
	slider.value_changed.connect(callback)
	setting_group.add_child(slider)


func _set_brightness(value: float) -> void:
	brightness_level = clampf(value, 0.35, 1.0)

	# Remove the old world-only modulator so brightness is not applied twice.
	var scene := get_tree().current_scene
	if scene != null:
		var old_modulator := scene.get_node_or_null("GameplayBrightness")
		if old_modulator is CanvasModulate:
			old_modulator.queue_free()

	# A full-screen black overlay on a high CanvasLayer affects the world,
	# HUD, dialogue, inventory, pause menu, and settings artwork together.
	var overlay_layer := get_tree().root.get_node_or_null("GlobalBrightnessOverlay") as CanvasLayer
	if overlay_layer == null:
		overlay_layer = CanvasLayer.new()
		overlay_layer.name = "GlobalBrightnessOverlay"
		overlay_layer.layer = 128
		overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().root.add_child(overlay_layer)

	var overlay := overlay_layer.get_node_or_null("BrightnessTint") as ColorRect
	if overlay == null:
		overlay = ColorRect.new()
		overlay.name = "BrightnessTint"
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		overlay.color = Color(0.0, 0.0, 0.0, 0.0)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay_layer.add_child(overlay)

	# Slider 1.0 = transparent overlay (full brightness); lower values darken
	# every visible layer equally without blocking mouse interaction.
	overlay.color = Color(0.0, 0.0, 0.0, 1.0 - brightness_level)


func _set_sound_volume(value: float) -> void:
	sound_volume_level = clampf(value, 0.0, 1.0)
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_volume_db(master_bus, linear_to_db(maxf(sound_volume_level, 0.001)))


func _set_music_volume(value: float) -> void:
	music_volume_level = clampf(value, 0.0, 1.0)
	_apply_music_volume_to_all_players()


func _on_tree_node_added(node: Node) -> void:
	# Apply the music setting when a scene introduces a new audio player, rather
	# than repeatedly searching every node in the game tree on every frame.
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		call_deferred("_apply_music_volume_to_player", node)


func _apply_music_volume_to_all_players() -> void:
	# Music streams are adjusted independently from sound effects by their
	# AudioStreamPlayer nodes, leaving the Master bus for overall sound volume.
	for node in get_tree().root.find_children("*", "AudioStreamPlayer", true, false):
		_apply_music_volume_to_player(node)
	for node in get_tree().root.find_children("*", "AudioStreamPlayer2D", true, false):
		_apply_music_volume_to_player(node)
	for node in get_tree().root.find_children("*", "AudioStreamPlayer3D", true, false):
		_apply_music_volume_to_player(node)


func _apply_music_volume_to_player(player: Node) -> void:
	if not player is AudioStreamPlayer and not player is AudioStreamPlayer2D and not player is AudioStreamPlayer3D:
		return
	var stream: AudioStream = player.get("stream")
	var stream_path := stream.resource_path.to_lower() if stream != null else ""
	var player_name := str(player.name).to_lower()
	if not (stream_path.contains("music") or stream_path.contains("bgm") or player_name.contains("music") or player_name.contains("bgm")):
		return
	if not player.has_meta("settings_base_volume_db"):
		player.set_meta("settings_base_volume_db", float(player.get("volume_db")))
	var base_volume := float(player.get_meta("settings_base_volume_db"))
	player.set("volume_db", base_volume + linear_to_db(maxf(music_volume_level, 0.001)))


func _show_pause_credits() -> void:
	_show_pause_subpage("CREDITS", "Kultura at Tradisyon\nA cultural heritage game project\n\nCreated with Godot Engine.", false)


func _show_pause_subpage(title_text: String, description: String, show_volume: bool) -> void:
	if not is_instance_valid(pause_menu_instance):
		return
	for child in pause_menu_instance.get_children():
		child.queue_free()
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-250, -210)
	panel.size = Vector2(500, 420)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.16, 0.13, 0.10, 0.99)
	panel_style.border_color = Color(0.78, 0.61, 0.35, 1.0)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", panel_style)
	pause_menu_instance.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 18)
	panel.add_child(layout)
	var heading := Label.new()
	heading.text = title_text
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 34)
	heading.add_theme_color_override("font_color", Color(0.91, 0.76, 0.49))
	layout.add_child(heading)
	var description_label := Label.new()
	description_label.text = description
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.add_theme_font_size_override("font_size", 23)
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description_label.add_theme_color_override("font_color", Color(0.97, 0.94, 0.86))
	layout.add_child(description_label)
	if show_volume:
		var bus_index := AudioServer.get_bus_index("Master")
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = db_to_linear(AudioServer.get_bus_volume_db(bus_index)) if bus_index >= 0 else 1.0
		slider.value_changed.connect(func(value: float):
			if bus_index >= 0:
				AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(value, 0.001)))
		)
		layout.add_child(slider)
	var back := _add_pause_button(layout, "Back", func(): _rebuild_pause_menu())
	back.custom_minimum_size = Vector2(300, 46)


func _rebuild_pause_menu() -> void:
	if not is_instance_valid(pause_menu_instance):
		return
	pause_menu_instance.queue_free()
	pause_menu_instance = null
	pause_menu_open = false
	get_tree().paused = false
	_open_pause_menu()


func _show_pause_message(title_text: String, body_text: String) -> void:
	_show_pause_subpage(title_text, body_text, false)


func _return_to_main_menu() -> void:
	_show_quit_confirmation()


func _show_quit_confirmation() -> void:
	if not is_instance_valid(pause_menu_instance):
		return

	# Keep the pause menu behind the confirmation, but block all clicks beneath it.
	var overlay := Control.new()
	overlay.name = "QuitConfirmationOverlay"
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 10
	pause_menu_instance.add_child(overlay)

	var dimmer := ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.0, 0.0, 0.0, 0.72)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dimmer)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-300, -180)
	panel.size = Vector2(600, 360)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.16, 0.13, 0.10, 1.0)
	panel_style.border_color = Color(0.78, 0.61, 0.35, 1.0)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", panel_style)
	overlay.add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 18)
	panel.add_child(layout)

	var heading := Label.new()
	heading.text = "QUIT GAME?"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 34)
	heading.add_theme_color_override("font_color", Color(0.91, 0.76, 0.49))
	layout.add_child(heading)

	var message := Label.new()
	message.text = "are you sure you want to quit? All unsaved progress will be lost"
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.size_flags_vertical = Control.SIZE_EXPAND_FILL
	message.add_theme_color_override("font_color", Color(0.97, 0.94, 0.86))
	layout.add_child(message)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 18)
	layout.add_child(button_row)

	var yes_button := _add_pause_button(button_row, "Yes", _quit_to_dashboard)
	yes_button.custom_minimum_size = Vector2(180, 48)
	var no_button := _add_pause_button(button_row, "No", func(): overlay.queue_free())
	no_button.custom_minimum_size = Vector2(180, 48)


func _quit_to_dashboard() -> void:
	# The game is launched from UGAT's dashboard as an HTML5 export.
	# In a browser, navigate back to dashboard.php; in a desktop build, quit normally.
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.location.href = '../../../dashboard.php';")
		return

	get_tree().paused = false
	get_tree().quit()


func _on_viewport_resized() -> void:
	_resize_navigation_buttons()

func _create_navigation_button(button_name: String, center_position: Vector2, callback: Callable) -> void:
	var button := Button.new()
	button.name = button_name
	button.text = ""
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_ARROW
	button.mouse_filter = Control.MOUSE_FILTER_STOP

	var empty_style := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty_style)
	button.add_theme_stylebox_override("hover", empty_style)
	button.add_theme_stylebox_override("pressed", empty_style)
	button.add_theme_stylebox_override("focus", empty_style)

	var hotspot_size := _get_hotspot_size(button_name)
	button.position = center_position - hotspot_size * 0.5
	button.size = hotspot_size
	button.pressed.connect(callback)

	add_child(button)

func _get_hotspot_size(button_name: String) -> Vector2:
	match button_name:
		"LeftNavigation":
			return Vector2(LEFT_NAV_WIDTH, LEFT_NAV_HEIGHT)
		"RightNavigation":
			return Vector2(RIGHT_NAV_WIDTH, RIGHT_NAV_HEIGHT)
		"DownNavigation":
			return Vector2(DOWN_NAV_WIDTH, DOWN_NAV_HEIGHT)
		_:
			return Vector2.ZERO

func _create_footsteps_player() -> void:
	footsteps_player = AudioStreamPlayer.new()
	footsteps_player.name = "FootstepsPlayer"
	footsteps_player.stream = FOOTSTEPS_SFX
	add_child(footsteps_player)

func _create_fade_overlay() -> void:
	fade_rect = ColorRect.new()
	fade_rect.name = "RoomTransitionFade"
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.position = Vector2.ZERO
	fade_rect.size = Vector2(_screen_width(), _screen_height())
	fade_rect.z_index = 1000
	add_child(fade_rect)

func _resize_navigation_buttons() -> void:
	var left_button := get_node_or_null("LeftNavigation") as Button
	var right_button := get_node_or_null("RightNavigation") as Button
	var down_button := get_node_or_null("DownNavigation") as Button

	if left_button:
		var left_size := Vector2(LEFT_NAV_WIDTH, LEFT_NAV_HEIGHT)
		left_button.position = LEFT_NAV_POSITION - left_size * 0.5
		left_button.size = left_size

	if right_button:
		var right_size := Vector2(RIGHT_NAV_WIDTH, RIGHT_NAV_HEIGHT)
		right_button.position = RIGHT_NAV_POSITION - right_size * 0.5
		right_button.size = right_size

	if down_button:
		# Keep the bottom navigation hotspot attached to the visible viewport
		# instead of a fixed 648px-high design coordinate. This matters when the
		# HTML5 canvas is embedded at a different size in the dashboard.
		down_button.anchor_left = 0.5
		down_button.anchor_right = 0.5
		down_button.anchor_top = 1.0
		down_button.anchor_bottom = 1.0
		down_button.offset_left = -DOWN_NAV_WIDTH * 0.5
		down_button.offset_right = DOWN_NAV_WIDTH * 0.5
		down_button.offset_top = -DOWN_NAV_HEIGHT - 12.0
		down_button.offset_bottom = -12.0

	if fade_rect:
		fade_rect.size = Vector2(_screen_width(), _screen_height())

func _update_cursor(mouse_position: Vector2) -> void:
	# While the camera is active, highlight only heritage items already recorded
	# in the journal, before checking ordinary room interactions or navigation.
	if _is_hovering_camera_target(mouse_position):
		if current_direction != "journal":
			current_direction = "journal"
			_set_visible_cursor_fallback(null)
			Input.set_custom_mouse_cursor(magnify_cursor, Input.CURSOR_ARROW, _cursor_hotspot(magnify_cursor))
		return

	# Modal overlays take priority over room interactables. Keep the normal
	# cursor while the recipe, pot, or dialogue screen is visible.
	if _is_screen_overlay_open():
		if current_direction != "":
			current_direction = ""
			_set_visible_cursor_fallback(null)
			Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
		return

	# Interactable objects and the journal always take cursor priority over
	# directional navigation hotspots, regardless of which scene is active.
	if _is_hovering_journal() or _is_hovering_room_interactable(mouse_position):
		if current_direction != "journal":
			current_direction = "journal"
			_set_visible_cursor_fallback(null)
			Input.set_custom_mouse_cursor(magnify_cursor, Input.CURSOR_ARROW, _cursor_hotspot(magnify_cursor))
		return

	var direction := ""
	var left_hotspot_size := Vector2(LEFT_NAV_WIDTH, LEFT_NAV_HEIGHT)
	var right_hotspot_size := Vector2(RIGHT_NAV_WIDTH, RIGHT_NAV_HEIGHT)
	var down_hotspot_size := Vector2(DOWN_NAV_WIDTH, DOWN_NAV_HEIGHT)
	var left_hotspot_offset := left_hotspot_size * 0.5
	var right_hotspot_offset := right_hotspot_size * 0.5
	var down_hotspot_offset := down_hotspot_size * 0.5

	var left_button := get_node_or_null("LeftNavigation") as Control
	var right_button := get_node_or_null("RightNavigation") as Control
	var down_button := get_node_or_null("DownNavigation") as Control

	if left_button != null and left_button.get_global_rect().has_point(mouse_position):
		direction = "left"
	elif right_button != null and right_button.get_global_rect().has_point(mouse_position):
		direction = "right"
	elif down_button != null and down_button.get_global_rect().has_point(mouse_position):
		direction = "down"

	if not _is_direction_available(direction):
		direction = ""

	if direction != "":
		if direction == current_direction:
			return
		current_direction = direction
		match direction:
			"left":
				_set_visible_cursor_fallback(null)
				Input.set_custom_mouse_cursor(left_cursor, Input.CURSOR_ARROW, _cursor_hotspot(left_cursor))
			"right":
				_set_visible_cursor_fallback(null)
				Input.set_custom_mouse_cursor(right_cursor, Input.CURSOR_ARROW, _cursor_hotspot(right_cursor))
			"down":
				_set_visible_cursor_fallback(down_cursor)
				Input.set_custom_mouse_cursor(down_cursor, Input.CURSOR_ARROW, _cursor_hotspot(down_cursor))
		return

	if current_direction != "":
		current_direction = ""
		_set_visible_cursor_fallback(null)
		Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)

func _set_visible_cursor_fallback(texture: Texture2D) -> void:
	if not is_instance_valid(visible_cursor_sprite):
		return
	visible_cursor_sprite.texture = texture
	visible_cursor_sprite.visible = texture != null
	if texture != null:
		visible_cursor_sprite.position = get_viewport().get_mouse_position()

func _is_direction_available(direction: String) -> bool:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return false

	match current_scene.scene_file_path:
		LIVING_ROOM:
			return direction in ["left", "right", "down"]
		MIGS_ROOM:
			return direction == "left"
		KITCHEN:
			return direction == "right"
		BACKYARD:
			return direction == "down"
		_:
			return false

func _go_left() -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	match current_scene.scene_file_path:
		LIVING_ROOM:
			_change_scene(KITCHEN)
		MIGS_ROOM:
			_change_scene(LIVING_ROOM)

func _go_right() -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	match current_scene.scene_file_path:
		LIVING_ROOM:
			_change_scene(MIGS_ROOM)
		KITCHEN:
			_change_scene(LIVING_ROOM)

func _go_down() -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	match current_scene.scene_file_path:
		LIVING_ROOM:
			_change_scene(BACKYARD)
		BACKYARD:
			_change_scene(LIVING_ROOM)

func _change_scene(scene_path: String) -> void:
	if navigation_locked:
		return
	var camera_controller := get_node_or_null("CameraController")
	if camera_controller != null and camera_controller.has_method("cancel_camera_mode"):
		camera_controller.call("cancel_camera_mode")

	navigation_locked = true
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	current_direction = ""

	var next_room: PackedScene = room_scenes.get(scene_path)
	if next_room == null:
		navigation_locked = false
		return

	if footsteps_player:
		footsteps_player.play()

	if fade_tween:
		fade_tween.kill()

	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	fade_tween = create_tween()
	fade_tween.tween_property(fade_rect, "color:a", 1.0, 0.72).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await fade_tween.finished

	get_tree().change_scene_to_packed(next_room)

	await get_tree().process_frame
	_set_brightness(brightness_level)
	_apply_music_volume_to_all_players()

	fade_tween = create_tween()
	fade_tween.tween_property(fade_rect, "color:a", 0.0, 0.82).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await fade_tween.finished

	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	navigation_locked = false
	_update_cursor(get_viewport().get_mouse_position())

func _exit_tree() -> void:
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	if is_instance_valid(visible_cursor_sprite):
		visible_cursor_sprite.visible = false

func _prepare_cursor(texture: Texture2D, max_size: float = CURSOR_MAX_SIZE) -> Texture2D:
	var image := texture.get_image()
	if image == null or image.is_empty():
		return texture

	var max_dimension: int = maxi(image.get_width(), image.get_height())
	if max_dimension <= max_size:
		return texture

	var scale_factor: float = max_size / float(max_dimension)
	var new_width: int = maxi(1, roundi(image.get_width() * scale_factor))
	var new_height: int = maxi(1, roundi(image.get_height() * scale_factor))
	image.resize(new_width, new_height, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)

func _cursor_hotspot(texture: Texture2D) -> Vector2:
	return Vector2(floor(texture.get_width() * 0.5), floor(texture.get_height() * 0.5))

func _screen_width() -> float:
	return get_viewport().get_visible_rect().size.x

func _screen_height() -> float:
	return get_viewport().get_visible_rect().size.y
