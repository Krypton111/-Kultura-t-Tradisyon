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

const LIVING_ROOM := "res://game_scenes/levels/living_room.tscn"
const KITCHEN := "res://game_scenes/levels/kitchen.tscn"
const MIGS_ROOM := "res://game_scenes/levels/migs_room.tscn"
const BACKYARD := "res://game_scenes/levels/backyard.tscn"
const JOURNAL_SCENE: PackedScene = preload("res://game_scenes/UI scenes/journal.tscn")

var current_direction := ""
var navigation_locked := false
var left_cursor: Texture2D
var right_cursor: Texture2D
var down_cursor: Texture2D
var magnify_cursor: Texture2D
var fade_rect: ColorRect
var fade_tween: Tween
var footsteps_player: AudioStreamPlayer
var journal_is_open := false
var journal_overlay_instance: Control
var journal_close: Sprite2D
var journal_open: Sprite2D
var camera_icon: Sprite2D
var camera_collected := false
var journal_collected := false

var room_scenes := {
	LIVING_ROOM: preload("res://game_scenes/levels/living_room.tscn"),
	KITCHEN: preload("res://game_scenes/levels/kitchen.tscn"),
	MIGS_ROOM: preload("res://game_scenes/levels/migs_room.tscn"),
	BACKYARD: preload("res://game_scenes/levels/backyard.tscn")
}

func _ready() -> void:
	left_cursor = _prepare_cursor(LEFT_CURSOR)
	right_cursor = _prepare_cursor(RIGHT_CURSOR)
	down_cursor = _prepare_cursor(DOWN_CURSOR, DOWN_CURSOR_MAX_SIZE)
	magnify_cursor = _prepare_cursor(MAGNIFY_CURSOR)

	_create_navigation_button("LeftNavigation", LEFT_NAV_POSITION, Callable(self, "_go_left"))
	_create_navigation_button("RightNavigation", RIGHT_NAV_POSITION, Callable(self, "_go_right"))
	_create_navigation_button("DownNavigation", DOWN_NAV_POSITION, Callable(self, "_go_down"))

	get_viewport().size_changed.connect(_on_viewport_resized)
	_create_fade_overlay()
	_create_footsteps_player()
	_setup_journal_toggle()

func _process(_delta: float) -> void:
	_update_journal_hover()

	if navigation_locked:
		return

	_update_cursor(get_viewport().get_mouse_position())

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

func reveal_journal() -> void:
	journal_collected = true
	if journal_close == null or journal_open == null:
		return
	journal_is_open = false
	journal_close.visible = false
	journal_open.visible = false
	_fade_hud_sprite_in(journal_close)

func reveal_camera() -> void:
	camera_collected = true
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

func _is_hovering_room_interactable(mouse_position: Vector2) -> bool:
	var current_scene := get_tree().current_scene
	if current_scene and current_scene.has_method("is_hovering_room_interactable"):
		return current_scene.is_hovering_room_interactable(mouse_position)
	return false

func _is_hovering_journal() -> bool:
	if journal_close == null or journal_open == null:
		return false

	var mouse_position := get_viewport().get_mouse_position()
	var over_close := journal_close.visible and journal_close.get_rect().has_point(journal_close.to_local(mouse_position))
	var over_open := journal_open.visible and journal_open.get_rect().has_point(journal_open.to_local(mouse_position))
	return over_close or over_open

func _input(event: InputEvent) -> void:
	# While the journal overlay is open, let it handle its own controls.
	if journal_is_open:
		return
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	if journal_close == null or journal_open == null:
		return

	var mouse_position := get_viewport().get_mouse_position()
	var over_close := journal_close.visible and journal_close.get_rect().has_point(journal_close.to_local(mouse_position))
	var over_open := journal_open.visible and journal_open.get_rect().has_point(journal_open.to_local(mouse_position))
	if over_close or over_open:
		_open_journal_overlay()
		get_viewport().set_input_as_handled()

func _open_journal_overlay() -> void:
	if journal_is_open or JOURNAL_SCENE == null:
		return

	journal_overlay_instance = JOURNAL_SCENE.instantiate() as Control
	if journal_overlay_instance == null:
		push_warning("The journal scene root must be a Control node.")
		return

	journal_is_open = true
	if journal_close:
		journal_close.visible = false
	if journal_open:
		journal_open.visible = true

	journal_overlay_instance.close_requested.connect(_close_journal_overlay)
	add_child(journal_overlay_instance)

func _close_journal_overlay() -> void:
	journal_is_open = false
	if is_instance_valid(journal_overlay_instance):
		journal_overlay_instance.queue_free()
	journal_overlay_instance = null

	if journal_close:
		journal_close.visible = journal_collected
	if journal_open:
		journal_open.visible = false

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
		var down_size := Vector2(DOWN_NAV_WIDTH, DOWN_NAV_HEIGHT)
		down_button.position = DOWN_NAV_POSITION - down_size * 0.5
		down_button.size = down_size

	if fade_rect:
		fade_rect.size = Vector2(_screen_width(), _screen_height())

func _update_cursor(mouse_position: Vector2) -> void:
	if _is_hovering_journal() or _is_hovering_room_interactable(mouse_position):
		if current_direction != "journal":
			current_direction = "journal"
			Input.set_custom_mouse_cursor(magnify_cursor, Input.CURSOR_ARROW, _cursor_hotspot(magnify_cursor))
		return

	var direction := ""
	var left_hotspot_size := Vector2(LEFT_NAV_WIDTH, LEFT_NAV_HEIGHT)
	var right_hotspot_size := Vector2(RIGHT_NAV_WIDTH, RIGHT_NAV_HEIGHT)
	var down_hotspot_size := Vector2(DOWN_NAV_WIDTH, DOWN_NAV_HEIGHT)
	var left_hotspot_offset := left_hotspot_size * 0.5
	var right_hotspot_offset := right_hotspot_size * 0.5
	var down_hotspot_offset := down_hotspot_size * 0.5

	if Rect2(
		LEFT_NAV_POSITION - left_hotspot_offset,
		left_hotspot_size
	).has_point(mouse_position):
		direction = "left"
	elif Rect2(
		RIGHT_NAV_POSITION - right_hotspot_offset,
		right_hotspot_size
	).has_point(mouse_position):
		direction = "right"
	elif Rect2(
		DOWN_NAV_POSITION - down_hotspot_offset,
		down_hotspot_size
	).has_point(mouse_position):
		direction = "down"

	if not _is_direction_available(direction):
		direction = ""

	if direction == current_direction:
		return

	current_direction = direction

	match direction:
		"left":
			Input.set_custom_mouse_cursor(left_cursor, Input.CURSOR_ARROW, _cursor_hotspot(left_cursor))
		"right":
			Input.set_custom_mouse_cursor(right_cursor, Input.CURSOR_ARROW, _cursor_hotspot(right_cursor))
		"down":
			Input.set_custom_mouse_cursor(down_cursor, Input.CURSOR_ARROW, _cursor_hotspot(down_cursor))
		_:
			Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)

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
	fade_tween.tween_property(fade_rect, "color:a", 1.0, 1.0)
	await fade_tween.finished

	get_tree().change_scene_to_packed(next_room)

	await get_tree().process_frame

	fade_tween = create_tween()
	fade_tween.tween_property(fade_rect, "color:a", 0.0, 1.0)
	await fade_tween.finished

	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	navigation_locked = false
	_update_cursor(get_viewport().get_mouse_position())

func _exit_tree() -> void:
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)

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
