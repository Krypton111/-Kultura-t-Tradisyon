extends Node
## Kitchen task controller. The model owns task rules/progress; this controller
## handles object clicks and builds the checklist/recipe views dynamically.

const KitchenTaskModelScript = preload("res://scripts/kitchen/kitchen_task_model.gd")
const DIALOGUE_SCENE_PATH := "res://game_scenes/UI scenes/dialogue.tscn"

const PANEL_BG := Color(0.10, 0.12, 0.15, 0.97)
const ACCENT := Color(0.88, 0.72, 0.42, 1.0)
const TEXT_COLOR := Color(0.97, 0.95, 0.88, 1.0)
const OBJECT_TO_INGREDIENT := {
	"Bangus": "bangus",
	"Condiments": "condiments",
	"Kamatis": "kamatis",
	"Kangkong": "kangkong",
	"MeasuringCup": "water",
	"Peppers": "peppers",
	"Radish": "radish",
	"SinigangMix": "sinigang_mix",
	"Talong": "talong"
}

var task_model = KitchenTaskModelScript.new()
var _dialogue_view: Control
var _hud: Node
var _task_panel: PanelContainer
var _task_list: VBoxContainer
var _progress_label: Label
var _task_message: Label
var _recipe_overlay: Control


func _ready() -> void:
	await get_tree().process_frame
	_hud = get_node_or_null("/root/HUD")
	var kitchen := get_parent()
	var lola := kitchen.get_node_or_null("LolaNenaStanding") as Sprite2D if kitchen != null else null

	if task_model.can_start(_hud, lola):
		_start_task_introduction()
	elif _hud != null and bool(_hud.get_meta(task_model.KITCHEN_INTRO_COMPLETED_META, false)) and not task_model.is_task_completed(_hud):
		_build_task_panel()
		_task_panel.visible = false

	_setup_recipe_hotspot()


func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	if _hud == null or not bool(_hud.get_meta(task_model.KITCHEN_INTRO_COMPLETED_META, false)):
		return
	if is_instance_valid(_recipe_overlay):
		return

	var kitchen := get_parent()
	var mouse_position := get_viewport().get_mouse_position()

	# Handle Container2 directly because generic Container layout may prevent its
	# child Button from receiving the click reliably.
	var recipe_area := kitchen.get_node_or_null("Container2") as Control
	if recipe_area != null and recipe_area.get_global_rect().has_point(mouse_position):
		_open_recipe()
		get_viewport().set_input_as_handled()
		return

	# Lola Nena is the checklist toggle, like opening the journal.
	var lola := kitchen.get_node_or_null("LolaNenaStanding") as Sprite2D
	if lola != null and lola.visible and _sprite_pixel_hit(lola, mouse_position):
		_toggle_task_panel()
		get_viewport().set_input_as_handled()
		return

	if task_model.is_task_completed(_hud):
		return

	# Check actual ingredient sprites, not buttons in the checklist.
	for object_name in OBJECT_TO_INGREDIENT:
		var sprite := kitchen.get_node_or_null(object_name) as Sprite2D
		if sprite == null or not sprite.visible:
			continue
		if _sprite_pixel_hit(sprite, mouse_position):
			var ingredient_id := str(OBJECT_TO_INGREDIENT[object_name])
			if task_model.prepare_ingredient(_hud, ingredient_id):
				_show_object_feedback(sprite, ingredient_id)
				if is_instance_valid(_task_panel) and _task_panel.visible:
					_refresh_task_list()
			get_viewport().set_input_as_handled()
			return


func _start_task_introduction() -> void:
	var packed := load(DIALOGUE_SCENE_PATH) as PackedScene
	if packed == null:
		push_warning("Kitchen task: could not load the dialogue scene.")
		return
	_dialogue_view = packed.instantiate() as Control
	if _dialogue_view == null:
		push_warning("Kitchen task: dialogue scene root must be a Control.")
		return
	_dialogue_view.sequence_finished.connect(_on_introduction_finished)
	_hud.add_child(_dialogue_view)
	_dialogue_view.call("start_custom_sequence", task_model.get_intro_dialogue())


func _on_introduction_finished() -> void:
	task_model.mark_intro_completed(_hud)
	_dialogue_view = null
	_build_task_panel()
	# Show the checklist immediately after the introduction dialogue finishes.
	_task_panel.visible = true
	_refresh_task_list()


func _toggle_task_panel() -> void:
	if task_model.is_task_completed(_hud):
		_show_completion_dialogue()
		return
	if not is_instance_valid(_task_panel):
		_build_task_panel()
	_task_panel.visible = not _task_panel.visible
	if _task_panel.visible:
		_refresh_task_list()


func _build_task_panel() -> void:
	if is_instance_valid(_task_panel) or _hud == null:
		return
	_task_panel = PanelContainer.new()
	_task_panel.name = "KitchenIngredientChecklist"
	_task_panel.position = Vector2(270, 75)
	_task_panel.size = Vector2(610, 500)
	_task_panel.custom_minimum_size = Vector2(610, 500)
	_task_panel.z_index = 120
	_task_panel.add_theme_stylebox_override("panel", _panel_style(PANEL_BG, ACCENT, 3))
	_hud.add_child(_task_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	_task_panel.add_child(outer)

	var heading := Label.new()
	heading.text = "LOLA NENA'S SINIGANG CHECKLIST"
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", ACCENT)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(heading)

	var hint := Label.new()
	hint.text = "Click the ingredient objects in the kitchen to prepare them. Click Lola Nena to check this list again."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", TEXT_COLOR)
	outer.add_child(hint)

	_progress_label = Label.new()
	_progress_label.add_theme_color_override("font_color", ACCENT)
	outer.add_child(_progress_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	_task_list = VBoxContainer.new()
	_task_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_task_list)

	_task_message = Label.new()
	_task_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_task_message.add_theme_color_override("font_color", TEXT_COLOR)
	outer.add_child(_task_message)

	var buttons := HBoxContainer.new()
	outer.add_child(buttons)
	var recipe_button := Button.new()
	recipe_button.text = "View Lola's Recipe"
	recipe_button.pressed.connect(_open_recipe)
	buttons.add_child(recipe_button)

	var leave_button := Button.new()
	leave_button.text = "← Leave Checklist"
	leave_button.pressed.connect(func(): _task_panel.visible = false)
	buttons.add_child(leave_button)
	_refresh_task_list()


func _refresh_task_list() -> void:
	if not is_instance_valid(_task_list) or _hud == null:
		return
	for child in _task_list.get_children():
		child.queue_free()
	for ingredient in task_model.get_ingredients():
		var ingredient_id := str(ingredient["id"])
		var row := HBoxContainer.new()
		_task_list.add_child(row)
		var state := Label.new()
		state.text = "✓" if task_model.is_ingredient_prepared(_hud, ingredient_id) else "○"
		state.custom_minimum_size.x = 28
		state.add_theme_color_override("font_color", ACCENT)
		row.add_child(state)
		var name_label := Label.new()
		name_label.text = str(ingredient["name"])
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_color_override("font_color", TEXT_COLOR)
		row.add_child(name_label)

	var ingredients: Array[Dictionary] = task_model.get_ingredients()
	_progress_label.text = "Prepared: %d / %d" % [task_model.get_prepared_count(_hud), ingredients.size()]
	_task_message.text = "All ingredients are ready!" if task_model.is_task_completed(_hud) else "Find and click each matching object in the kitchen."


func _show_object_feedback(sprite: Sprite2D, ingredient_id: String) -> void:
	# Briefly highlight the clicked item; task state remains in the model.
	var original := sprite.modulate
	sprite.modulate = Color(1.0, 0.88, 0.48, 1.0)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", original, 0.35)
	if task_model.is_task_completed(_hud):
		_task_message.text = "All ingredients are ready! Click Lola Nena to review your completed checklist."


func _show_completion_dialogue() -> void:
	var packed := load(DIALOGUE_SCENE_PATH) as PackedScene
	if packed == null:
		return
	var view := packed.instantiate() as Control
	if view == null:
		return
	_hud.add_child(view)
	view.call("start_custom_sequence", [
		{"speaker": "Lola Nena", "text": "Maraming salamat, Migs! You prepared everything we need for our sinigang."},
		{"speaker": "Migs", "text": "You're welcome, Lola! The ingredients are ready."}
	])


func _sprite_pixel_hit(sprite: Sprite2D, viewport_position: Vector2) -> bool:
	if sprite.texture == null or not sprite.visible:
		return false

	# Convert viewport coordinates into canvas coordinates before transforming
	# into the sprite's local texture coordinates.
	var canvas_position := get_viewport().get_canvas_transform().affine_inverse() * viewport_position
	var local := sprite.to_local(canvas_position)
	var rect := sprite.get_rect()
	if not rect.has_point(local):
		return false

	var texture_image := sprite.texture.get_image()
	if texture_image == null or texture_image.is_empty():
		return true
	var uv := (local - rect.position) / rect.size
	var px := clampi(int(uv.x * texture_image.get_width()), 0, texture_image.get_width() - 1)
	var py := clampi(int(uv.y * texture_image.get_height()), 0, texture_image.get_height() - 1)
	return texture_image.get_pixel(px, py).a > 0.15

func _setup_recipe_hotspot() -> void:
	var kitchen := get_parent()
	var container := kitchen.get_node_or_null("Container2") as Control if kitchen != null else null
	if container == null:
		push_warning("Kitchen task: Container2 recipe hotspot was not found.")
		return
	var button := Button.new()
	button.name = "RecipeHotspot"
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.text = ""
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = "View Lola Nena's Recipe"
	for style_name in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	button.pressed.connect(_open_recipe)
	container.add_child(button)


func _open_recipe() -> void:
	if is_instance_valid(_recipe_overlay):
		return
	var texture := load(task_model.RECIPE_TEXTURE_PATH) as Texture2D
	if texture == null:
		push_warning("Kitchen task: recipe image was not found at " + task_model.RECIPE_TEXTURE_PATH)
		return
	_recipe_overlay = Control.new()
	_recipe_overlay.name = "LolaRecipeOverlay"
	_recipe_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_recipe_overlay.z_index = 500
	_hud.add_child(_recipe_overlay)
	var dimmer := ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0, 0, 0, 0.78)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	_recipe_overlay.add_child(dimmer)
	var card := PanelContainer.new()
	card.position = Vector2(180, 35)
	card.size = Vector2(790, 575)
	card.add_theme_stylebox_override("panel", _panel_style(PANEL_BG, ACCENT, 3))
	_recipe_overlay.add_child(card)
	var content := VBoxContainer.new()
	card.add_child(content)
	var title := Label.new()
	title.text = "LOLA NENA'S RECIPE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", ACCENT)
	content.add_child(title)
	var image := TextureRect.new()
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(image)
	var close_button := Button.new()
	close_button.text = "← Leave Recipe"
	close_button.pressed.connect(func():
		_recipe_overlay.queue_free()
		_recipe_overlay = null
	)
	content.add_child(close_button)


func _panel_style(background: Color, border_color: Color, border_size: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border_color
	style.set_border_width_all(border_size)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(16)
	return style
