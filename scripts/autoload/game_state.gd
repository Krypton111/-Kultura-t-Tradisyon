extends Node
## Authoritative runtime state for story, inventory, and task progress.
## Autoloaded independently of the HUD so gameplay state is not owned by presentation.

signal state_changed(key: String, value: Variant)

const DEFAULTS := {
	"living_room_heritage_completed": false,
	"living_room_visited_story_ids": [],
	"living_room_recorded_story_ids": [],
	"living_room_final_dialogue_started": false,
	"heritage_entries": [],
	"kitchen_task_intro_completed": false,
	"kitchen_ingredient_task_completed": false,
	"kitchen_ingredient_progress": {},
	"kitchen_collected_ingredient_ids": [],
	"camera_collected": false,
	"journal_collected": false,
	"inventory_items": []
}

var _values: Dictionary = {}


func _ready() -> void:
	for key in DEFAULTS:
		_values[key] = DEFAULTS[key].duplicate(true) if DEFAULTS[key] is Array or DEFAULTS[key] is Dictionary else DEFAULTS[key]


func get_state(key: String, fallback: Variant = null) -> Variant:
	if _values.has(key):
		var value: Variant = _values[key]
		return value.duplicate(true) if value is Array or value is Dictionary else value
	return fallback


func set_state(key: String, value: Variant) -> void:
	_values[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	state_changed.emit(key, get_state(key))


func has_state(key: String) -> bool:
	return _values.has(key)


func add_unique_id(key: String, value: String) -> bool:
	var values: Array = get_state(key, [])
	if values.has(value):
		return false
	values.append(value)
	set_state(key, values)
	return true


func reset_runtime_state() -> void:
	_values.clear()
	for key in DEFAULTS:
		_values[key] = DEFAULTS[key].duplicate(true) if DEFAULTS[key] is Array or DEFAULTS[key] is Dictionary else DEFAULTS[key]
