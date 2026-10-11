extends Control

const TYPEWRITER_SECONDS_PER_CHARACTER := 0.018

const OPENING_LINES: Array[Dictionary] = [
	{
		"speaker": "Migs",
		"text": "It’s been a while since I last visited Lola. I wonder if anything has changed."
	},
	{
		"speaker": "Lola Nena",
		"text": "Migs! There you are! Come in, hijo. I was just fixing some things around the house."
	},
	{
		"speaker": "Migs",
		"text": "Hi, Lola! Do you need help with anything?"
	},
	{
		"speaker": "Lola Nena",
		"text": "Actually, yes. I’ve been looking through some of our old belongings. Some of these things have been with our family for years, but I’m afraid their stories might be forgotten."
	},
	{
		"speaker": "Migs",
		"text": "You mean the old things around the house?"
	},
	{
		"speaker": "Lola Nena",
		"text": "Not just the things, hijo. The memories, traditions, and people behind them."
	},
	{
		"speaker": "Lola Nena",
		"text": "Will you help me document a few of them? If we write down what we learn, their stories can be remembered and shared."
	},
	{
		"speaker": "Migs",
		"text": "Of course, Lola. I’ll get my camera and journal from my room, then come back and explore the things around the house."
	}
]

@onready var dialogue_text: RichTextLabel = $DialogueText
@onready var continue_hint: Label = $ContinueHint
@onready var generic_name_box: Sprite2D = $DialogueNameBox
@onready var migs_name_box: Sprite2D = $MigsNameDialogueBox
@onready var lola_name_box: Sprite2D = $LolaNenaNameDialogueBox

var line_index: int = 0
var dialogue_active: bool = false
var typewriter_tween: Tween

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Keep the generic nameplate visible behind the character-specific name images.
	generic_name_box.visible = true
	migs_name_box.visible = false
	lola_name_box.visible = false

func start_opening_sequence() -> void:
	if dialogue_active:
		return

	# All Migs–Lola conversations in the living room should use her looking pose.
	_set_lola_dialogue_pose(true)

	dialogue_active = true
	line_index = 0
	visible = true
	focus_mode = Control.FOCUS_ALL
	grab_focus()

	var hud := get_node_or_null("/root/HUD")
	if hud != null:
		hud.set("navigation_locked", true)

	_show_current_line()

func _gui_input(event: InputEvent) -> void:
	if not dialogue_active:
		return

	var advance_pressed := false
	if event is InputEventMouseButton:
		advance_pressed = event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	elif event is InputEventKey:
		advance_pressed = event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]

	if not advance_pressed:
		return

	accept_event()

	# The first press completes the typewriter effect; the next advances.
	if typewriter_tween != null and typewriter_tween.is_running():
		typewriter_tween.kill()
		dialogue_text.visible_characters = -1
		continue_hint.text = "CLICK OR PRESS ENTER TO CONTINUE  ›"
		return

	line_index += 1
	if line_index >= OPENING_LINES.size():
		_finish_dialogue()
		return

	_show_current_line()

func _show_current_line() -> void:
	var line: Dictionary = OPENING_LINES[line_index]
	var is_lola_speaking := str(line["speaker"]) == "Lola Nena"
	migs_name_box.visible = not is_lola_speaking
	lola_name_box.visible = is_lola_speaking
	dialogue_text.text = str(line["text"])
	dialogue_text.visible_characters = 0
	continue_hint.text = "CLICK OR PRESS ENTER  ›"

	var character_count := dialogue_text.get_total_character_count()
	typewriter_tween = create_tween()
	typewriter_tween.tween_property(
		dialogue_text,
		"visible_characters",
		character_count,
		maxf(0.25, character_count * TYPEWRITER_SECONDS_PER_CHARACTER)
	)
	typewriter_tween.finished.connect(_on_typewriter_finished)

func _on_typewriter_finished() -> void:
	if dialogue_active:
		dialogue_text.visible_characters = -1
		continue_hint.text = "CLICK OR PRESS ENTER TO CONTINUE  ›"

func _finish_dialogue() -> void:
	# Restore Lola's idle pose as soon as the conversation ends.
	_set_lola_dialogue_pose(false)
	dialogue_active = false
	visible = false

	var hud := get_node_or_null("/root/HUD")
	if hud != null:
		hud.set("navigation_locked", false)

	queue_free()


func _set_lola_dialogue_pose(is_looking_at_migs: bool) -> void:
	var living_room := get_tree().get_first_node_in_group("living_room_scene")
	if living_room != null and living_room.has_method("set_lola_dialogue_pose"):
		living_room.call("set_lola_dialogue_pose", is_looking_at_migs)
