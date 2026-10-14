extends Control

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
