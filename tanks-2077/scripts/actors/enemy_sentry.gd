extends CharacterBody3D

@export var max_health: int = 1
var health: int

@export var bullet_scene: PackedScene
@export var bullet_speed: float = 20.0
@export var fire_interval: float = 1.2
@export var spawn_forward_offset: float = 0.6

@onready var turret: Node3D = $Turret
@onready var muzzle: Marker3D = $Turret/Muzzle

var player: Node3D

func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	_find_player()

	var t := Timer.new()
	t.wait_time = fire_interval
	t.one_shot = false
	t.autostart = true
	add_child(t)
	t.timeout.connect(_fire)

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		_find_player()
		if not is_instance_valid(player):
			return

	_aim_at_player()

func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player") as Node3D

func _aim_at_player() -> void:
	var to_target := player.global_position - turret.global_position
	to_target.y = 0.0
	if to_target.length() < 0.001:
		return
	turret.look_at(turret.global_position + to_target, Vector3.UP)

func _has_los_to_player() -> bool:
	if not is_instance_valid(player):
		return false

	var from := muzzle.global_position
	var to := player.global_position
	to.y = from.y

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self]
	query.collision_mask = (1 << 0) | (1 << 2) # tanks + world

	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false

	return hit["collider"] == player

func _fire() -> void:
	if bullet_scene == null or not is_instance_valid(player):
		return
	if not _has_los_to_player():
		return

	var bullet := bullet_scene.instantiate()

	var level_root := get_tree().current_scene.get_node_or_null("LevelRoot")
	if level_root != null:
		level_root.add_child(bullet)
	else:
		get_tree().current_scene.add_child(bullet)

	var dir := -turret.global_transform.basis.z.normalized()
	bullet.global_transform = muzzle.global_transform
	bullet.global_position = muzzle.global_position + dir * spawn_forward_offset

	if bullet is CollisionObject3D:
		bullet.set_collision_layer_value(2, true)
		bullet.set_collision_mask_value(1, true)
		bullet.set_collision_mask_value(3, true)

	if bullet is CharacterBody3D:
		bullet.velocity = dir * bullet_speed

func apply_damage(amount: int = 1) -> void:
	health -= amount
	if health <= 0:
		queue_free()
