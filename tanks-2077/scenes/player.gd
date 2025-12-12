extends CharacterBody3D

@export var move_speed: float = 8.0

@export var bullet_scene: PackedScene
@export var bullet_speed: float = 25.0
@export var max_bullets_alive: int = 5
@export var spawn_forward_offset: float = 1.0

# Bullet collisions (simple scheme)
# Tanks + world on layer 1, bullets on layer 2
@export var bullet_collision_layer: int = 2
@export var bullet_collision_mask: int = 5

@export var max_health: int = 1
var health: int

@onready var turret: Node3D = $Turret
@onready var muzzle: Marker3D = $Turret/Muzzle
@onready var cam: Camera3D = get_viewport().get_camera_3d()

var move_input: Vector2 = Vector2.ZERO
var active_bullets: Array[Node] = []

func _ready() -> void:
	health = max_health

func apply_damage(amount: int = 1) -> void:
	health -= amount
	print("Player hit! HP =", health)
	if health <= 0:
		queue_free()

func _physics_process(delta: float) -> void:
	# Fire
	if Input.is_action_just_pressed("fire"):
		print("FIRE CLICKED")
		_try_fire()

	# Movement
	move_input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move_vec = Vector3(move_input.x, 0.0, move_input.y)

	if move_vec.length() > 0.001:
		rotation.y = atan2(-move_vec.x, -move_vec.z)

	velocity.x = move_vec.x * move_speed
	velocity.z = move_vec.z * move_speed
	velocity.y = 0.0
	move_and_slide()
	global_position.y = 0.5

func _process(delta: float) -> void:
	_aim_turret_at_mouse()

func _aim_turret_at_mouse() -> void:
	if cam == null:
		return

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var from: Vector3 = cam.project_ray_origin(mouse_pos)
	var dir: Vector3 = cam.project_ray_normal(mouse_pos)

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
	if bullet_scene == null:
		print("No bullet_scene assigned on Player!")
		return

	# Enforce max bullets alive
	active_bullets = active_bullets.filter(func(b): return is_instance_valid(b))
	if active_bullets.size() >= max_bullets_alive:
		return

	var bullet := bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	active_bullets.append(bullet)

	# Fire direction (Godot forward is -Z)
	var dir: Vector3 = -turret.global_transform.basis.z.normalized()

	# Spawn bullet at muzzle, pushed forward
	bullet.global_transform = muzzle.global_transform
	bullet.global_position = muzzle.global_position + dir * spawn_forward_offset
# Make bullets hit Tanks (layer 1) + World (layer 3) => mask = 1 + 4 = 5
	if bullet is CollisionObject3D:
		bullet.set_collision_layer_value(2, true)   # bullet layer = 2
		bullet.set_collision_mask_value(1, true)    # collide with tanks (layer 1)
		bullet.set_collision_mask_value(3, true)    # collide with world (layer 3)

		# Ignore player briefly so it doesn't instantly collide at spawn,
		# then allow ricochets to kill the player later.
		bullet.add_collision_exception_with(self)
		get_tree().create_timer(0.05).timeout.connect(func():
			if is_instance_valid(bullet):
				bullet.remove_collision_exception_with(self)
		)

	# IMPORTANT: CharacterBody3D already has built-in `velocity`
	if bullet is CharacterBody3D:
		bullet.velocity = dir * bullet_speed
	else:
		print("Bullet root is not CharacterBody3D. Make Bullet.tscn root CharacterBody3D.")

	print("Spawned bullet at ", bullet.global_position, " dir=", dir)
