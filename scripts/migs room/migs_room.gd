extends Control

const HIT_ALPHA_THRESHOLD := 0.1

func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return

	var mouse_position := get_global_mouse_position()
	var journal_sprite := get_node_or_null("Journal") as Sprite2D
	var camera_sprite := get_node_or_null("Camera") as Sprite2D

	# Check the camera first so its opaque pixels win if the artwork overlaps.
	if _is_opaque_pixel_at(camera_sprite, mouse_position):
		get_viewport().set_input_as_handled()
		await _fade_out_and_remove(camera_sprite, "reveal_camera")
		return

	if _is_opaque_pixel_at(journal_sprite, mouse_position):
		get_viewport().set_input_as_handled()
		await _fade_out_and_remove(journal_sprite, "reveal_journal")

func _fade_out_and_remove(sprite: Sprite2D, hud_method: String) -> void:
	if sprite == null or sprite.get_meta("being_collected", false):
		return

	sprite.set_meta("being_collected", true)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.35)
	await tween.finished

	var hud := get_node_or_null("/root/HUD")
	if hud and hud.has_method(hud_method):
		hud.call(hud_method)

	if is_instance_valid(sprite):
		sprite.queue_free()

func is_hovering_room_interactable(global_position: Vector2) -> bool:
	return _is_opaque_pixel_at(get_node_or_null("Journal") as Sprite2D, global_position) \
		or _is_opaque_pixel_at(get_node_or_null("Camera") as Sprite2D, global_position)

func _is_opaque_pixel_at(sprite: Sprite2D, global_position: Vector2) -> bool:
	if sprite == null or not sprite.visible or sprite.texture == null:
		return false
	if sprite.get_meta("being_collected", false):
		return false
		return false

	var local_position := sprite.to_local(global_position)
	var rect := sprite.get_rect()
	if not rect.has_point(local_position):
		return false

	var image := sprite.texture.get_image()
	if image == null or image.is_empty():
		return false

	var uv := (local_position - rect.position) / rect.size
	var pixel_x := clampi(int(uv.x * image.get_width()), 0, image.get_width() - 1)
	var pixel_y := clampi(int(uv.y * image.get_height()), 0, image.get_height() - 1)
	return image.get_pixel(pixel_x, pixel_y).a > HIT_ALPHA_THRESHOLD
