extends Control

const HERITAGE_STORIES: Dictionary = {
	"FamilyPicture": {
		"title": "A Family Photograph",
		"migs": "Lola, who is in this family picture?",
		"lola": "That was one of our family gatherings. This picture keeps those happy moments close.",
		"entry": "Family photographs preserve loved ones, gatherings, and shared memories."
	},
	"LolaNenaPortrait": {
		"title": "A Face from the Past",
		"migs": "Lola, who is in this old portrait?",
		"lola": "Your great-grandmother. Her stories remind us of the people who came before us.",
		"entry": "Portraits preserve memories of earlier generations and the lives they lived."
	},
	"Salakot": {
		"title": "The Salakot",
		"migs": "What was the salakot used for, Lola?",
		"lola": "It helped protect farmers from the sun and rain. It was made for everyday work.",
		"entry": "The salakot reflects Filipino ingenuity and traditional everyday life."
	},
	"Books": {
		"title": "Books Full of Stories",
		"migs": "Why do you keep these old books?",
		"lola": "Books carry ideas, language, and memories from one generation to the next.",
		"entry": "Books preserve knowledge, language, and ideas across generations."
	},
	"Urn": {
		"title": "The Old Urn",
		"migs": "Do you know where this urn came from?",
		"lola": "It has been here for years. We should ask our elders before guessing its story.",
		"entry": "Record an object's history carefully, using reliable memories instead of guesses."
	},
	"Plants": {
		"title": "Lessons in the Garden",
		"migs": "Who taught you to care for plants, Lola?",
		"lola": "My mother did. I learned by watching her and caring for them every day.",
		"entry": "Plant care can preserve family routines and knowledge passed down over time."
	},
	"Plants3": {
		"title": "A Living Tradition",
		"migs": "Have we always kept plants at home?",
		"lola": "As long as I can remember. Caring for them taught us patience.",
		"entry": "Everyday habits can become traditions when families pass them on."
	},
	"Banig": {
		"title": "The Woven Banig",
		"migs": "Who makes a banig, Lola?",
		"lola": "Skilled weavers make these mats by hand. Their patterns and techniques deserve to be remembered.",
		"entry": "A banig preserves traditional weaving skills, patterns, and local craft knowledge."
	},
	"TableRadio": {
		"title": "Voices on the Radio",
		"migs": "Did you listen to this radio when you were young?",
		"lola": "We listened to news and music together. Those broadcasts became family memories.",
		"entry": "Old radios show how families once shared news, music, and entertainment."
	},
	"PictureFrameTopleft": {
		"title": "More Than a Frame",
		"migs": "Why keep old pictures instead of replacing them?",
		"lola": "The people and moments matter, hijo. Their stories make each picture precious.",
		"entry": "Names, dates, and memories give photographs meaning beyond their frames."
	},
	"Plants2Up": {
		"title": "Care Passed Down",
		"migs": "These plants look carefully tended, Lola.",
		"lola": "They remind me of the small lessons my family taught me about caring for our home.",
		"entry": "Caring for household plants can preserve family knowledge and daily traditions."
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
	var hud := get_node_or_null("/root/HUD")
	if _heritage_dialogue_open or (hud != null and bool(hud.get_meta("living_room_heritage_completed", false))) or not (event is InputEventMouseButton):
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
	if _visited_story_ids.size() >= HERITAGE_STORIES.size() and not _final_kitchen_dialogue_started:
		_final_kitchen_dialogue_started = true
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
	if _heritage_dialogue_open:
		return false
	for object_name in HERITAGE_STORIES.keys():
		var sprite := get_node_or_null(NodePath(str(object_name))) as Sprite2D
		if sprite == null or not sprite.visible:
			continue
		if _is_opaque_pixel_clicked(sprite, mouse_position, _story_images.get(object_name)):
			return true
	# Keep the magnifying cursor for the existing TV, window, and couch interactions too.
	for node_name in ["Stand+closedTV", "Stand+openTv", "WindowOpen", "WindowClosed", "Couch+plant"]:
		var sprite := get_node_or_null(NodePath(node_name)) as Sprite2D
		if sprite != null and sprite.visible and _is_opaque_pixel_clicked(sprite, mouse_position, sprite.texture.get_image()):
			return true
	return false

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

func _on_couch_clicked() -> void:
	pass

func _on_lola_clicked() -> void:
	lola_not_looking.visible = not lola_not_looking.visible
	lola_looking.visible = not lola_looking.visible
