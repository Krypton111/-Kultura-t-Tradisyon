extends Control

@onready var closed_tv: Sprite2D = get_node("Stand+closedTV")
@onready var open_tv: Sprite2D = get_node("Stand+openTv")
@onready var window_open: Sprite2D = get_node("WindowOpen")
@onready var window_closed: Sprite2D = get_node("WindowClosed")
@onready var couch: Sprite2D = get_node("Couch+plant")
@onready var lola_not_looking: Sprite2D = get_node("LolaNenaNotLooking")
@onready var lola_looking: Sprite2D = get_node("LolaNenaLooking")

func _ready() -> void:
	# Shared hook for dialogue scenes: Lola looks toward Migs during
	# living-room conversations and returns to her idle pose afterward.
	add_to_group("living_room_scene")
	closed_tv.visible = true
	open_tv.visible = false

	# Once both items have been collected, Lola has moved to the kitchen.
	var hud := get_node_or_null("/root/HUD")
	var lola_has_moved: bool = false
	if hud != null and hud.has_method("has_collected_room_items"):
		lola_has_moved = bool(hud.call("has_collected_room_items"))
	if lola_has_moved:
		lola_not_looking.visible = false
		lola_looking.visible = false

	# The artwork stays exactly where it was placed in Canva.
	# The TV uses a fixed point-and-click area.
	_create_tv_button()

	# Other interactive objects keep their automatically generated
	# transparent UI interaction regions.
	# The interaction areas stay active even after the artwork changes state,
	# so the player can click the curtain and Lola Nena again to return them
	# to their normal states.
	_create_interaction_button(window_open, Callable(self, "_on_window_clicked"), "WindowButton")
	_create_interaction_button(couch, Callable(self, "_on_couch_clicked"), "CouchButton")
	if not lola_has_moved:
		_create_interaction_button(lola_not_looking, Callable(self, "_on_lola_clicked"), "LolaNenaButton")

	# On the first visit, fade the HUD in first, then start the living-room
	# fade 0.5 seconds later. Normal room-to-room transitions remain unchanged.
	if hud != null and bool(hud.get_meta("opening_intro_transition", false)):
		modulate = Color(0, 0, 0, 1)
		hud.visible = true

		# Start the HUD fade immediately.
		var hud_tween := create_tween()
		hud_tween.set_parallel(true)
		for hud_child in hud.get_children():
			if hud_child is CanvasItem:
				var target_alpha: float = hud_child.modulate.a
				hud_child.modulate.a = 0.0
				hud_tween.tween_property(hud_child, "modulate:a", target_alpha, 1.2)

		# Give the HUD a 0.5-second head start before fading in the room.
		await get_tree().create_timer(0.5).timeout
		var room_tween := create_tween()
		room_tween.tween_property(self, "modulate", Color.WHITE, 1.2)
		await room_tween.finished

		hud.set_meta("opening_intro_transition", false)

		# Start Scene 1's opening conversation after the room has fully faded in.
		# The dialogue scene is added to the HUD CanvasLayer so it renders above
		# the room and HUD artwork, using the existing dialogue box design.
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

func set_lola_dialogue_pose(is_looking_at_migs: bool) -> void:
	# If Lola has already moved out of the living room, leave both sprites hidden.
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

	# TV interaction area:
	# Center = X 189.5, Y 329.0
	# Size = 192 x 185
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

	# Sprite2D coordinates are centered on the texture.
	# Convert the non-transparent image rectangle into the same
	# scaled screen coordinates without changing the sprite itself.
	var scaled_size := Vector2(image.get_width(), image.get_height()) * sprite.scale
	var scaled_used_position := Vector2(used_rect.position) * sprite.scale
	var scaled_used_size := Vector2(used_rect.size) * sprite.scale

	button.position = sprite.position - (scaled_size / 2.0) + scaled_used_position
	button.size = scaled_used_size

	button.pressed.connect(callback)
	add_child(button)

func _on_tv_clicked() -> void:
	# Toggle the TV every time the player clicks it.
	closed_tv.visible = not closed_tv.visible
	open_tv.visible = not open_tv.visible

func _on_window_clicked() -> void:
	# Toggle the curtain/window between its open and normal closed state.
	window_open.visible = not window_open.visible
	window_closed.visible = not window_closed.visible

func _on_couch_clicked() -> void:
	# Interaction area is ready for the couch/plant event.
	pass

func _on_lola_clicked() -> void:
	# Toggle Lola Nena between her normal pose and looking-at-Migs pose.
	lola_not_looking.visible = not lola_not_looking.visible
	lola_looking.visible = not lola_looking.visible
