extends CanvasLayer

func _ready():
	if is_multiplayer_authority() == false:
		queue_free()
