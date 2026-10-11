extends Control

signal close_requested

@onready var leave_arrow: Sprite2D = $LeaveArrow
@onready var left_arrow: Sprite2D = $JournalArrowLeft
@onready var right_arrow: Sprite2D = $JournalArrowRight

var _entry_index := 0
var _entry_title: Label
var _entry_text: Label
var _page_counter: Label
var _entries: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 1100 # Render above the HUD transition fade and navigation layer.
	_load_entries()
	_create_leave_button()
	_create_arrow_button(left_arrow, -1, "PreviousMemoryButton")
	_create_arrow_button(right_arrow, 1, "NextMemoryButton")
	_create_journal_text()

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

func _load_entries() -> void:
	var hud := get_node_or_null("/root/HUD")
	if hud != null:
		var stored = hud.get("heritage_entries")
		if stored is Array:
			_entries = stored.duplicate(true)

func _create_journal_text() -> void:
	# Small, warm-toned type sits on the open pages without replacing the art.
	_entry_title = Label.new()
	_entry_title.position = Vector2(405, 267)
	_entry_title.size = Vector2(330, 28)
	_entry_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_entry_title.add_theme_font_size_override("font_size", 15)
	_entry_title.add_theme_color_override("font_color", Color(0.25, 0.20, 0.14))
	add_child(_entry_title)

	_entry_text = Label.new()
	_entry_text.position = Vector2(405, 298)
	_entry_text.size = Vector2(330, 78)
	_entry_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_entry_text.add_theme_font_size_override("font_size", 11)
	_entry_text.add_theme_color_override("font_color", Color(0.25, 0.20, 0.14))
	add_child(_entry_text)

	_page_counter = Label.new()
	_page_counter.position = Vector2(500, 378)
	_page_counter.size = Vector2(150, 18)
	_page_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_counter.add_theme_font_size_override("font_size", 10)
	_page_counter.add_theme_color_override("font_color", Color(0.38, 0.30, 0.20))
	add_child(_page_counter)
	_update_journal_text()

func _update_journal_text() -> void:
	if _entry_title == null:
		return
	if _entries.is_empty():
		_entry_title.text = "HERITAGE JOURNAL"
		_entry_text.text = "Your first story is waiting. Explore the living room and ask Lola Nena about the things her family has kept."
		_page_counter.text = "No entries yet"
		return
	_entry_index = clampi(_entry_index, 0, _entries.size() - 1)
	var entry: Dictionary = _entries[_entry_index]
	_entry_title.text = str(entry.get("title", "Untitled Memory"))
	_entry_text.text = str(entry.get("text", ""))
	_page_counter.text = "Memory %d of %d" % [_entry_index + 1, _entries.size()]

func _create_arrow_button(sprite: Sprite2D, step: int, button_name: String) -> void:
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
	button.position = sprite.position - scaled_size / 2.0 + scaled_used_position
	button.size = scaled_used_size
	button.pressed.connect(func() -> void:
		if _entries.size() > 1:
			_entry_index = posmod(_entry_index + step, _entries.size())
			_update_journal_text()
	)
	add_child(button)
	button.z_index = 10
