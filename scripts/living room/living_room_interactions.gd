extends Control

const HERITAGE_STORIES: Dictionary = {
	"FamilyPicture": {
		"title": "A Picture That Keeps Us Together",
		"migs": "Lola, who are all the people in this old family picture?",
		"lola": "That was taken during one of our family gatherings. Some faces are no longer with us, but this picture helps me remember their laughter and the way we celebrated together.",
		"entry": "Family photographs preserve memories of loved ones, gatherings, and traditions. Recording the people and occasion in a photo helps future generations understand its story."
	},
	"LolaNenaPortrait": {
		"title": "The Face Behind the Stories",
		"migs": "Lola, this portrait looks like it has been here for a long time. Who kept it safe?",
		"lola": "Your great-grandmother treasured it. A portrait reminds us that every generation has people whose lives and choices helped shape our family.",
		"entry": "Portraits help preserve the memory of people from earlier generations. Their names and stories give the image meaning beyond the frame."
	},
	"Salakot": {
		"title": "A Hat Made for Everyday Life",
		"migs": "I've seen salakot before, but I never asked why people used them.",
		"lola": "A salakot helped shield farmers and workers from the sun and rain. It tells a story about the resourcefulness of people and the work that sustained their communities.",
		"entry": "The salakot is a traditional Filipino hat associated with practical everyday life, especially outdoor work. Learning how and why it was used preserves knowledge of local ways of living."
	},
	"Books": {
		"title": "Pages Worth Passing On",
		"migs": "Are these books still important even if some of them are old?",
		"lola": "Of course, hijo. Books carry ideas, language, and memories from one reader to another. The notes and names inside can tell their own stories, too.",
		"entry": "Books preserve knowledge, language, and ideas. Keeping them safe and noting who owned or read them can help future generations discover their history."
	},
	"Urn": {
		"title": "A Vessel with a Past",
		"migs": "Lola, do you know where this urn came from?",
		"lola": "It has been kept in our family for years. Before we decide what it means, we should ask the elders who remember it and record what they know instead of guessing.",
		"entry": "An old vessel can be part of a family's material heritage. Its origin and purpose should be documented through reliable family memories rather than assumptions."
	},
	"Plants": {
		"title": "A Living Tradition",
		"migs": "You take such good care of these plants, Lola. Did someone teach you?",
		"lola": "My mother did. She taught me which plants liked the shade and how to care for them. I passed those little lessons on by doing them every day.",
		"entry": "Gardening knowledge can be part of living heritage. Plant care, family routines, and knowledge passed from one generation to another are traditions worth recording."
	},
	"Plants3": {
		"title": "Green Things, Old Lessons",
		"migs": "Did our family always keep plants around the house?",
		"lola": "As long as I can remember. Caring for them taught us patience and responsibility. Sometimes traditions survive through simple habits we repeat together.",
		"entry": "Everyday routines, such as tending household plants, can carry family values and memories. Recording who taught the practice helps keep it alive."
	},
	"Banig": {
		"title": "Woven by Hand, Remembered by Heart",
		"migs": "This banig looks simple, but it has such a distinct pattern.",
		"lola": "A banig is woven with care, and patterns and techniques can differ from place to place. The skill behind it deserves to be remembered, not just the finished mat.",
		"entry": "A banig is a woven mat and an example of Filipino craft heritage. Remembering the maker, materials, place, and weaving technique helps preserve the knowledge behind it."
	},
	"TableRadio": {
		"title": "Voices from Another Time",
		"migs": "Did you listen to this radio when you were younger?",
		"lola": "We gathered around it for news, music, and stories. Families shared the same broadcasts, and those moments became memories of their own.",
		"entry": "An old radio can remind a family how people received news, music, and entertainment. Recording what they listened to turns an object into a window to everyday life."
	},
	"PictureFrameTopleft": {
		"title": "Look Beyond the Frame",
		"migs": "Why do we keep old pictures instead of replacing them?",
		"lola": "Because the people and moments in them matter. A frame protects a picture, but the story we tell about it is what helps it live on.",
		"entry": "Picture frames protect treasured images, but oral history gives those images context. Names, dates, places, and memories make photographs more meaningful."
	}
}

@onready var closed_tv: Sprite2D = get_node("Stand+closedTV")
@onready var open_tv: Sprite2D = get_node("Stand+openTv")
@onready var window_open: Sprite2D = get_node("WindowOpen")
@onready var window_closed: Sprite2D = get_node("WindowClosed")
@onready var couch: Sprite2D = get_node("Couch+plant")
@onready var lola_not_looking: Sprite2D = get_node("LolaNenaNotLooking")
@onready var lola_looking: Sprite2D = get_node("LolaNenaLooking")

var _heritage_dialogue_open := false
var _story_images: Dictionary = {}
var _recorded_story_ids: Array[String] = []

func _ready() -> void:
	add_to_group("living_room_scene")
	closed_tv.visible = true
	open_tv.visible = false

	var hud := get_node_or_null("/root/HUD")
	var lola_has_moved := false
	if hud != null and hud.has_method("has_collected_room_items"):
		lola_has_moved = bool(hud.call("has_collected_room_items"))
	if lola_has_moved:
		lola_not_looking.visible = false
		lola_looking.visible = false

	_create_tv_button()
	_create_interaction_button(window_open, Callable(self, "_on_window_clicked"), "WindowButton")
	_create_interaction_button(couch, Callable(self, "_on_couch_clicked"), "CouchButton")
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

func _input(event: InputEvent) -> void:
	if _heritage_dialogue_open or not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	var hud := get_node_or_null("/root/HUD")
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
	var hud := get_node_or_null("/root/HUD")
	if hud == null:
		return
	if hud.has_method("get") and bool(hud.get("navigation_locked")):
		return

	var story: Dictionary = HERITAGE_STORIES[object_name]
	_heritage_dialogue_open = true
	hud.set("navigation_locked", true)
	var overlay := Control.new()
	overlay.name = "HeritageStoryOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 1050
	hud.add_child(overlay)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.035, 0.045, 0.055, 0.78)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(shade)

	var panel := PanelContainer.new()
	panel.name = "StoryCard"
	panel.position = Vector2(180, 110)
	panel.size = Vector2(792, 430)
	panel.add_theme_stylebox_override("panel", _make_story_panel_style())
	overlay.add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	panel.add_child(layout)

	var eyebrow := Label.new()
	eyebrow.text = "LOLA NENA'S LIVING ROOM  •  HERITAGE JOURNAL"
	eyebrow.add_theme_font_size_override("font_size", 13)
	eyebrow.add_theme_color_override("font_color", Color(0.78, 0.65, 0.39))
	layout.add_child(eyebrow)

	var title := Label.new()
	title.text = str(story["title"])
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color(0.96, 0.91, 0.79))
	layout.add_child(title)

	var migs_line := _make_story_line("MIGS", str(story["migs"]), Color(0.62, 0.78, 0.91))
	layout.add_child(migs_line)
	var lola_line := _make_story_line("LOLA NENA", str(story["lola"]), Color(0.86, 0.72, 0.48))
	layout.add_child(lola_line)

	var note := Label.new()
	note.text = "JOURNAL NOTE  •  " + str(story["entry"])
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 14)
	note.add_theme_color_override("font_color", Color(0.86, 0.85, 0.80))
	layout.add_child(note)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(spacer)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 10)
	layout.add_child(buttons)

	var close_button := Button.new()
	close_button.text = "KEEP EXPLORING"
	close_button.custom_minimum_size = Vector2(180, 42)
	close_button.pressed.connect(func() -> void: _close_heritage_story(overlay, hud))
	buttons.add_child(close_button)

	var record_button := Button.new()
	record_button.text = "✦  RECORD IN JOURNAL"
	record_button.custom_minimum_size = Vector2(230, 42)
	record_button.add_theme_color_override("font_color", Color(0.12, 0.13, 0.13))
	record_button.add_theme_stylebox_override("normal", _make_record_button_style())
	record_button.add_theme_stylebox_override("hover", _make_record_button_style(true))
	record_button.pressed.connect(func() -> void:
		if not _recorded_story_ids.has(object_name):
			if hud.has_method("record_heritage_entry"):
				hud.call("record_heritage_entry", str(story["title"]), str(story["entry"]))
			_recorded_story_ids.append(object_name)
		_close_heritage_story(overlay, hud)
	)
	buttons.add_child(record_button)

func _make_story_line(speaker: String, words: String, speaker_color: Color) -> Control:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 3)
	var name_label := Label.new()
	name_label.text = speaker
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", speaker_color)
	container.add_child(name_label)
	var line := Label.new()
	line.text = words
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_theme_font_size_override("font_size", 16)
	line.add_theme_color_override("font_color", Color(0.94, 0.92, 0.86))
	container.add_child(line)
	return container

func _make_story_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.13, 0.15, 0.98)
	style.border_color = Color(0.72, 0.57, 0.32)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	return style

func _make_record_button_style(hovered: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.86, 0.72, 0.48) if hovered else Color(0.78, 0.64, 0.39)
	style.set_corner_radius_all(7)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style

func _close_heritage_story(overlay: Control, hud: Node) -> void:
	_heritage_dialogue_open = false
	if is_instance_valid(overlay):
		overlay.queue_free()
	hud.set("navigation_locked", false)

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

func _on_couch_clicked() -> void:
	pass

func _on_lola_clicked() -> void:
	lola_not_looking.visible = not lola_not_looking.visible
	lola_looking.visible = not lola_looking.visible
