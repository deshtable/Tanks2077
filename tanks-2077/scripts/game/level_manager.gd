extends Node

@export var levels: Array[PackedScene] = []
@export var player_scene: PackedScene
@export var sentry_scene: PackedScene

@onready var level_root: Node = $"../LevelRoot"

var current_index := 0
var current_level: Node = null
var player: Node = null

var transitioning := false
var player_dead := false

# Robust enemy tracking
var enemies_tracked: Dictionary = {} # key: instance_id -> true
var enemy_count := 0

func _ready() -> void:
	if levels.is_empty():
		push_error("LevelManager: No levels assigned!")
		return
	call_deferred("_load_level", 0)

func restart_level() -> void:
	if transitioning:
		return
	print("LevelManager: RESTART requested")
	transitioning = true
	player_dead = true
	call_deferred("_load_level", current_index)

func next_level() -> void:
	if transitioning:
		return
	print("LevelManager: NEXT LEVEL requested")
	transitioning = true
	player_dead = false
	var next := current_index + 1
	if next < levels.size():
		call_deferred("_load_level", next)
	else:
		print("All levels complete!")

func _load_level(index: int) -> void:
	current_index = index
	player = null
	current_level = null

	# reset enemy tracking
	enemies_tracked.clear()
	enemy_count = 0

	# Clear LevelRoot
	for c in level_root.get_children():
		c.queue_free()

	# wait one frame so frees process
	await get_tree().process_frame

	# Instance new level
	current_level = levels[current_index].instantiate()
	level_root.add_child(current_level)

	_spawn_player()
	_spawn_enemies()

	# unlock transitions after setup
	player_dead = false
	transitioning = false
	print("LevelManager: Loaded level", current_index + 1, " enemy_count=", enemy_count)

func _spawn_player() -> void:
	if player_scene == null:
		push_error("LevelManager: player_scene not assigned!")
		return

	var spawn := current_level.find_child("PlayerSpawn", true, false) as Marker3D
	if spawn == null:
		push_error("LevelManager: PlayerSpawn missing in level.")
		return

	player = player_scene.instantiate()
	level_root.add_child(player)
	player.global_transform = spawn.global_transform

	# died signal restart
	if player.has_signal("died"):
		player.died.connect(func():
			print("LevelManager: got player.died")
			restart_level()
		)

	# IMPORTANT: remove the tree_exited fallback (it fires during cleanup)
	# If you want it later, only use it when NOT transitioning.

func _spawn_enemies() -> void:
	if sentry_scene == null:
		push_error("LevelManager: sentry_scene not assigned!")
		return

	var spawns := current_level.find_child("EnemySpawns", true, false)
	if spawns == null:
		print("LevelManager: No EnemySpawns in this level.")
		return

	for child in spawns.get_children():
		if child is Marker3D:
			var e := sentry_scene.instantiate()
			level_root.add_child(e)
			e.global_transform = (child as Marker3D).global_transform

			_track_enemy(e)

func _track_enemy(e: Node) -> void:
	var id := e.get_instance_id()
	if enemies_tracked.has(id):
		return # already tracked, avoid double decrement

	enemies_tracked[id] = true
	enemy_count += 1

	# decrement exactly once
	e.tree_exited.connect(func():
		_on_enemy_exited(id)
	)

func _on_enemy_exited(id: int) -> void:
	if not enemies_tracked.has(id):
		return # already processed
	enemies_tracked.erase(id)
	enemy_count -= 1
	print("Enemy died. Remaining:", enemy_count)
	_check_level_complete()

func _check_level_complete() -> void:
	if transitioning or player_dead:
		return
	if not is_instance_valid(player):
		return

	if enemy_count <= 0:
		next_level()
