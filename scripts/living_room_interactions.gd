extends Control

@onready var closed_tv: Sprite2D = get_node("Stand+closedTV")
@onready var open_tv: Sprite2D = get_node("Stand+openTv")
@onready var window_open: Sprite2D = get_node("WindowOpen")
@onready var window_closed: Sprite2D = get_node("WindowClosed")
@onready var couch: Sprite2D = get_node("Couch+plant")
@onready var lola_not_looking: Sprite2D = get_node("LolaNenaNotLooking")
@onready var lola_looking: Sprite2D = get_node("LolaNenaLooking")

func _ready() -> void:
    closed_tv.visible = true
    open_tv.visible = false

    # The artwork stays exactly where it was placed in Canva.
    # These transparent UI buttons are created from each PNG's
    # non-transparent pixel bounds, so they act as point-and-click
    # interaction regions without using physics collisions.
    _create_interaction_button(closed_tv, Callable(self, "_on_tv_clicked"), "TVButton")
    _create_interaction_button(window_open, Callable(self, "_on_window_clicked"), "WindowButton")
    _create_interaction_button(couch, Callable(self, "_on_couch_clicked"), "CouchButton")
    _create_interaction_button(lola_not_looking, Callable(self, "_on_lola_clicked"), "LolaNenaButton")

func _create_interaction_button(sprite: Sprite2D, callback: Callable, button_name: String) -> void:
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

    # Sprite2D coordinates are centered on the texture.
    # Convert the non-transparent image rectangle into the same
    # scaled screen coordinates without changing the sprite itself.
    var scaled_size := Vector2(image.get_width(), image.get_height()) * sprite.scale
    var scaled_used_position := Vector2(used_rect.position) * sprite.scale
    var scaled_used_size := Vector2(used_rect.size) * sprite.scale

    button.position = sprite.position - (scaled_size / 2.0) + scaled_used_position
    button.size = scaled_used_size

    button.pressed.connect(callback)
    add_child(button)

func _on_tv_clicked() -> void:
    closed_tv.visible = false
    open_tv.visible = true

func _on_window_clicked() -> void:
    window_open.visible = false
    window_closed.visible = true

func _on_couch_clicked() -> void:
    # Interaction area is ready for the couch/plant event.
    pass

func _on_lola_clicked() -> void:
    lola_not_looking.visible = false
    lola_looking.visible = true
