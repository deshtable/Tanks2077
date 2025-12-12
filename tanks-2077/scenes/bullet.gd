extends CharacterBody3D

var bounces := 0
const MAX_BOUNCES := 2

func _ready() -> void:
	print("Bullet ready at ", global_position)

func _physics_process(delta: float) -> void:
	if velocity.length_squared() < 0.000001:
		return

	var collision := move_and_collide(velocity * delta)
	if collision:
		print("Bullet hit something")
		velocity = velocity.bounce(collision.get_normal())
		bounces += 1
		if bounces > MAX_BOUNCES:
			queue_free()
