#!/usr/bin/env python3
# Applies achievement-system changes to a LOCAL checkout only. No GitHub API,
# commit, or push is used. Run from the repository root with:
#     python apply_achievement_system.py

from pathlib import Path
import sys

MANAGER_PATH = Path("scripts/autoload/achievement_manager.gd")

MANAGER_SOURCE = r'''extends CanvasLayer
## Per-save achievement state and bottom-right toast notifications.

const DEFINITIONS: Array[Dictionary] = [
    {"id": "heritage_collector", "title": "A Curious Mind", "description": "Discover every living-room heritage object and receive the salakot from Lola Nena."},
    {"id": "ingredients_in_pot", "title": "A Taste of Home", "description": "Collect every required sinigang ingredient and place them all in the pot."},
    {"id": "collect_eggs", "title": "A Helping Hand", "description": "Collect the eggs from the chicken coop."},
    {"id": "ending_city", "title": "Back to the City", "description": "Choose to return to the city and share what you learned."},
    {"id": "ending_stay", "title": "A Place to Belong", "description": "Choose to stay and help Lola Nena preserve your family's heritage."}
]

const TOAST_WIDTH := 360.0
const TOAST_HEIGHT := 92.0
const TOAST_RIGHT_MARGIN := 20.0
const TOAST_BOTTOM_MARGIN := 20.0
const TOAST_SLIDE_DURATION := 0.35
const TOAST_VISIBLE_SECONDS := 3.0

var _notification_queue: Array[String] = []
var _notification_active := false


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 3000


func get_definitions() -> Array[Dictionary]:
    return DEFINITIONS.duplicate(true)


func get_unlocked_ids() -> Array:
    var state := get_node_or_null("/root/GameState")
    if state == null:
        return []
    var stored: Variant = state.get_state("achievements_unlocked", [])
    return stored.duplicate(true) if stored is Array else []


func is_unlocked(achievement_id: String) -> bool:
    return get_unlocked_ids().has(achievement_id)


func unlock(achievement_id: String) -> void:
    var known := false
    for definition in DEFINITIONS:
        if str(definition.get("id", "")) == achievement_id:
            known = true
            break
    if not known:
        push_warning("Ignored unknown achievement ID: " + achievement_id)
        return

    var state := get_node_or_null("/root/GameState")
    if state == null:
        push_warning("Cannot unlock achievement; GameState is unavailable.")
        return

    var unlocked := get_unlocked_ids()
    if unlocked.has(achievement_id):
        return

    unlocked.append(achievement_id)
    state.set_state("achievements_unlocked", unlocked)
    _notification_queue.append(achievement_id)
    if not _notification_active:
        _show_next_notification()


func _show_next_notification() -> void:
    if _notification_queue.is_empty():
        _notification_active = false
        return

    _notification_active = true
    var achievement_id: String = _notification_queue.pop_front()
    var definition: Dictionary = {}
    for item in DEFINITIONS:
        if str(item.get("id", "")) == achievement_id:
            definition = item
            break

    var toast := PanelContainer.new()
    toast.name = "AchievementToast"
    toast.process_mode = Node.PROCESS_MODE_ALWAYS
    toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
    toast.anchor_left = 1.0
    toast.anchor_right = 1.0
    toast.anchor_top = 1.0
    toast.anchor_bottom = 1.0
    toast.offset_left = 20.0
    toast.offset_right = TOAST_WIDTH + TOAST_RIGHT_MARGIN
    toast.offset_top = -TOAST_HEIGHT - TOAST_BOTTOM_MARGIN
    toast.offset_bottom = -TOAST_BOTTOM_MARGIN

    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.12, 0.095, 0.065, 0.98)
    style.border_color = Color(0.82, 0.66, 0.39, 1.0)
    style.set_border_width_all(2)
    style.set_corner_radius_all(10)
    style.content_margin_left = 16.0
    style.content_margin_right = 16.0
    style.content_margin_top = 10.0
    style.content_margin_bottom = 10.0
    toast.add_theme_stylebox_override("panel", style)

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 3)
    toast.add_child(column)

    var heading := Label.new()
    heading.text = "ACHIEVEMENT UNLOCKED"
    heading.add_theme_font_size_override("font_size", 14)
    heading.add_theme_color_override("font_color", Color(0.91, 0.76, 0.49))
    column.add_child(heading)

    var title := Label.new()
    title.text = str(definition.get("title", achievement_id))
    title.add_theme_font_size_override("font_size", 20)
    title.add_theme_color_override("font_color", Color(0.98, 0.95, 0.87))
    title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(title)

    add_child(toast)

    var slide_in := create_tween()
    slide_in.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    slide_in.tween_property(toast, "offset_left", -(TOAST_WIDTH + TOAST_RIGHT_MARGIN), TOAST_SLIDE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    slide_in.parallel().tween_property(toast, "offset_right", -TOAST_RIGHT_MARGIN, TOAST_SLIDE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    await slide_in.finished
    await get_tree().create_timer(TOAST_VISIBLE_SECONDS, true).timeout

    var slide_out := create_tween()
    slide_out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    slide_out.tween_property(toast, "offset_left", 20.0, TOAST_SLIDE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
    slide_out.parallel().tween_property(toast, "offset_right", TOAST_WIDTH + TOAST_RIGHT_MARGIN, TOAST_SLIDE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
    await slide_out.finished

    if is_instance_valid(toast):
        toast.queue_free()
    _show_next_notification()
'''

def replace_once(source, old, new, label):
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly one insertion anchor, found {count}")
    return source.replace(old, new, 1)

def main():
    paths = {
        "project": Path("project.godot"),
        "state": Path("scripts/autoload/game_state.gd"),
        "hud": Path("scripts/UI/hud_navigation.gd"),
        "living": Path("scripts/living room/living_room_interactions.gd"),
        "kitchen": Path("scripts/kitchen/kitchen_task_controller.gd"),
        "coop": Path("scripts/backyard/chicken_coop.gd"),
    }
    missing = [str(p) for p in paths.values() if not p.is_file()]
    if missing:
        print("ERROR: Run this script from the repository root. Missing: " + ", ".join(missing))
        return 2
    if MANAGER_PATH.exists():
        print(f"ERROR: {MANAGER_PATH} already exists; refusing to overwrite it.")
        return 3

    data = {key: path.read_text(encoding="utf-8") for key, path in paths.items()}

    data["project"] = replace_once(
        data["project"],
        'AudioFeedback="*res://scripts/autoload/audio_feedback.gd"\nHUD="*res://game_scenes/UI scenes/HUD.tscn"',
        'AudioFeedback="*res://scripts/autoload/audio_feedback.gd"\nAchievementManager="*res://scripts/autoload/achievement_manager.gd"\nHUD="*res://game_scenes/UI scenes/HUD.tscn"',
        "project.godot autoload"
    )
    data["state"] = replace_once(
        data["state"],
        '\t"inventory_items": []',
        '\t"inventory_items": [],\n\t"achievements_unlocked": []',
        "GameState default"
    )
    data["hud"] = replace_once(
        data["hud"],
        '\t_add_pause_button(layout, "Load Game", _load_game)\n\t_add_pause_button(layout, "Settings", _show_pause_settings)',
        '\t_add_pause_button(layout, "Load Game", _load_game)\n\t_add_pause_button(layout, "Achievements", _show_pause_achievements)\n\t_add_pause_button(layout, "Settings", _show_pause_settings)',
        "pause-menu button"
    )

    achievements_method = r'''
func _show_pause_achievements() -> void:
	if not is_instance_valid(pause_menu_instance):
		return
	for child in pause_menu_instance.get_children():
		child.queue_free()

	var panel := PanelContainer.new()
	panel.name = "AchievementsPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-360, -290)
	panel.size = Vector2(720, 580)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.16, 0.13, 0.10, 0.99)
	panel_style.border_color = Color(0.78, 0.61, 0.35, 1.0)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 22.0
	panel_style.content_margin_right = 22.0
	panel_style.content_margin_top = 18.0
	panel_style.content_margin_bottom = 18.0
	panel.add_theme_stylebox_override("panel", panel_style)
	pause_menu_instance.add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	panel.add_child(layout)

	var heading := Label.new()
	heading.text = "ACHIEVEMENTS"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 32)
	heading.add_theme_color_override("font_color", Color(0.91, 0.76, 0.49))
	layout.add_child(heading)

	var manager := get_node_or_null("/root/AchievementManager")
	var unlocked: Array = manager.call("get_unlocked_ids") if manager != null else []
	var definitions: Array = manager.call("get_definitions") if manager != null else []
	var summary := Label.new()
	summary.text = "%d / %d unlocked in this save" % [unlocked.size(), definitions.size()]
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.add_theme_font_size_override("font_size", 17)
	summary.add_theme_color_override("font_color", Color(0.97, 0.94, 0.86))
	layout.add_child(summary)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	for definition in definitions:
		var achievement_id := str(definition.get("id", ""))
		var is_unlocked := unlocked.has(achievement_id)
		var row := PanelContainer.new()
		var row_style := StyleBoxFlat.new()
		row_style.bg_color = Color(0.24, 0.19, 0.14, 1.0) if is_unlocked else Color(0.12, 0.105, 0.09, 1.0)
		row_style.border_color = Color(0.78, 0.61, 0.35, 1.0) if is_unlocked else Color(0.35, 0.31, 0.26, 1.0)
		row_style.set_border_width_all(1)
		row_style.set_corner_radius_all(6)
		row_style.content_margin_left = 12.0
		row_style.content_margin_right = 12.0
		row_style.content_margin_top = 8.0
		row_style.content_margin_bottom = 8.0
		row.add_theme_stylebox_override("panel", row_style)
		list.add_child(row)

		var row_layout := VBoxContainer.new()
		row_layout.add_theme_constant_override("separation", 3)
		row.add_child(row_layout)

		var title := Label.new()
		title.text = ("✓  " if is_unlocked else "LOCKED  ") + str(definition.get("title", "Achievement"))
		title.add_theme_font_size_override("font_size", 20)
		title.add_theme_color_override("font_color", Color(0.91, 0.76, 0.49) if is_unlocked else Color(0.65, 0.62, 0.56))
		row_layout.add_child(title)

		var description := Label.new()
		description.text = str(definition.get("description", ""))
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.add_theme_font_size_override("font_size", 15)
		description.add_theme_color_override("font_color", Color(0.97, 0.94, 0.86) if is_unlocked else Color(0.58, 0.56, 0.52))
		row_layout.add_child(description)

	var back := _add_pause_button(layout, "Back", Callable(self, "_rebuild_pause_menu"))
	back.custom_minimum_size = Vector2(260, 42)


'''
    data["hud"] = replace_once(
        data["hud"],
        "func _show_pause_slot_menu(load_mode: bool) -> void:",
        achievements_method + "func _show_pause_slot_menu(load_mode: bool) -> void:",
        "Achievements view method"
    )

    data["living"] = replace_once(
        data["living"],
        '\tif game_state != null:\n\t\tgame_state.set_state("living_room_heritage_completed", true)\n\tif hud != null:\n\t\thud.set("navigation_locked", false)',
        '\tif game_state != null:\n\t\tgame_state.set_state("living_room_heritage_completed", true)\n'
        '\t\tvar achievement_manager := get_node_or_null("/root/AchievementManager")\n'
        '\t\tvar visited: Array = game_state.get_state("living_room_visited_story_ids", [])\n'
        '\t\tif achievement_manager != null and bool(game_state.get_state("salakot_reward_received", false)) and visited.size() >= HERITAGE_STORIES.size():\n'
        '\t\t\tachievement_manager.call("unlock", "heritage_collector")\n'
        '\tif hud != null:\n\t\thud.set("navigation_locked", false)',
        "heritage achievement trigger"
    )
    data["living"] = replace_once(
        data["living"],
        '\tgame_state.set_state("ending_choice", choice)\n\t_play_ending_dialogue(choice)',
        '\tgame_state.set_state("ending_choice", choice)\n'
        '\tvar achievement_manager := get_node_or_null("/root/AchievementManager")\n'
        '\tif achievement_manager != null:\n'
        '\t\tachievement_manager.call("unlock", "ending_stay" if choice == "stay" else "ending_city")\n'
        '\t_play_ending_dialogue(choice)',
        "ending achievement trigger"
    )
    data["kitchen"] = replace_once(
        data["kitchen"],
        '\t\t\tif game_state != null:\n\t\t\t\tgame_state.set_state(task_model.KITCHEN_TASK_COMPLETED_META, true)\n\t\t\t_finish_pot_task()',
        '\t\t\tif game_state != null:\n\t\t\t\tgame_state.set_state(task_model.KITCHEN_TASK_COMPLETED_META, true)\n'
        '\t\t\tvar achievement_manager := get_node_or_null("/root/AchievementManager")\n'
        '\t\t\tif achievement_manager != null:\n'
        '\t\t\t\tachievement_manager.call("unlock", "ingredients_in_pot")\n'
        '\t\t\t_finish_pot_task()',
        "pot achievement trigger"
    )
    data["coop"] = replace_once(
        data["coop"],
        '\t_eggs_collected = true\n\t_game_state.set_state("coop_eggs_collected", true)\n\tvar tween := create_tween()',
        '\t_eggs_collected = true\n\t_game_state.set_state("coop_eggs_collected", true)\n'
        '\tvar achievement_manager := get_node_or_null("/root/AchievementManager")\n'
        '\tif achievement_manager != null:\n'
        '\t\tachievement_manager.call("unlock", "collect_eggs")\n'
        '\tvar tween := create_tween()',
        "egg achievement trigger"
    )

    # Every insertion anchor has been validated before any file is written.
    for key, path in paths.items():
        backup = path.with_name(path.name + ".achievement-backup")
        if not backup.exists():
            backup.write_text(path.read_text(encoding="utf-8"), encoding="utf-8")
    for key, path in paths.items():
        path.write_text(data[key], encoding="utf-8")

    MANAGER_PATH.parent.mkdir(parents=True, exist_ok=True)
    MANAGER_PATH.write_text(MANAGER_SOURCE, encoding="utf-8")
    print("Achievement system applied to this local checkout.")
    print("Backups: each changed file has a .achievement-backup copy.")
    print("No GitHub requests, commits, or pushes were made.")
    print("Open the project in Godot and check the Output panel for parse errors.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print("ERROR: " + str(exc))
        print("No GitHub changes were made.")
        raise SystemExit(1)
