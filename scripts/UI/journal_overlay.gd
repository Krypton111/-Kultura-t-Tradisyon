extends Control

signal close_requested

@onready var leave_arrow: Sprite2D = $LeaveArrow

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 1100 # Render above the HUD transition fade and navigation layer.
	_create_leave_button()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close_requested.emit()
		get_viewport().set_input_as_handled()

func _create_leave_button() -> void:
	if leave_arrow.texture == null:
		return

	var image := leave_arrow.texture.get_image()
	if image == null:
		return

	var used_rect := image.get_used_rect()
	if used_rect.size.x <= 0 or used_rect.size.y <= 0:
		return

	var button := Button.new()
	button.name = "LeaveJournalButton"
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

	var scaled_size := Vector2(image.get_width(), image.get_height()) * leave_arrow.scale
	var scaled_used_position := Vector2(used_rect.position) * leave_arrow.scale
	var scaled_used_size := Vector2(used_rect.size) * leave_arrow.scale
	button.position = leave_arrow.position - scaled_size / 2.0 + scaled_used_position
	button.size = scaled_used_size
	button.pressed.connect(func() -> void: close_requested.emit())
	add_child(button)
	button.z_index = 10
