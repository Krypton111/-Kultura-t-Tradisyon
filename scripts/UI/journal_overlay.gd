extends Control

signal close_requested

@onready var leave_arrow: Sprite2D = $LeaveArrow
@onready var left_arrow: Sprite2D = $JournalArrowLeft
@onready var right_arrow: Sprite2D = $JournalArrowRight

var _entry_index := 0
var _entry_titles: Array[Label] = []
var _entry_texts: Array[Label] = []
var _entry_photos: Array[TextureRect] = []
var _page_counter: Label
var _entries: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 1100 # Render above the HUD transition fade and navigation layer.
	_load_entries()
	_create_leave_button()
	_create_arrow_button(left_arrow, -4, "PreviousMemoryButton")
	_create_arrow_button(right_arrow, 4, "NextMemoryButton")
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
	# Keep all findings inside the two page containers from journal.tscn.
	# Each page holds exactly two findings: one above and one below.
	var page_nodes: Array[Control] = [$pg1, $pg2]
	var page_positions := [Vector2(24, 92), Vector2(24, 285)]
	var text_width := 300.0

	for page_index in range(2):
		for slot_index in range(2):
			var entry_slot := page_index * 2 + slot_index
			var title := Label.new()
			title.name = "FindingTitle%d" % (entry_slot + 1)
			title.position = page_positions[slot_index]
			title.size = Vector2(text_width, 28)
			title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			title.add_theme_font_size_override("font_size", 15)
			title.add_theme_color_override("font_color", Color(0.25, 0.20, 0.14))
			page_nodes[page_index].add_child(title)
			_entry_titles.append(title)

			var body := Label.new()
			body.name = "FindingText%d" % (entry_slot + 1)
			body.position = page_positions[slot_index] + Vector2(0, 32)
			body.size = Vector2(text_width, 72)
			body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
			body.add_theme_font_size_override("font_size", 12)
			body.add_theme_color_override("font_color", Color(0.25, 0.20, 0.14))
			page_nodes[page_index].add_child(body)
			_entry_texts.append(body)

			var photo := TextureRect.new()
			photo.name = "FindingPhoto%d" % (entry_slot + 1)
			photo.position = page_positions[slot_index] + Vector2(0, 108)
			photo.size = Vector2(108, 64)
			photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
			photo.visible = false
			page_nodes[page_index].add_child(photo)
			_entry_photos.append(photo)

	_page_counter = Label.new()
	_page_counter.position = Vector2(460, 535)
	_page_counter.size = Vector2(230, 20)
	_page_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_counter.add_theme_font_size_override("font_size", 10)
	_page_counter.add_theme_color_override("font_color", Color(0.38, 0.30, 0.20))
	add_child(_page_counter)
	_update_journal_text()

func _update_journal_text() -> void:
	if _entry_titles.is_empty():
		return
	if _entries.is_empty():
		_entry_titles[0].text = "HERITAGE JOURNAL"
		_entry_texts[0].text = "Your first story is waiting. Explore the living room and ask Lola Nena about the things her family has kept."
		for i in range(1, 4):
			_entry_titles[i].text = ""
			_entry_texts[i].text = ""
		for photo in _entry_photos:
			photo.texture = null
			photo.visible = false
		_page_counter.text = "No entries yet"
		return

	var spread_start := clampi(floori(float(_entry_index) / 4.0) * 4, 0, maxi(0, _entries.size() - 1))
	_entry_index = spread_start
	for i in range(4):
		var entry_index := spread_start + i
		if entry_index < _entries.size():
			var entry: Dictionary = _entries[entry_index]
			_entry_titles[i].text = str(entry.get("title", "Untitled Memory"))
			_entry_texts[i].text = str(entry.get("text", ""))
			var photo_path := str(entry.get("photo_path", ""))
			var photo_texture := load(photo_path) as Texture2D if not photo_path.is_empty() else null
			_entry_photos[i].texture = photo_texture
			_entry_photos[i].visible = photo_texture != null
		else:
			_entry_titles[i].text = ""
			_entry_texts[i].text = ""
			_entry_photos[i].texture = null
			_entry_photos[i].visible = false
	var last_index := mini(spread_start + 4, _entries.size())
	_page_counter.text = "Memories %d–%d of %d" % [spread_start + 1, last_index, _entries.size()]

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
		if _entries.size() > 4:
			var spread_count := ceili(float(_entries.size()) / 4.0)
			var current_spread := floori(float(_entry_index) / 4.0)
			var next_spread := posmod(current_spread + int(step / 4), spread_count)
			_entry_index = next_spread * 4
			_update_journal_text()
	)
	add_child(button)
	button.z_index = 10
