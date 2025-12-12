extends CharacterBody3D

@export var max_health: int = 1
var health: int

func _ready() -> void:
	health = max_health

func apply_damage(amount: int = 1) -> void:
	health -= amount
	if health <= 0:
		queue_free()
