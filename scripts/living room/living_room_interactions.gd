extends Control

const HeritageStoryCatalog = preload("res://scripts/living room/heritage_story_catalog.gd")
const HERITAGE_STORIES: Dictionary = HeritageStoryCatalog.STORIES

@onready var closed_tv: Sprite2D = get_node("Stand+closedTV")
@onready var open_tv: Sprite2D = get_node("Stand+openTv")
@onready var window_open: Sprite2D = get_node("WindowOpen")
@onready var window_closed: Sprite2D = get_node("WindowClosed")
@onready var lola_not_looking: Sprite2D = get_node("LolaNenaNotLooking")
@onready var lola_looking: Sprite2D = get_node("LolaNenaLooking")

var _heritage_dialogue_open := false
var _story_images: Dictionary = {}
var _recorded_story_ids: Array[String] = []
var _visited_story_ids: Array[String] = []
var _final_kitchen_dialogue_started := false

func _ready() -> void:
	add_to_group("living_room_scene")
	closed_tv.visible = true
	open_tv.visible = false

	var hud := get_node_or_null("/root/HUD")
	var lola_has_moved := false
	if hud != null:
		lola_has_moved = bool(hud.get_meta("living_room_heritage_completed", false))
		# Keep heritage progress on the persistent HUD, not on this room instance.
		# The living room scene may be freed and recreated when changing rooms.
		var saved_visited: Array = hud.get_meta("living_room_visited_story_ids", [])
		var saved_recorded: Array = hud.get_meta("living_room_recorded_story_ids", [])
		_visited_story_ids.assign(saved_visited)
		_recorded_story_ids.assign(saved_recorded)
		_final_kitchen_dialogue_started = bool(hud.get_meta("living_room_final_dialogue_started", false))
	if lola_has_moved:
		lola_not_looking.visible = false
		lola_looking.visible = false

	_create_tv_button()
	_create_interaction_button(window_open, Callable(self, "_on_window_clicked"), "WindowButton")
	if not lola_has_moved:
		_create_interaction_button(lola_not_looking, Callable(self, "_on_lola_clicked"), "LolaNenaButton")

	# Cache each heritage object's texture once; hit-testing uses its actual
	# opaque pixels so transparent parts of layered artwork don't steal clicks.
	for object_name in HERITAGE_STORIES.keys():
		var sprite := get_node_or_null(NodePath(str(object_name))) as Sprite2D
		if sprite != null and sprite.texture != null:
			_story_images[object_name] = sprite.texture.get_image()

	if hud != null and bool(hud.get_meta("opening_intro_transition", false)):
		modulate = Color(0, 0, 0, 1)
		hud.visible = true
		var hud_tween := create_tween()
		hud_tween.set_parallel(true)
		for hud_child in hud.get_children():
			if hud_child is CanvasItem:
				var target_alpha: float = hud_child.modulate.a
				hud_child.modulate.a = 0.0
				hud_tween.tween_property(hud_child, "modulate:a", target_alpha, 1.2)
		await get_tree().create_timer(0.5).timeout
		var room_tween := create_tween()
		room_tween.tween_property(self, "modulate", Color.WHITE, 1.2)
		await room_tween.finished
		hud.set_meta("opening_intro_transition", false)
		var dialogue_scene := load("res://game_scenes/UI scenes/dialogue.tscn") as PackedScene
		if dialogue_scene != null:
			var dialogue_instance := dialogue_scene.instantiate()
			hud.add_child(dialogue_instance)
			if dialogue_instance.has_method("start_opening_sequence"):
				dialogue_instance.call("start_opening_sequence")
			else:
				dialogue_instance.queue_free()
				hud.set("navigation_locked", false)
		else:
			push_warning("Could not load the opening dialogue scene.")
			hud.set("navigation_locked", false)

func _process(_delta: float) -> void:
	# Keep button-based interactions locked until both required room items are collected.
	var unlocked := _room_interactables_unlocked()
	for button_name in ["TVButton", "WindowButton", "LolaNenaButton"]:
		var button := get_node_or_null(NodePath(button_name)) as Button
		if button != null:
			button.disabled = not unlocked

func _room_interactables_unlocked() -> bool:
	var hud := get_node_or_null("/root/HUD")
	return hud != null and hud.has_method("has_collected_room_items") and bool(hud.call("has_collected_room_items"))

func _input(event: InputEvent) -> void:
	var hud := get_node_or_null("/root/HUD")
	if not _room_interactables_unlocked() or _heritage_dialogue_open or (hud != null and bool(hud.get_meta("living_room_heritage_completed", false))) or not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	# Do not intercept clicks intended for the opening dialogue or room transitions.
	if hud == null or bool(hud.get("navigation_locked")):
		return

	var mouse_position := get_global_mouse_position()
	var children := get_children()
	# Later Sprite2D children are drawn above earlier ones, so test them first.
	for i in range(children.size() - 1, -1, -1):
		var sprite := children[i] as Sprite2D
		if sprite == null or not HERITAGE_STORIES.has(sprite.name):
			continue
		# A completed story remains completed when the player returns to this room.
		if _visited_story_ids.has(sprite.name):
			continue
		if _is_opaque_pixel_clicked(sprite, mouse_position, _story_images.get(sprite.name)):
			_open_heritage_story(sprite.name)
			get_viewport().set_input_as_handled()
			return

func _is_opaque_pixel_clicked(sprite: Sprite2D, mouse_position: Vector2, image: Image) -> bool:
	if image == null or image.is_empty() or not sprite.visible:
		return false
	var local_point := sprite.to_local(mouse_position)
	var pixel := Vector2i(floori(local_point.x + image.get_width() * 0.5), floori(local_point.y + image.get_height() * 0.5))
	if pixel.x < 0 or pixel.y < 0 or pixel.x >= image.get_width() or pixel.y >= image.get_height():
		return false
	return image.get_pixelv(pixel).a > 0.12

func _open_heritage_story(object_name: String) -> void:
	if _heritage_dialogue_open or not HERITAGE_STORIES.has(object_name):
		return
	var hud := get_node_or_null("/root/HUD")
	if hud == null or bool(hud.get("navigation_locked")):
		return

	var story: Dictionary = HERITAGE_STORIES[object_name]
	var lines: Array[Dictionary] = [
		{"speaker": "Migs", "text": str(story["migs"])},
		{"speaker": "Lola Nena", "text": str(story["lola"])}
	]
	_start_living_room_dialogue(lines, Callable(self, "_on_object_dialogue_finished").bind(object_name))

func _start_living_room_dialogue(lines: Array[Dictionary], finished_callback: Callable) -> void:
	var hud := get_node_or_null("/root/HUD")
	if hud == null:
		return
	var dialogue_scene := load("res://game_scenes/UI scenes/dialogue.tscn") as PackedScene
	if dialogue_scene == null:
		push_warning("Could not load the dialogue scene.")
		return
	_heritage_dialogue_open = true
	hud.set("navigation_locked", true)
	var dialogue := dialogue_scene.instantiate()
	hud.add_child(dialogue)
	dialogue.sequence_finished.connect(finished_callback)
	dialogue.call("start_custom_sequence", lines)

func _on_object_dialogue_finished(object_name: String) -> void:
	_heritage_dialogue_open = false
	var story: Dictionary = HERITAGE_STORIES[object_name]
	var hud := get_node_or_null("/root/HUD")
	if hud != null and not _recorded_story_ids.has(object_name):
		_recorded_story_ids.append(object_name)
		if hud.has_method("record_heritage_entry"):
			hud.call("record_heritage_entry", str(story["title"]), str(story["entry"]))
	if not _visited_story_ids.has(object_name):
		_visited_story_ids.append(object_name)
	# Persist progress immediately so leaving the room cannot reset completed stories.
	if hud != null:
		hud.set_meta("living_room_visited_story_ids", _visited_story_ids.duplicate())
		hud.set_meta("living_room_recorded_story_ids", _recorded_story_ids.duplicate())
	if _visited_story_ids.size() >= HERITAGE_STORIES.size() and not _final_kitchen_dialogue_started:
		_final_kitchen_dialogue_started = true
		if hud != null:
			hud.set_meta("living_room_final_dialogue_started", true)
		_start_kitchen_reminder_dialogue()
	elif hud != null:
		hud.set("navigation_locked", false)

func _start_kitchen_reminder_dialogue() -> void:
	var lines: Array[Dictionary] = [
		{"speaker": "Lola Nena", "text": "We’ve remembered so many stories today, Migs."},
		{"speaker": "Migs", "text": "I’m glad we wrote them down, Lola."},
		{"speaker": "Lola Nena", "text": "It’s almost tanghali. I need to start cooking in the kitchen."},
		{"speaker": "Migs", "text": "Sige, Lola. I’ll let you get started!"}
	]
	_start_living_room_dialogue(lines, Callable(self, "_on_kitchen_reminder_finished"))

func _on_kitchen_reminder_finished() -> void:
	_heritage_dialogue_open = false
	var hud := get_node_or_null("/root/HUD")
	if hud != null:
		hud.set_meta("living_room_heritage_completed", true)
		hud.set("navigation_locked", false)
	# Lola has left the living room to begin preparing lunch.
	lola_not_looking.visible = false
	lola_looking.visible = false

func is_hovering_room_interactable(mouse_position: Vector2) -> bool:
	if not _room_interactables_unlocked() or _heritage_dialogue_open:
		return false
	for object_name in HERITAGE_STORIES.keys():
		if _visited_story_ids.has(str(object_name)):
			continue
		var sprite := get_node_or_null(NodePath(str(object_name))) as Sprite2D
		if sprite == null or not sprite.visible:
			continue
		if _is_opaque_pixel_clicked(sprite, mouse_position, _story_images.get(object_name)):
			return true
	# The TV and window are interactable, but the TV stand itself is not.
	# The TV screen occupies the upper portion of the combined TV/stand artwork.
	for node_name in ["Stand+closedTV", "Stand+openTv"]:
		var tv_sprite := get_node_or_null(NodePath(node_name)) as Sprite2D
		if tv_sprite != null and tv_sprite.visible and _is_tv_screen_hovered(tv_sprite, mouse_position):
			return true
	for node_name in ["WindowOpen", "WindowClosed"]:
		var window_sprite := get_node_or_null(NodePath(node_name)) as Sprite2D
		if window_sprite != null and window_sprite.visible and _is_opaque_pixel_clicked(window_sprite, mouse_position, window_sprite.texture.get_image()):
			return true
	return false


func _is_tv_screen_hovered(sprite: Sprite2D, mouse_position: Vector2) -> bool:
	if sprite.texture == null or not sprite.visible:
		return false
	var image := sprite.texture.get_image()
	if image == null or image.is_empty():
		return false
	var local_point := sprite.to_local(mouse_position)
	var pixel := Vector2i(
		floori(local_point.x + image.get_width() * 0.5),
		floori(local_point.y + image.get_height() * 0.5)
	)
	if pixel.x < 0 or pixel.y < 0 or pixel.x >= image.get_width() or pixel.y >= image.get_height():
		return false
	# Restrict the cursor to the TV portion at the top of the combined artwork,
	# excluding the stand in the lower section.
	if pixel.y >= int(image.get_height() * 0.58):
		return false
	return image.get_pixelv(pixel).a > 0.12

func can_go_to_kitchen() -> bool:
	var hud := get_node_or_null("/root/HUD")
	return hud != null and bool(hud.get_meta("living_room_heritage_completed", false))

func set_lola_dialogue_pose(is_looking_at_migs: bool) -> void:
	if not lola_not_looking.visible and not lola_looking.visible:
		return
	lola_looking.visible = is_looking_at_migs
	lola_not_looking.visible = not is_looking_at_migs

func _create_tv_button() -> void:
	var button := Button.new()
	button.name = "TVButton"
	button.text = ""
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	var empty_style := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty_style)
	button.add_theme_stylebox_override("hover", empty_style)
	button.add_theme_stylebox_override("pressed", empty_style)
	button.add_theme_stylebox_override("focus", empty_style)
	button.size = Vector2(192, 185)
	button.position = Vector2(189.5, 329.0) - (button.size / 2.0)
	button.pressed.connect(_on_tv_clicked)
	add_child(button)

func _create_interaction_button(sprite: Sprite2D, callback: Callable, button_name: String) -> void:
	if sprite.texture == null:
		return
	var image := sprite.texture.get_image()
	if image == null:
		return
	var used_rect := image.get_used_rect()
	if used_rect.size.x <= 0 or used_rect.size.y <= 0:
		return
	var button := Button.new()
	button.name = button_name
	button.text = ""
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	var empty_style := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty_style)
	button.add_theme_stylebox_override("hover", empty_style)
	button.add_theme_stylebox_override("pressed", empty_style)
	button.add_theme_stylebox_override("focus", empty_style)
	var scaled_size := Vector2(image.get_width(), image.get_height()) * sprite.scale
	var scaled_used_position := Vector2(used_rect.position) * sprite.scale
	var scaled_used_size := Vector2(used_rect.size) * sprite.scale
	button.position = sprite.position - (scaled_size / 2.0) + scaled_used_position
	button.size = scaled_used_size
	button.pressed.connect(callback)
	add_child(button)

func _on_tv_clicked() -> void:
	closed_tv.visible = not closed_tv.visible
	open_tv.visible = not open_tv.visible

func _on_window_clicked() -> void:
	window_open.visible = not window_open.visible
	window_closed.visible = not window_closed.visible


func _on_lola_clicked() -> void:
	lola_not_looking.visible = not lola_not_looking.visible
	lola_looking.visible = not lola_looking.visible
