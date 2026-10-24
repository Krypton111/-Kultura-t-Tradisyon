extends Control
## Feeding and egg-collection interactions for the chicken coop.

const DIALOGUE_SCENE_PATH := "res://game_scenes/UI scenes/dialogue.tscn"
const BACKYARD_SCENE_PATH := "res://game_scenes/levels/backyard.tscn"
const EGGS_TEXTURE: Texture2D = preload("res://GAME ASSETS/Backyard/chicken coop/coop eggs.png")
const DOWN_CURSOR: Texture2D = preload("res://GAME ASSETS/UI/HUD/bottom room.png")
const DOWN_CURSOR_MAX_SIZE := 160.0
const DOWN_NAV_POSITION := Vector2(566.5, 607.0)
const DOWN_NAV_WIDTH := 450.0
const DOWN_NAV_HEIGHT := 100.0
const FILLED_CUPS_ID := "cups_with_seeds_close_up"
const FILLED_BASKET_ID := "basket_with_seeds_close_up"
const EGGS_ITEM_ID := "coop_eggs"

var _hud: Node
var _game_state: Node
var _eggs: Sprite2D
var _chickens_position_1: Node2D
var _chickens_position_2: Node2D
var _container: Control
var _container_2: Control
var _cups_fed := false
var _basket_fed := false
var _eggs_collected := false
var _busy := false
var _return_navigation_layer: CanvasLayer
var _return_navigation_button: Button
var _down_cursor: Texture2D

func _ready() -> void:
	_hud = get_node_or_null("/root/HUD")
	_game_state = get_node_or_null("/root/GameState")
	_eggs = get_node_or_null("CoopEggs") as Sprite2D
	_chickens_position_1 = get_node_or_null("ChickensPosition1") as Node2D
	_chickens_position_2 = get_node_or_null("ChickensPosition2") as Node2D
	_container = get_node_or_null("Container") as Control
	_container_2 = get_node_or_null("Container2") as Control

	if _game_state != null:
		_cups_fed = bool(_game_state.get_state("coop_cups_fed", false))
		_basket_fed = bool(_game_state.get_state("coop_basket_fed", false))
		_eggs_collected = bool(_game_state.get_state("coop_eggs_collected", false))

	_update_chicken_positions()
	if _eggs != null:
		_eggs.visible = not _eggs_collected
	_refresh_feeder_drop_targets()
	_setup_return_navigation()

func _setup_return_navigation() -> void:
	# The HUD's normal DownNavigation is intentionally unavailable in this scene.
	# Create the same bottom-arrow interaction above the HUD only for the coop,
	# so the player can return to the Backyard without changing the global map.
	_return_navigation_layer = CanvasLayer.new()
	_return_navigation_layer.name = "ChickenCoopReturnNavigation"
	_return_navigation_layer.layer = 20
	add_child(_return_navigation_layer)

	_return_navigation_button = Button.new()
	_return_navigation_button.name = "DownNavigation"
	_return_navigation_button.text = ""
	_return_navigation_button.flat = true
	_return_navigation_button.focus_mode = Control.FOCUS_NONE
	_return_navigation_button.mouse_default_cursor_shape = Control.CURSOR_ARROW
	_return_navigation_button.mouse_filter = Control.MOUSE_FILTER_STOP
	var empty_style := StyleBoxEmpty.new()
	_return_navigation_button.add_theme_stylebox_override("normal", empty_style)
	_return_navigation_button.add_theme_stylebox_override("hover", empty_style)
	_return_navigation_button.add_theme_stylebox_override("pressed", empty_style)
	_return_navigation_button.add_theme_stylebox_override("focus", empty_style)
	_return_navigation_button.position = DOWN_NAV_POSITION - Vector2(DOWN_NAV_WIDTH, DOWN_NAV_HEIGHT) * 0.5
	_return_navigation_button.size = Vector2(DOWN_NAV_WIDTH, DOWN_NAV_HEIGHT)
	_return_navigation_button.pressed.connect(_return_to_backyard)
	_return_navigation_layer.add_child(_return_navigation_button)

	_down_cursor = _prepare_cursor(DOWN_CURSOR, DOWN_CURSOR_MAX_SIZE)

func _process(_delta: float) -> void:
	if _return_navigation_button == null or _hud == null:
		return
	if bool(_hud.get("navigation_locked")) or _busy:
		Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
		return

	var mouse_position := get_viewport().get_mouse_position()
	var hotspot := Rect2(
		DOWN_NAV_POSITION - Vector2(DOWN_NAV_WIDTH, DOWN_NAV_HEIGHT) * 0.5,
		Vector2(DOWN_NAV_WIDTH, DOWN_NAV_HEIGHT)
	)
	if hotspot.has_point(mouse_position):
		Input.set_custom_mouse_cursor(_down_cursor, Input.CURSOR_ARROW, _cursor_hotspot(_down_cursor))
	else:
		Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)

func _return_to_backyard() -> void:
	if _busy or _hud == null or bool(_hud.get("navigation_locked")):
		return
	_hud.call("_change_scene", BACKYARD_SCENE_PATH)

func is_hovering_room_interactable(mouse_position: Vector2) -> bool:
	if _hud != null and bool(_hud.get("navigation_locked")):
		return false
	if _eggs != null and _eggs.visible and _sprite_pixel_hit(_eggs, mouse_position):
		return true
	return (_container != null and _container.get_global_rect().has_point(mouse_position)) or (_container_2 != null and _container_2.get_global_rect().has_point(mouse_position))

func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed or _busy:
		return
	if _hud != null and bool(_hud.get("navigation_locked")):
		return

	var mouse_position := get_viewport().get_mouse_position()
	if _eggs != null and _eggs.visible and _sprite_pixel_hit(_eggs, mouse_position):
		get_viewport().set_input_as_handled()
		if not _both_feed_containers_filled():
			_show_need_distraction_monologue()
		else:
			_collect_eggs()
		return

func _refresh_feeder_drop_targets() -> void:
	if _hud == null or not _hud.has_method("set_inventory_drop_targets"):
		return
	var targets: Dictionary = {}
	if _container != null and not _cups_fed:
		targets["coop_cups_feeder"] = _container.get_global_rect()
	if _container_2 != null and not _basket_fed:
		targets["coop_basket_feeder"] = _container_2.get_global_rect()
	_hud.call("set_inventory_drop_targets", targets)

	if _hud.has_signal("inventory_item_dropped_on_target"):
		var callback := Callable(self, "_on_inventory_item_dropped_on_target")
		if not _hud.is_connected("inventory_item_dropped_on_target", callback):
			_hud.connect("inventory_item_dropped_on_target", callback)

func _on_inventory_item_dropped_on_target(item_id: String, target_id: String) -> void:
	if _busy:
		return
	if target_id == "coop_cups_feeder" and item_id == FILLED_CUPS_ID:
		if _hud.call("remove_inventory_item", FILLED_CUPS_ID):
			_cups_fed = true
			_game_state.set_state("coop_cups_fed", true)
			_show_feeding_hint("The cups of seeds are in the feeder.")
	elif target_id == "coop_basket_feeder" and item_id == FILLED_BASKET_ID:
		if _hud.call("remove_inventory_item", FILLED_BASKET_ID):
			_basket_fed = true
			_game_state.set_state("coop_basket_fed", true)
			_show_feeding_hint("The basket of seeds are in the feeder.")
	else:
		_show_feeding_hint("That item doesn't belong in this feeder.")
	_update_chicken_positions()
	_refresh_feeder_drop_targets()

func _both_feed_containers_filled() -> bool:
	return _cups_fed and _basket_fed

func _update_chicken_positions() -> void:
	var chickens_fed := _both_feed_containers_filled()
	if _chickens_position_1 != null:
		_chickens_position_1.visible = not chickens_fed
	if _chickens_position_2 != null:
		_chickens_position_2.visible = chickens_fed

func _show_need_distraction_monologue() -> void:
	_show_dialogue([
		{"speaker": "Migs", "text": "I need to make a distraction. What could the chickens want?"},
		{"speaker": "Migs", "text": "What did Lola tell me to do with the chickens again?"}
	])

func _collect_eggs() -> void:
	if _eggs_collected or _hud == null:
		return
	_eggs_collected = true
	_game_state.set_state("coop_eggs_collected", true)
	var tween := create_tween()
	tween.tween_property(_eggs, "modulate:a", 0.0, 0.4)
	await tween.finished
	_eggs.visible = false
	_eggs.modulate.a = 1.0
	_hud.call("add_inventory_item", EGGS_ITEM_ID, "Coop Eggs", EGGS_TEXTURE)
	_show_dialogue([
		{"speaker": "Migs", "text": "Got the eggs! Now I can bring them back to Lola."},
		{"speaker": "Lola Nena", "text": "Migs!"},
		{"speaker": "Lola Nena", "text": "Migs, come back to the kitchen, apo. I need you to check the sinigang na bangus."},
		{"speaker": "Lola Nena", "text": "It is done cooking already. Come back inside before it gets cold."}
	])

func _show_dialogue(lines: Array[Dictionary]) -> void:
	if _hud == null:
		return
	var packed := load(DIALOGUE_SCENE_PATH) as PackedScene
	if packed == null:
		push_warning("Chicken coop: could not load the dialogue scene.")
		return
	var dialogue := packed.instantiate() as Control
	if dialogue == null:
		return
	_busy = true
	_hud.set("navigation_locked", true)
	_hud.add_child(dialogue)
	dialogue.sequence_finished.connect(func():
		_busy = false
		if _hud != null:
			_hud.set("navigation_locked", false)
	)
	dialogue.call("start_custom_sequence", lines)

func _show_feeding_hint(message: String) -> void:
	var hint := Label.new()
	hint.name = "ChickenCoopHint"
	hint.position = Vector2(330, 575)
	hint.size = Vector2(500, 40)
	hint.text = message
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.98, 0.86, 0.64, 1.0))
	hint.add_theme_font_size_override("font_size", 18)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.z_index = 500
	add_child(hint)
	var tween := create_tween()
	tween.tween_interval(1.2)
	tween.tween_property(hint, "modulate:a", 0.0, 0.4)
	tween.tween_callback(hint.queue_free)

func _sprite_pixel_hit(sprite: Sprite2D, viewport_position: Vector2) -> bool:
	if sprite.texture == null or not sprite.visible:
		return false
	var canvas_position := get_viewport().get_canvas_transform().affine_inverse() * viewport_position
	var local_position := sprite.to_local(canvas_position)
	var rect := sprite.get_rect()
	if not rect.has_point(local_position):
		return false
	var image := sprite.texture.get_image()
	if image == null or image.is_empty():
		return true
	var uv := (local_position - rect.position) / rect.size
	var px := clampi(int(uv.x * image.get_width()), 0, image.get_width() - 1)
	var py := clampi(int(uv.y * image.get_height()), 0, image.get_height() - 1)
	return image.get_pixel(px, py).a > 0.12

func _prepare_cursor(texture: Texture2D, max_size: float) -> Texture2D:
	if texture == null:
		return null
	var image := texture.get_image()
	if image == null or image.is_empty():
		return texture
	var max_dimension := float(maxi(image.get_width(), image.get_height()))
	if max_dimension <= max_size:
		return texture
	var scale_factor := max_size / max_dimension
	var new_width := maxi(1, roundi(image.get_width() * scale_factor))
	var new_height := maxi(1, roundi(image.get_height() * scale_factor))
	image.resize(new_width, new_height, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)

func _cursor_hotspot(texture: Texture2D) -> Vector2:
	if texture == null:
		return Vector2.ZERO
	return Vector2(floor(texture.get_width() * 0.5), floor(texture.get_height() * 0.5))

func _exit_tree() -> void:
	if is_instance_valid(_hud):
		_hud.call("set_inventory_drop_targets", {})
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
