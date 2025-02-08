extends TextureProgressBar
class_name HealthBar

@export var health_system : HealthSystem

# Called when the node enters the scene tree for the first time.
func _ready():
	if health_system:
		max_value = health_system.total_health
		value = health_system.total_health
		health_system.max_health_updated.connect(_on_max_health_updated)
		health_system.health_updated.connect(_on_health_updated)

func _on_health_updated(new_health):
	value = new_health

func _on_max_health_updated(_max_health):
	max_value = _max_health
