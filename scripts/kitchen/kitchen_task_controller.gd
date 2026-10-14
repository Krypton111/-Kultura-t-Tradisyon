extends Node
## Coordinates the kitchen task. Model = task rules/data; this script = controller;
## dynamically-built controls and recipe image = view. Kitchen scene setup remains in kitchen.gd.

const KitchenTaskModelScript = preload("res://scripts/kitchen/kitchen_task_model.gd")
const DIALOGUE_SCENE_PATH := "res://game_scenes/UI scenes/dialogue.tscn"

const PANEL_BG := Color(0.10, 0.12, 0.15, 0.97)
const PANEL_INNER := Color(0.16, 0.18, 0.20, 1.0)
const ACCENT := Color(0.88, 0.72, 0.42, 1.0)
const TEXT_COLOR := Color(0.97, 0.95, 0.88, 1.0)

var task_model = KitchenTaskModelScript.new()
var _dialogue_view: Control
var _hud: Node
var _task_panel: PanelContainer
var _task_list: VBoxContainer
var _progress_label: Label
var _recipe_overlay: Control
var _recipe_button: Button
var _task_message: Label


func _ready() -> void:
	await get_tree().process_frame
	_hud = get_node_or_null("/root/HUD")
	var kitchen := get_parent()
	var lola := kitchen.get_node_or_null("LolaNenaStanding") as Sprite2D if kitchen != null else null

	if task_model.can_start(_hud, lola):
		_start_task_introduction()
	elif _hud != null and bool(_hud.get_meta(task_model.KITCHEN_INTRO_COMPLETED_META, false)) and not task_model.is_task_completed(_hud):
		_show_task_panel()

	_setup_recipe_hotspot()


func _start_task_introduction() -> void:
	var dialogue_scene := load(DIALOGUE_SCENE_PATH) as PackedScene
	if dialogue_scene == null:
		push_warning("Kitchen task: could not load the dialogue scene.")
		return

	_dialogue_view = dialogue_scene.instantiate() as Control
	if _dialogue_view == null:
		push_warning("Kitchen task: dialogue scene root must be a Control.")
		return

	_dialogue_view.sequence_finished.connect(_on_introduction_finished)
	_hud.add_child(_dialogue_view)
	_dialogue_view.call("start_custom_sequence", task_model.get_intro_dialogue())


func _on_introduction_finished() -> void:
	task_model.mark_intro_completed(_hud)
	_dialogue_view = null
	_show_task_panel()


func _show_task_panel() -> void:
	if not is_instance_valid(_hud) or task_model.is_task_completed(_hud):
		return
	if is_instance_valid(_task_panel):
		_task_panel.visible = true
		_refresh_task_list()
		return

	_task_panel = PanelContainer.new()
	_task_panel.name = "KitchenIngredientTaskPanel"
	_task_panel.position = Vector2(270, 90)
	_task_panel.size = Vector2(610, 470)
	_task_panel.custom_minimum_size = Vector2(610, 470)
	_task_panel.z_index = 120
	_task_panel.add_theme_stylebox_override("panel", _panel_style(PANEL_BG, ACCENT, 3))
	_hud.add_child(_task_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	_task_panel.add_child(outer)

	var heading := Label.new()
	heading.text = "LOLA NENA'S SINIGANG PREPARATION"
	heading.add_theme_font_size_override("font_size", 23)
	heading.add_theme_color_override("font_color", ACCENT)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(heading)

	var description := Label.new()
	description.text = "Prepare each item below. Click Lola's Recipe in the kitchen for the recipe card."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_color_override("font_color", TEXT_COLOR)
	outer.add_child(description)

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

	var bottom := HBoxContainer.new()
	outer.add_child(bottom)
	var recipe_btn := Button.new()
	recipe_btn.text = "View Lola's Recipe"
	recipe_btn.pressed.connect(_open_recipe)
	bottom.add_child(recipe_btn)
	var close_btn := Button.new()
	close_btn.text = "Hide Task"
	close_btn.pressed.connect(func(): _task_panel.visible = false)
	bottom.add_child(close_btn)

	_refresh_task_list()


func _refresh_task_list() -> void:
	if not is_instance_valid(_task_list) or not is_instance_valid(_hud):
		return
	for child in _task_list.get_children():
		child.queue_free()

	var ingredients: Array[Dictionary] = task_model.get_ingredients()
	for ingredient in ingredients:
		var ingredient_id := str(ingredient["id"])
		var row := HBoxContainer.new()
		_task_list.add_child(row)
		var action := Button.new()
		action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action.text = ("✓  " if task_model.is_ingredient_prepared(_hud, ingredient_id) else "Prepare  ") + str(ingredient["instruction"])
		action.disabled = task_model.is_ingredient_prepared(_hud, ingredient_id)
		action.pressed.connect(_on_prepare_ingredient.bind(ingredient_id))
		row.add_child(action)

	var prepared := task_model.get_prepared_count(_hud)
	_progress_label.text = "Ingredients prepared: %d / %d" % [prepared, ingredients.size()]
	if task_model.is_task_completed(_hud):
		_task_message.text = "All ingredients are ready! Lola Nena will be proud of your help."
	else:
		_task_message.text = "Select each preparation step to complete it. Your progress is saved while you move between rooms."


func _on_prepare_ingredient(ingredient_id: String) -> void:
	if task_model.prepare_ingredient(_hud, ingredient_id):
		_refresh_task_list()


func _setup_recipe_hotspot() -> void:
	var kitchen := get_parent()
	var container := kitchen.get_node_or_null("Container2") as Control if kitchen != null else null
	if container == null:
		push_warning("Kitchen task: Container2 recipe hotspot was not found.")
		return

	_recipe_button = Button.new()
	_recipe_button.name = "RecipeHotspot"
	_recipe_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_recipe_button.text = ""
	_recipe_button.flat = true
	_recipe_button.focus_mode = Control.FOCUS_NONE
	_recipe_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_recipe_button.tooltip_text = "View Lola Nena's Recipe"
	_recipe_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_recipe_button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	_recipe_button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	_recipe_button.pressed.connect(_open_recipe)
	container.add_child(_recipe_button)


func _open_recipe() -> void:
	if is_instance_valid(_recipe_overlay):
		_recipe_overlay.visible = true
		return

	var recipe_texture := load(task_model.RECIPE_TEXTURE_PATH) as Texture2D
	if recipe_texture == null:
		push_warning("Kitchen task: recipe image was not found at " + task_model.RECIPE_TEXTURE_PATH)
		_show_recipe_missing_message()
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
	card.custom_minimum_size = Vector2(790, 575)
	card.add_theme_stylebox_override("panel", _panel_style(PANEL_BG, ACCENT, 3))
	_recipe_overlay.add_child(card)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	card.add_child(content)

	var title := Label.new()
	title.text = "LOLA NENA'S RECIPE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", ACCENT)
	content.add_child(title)

	var image := TextureRect.new()
	image.texture = recipe_texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(image)

	var close_btn := Button.new()
	close_btn.text = "Close Recipe"
	close_btn.pressed.connect(func(): _recipe_overlay.queue_free(); _recipe_overlay = null)
	content.add_child(close_btn)


func _show_recipe_missing_message() -> void:
	var popup := AcceptDialog.new()
	popup.title = "Recipe unavailable"
	popup.dialog_text = "Couldn't load Lola's recipe image. Please verify the file path: " + task_model.RECIPE_TEXTURE_PATH
	_hud.add_child(popup)
	popup.popup_centered()


func _panel_style(background: Color, border_color: Color, border_size: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border_color
	style.set_border_width_all(border_size)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(16)
	return style
