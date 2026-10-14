extends Control

func _ready() -> void:
	var lola := get_node_or_null("LolaNenaStanding") as Sprite2D
	var hud := get_node_or_null("/root/HUD")

	if lola == null:
		return

	var items_collected := false
	if hud and hud.has_method("has_collected_room_items"):
		items_collected = hud.has_collected_room_items()

	lola.visible = items_collected
git