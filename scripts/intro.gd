extends Control

const LIVING_ROOM_SCENE := "res://game_scenes/levels/living_room.tscn"
const TYPEWRITER_SECONDS_PER_CHARACTER := 0.055
const HOLD_SECONDS := 3.0
const TEXT_FADE_SECONDS := 0.8

@onready var quote: RichTextLabel = $Quote

func _ready() -> void:
	# Keep the in-game HUD out of sight until the living room appears.
	var hud := get_node_or_null("/root/HUD")
	if hud != null:
		hud.visible = false
		hud.set_meta("opening_intro_transition", true)
		if "navigation_locked" in hud:
			hud.set("navigation_locked", true)

	# Start with an empty quote and reveal it character by character.
	quote.visible_characters = 0
	var character_count := quote.get_total_character_count()
	var typing_duration := character_count * TYPEWRITER_SECONDS_PER_CHARACTER

	var typing_tween := create_tween()
	typing_tween.tween_property(quote, "visible_characters", character_count, typing_duration)
	await typing_tween.finished

	# Let the complete quotation linger before fading it away.
	await get_tree().create_timer(HOLD_SECONDS).timeout

	var fade_tween := create_tween()
	fade_tween.tween_property(quote, "modulate:a", 0.0, TEXT_FADE_SECONDS)
	await fade_tween.finished

	# The next scene fades in from black after the quotation disappears.
	get_tree().change_scene_to_file(LIVING_ROOM_SCENE)
