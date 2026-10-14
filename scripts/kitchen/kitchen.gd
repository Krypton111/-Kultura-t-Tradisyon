extends Control

const INGREDIENT_NODES := [
	"Bangus",
	"Condiments",
	"Kamatis",
	"Kangkong",
	"MeasuringCup",
	"Peppers",
	"Radish",
	"SinigangMix",
	"Talong"
]


func _ready() -> void:
	var lola := get_node_or_null("LolaNenaStanding") as Sprite2D
	var hud := get_node_or_null("/root/HUD")

	if lola == null:
		return

	# Lola Nena should only appear in the Kitchen after the player has
	# examined ALL heritage interactables in the Living Room.
	# Collecting the Journal and Camera in Migs' Room is not enough.
	var living_room_heritage_completed := false
	if hud != null:
		living_room_heritage_completed = bool(hud.get_meta("living_room_heritage_completed", false))

	lola.visible = living_room_heritage_completed


# Used by the HUD cursor logic. Show the magnifying glass over Lola,
# uncollected ingredients, and Lola's recipe hotspot.
func is_hovering_room_interactable(mouse_position: Vector2) -> bool:
	var lola := get_node_or_null("LolaNenaStanding") as Sprite2D
	if lola != null and lola.visible and _sprite_pixel_hit(lola, mouse_position):
		return true

	for node_name in INGREDIENT_NODES:
		var ingredient := get_node_or_null(node_name) as Sprite2D
		if ingredient == null or not ingredient.visible:
			continue
		if bool(ingredient.get_meta("ingredient_collected", false)):
			continue
		if _sprite_pixel_hit(ingredient, mouse_position):
			return true

	var recipe_area := get_node_or_null("Container2") as Control
	if recipe_area != null and recipe_area.get_global_rect().has_point(mouse_position):
		return true

	return false


func _sprite_pixel_hit(sprite: Sprite2D, viewport_position: Vector2) -> bool:
	if sprite.texture == null or not sprite.visible:
		return false

	var canvas_position := get_viewport().get_canvas_transform().affine_inverse() * viewport_position
	var local_position := sprite.to_local(canvas_position)
	var rect := sprite.get_rect()
	if not rect.has_point(local_position):
		return false

	var texture_image := sprite.texture.get_image()
	if texture_image == null or texture_image.is_empty():
		return true

	var uv := (local_position - rect.position) / rect.size
	var px := clampi(int(uv.x * texture_image.get_width()), 0, texture_image.get_width() - 1)
	var py := clampi(int(uv.y * texture_image.get_height()), 0, texture_image.get_height() - 1)
	return texture_image.get_pixel(px, py).a > 0.15
