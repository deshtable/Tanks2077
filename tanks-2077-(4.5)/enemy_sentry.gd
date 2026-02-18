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

func _has_los_to_player() -> bool:
	if player == null:
		return false

	var from: Vector3 = muzzle.global_position
	var to: Vector3 = player.global_position
	to.y = from.y  # keep the ray flat on the plane

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self]
	query.collision_mask = (1 << 0) | (1 << 2)  # Layer 1 (tanks) + Layer 3 (world)

	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false

	return hit["collider"] == player

func _ready() -> void:
	health = max_health
	# simplest: find the player by name "Player" in the current scene
	player = get_tree().current_scene.get_node_or_null("Player")

	# fire timer
	var t := Timer.new()
	t.wait_time = fire_interval
	t.one_shot = false
	t.autostart = true
	add_child(t)
	t.timeout.connect(_fire)

func _process(delta: float) -> void:
	if player == null:
		player = get_tree().current_scene.get_node_or_null("Player")
		if player == null:
			return

	_aim_at_player()

func _aim_at_player() -> void:
	var to_target: Vector3 = player.global_position - turret.global_position
	to_target.y = 0.0
	if to_target.length() < 0.001:
		return
	turret.look_at(turret.global_position + to_target, Vector3.UP)

func _fire() -> void:
	if player == null or bullet_scene == null:
		return
	if not _has_los_to_player():
		return
	var bullet := bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)

	var dir: Vector3 = -turret.global_transform.basis.z.normalized()
	bullet.global_transform = muzzle.global_transform
	bullet.global_position = muzzle.global_position + dir * spawn_forward_offset

# Make bullets hit Tanks (layer 1) + World (layer 3) => mask = 1 + 4 = 5
	if bullet is CollisionObject3D:
		bullet.set_collision_layer_value(2, true)   # bullet layer = 2
		bullet.set_collision_mask_value(1, true)    # collide with tanks (layer 1)
		bullet.set_collision_mask_value(3, true)    # collide with world (layer 3)
	bullet.velocity = dir * bullet_speed

func apply_damage(amount: int = 1) -> void:
	health -= amount
	if health <= 0:
		queue_free()
