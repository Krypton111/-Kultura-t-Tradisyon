extends CanvasLayer

const EDGE_SIZE := 48.0

const LEFT_CURSOR := preload("res://GAME ASSETS/UI/HUD/left room.png")
const RIGHT_CURSOR := preload("res://GAME ASSETS/UI/HUD/right room.png")
const DOWN_CURSOR := preload("res://GAME ASSETS/UI/HUD/bottom room.png")

const LIVING_ROOM := "res://game_scenes/levels/living_room.tscn"
const KITCHEN := "res://game_scenes/levels/kitchen.tscn"
const MIGS_ROOM := "res://game_scenes/levels/migs_room.tscn"
const BACKYARD := "res://game_scenes/levels/backyard.tscn"

var current_direction := ""
var navigation_locked := false
var left_cursor: Texture2D
var right_cursor: Texture2D
var down_cursor: Texture2D

func _ready() -> void:
    left_cursor = _prepare_cursor(LEFT_CURSOR)
    right_cursor = _prepare_cursor(RIGHT_CURSOR)
    down_cursor = _prepare_cursor(DOWN_CURSOR)

    _create_edge_button("LeftNavigation", Vector2(EDGE_SIZE, _screen_height() - EDGE_SIZE), Vector2(0, 0), Callable(self, "_go_left"))
    _create_edge_button("RightNavigation", Vector2(EDGE_SIZE, _screen_height() - EDGE_SIZE), Vector2(_screen_width() - EDGE_SIZE, 0), Callable(self, "_go_right"))
    _create_edge_button("DownNavigation", Vector2(_screen_width(), EDGE_SIZE), Vector2(0, _screen_height() - EDGE_SIZE), Callable(self, "_go_down"))

    get_viewport().size_changed.connect(_on_viewport_resized)

func _process(_delta: float) -> void:
    if navigation_locked:
        return

    _update_cursor(get_viewport().get_mouse_position())

func _on_viewport_resized() -> void:
    _resize_navigation_buttons()

func _create_edge_button(button_name: String, button_size: Vector2, button_position: Vector2, callback: Callable) -> void:
    var button := Button.new()
    button.name = button_name
    button.text = ""
    button.flat = true
    button.focus_mode = Control.FOCUS_NONE
    button.mouse_default_cursor_shape = Control.CURSOR_ARROW
    button.mouse_filter = Control.MOUSE_FILTER_STOP

    var empty_style := StyleBoxEmpty.new()
    button.add_theme_stylebox_override("normal", empty_style)
    button.add_theme_stylebox_override("hover", empty_style)
    button.add_theme_stylebox_override("pressed", empty_style)
    button.add_theme_stylebox_override("focus", empty_style)

    button.position = button_position
    button.size = button_size
    button.pressed.connect(callback)

    add_child(button)

func _resize_navigation_buttons() -> void:
    var left_button := get_node_or_null("LeftNavigation") as Button
    var right_button := get_node_or_null("RightNavigation") as Button
    var down_button := get_node_or_null("DownNavigation") as Button

    var width := _screen_width()
    var height := _screen_height()

    if left_button:
        left_button.position = Vector2(0, 0)
        left_button.size = Vector2(EDGE_SIZE, height - EDGE_SIZE)

    if right_button:
        right_button.position = Vector2(width - EDGE_SIZE, 0)
        right_button.size = Vector2(EDGE_SIZE, height - EDGE_SIZE)

    if down_button:
        down_button.position = Vector2(0, height - EDGE_SIZE)
        down_button.size = Vector2(width, EDGE_SIZE)

func _update_cursor(mouse_position: Vector2) -> void:
    var width := _screen_width()
    var height := _screen_height()

    var direction := ""

    # The bottom edge has priority at the corners.
    if mouse_position.y >= height - EDGE_SIZE:
        direction = "down"
    elif mouse_position.x <= EDGE_SIZE:
        direction = "left"
    elif mouse_position.x >= width - EDGE_SIZE:
        direction = "right"

    if direction == current_direction:
        return

    current_direction = direction

    match direction:
        "left":
            Input.set_custom_mouse_cursor(left_cursor, Input.CURSOR_ARROW, Vector2(left_cursor.get_width() / 2.0, left_cursor.get_height() / 2.0))
        "right":
            Input.set_custom_mouse_cursor(right_cursor, Input.CURSOR_ARROW, Vector2(right_cursor.get_width() / 2.0, right_cursor.get_height() / 2.0))
        "down":
            Input.set_custom_mouse_cursor(down_cursor, Input.CURSOR_ARROW, Vector2(down_cursor.get_width() / 2.0, down_cursor.get_height() / 2.0))
        _:
            Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)

func _go_left() -> void:
    match get_tree().current_scene.scene_file_path:
        LIVING_ROOM:
            _change_scene(KITCHEN)
        MIGS_ROOM:
            _change_scene(KITCHEN)
        BACKYARD:
            _change_scene(MIGS_ROOM)

func _go_right() -> void:
    match get_tree().current_scene.scene_file_path:
        LIVING_ROOM:
            _change_scene(MIGS_ROOM)
        KITCHEN:
            _change_scene(MIGS_ROOM)
        MIGS_ROOM:
            _change_scene(BACKYARD)
        BACKYARD:
            return

func _go_down() -> void:
    match get_tree().current_scene.scene_file_path:
        LIVING_ROOM:
            _change_scene(BACKYARD)
        KITCHEN:
            _change_scene(BACKYARD)

func _change_scene(scene_path: String) -> void:
    if navigation_locked:
        return

    navigation_locked = true
    Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
    current_direction = ""
    get_tree().change_scene_to_file(scene_path)

func _exit_tree() -> void:
    Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)

func _prepare_cursor(source: Texture2D) -> Texture2D:
    var image := source.get_image()
    if image == null:
        return source

    var max_size: float = 128.0
    var source_size := Vector2(
        float(image.get_width()),
        float(image.get_height())
    )

    var scale_factor: float = minf(
        max_size / source_size.x,
        max_size / source_size.y
    )
    scale_factor = minf(scale_factor, 1.0)

    if scale_factor < 1.0:
        var new_size := Vector2i(
            max(1, int(source_size.x * scale_factor)),
            max(1, int(source_size.y * scale_factor))
        )

        image.resize(
            new_size.x,
            new_size.y,
            Image.INTERPOLATE_LANCZOS
        )

    return ImageTexture.create_from_image(image)

func _screen_width() -> float:
    return get_viewport().get_visible_rect().size.x

func _screen_height() -> float:
    return get_viewport().get_visible_rect().size.y
