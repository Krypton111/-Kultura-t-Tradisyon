extends Node
## Tracks active gameplay time across scene changes.
## The tracker is an autoload, so scene changes do not reset the clock.
## Its default process mode pauses with SceneTree.paused.

signal gameplay_started
signal gameplay_completed(elapsed_seconds: int)

var is_running := false
var has_started := false
var has_completed := false
var elapsed_seconds: float = 0.0


func start_gameplay() -> void:
	if has_started or has_completed:
		return
	has_started = true
	is_running = true
	gameplay_started.emit()


func _process(delta: float) -> void:
	if is_running and not has_completed:
		elapsed_seconds += delta


func complete_gameplay() -> int:
	if has_completed:
		return get_elapsed_seconds()

	if not has_started:
		push_warning("Gameplay timer was never started; completion time will be zero.")
		elapsed_seconds = 0.0

	is_running = false
	has_completed = true
	var final_seconds := get_elapsed_seconds()
	gameplay_completed.emit(final_seconds)
	return final_seconds


func get_elapsed_seconds() -> int:
	return int(floor(elapsed_seconds))


func get_elapsed_seconds_precise() -> float:
	return elapsed_seconds


func get_formatted_time() -> String:
	var total := get_elapsed_seconds()
	var hours := int(total / 3600)
	var minutes := int((total % 3600) / 60)
	var seconds := total % 60
	if hours > 0:
		return "%02d:%02d:%02d" % [hours, minutes, seconds]
	return "%02d:%02d" % [minutes, seconds]


func reset_for_new_run() -> void:
	is_running = false
	has_started = false
	has_completed = false
	elapsed_seconds = 0.0
