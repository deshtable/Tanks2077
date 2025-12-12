extends CharacterBody3D

@export var move_speed: float = 8.0

@export var bullet_scene: PackedScene
@export var bullet_speed: float = 25.0
@export var max_bullets_alive: int = 5
@export var spawn_forward_offset: float = 0.6

@onready var turret: Node3D = $Turret
@onready var muzzle: Marker3D = $Turret/Muzzle
@onready var cam: Camera3D = get_viewport().get_camera_3d()

var move_input: Vector2 = Vector2.ZERO
var active_bullets: Array[Node] = []


func _physics_process(delta: float) -> void:
	# Fire
	if Input.is_action_just_pressed("fire"):
		print("FIRE CLICKED")
		_try_fire()

	# Movement
	move_input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move_vec = Vector3(move_input.x, 0.0, move_input.y)

	if move_vec.length() > 0.001:
		# Face movement direction
		rotation.y = atan2(-move_vec.x, -move_vec.z)

	velocity.x = move_vec.x * move_speed
	velocity.z = move_vec.z * move_speed
	velocity.y = 0.0
	move_and_slide()


func _process(delta: float) -> void:
	_aim_turret_at_mouse()


func _aim_turret_at_mouse() -> void:
	if cam == null:
		return

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var from: Vector3 = cam.project_ray_origin(mouse_pos)
	var dir: Vector3 = cam.project_ray_normal(mouse_pos)

	# Intersect with the ground plane at y = 0
	if abs(dir.y) < 0.0001:
		return
	var t := -from.y / dir.y
	if t < 0.0:
		return
	var target: Vector3 = from + dir * t

	var to_target: Vector3 = target - turret.global_transform.origin
	to_target.y = 0.0
	if to_target.length() < 0.001:
		return

	turret.look_at(turret.global_transform.origin + to_target, Vector3.UP)


func _try_fire() -> void:
	# Bullet scene must be assigned in Inspector
	if bullet_scene == null:
		print("No bullet_scene assigned on Player!")
		return

	# Enforce max bullets alive (clean invalid refs first)
	active_bullets = active_bullets.filter(func(b): return is_instance_valid(b))
	if active_bullets.size() >= max_bullets_alive:
		return

	var bullet := bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	active_bullets.append(bullet)

	# Fire direction (Godot forward is -Z)
	var dir: Vector3 = -turret.global_transform.basis.z.normalized()

	# Spawn at muzzle but pushed forward so it doesn't instantly collide with the tank
	bullet.global_transform = muzzle.global_transform
	bullet.global_position = muzzle.global_position + dir * spawn_forward_offset

	# Prevent bullet from colliding with the player immediately
	if bullet is CollisionObject3D:
		bullet.add_collision_exception_with(self)

	# Bullet script should define `velocity` (Vector3). We'll set it.
	# If this print shows but bullet doesn't move, your Bullet script isn't using move_and_collide/move_and_slide.
	if "velocity" in bullet:
		bullet.velocity = dir * bullet_speed
	else:
		# Fallback: set a metadata or call method if you made it differently
		print("Bullet has no 'velocity' property. Add `var velocity: Vector3` to Bullet.gd")

	print("Spawned bullet at ", bullet.global_position, " dir=", dir)
