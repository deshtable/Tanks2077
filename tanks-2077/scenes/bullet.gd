extends CharacterBody3D

var bounces := 0
const MAX_BOUNCES := 2

func _physics_process(delta: float) -> void:
	if velocity.length_squared() < 0.000001:
		return

	var collision := move_and_collide(velocity * delta)
	if collision:
		var node := collision.get_collider()

		# Walk up parents until we find something damageable
		while node != null and not node.has_method("apply_damage"):
			node = node.get_parent()

		if node != null:
			node.apply_damage(1)
			queue_free()
			return

		# Otherwise bounce
		velocity = velocity.bounce(collision.get_normal())
		bounces += 1
		if bounces > MAX_BOUNCES:
			queue_free()
