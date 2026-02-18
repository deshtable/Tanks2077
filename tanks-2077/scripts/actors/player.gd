extends CharacterBody3D
signal died

@export var move_speed: float = 8.0

@export var bullet_scene: PackedScene
@export var bullet_speed: float = 25.0
@export var max_bullets_alive: int = 5
@export var spawn_forward_offset: float = 1.0

@export var bullet_collision_layer: int = 2
@export var bullet_collision_mask: int = 5

@export var max_health: int = 1
var health: int

@onready var turret: Node3D = $Turret
@onready var muzzle: Marker3D = $Turret/Muzzle
@onready var cam: Camera3D = get_viewport().get_camera_3d()

var active_bullets: Array[Node] = []

func _ready() -> void:
	add_to_group("player")
	health = max_health

func apply_damage(amount: int = 1) -> void:
	health -= amount
	print("Player hit! HP =", health)
	if health <= 0:
		print("PLAYER DIED -> emitting died")
		died.emit()
		call_deferred("queue_free")

func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("fire"):
		_try_fire()

	var move_input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move_vec := Vector3(move_input.x, 0.0, move_input.y)

	if move_vec.length() > 0.001:
		rotation.y = atan2(-move_vec.x, -move_vec.z)

	velocity.x = move_vec.x * move_speed
	velocity.z = move_vec.z * move_speed
	velocity.y = 0.0
	move_and_slide()

func _process(_delta: float) -> void:
	_aim_turret_at_mouse()

func _aim_turret_at_mouse() -> void:
	if cam == null:
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mouse_pos)
	var dir := cam.project_ray_normal(mouse_pos)

	if abs(dir.y) < 0.0001:
		return

	var plane_y := turret.global_position.y
	var t := (plane_y - from.y) / dir.y
	if t < 0.0:
		return

	var target := from + dir * t
	var to_target := target - turret.global_position
	to_target.y = 0.0
	if to_target.length() < 0.001:
		return

	turret.look_at(turret.global_position + to_target, Vector3.UP)

func _try_fire() -> void:
	if bullet_scene == null:
		print("No bullet_scene assigned on Player!")
		return

	active_bullets = active_bullets.filter(func(b): return is_instance_valid(b))
	if active_bullets.size() >= max_bullets_alive:
		return

	var bullet := bullet_scene.instantiate()

	var level_root := get_tree().current_scene.get_node_or_null("LevelRoot")
	if level_root != null:
		level_root.add_child(bullet)
	else:
		get_tree().current_scene.add_child(bullet)

	active_bullets.append(bullet)

	var dir := -turret.global_transform.basis.z.normalized()

	bullet.global_transform = muzzle.global_transform
	bullet.global_position = muzzle.global_position + dir * spawn_forward_offset

	if bullet is CollisionObject3D:
		bullet.collision_layer = 1 << (bullet_collision_layer - 1)
		bullet.collision_mask = bullet_collision_mask
		bullet.add_collision_exception_with(self)
		get_tree().create_timer(0.05).timeout.connect(func():
			if is_instance_valid(bullet):
				bullet.remove_collision_exception_with(self)
		)

	if bullet is CharacterBody3D:
		bullet.velocity = dir * bullet_speed
