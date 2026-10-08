extends Area2D

@onready var closed_tv: Sprite2D = get_node("Stand+closedTV")
@onready var open_tv: Sprite2D = get_node("Stand+openTv")
@onready var collision_shape: CollisionShape2D = get_node("CollisionShape2D")

func _ready() -> void:
    closed_tv.visible = true
    open_tv.visible = false

    if closed_tv.texture:
        var rectangle := RectangleShape2D.new()
        rectangle.size = closed_tv.texture.get_size() * closed_tv.scale
        collision_shape.shape = rectangle

func _input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
            closed_tv.visible = false
            open_tv.visible = true
