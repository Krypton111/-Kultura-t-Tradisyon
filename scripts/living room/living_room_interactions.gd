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
	var game_state := get_node_or_null("/root/GameState")
	var salakot_reward_received := bool(game_state.get_state("salakot_reward_received", false)) if game_state != null else false
	var salakot_sprite := get_node_or_null("Salakot") as Sprite2D
	if salakot_reward_received and salakot_sprite != null:
		salakot_sprite.visible = false
		salakot_sprite.modulate.a = 1.0
	var lola_has_moved := false
	if game_state != null:
		lola_has_moved = bool(game_state.get_state("living_room_heritage_completed", false))
		var saved_visited: Array = game_state.get_state("living_room_visited_story_ids", [])
		var saved_recorded: Array = game_state.get_state("living_room_recorded_story_ids", [])
		_visited_story_ids.assign(saved_visited)
		_recorded_story_ids.assign(saved_recorded)
		_final_kitchen_dialogue_started = bool(game_state.get_state("living_room_final_dialogue_started", false))
	var lunch_completed := bool(game_state.get_state("lunch_completed", false)) if game_state != null else false
	if lunch_completed:
		# The meal sequence returns Migs and Lola to the living room together.
		# Show Lola's seated, relaxed pose instead of the earlier empty-room state.
		lola_not_looking.visible = true
		lola_looking.visible = false
	elif lola_has_moved:
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

	# Resume the ending flow after the room and persistent HUD are ready.
	call_deferred("_resume_ending_if_needed")

func _resume_ending_if_needed() -> void:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null or not bool(game_state.get_state("lunch_completed", false)):
		return
	if bool(game_state.get_state("ending_completed", false)):
		_show_ending_card(str(game_state.get_state("ending_choice", "")))
		return
	var saved_choice := str(game_state.get_state("ending_choice", ""))
	if saved_choice in ["stay", "city"]:
		_play_ending_dialogue(saved_choice)
	else:
		_start_ending_question()

func _start_ending_question() -> void:
	if _heritage_dialogue_open:
		return
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null or not bool(game_state.get_state("lunch_completed", false)):
		return
	var lines: Array[Dictionary] = [
		{"speaker": "Lola Nena", "text": "Migs, seeing you here in our home again makes me happy. Today, we shared a meal, remembered the stories behind our old belongings, and talked about the traditions our family has carried for generations."},
		{"speaker": "Migs", "text": "I never realized how much meaning was hidden in the things around us, Lola. Every story helped me understand our family and where we came from a little better."},
		{"speaker": "Lola Nena", "text": "That is why I have always wanted to share these things with you, hijo. Our heritage is more than old objects and stories. It lives in the food we prepare, the work we do, the celebrations we keep, and the lessons we pass from one generation to the next."},
		{"speaker": "Migs", "text": "I understand that more now. I want other people to appreciate these traditions too, and I also want to make sure our family's stories are not forgotten."},
		{"speaker": "Lola Nena", "text": "There are different ways you can help. You could stay here in the province with me, help care for our home, learn more of our customs, and pass them on to the younger ones."},
		{"speaker": "Lola Nena", "text": "Or you could return to the city and share what you have learned with your friends and community. Even far from here, you can keep our traditions alive by telling our stories and encouraging others to value their own heritage."},
		{"speaker": "Migs", "text": "Both choices matter, Lola. I just need to think about where I can do the most good."},
		{"speaker": "Lola Nena", "text": "You do not have to carry every responsibility alone, Migs. Whatever you choose, remember that heritage survives when people care for it and share it. Take your time, hijo. The decision is yours."}
	]
	_start_living_room_dialogue(lines, Callable(self, "_on_ending_question_finished"))

func _on_ending_question_finished() -> void:
	_heritage_dialogue_open = false
	var hud := get_node_or_null("/root/HUD")
	if hud != null:
		hud.set("navigation_locked", true)
	_show_ending_choice_panel()

func _show_ending_choice_panel() -> void:
	var hud := get_node_or_null("/root/HUD") as Control
	if hud == null:
		return
	hud.set("navigation_locked", true)
	var existing := hud.get_node_or_null("EndingChoiceOverlay")
	if existing != null:
		existing.queue_free()
	var overlay := Control.new()
	overlay.name = "EndingChoiceOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(overlay)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.035, 0.025, 0.018, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 420)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.16, 0.13, 0.10, 0.99)
	panel_style.border_color = Color(0.78, 0.61, 0.35, 1.0)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(14)
	panel_style.content_margin_left = 34.0
	panel_style.content_margin_right = 34.0
	panel_style.content_margin_top = 28.0
	panel_style.content_margin_bottom = 28.0
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 18)
	panel.add_child(layout)

	var heading := Label.new()
	heading.text = "A CHOICE FOR THE FUTURE"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 30)
	heading.add_theme_color_override("font_color", Color(0.91, 0.76, 0.49))
	layout.add_child(heading)

	var prompt := Label.new()
	prompt.text = "What will Migs do with the traditions and heritage he has learned?"
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 20)
	prompt.add_theme_color_override("font_color", Color(0.97, 0.94, 0.86))
	layout.add_child(prompt)

	layout.add_child(_make_ending_choice_button("Stay and Help Lola Nena", "Remain in the province and preserve their family heritage together.", Callable(self, "_choose_ending").bind("stay")))
	layout.add_child(_make_ending_choice_button("Return to the City", "Share what he learned with others in the city.", Callable(self, "_choose_ending").bind("city")))

func _make_ending_choice_button(title_text: String, description_text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = title_text + "\n" + description_text
	button.custom_minimum_size = Vector2(660, 88)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color(0.97, 0.94, 0.86))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.86, 0.59))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.24, 0.19, 0.14, 1.0)
	normal.border_color = Color(0.61, 0.46, 0.28, 1.0)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 14.0
	normal.content_margin_right = 14.0
	normal.content_margin_top = 10.0
	normal.content_margin_bottom = 10.0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.31, 0.24, 0.16, 1.0)
	hover.border_color = Color(0.91, 0.76, 0.49, 1.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.pressed.connect(callback)
	return button

func _choose_ending(choice: String) -> void:
	var hud := get_node_or_null("/root/HUD")
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return
	var overlay := hud.get_node_or_null("EndingChoiceOverlay") if hud != null else null
	if overlay != null:
		overlay.queue_free()
	game_state.set_state("ending_choice", choice)
	_play_ending_dialogue(choice)

func _play_ending_dialogue(choice: String) -> void:
	var lines: Array[Dictionary] = []
	if choice == "stay":
		lines = [
			{"speaker": "Migs", "text": "I have decided to stay here with you, Lola. I want to learn more about our traditions instead of only hearing about them once in a while."},
			{"speaker": "Lola Nena", "text": "I would love that, hijo. There is still so much I can teach you, from the stories of our elders to the little everyday practices that make our culture special."},
			{"speaker": "Migs", "text": "I can help with the house, join in our traditions, and write down the stories so we can share them with the younger members of our family."},
			{"speaker": "Lola Nena", "text": "Remember that preserving heritage is not only about keeping the past untouched. It is also about understanding its meaning and finding thoughtful ways to pass it on as life changes."},
			{"speaker": "Migs", "text": "I’ll keep learning from you and from our community, Lola. I want the next generation to feel connected to these stories just as I do now."},
			{"speaker": "Lola Nena", "text": "Then we will do it together, hijo. As long as we keep caring, practicing, and teaching, our traditions will continue to live in our home."}
		]
	else:
		lines = [
			{"speaker": "Migs", "text": "I think I should return to the city, Lola. I want to share what I learned with my friends and help them understand why our traditions matter."},
			{"speaker": "Lola Nena", "text": "I will miss having you here, hijo, but I understand. Distance does not mean you have to leave your heritage behind."},
			{"speaker": "Migs", "text": "I could tell my friends about our stories, share the meaning behind our food and customs, and encourage them to learn about their own families too."},
			{"speaker": "Lola Nena", "text": "That would make me proud. Share our stories with care and respect, and remember that every community has traditions worth understanding and protecting."},
			{"speaker": "Migs", "text": "I’ll keep in touch and come back whenever I can. I want to keep learning from you even while I share what you have taught me with others."},
			{"speaker": "Lola Nena", "text": "Then take these memories with you, hijo. Wherever life brings you, you can help our heritage live on by remembering it, practicing it, and passing it along."}
		]
	_start_living_room_dialogue(lines, Callable(self, "_on_ending_dialogue_finished").bind(choice))

func _on_ending_dialogue_finished(choice: String) -> void:
	_heritage_dialogue_open = false
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null:
		game_state.set_state("ending_completed", true)
	_show_ending_card(choice)

func _show_ending_card(choice: String) -> void:
	var hud := get_node_or_null("/root/HUD") as Control
	if hud == null:
		return
	hud.set("navigation_locked", true)
	var existing := hud.get_node_or_null("EndingChoiceOverlay")
	if existing != null:
		existing.queue_free()
	var overlay := Control.new()
	overlay.name = "EndingChoiceOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(overlay)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.035, 0.025, 0.018, 0.86)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 390)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.16, 0.13, 0.10, 0.99)
	panel_style.border_color = Color(0.78, 0.61, 0.35, 1.0)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(14)
	panel_style.content_margin_left = 36.0
	panel_style.content_margin_right = 36.0
	panel_style.content_margin_top = 34.0
	panel_style.content_margin_bottom = 34.0
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 20)
	panel.add_child(layout)

	var heading := Label.new()
	heading.text = "THE END"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 36)
	heading.add_theme_color_override("font_color", Color(0.91, 0.76, 0.49))
	layout.add_child(heading)

	var ending_text := Label.new()
	if choice == "stay":
		ending_text.text = "Migs chooses to stay in the province, helping Lola Nena care for their home and pass their family's traditions and heritage to future generations. By learning, documenting, and practicing these traditions, he strengthens their place in the community."
	else:
		ending_text.text = "Migs returns to the city carrying the stories and lessons he learned from Lola Nena. By sharing them with friends and his wider community, he helps keep their traditions alive beyond the province."
	ending_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ending_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ending_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ending_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ending_text.add_theme_font_size_override("font_size", 20)
	ending_text.add_theme_color_override("font_color", Color(0.97, 0.94, 0.86))
	layout.add_child(ending_text)

	var subtitle := Label.new()
	subtitle.text = "Cultural heritage lives on when we choose to care for it, share it, and pass it on."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.add_theme_color_override("font_color", Color(0.91, 0.76, 0.49))
	layout.add_child(subtitle)

	var finish_label := Label.new()
	finish_label.text = "Thank you for playing Kultura at Tradisyon."
	finish_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	finish_label.add_theme_font_size_override("font_size", 15)
	finish_label.add_theme_color_override("font_color", Color(0.97, 0.94, 0.86))
	layout.add_child(finish_label)

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
	if not _room_interactables_unlocked() or _heritage_dialogue_open or (hud != null and bool(get_node("/root/GameState").get_state("living_room_heritage_completed", false))) or not (event is InputEventMouseButton):
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
	var game_state := get_node_or_null("/root/GameState")
	if hud != null and not _recorded_story_ids.has(object_name):
		_recorded_story_ids.append(object_name)
		if hud.has_method("record_heritage_entry"):
			hud.call("record_heritage_entry", str(story["title"]), str(story["entry"]), object_name)
	if not _visited_story_ids.has(object_name):
		_visited_story_ids.append(object_name)
	# Persist progress immediately so leaving the room cannot reset completed stories.
	if game_state != null:
		game_state.set_state("living_room_visited_story_ids", _visited_story_ids)
		game_state.set_state("living_room_recorded_story_ids", _recorded_story_ids)
	if _visited_story_ids.size() >= HERITAGE_STORIES.size() and not _final_kitchen_dialogue_started:
		_final_kitchen_dialogue_started = true
		if game_state != null:
			game_state.set_state("living_room_final_dialogue_started", true)
		_start_salakot_reward_dialogue()
	elif hud != null:
		hud.set("navigation_locked", false)

func _start_salakot_reward_dialogue() -> void:
	var lines: Array[Dictionary] = [
		{"speaker": "Lola Nena", "text": "You’ve helped me remember the stories behind our family’s old belongings, Migs. As a thank-you, I’d like you to have this salakot."},
		{"speaker": "Migs", "text": "Really, Lola? Thank you! I’ll take good care of it."}
	]
	_start_living_room_dialogue(lines, Callable(self, "_on_salakot_reward_dialogue_finished"))


func _on_salakot_reward_dialogue_finished() -> void:
	_heritage_dialogue_open = false
	var hud := get_node_or_null("/root/HUD")
	var game_state := get_node_or_null("/root/GameState")
	var salakot_sprite := get_node_or_null("Salakot") as Sprite2D
	if hud != null:
		hud.set("navigation_locked", true)
	if salakot_sprite != null:
		var fade_out := create_tween()
		fade_out.tween_property(salakot_sprite, "modulate:a", 0.0, 0.6)
		await fade_out.finished
		salakot_sprite.visible = false
		salakot_sprite.modulate.a = 1.0
		if hud != null and hud.has_method("add_inventory_item"):
			hud.call("add_inventory_item", "salakot", "Salakot", salakot_sprite.texture)
	elif hud != null and hud.has_method("add_inventory_item"):
		var salakot_texture := load("res://GAME ASSETS/Living Room/salakot.png") as Texture2D
		if salakot_texture != null:
			hud.call("add_inventory_item", "salakot", "Salakot", salakot_texture)
	if game_state != null:
		game_state.set_state("salakot_reward_received", true)
	# The inventory item fades in after the room sprite fades out. Only after
	# that animation completes do we let Lola begin the tanghali/cooking dialogue.
	await get_tree().create_timer(0.55).timeout
	_start_kitchen_reminder_dialogue()


func _start_kitchen_reminder_dialogue() -> void:
	var lines: Array[Dictionary] = [
		{"speaker": "Lola Nena", "text": "We’ve remembered so many stories today, Migs."},
		{"speaker": "Migs", "text": "I’m glad we wrote them down, Lola."},
		{"speaker": "Lola Nena", "text": "It’s already tanghali. I need to start cooking in the kitchen."},
		{"speaker": "Migs", "text": "Sige, Lola. I’ll let you get started!"}
	]
	_start_living_room_dialogue(lines, Callable(self, "_on_kitchen_reminder_finished"))

func _on_kitchen_reminder_finished() -> void:
	_heritage_dialogue_open = false
	var hud := get_node_or_null("/root/HUD")
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null:
		game_state.set_state("living_room_heritage_completed", true)
	if hud != null:
		hud.set("navigation_locked", false)
	# Lola has left the living room to begin preparing lunch.
	lola_not_looking.visible = false
	lola_looking.visible = false

func get_heritage_photo_target(mouse_position: Vector2) -> Dictionary:
	if _heritage_dialogue_open:
		return {}
	# A photograph is only available after the matching story has been recorded.
	# Test topmost heritage sprites first, matching the room's existing hit-testing.
	var children := get_children()
	for i in range(children.size() - 1, -1, -1):
		var sprite := children[i] as Sprite2D
		if sprite == null or not HERITAGE_STORIES.has(sprite.name):
			continue
		if not _recorded_story_ids.has(sprite.name) or not sprite.visible or sprite.texture == null:
			continue
		var story: Dictionary = HERITAGE_STORIES[sprite.name]
		# Once this entry already has a photo, it is no longer a camera target.
		if _heritage_entry_has_photo(str(story.get("title", ""))):
			continue
		if _is_opaque_pixel_clicked(sprite, mouse_position, _story_images.get(sprite.name)):
			return {
				"object_name": str(sprite.name),
				"title": str(story.get("title", "")),
				"texture_path": str(sprite.texture.resource_path)
			}
	return {}


func _heritage_entry_has_photo(entry_title: String) -> bool:
	var hud := get_node_or_null("/root/HUD")
	if hud == null:
		return false
	var entries: Array = hud.get("heritage_entries")
	for entry in entries:
		if str(entry.get("title", "")) == entry_title:
			return not str(entry.get("photo_path", "")).is_empty()
	return false


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
	var game_state := get_node_or_null("/root/GameState")
	return game_state != null and bool(game_state.get_state("living_room_heritage_completed", false))

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
