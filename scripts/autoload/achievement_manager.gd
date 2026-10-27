extends CanvasLayer
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

    # Keep the signed-in UGAT website profile in sync when running as a web export.
    _sync_achievements_to_website()

    _notification_queue.append(achievement_id)
    if not _notification_active:
        _show_next_notification()


func _sync_achievements_to_website() -> void:
    # The website session cookie is available only when the game is served from UGAT.
    if not OS.has_feature("web"):
        return

    var state := get_node_or_null("/root/GameState")
    if state == null:
        push_warning("Achievement sync skipped; GameState is unavailable.")
        return

    var stored: Variant = state.get_state("achievements_unlocked", [])
    if not stored is Array:
        push_warning("Achievement sync skipped; achievements_unlocked is not an Array.")
        return

    # Send only known achievement IDs; never send a username or account ID.
    var valid_ids: Array[String] = []
    for stored_id in stored:
        var id := str(stored_id)
        for definition in DEFINITIONS:
            if str(definition.get("id", "")) == id:
                if not valid_ids.has(id):
                    valid_ids.append(id)
                break

    if valid_ids.is_empty():
        return

    var endpoint: String = JavaScriptBridge.eval(
        "new URL('../../../save_game_achievement.php', window.location.href).href",
        true
    )
    if endpoint.is_empty():
        push_warning("Achievement sync failed; could not resolve the UGAT endpoint.")
        return

    var request_node := HTTPRequest.new()
    request_node.name = "AchievementWebsiteSync"
    request_node.timeout = 15.0
    get_tree().root.add_child(request_node)
    request_node.request_completed.connect(
        func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
            if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
                push_warning("Achievement sync failed (HTTP %s): %s" % [
                    response_code,
                    body.get_string_from_utf8()
                ])
            request_node.queue_free()
    )

    var headers := PackedStringArray(["Content-Type: application/json"])
    var body := JSON.stringify({"achievement_ids": valid_ids})
    var error := request_node.request(
        endpoint,
        headers,
        HTTPClient.METHOD_POST,
        body
    )
    if error != OK:
        request_node.queue_free()
        push_warning("Could not start achievement sync request: %s" % error)


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
