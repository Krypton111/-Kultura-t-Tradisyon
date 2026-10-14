extends Node
## Kitchen task controller. The model owns task rules/progress; this controller
## handles object clicks and builds the checklist/recipe views dynamically.

const KitchenTaskModelScript = preload("res://scripts/kitchen/kitchen_task_model.gd")
const DIALOGUE_SCENE_PATH := "res://game_scenes/UI scenes/dialogue.tscn"
const POT_TEXTURE_PATH := "res://GAME ASSETS/Kitchen/sinigang pot empty.png"
const LEAVE_ARROW_TEXTURE = preload("res://GAME ASSETS/UI/HUD/leave_arrow.png")

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
var _recipe_overlay: Control
var _pot_overlay: Control
var _pot_drop_area: Control
var _pot_dialogue_open := false
var _pot_filled_items: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	_hud = get_node_or_null("/root/HUD")
	var kitchen := get_parent()
	var lola := kitchen.get_node_or_null("LolaNenaStanding") as Sprite2D if kitchen != null else null

	if task_model.can_start(_hud, lola):
		_start_task_introduction()
	_setup_recipe_hotspot()
	if _hud != null and _hud.has_signal("inventory_item_dropped"):
		var drop_callable := Callable(self, "_on_inventory_item_dropped")
		if not _hud.is_connected("inventory_item_dropped", drop_callable):
			_hud.connect("inventory_item_dropped", drop_callable)


func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	if _hud == null or not bool(_hud.get_meta(task_model.KITCHEN_INTRO_COMPLETED_META, false)):
		return
	if is_instance_valid(_recipe_overlay) or is_instance_valid(_pot_overlay):
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

	# Lola Nena explains the pot step; the old checklist is removed.
	var lola := kitchen.get_node_or_null("LolaNenaStanding") as Sprite2D
	if lola != null and lola.visible and _sprite_pixel_hit(lola, mouse_position):
		_start_pot_dialogue()
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
				var item_name := _ingredient_display_name(ingredient_id)
				var hud_layer := get_node_or_null("/root/HUD")
				if hud_layer != null and hud_layer.has_method("add_inventory_item"):
					hud_layer.call("add_inventory_item", ingredient_id, item_name, sprite.texture)
				_fade_collected_ingredient(sprite, ingredient_id)
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


func _start_pot_dialogue() -> void:
	if _pot_dialogue_open or is_instance_valid(_pot_overlay):
		return
	_pot_dialogue_open = true
	var packed := load(DIALOGUE_SCENE_PATH) as PackedScene
	if packed == null:
		_pot_dialogue_open = false
		return
	var view := packed.instantiate() as Control
	if view == null:
		_pot_dialogue_open = false
		return
	_hud.add_child(view)
	var lines: Array[Dictionary] = [
		{"speaker": "Lola Nena", "text": "Migs, please put all the ingredients you gathered into this pot. Drag each item from your inventory and drop it into the pot."}
	]
	view.call("start_custom_sequence", lines)
	view.sequence_finished.connect(func():
		_pot_dialogue_open = false
		_show_empty_pot()
	)


func _show_empty_pot() -> void:
	if is_instance_valid(_pot_overlay):
		return
	var pot_texture := load(POT_TEXTURE_PATH) as Texture2D
	if pot_texture == null:
		push_warning("Kitchen task: empty pot image not found: " + POT_TEXTURE_PATH)
		return
	_pot_overlay = Control.new()
	_pot_overlay.name = "SinigangPotOverlay"
	_pot_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pot_overlay.z_index = 1100
	_pot_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_hud.add_child(_pot_overlay)

	var dimmer := ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0, 0, 0, 0.62)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	_pot_overlay.add_child(dimmer)

	var pot := TextureRect.new()
	pot.name = "SinigangPotDropArea"
	pot.texture = pot_texture
	pot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pot.size = Vector2(560, 430)
	pot.position = (get_viewport().get_visible_rect().size - pot.size) * 0.5
	pot.mouse_filter = Control.MOUSE_FILTER_STOP
	_pot_overlay.add_child(pot)
	_pot_drop_area = pot

	var leave_sprite := Sprite2D.new()
	leave_sprite.texture = LEAVE_ARROW_TEXTURE
	leave_sprite.position = Vector2(576, 324)
	leave_sprite.scale = Vector2(0.3, 0.3)
	_pot_overlay.add_child(leave_sprite)
	var leave_button := _make_leave_arrow_button(leave_sprite)
	leave_button.pressed.connect(func():
		_pot_overlay.queue_free()
		_pot_overlay = null
		_pot_drop_area = null
		_hud.call("set_inventory_drop_rect", Rect2())
	)
	_hud.call("set_inventory_drop_rect", pot.get_global_rect())


func _make_leave_arrow_button(sprite: Sprite2D) -> Button:
	var button := Button.new()
	button.name = "LeavePotButton"
	button.text = ""
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for style_name in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	var image := LEAVE_ARROW_TEXTURE.get_image()
	var used_rect := image.get_used_rect()
	var scaled_size := Vector2(image.get_width(), image.get_height()) * sprite.scale
	var scaled_used_position := Vector2(used_rect.position) * sprite.scale
	var scaled_used_size := Vector2(used_rect.size) * sprite.scale
	button.position = sprite.position - scaled_size / 2.0 + scaled_used_position
	button.size = scaled_used_size
	button.z_index = 10
	_pot_overlay.add_child(button)
	return button


func _on_inventory_item_dropped(item_id: String) -> void:
	if not is_instance_valid(_pot_overlay):
		return
	if _hud.call("remove_inventory_item", item_id):
		if not _pot_filled_items.has(item_id):
			_pot_filled_items.append(item_id)
		var progress: Dictionary = task_model.get_progress(_hud)
		progress[item_id] = true
		_hud.set_meta(task_model.KITCHEN_PROGRESS_META, progress)
		if _pot_filled_items.size() >= task_model.get_ingredients().size():
			_hud.set_meta(task_model.KITCHEN_TASK_COMPLETED_META, true)


func _ingredient_display_name(ingredient_id: String) -> String:
	for ingredient in task_model.get_ingredients():
		if str(ingredient.get("id", "")) == ingredient_id:
			return str(ingredient.get("name", ingredient_id))
	return ingredient_id.capitalize()


func _fade_collected_ingredient(sprite: Sprite2D, ingredient_id: String) -> void:
	sprite.set_meta("ingredient_collected", true)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.45)
	tween.tween_callback(func():
		if is_instance_valid(sprite):
			sprite.visible = false
	)


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
