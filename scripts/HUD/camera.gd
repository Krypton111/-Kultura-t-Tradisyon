extends Node
## Camera interaction component. Uses heritage artwork already present in the room
## and attaches its asset path to the matching journal entry.

var camera_mode_active := false
var _hud: Node
var _camera_icon: Sprite2D


func _ready() -> void:
	_hud = get_parent()
	_camera_icon = _hud.get_node_or_null("Camera") as Sprite2D


func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	if _hud == null or not bool(_hud.get("camera_collected")):
		return
	if bool(_hud.get("navigation_locked")) or bool(_hud.get("journal_is_open")):
		return

	var mouse_position := get_viewport().get_mouse_position()
	if _is_hovering_camera_icon(mouse_position):
		if camera_mode_active:
			cancel_camera_mode()
		else:
			camera_mode_active = true
			_update_camera_icon()
			Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
		get_viewport().set_input_as_handled()
		return

	if not camera_mode_active:
		return

	# Let the journal open normally, and leave camera mode before showing it.
	if _hud.has_method("_is_hovering_journal") and bool(_hud.call("_is_hovering_journal")):
		cancel_camera_mode()
		return

	var current_scene := get_tree().current_scene
	if current_scene != null and current_scene.has_method("get_heritage_photo_target"):
		var target: Dictionary = current_scene.call("get_heritage_photo_target", mouse_position)
		if not target.is_empty():
			# The room handles the camera sound, Lola's response, and saving the
			# photo together with the journal entry after the dialogue completes.
			if current_scene.has_method("on_camera_photo_taken"):
				current_scene.call("on_camera_photo_taken", target)
				cancel_camera_mode()
				get_viewport().set_input_as_handled()
				return

	# Let the existing room-navigation hotspots continue to work if no heritage
	# item was targeted. Other clicks stay in camera mode and cannot open dialogue.
	if _is_navigation_hotspot(mouse_position):
		cancel_camera_mode()
		return
	get_viewport().set_input_as_handled()


func cancel_camera_mode() -> void:
	camera_mode_active = false
	_update_camera_icon()
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)


func _update_camera_icon() -> void:
	if is_instance_valid(_camera_icon):
		_camera_icon.modulate = Color(1.0, 0.82, 0.55) if camera_mode_active else Color.WHITE


func _is_hovering_camera_icon(mouse_position: Vector2) -> bool:
	return _camera_icon != null and _camera_icon.visible and _camera_icon.get_rect().has_point(_camera_icon.to_local(mouse_position))


func _is_navigation_hotspot(mouse_position: Vector2) -> bool:
	var left_rect := Rect2(Vector2(180.0, 265.0) - Vector2(90.0, 800.0) * 0.5, Vector2(90.0, 800.0))
	var right_rect := Rect2(Vector2(1104.0, 263.0) - Vector2(160.0, 300.0) * 0.5, Vector2(160.0, 300.0))
	var down_rect := Rect2(Vector2(566.5, 607.0) - Vector2(450.0, 100.0) * 0.5, Vector2(450.0, 100.0))
	return left_rect.has_point(mouse_position) or right_rect.has_point(mouse_position) or down_rect.has_point(mouse_position)
