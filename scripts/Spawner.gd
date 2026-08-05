extends Node3D

# Wave-based enemy spawner with random delays and increasing difficulty.

# Enemy UFO models — preloaded once, not load()'d per spawn
var enemy_models: Array[PackedScene] = [
	preload("res://assets/Models/GLB format/enemy-ufo-a.glb"),
	preload("res://assets/Models/GLB format/enemy-ufo-b.glb"),
	preload("res://assets/Models/GLB format/enemy-ufo-c.glb"),
	preload("res://assets/Models/GLB format/enemy-ufo-d.glb"),
]

var enemy_script = preload("res://scripts/Enemy.gd")

@export var enemy_speed: float = 1.5     # Tiles per second
@export var pool_size: int = 30          # Pre-allocated enemy count

# Wave configuration
@export var base_enemy_count_min: int = 3
@export var base_enemy_count_max: int = 5
@export var enemies_increase_per_wave_min: int = 1
@export var enemies_increase_per_wave_max: int = 2
@export var wave_delay_min: float = 3.0
@export var wave_delay_max: float = 8.0
@export var spawn_delay_min: float = 0.5
@export var spawn_delay_max: float = 3.0

signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)

# Wave state
enum WaveState { WAITING_FOR_FIRST_WAVE, SPAWNING, WAVE_PAUSE }
var _state: int = WaveState.WAITING_FOR_FIRST_WAVE
var current_wave: int = 0
var _enemies_to_spawn: int = 0
var _enemies_spawned: int = 0

# Timers
var _spawn_timer: float = 0.0
var _wave_pause_timer: float = 0.0
var _first_wave_delay: float = 3.0  # Short delay before wave 1 starts

var _waypoints: Array[Vector3] = []
var _ready_to_spawn: bool = false

# Speed multiplier — set by SpeedToggle
var _speed_multiplier: float = 1.0

## Applies the speed multiplier to all currently active enemies and stores
## it for future spawns.
func set_speed_multiplier(multiplier: float) -> void:
	_speed_multiplier = multiplier
	for enemy in _active_enemies:
		if is_instance_valid(enemy) and enemy.has_method("set_speed_multiplier"):
			enemy.set_speed_multiplier(_speed_multiplier)

# Object pool — avoids allocation hitches during waves
var _pool: Array[Node3D] = []
var _active_enemies: Array[Node3D] = []

func setup(path: Array[Vector2i]) -> void:
	# Convert grid coordinates to world-space Vector3 waypoints
	for grid_pos in path:
		_waypoints.append(Vector3(grid_pos.x * 1.0, 0.5, grid_pos.y * 1.0))

	_build_pool()
	_ready_to_spawn = true
	_state = WaveState.WAITING_FOR_FIRST_WAVE
	_wave_pause_timer = _first_wave_delay

func _build_pool() -> void:
	for i in range(pool_size):
		var type_index = i % enemy_models.size()
		var enemy = _create_enemy_node(type_index)
		enemy.deactivate()
		_pool.append(enemy)

func _create_enemy_node(type_index: int) -> Node3D:
	var enemy_root = Node3D.new()
	enemy_root.set_script(enemy_script)

	# Pick a specific UFO model for this enemy
	var model_scene = enemy_models[type_index]
	var model_instance = model_scene.instantiate()
	_set_extra_cull_margin_recursive(model_instance, 100.0)
	enemy_root.add_child(model_instance)

	# Parent to the Map node
	get_parent().add_child(enemy_root)

	# Set enemy type stats (coin_value, max_hp) based on model type
	enemy_root.setup_enemy_type(type_index)

	# Connect the reached_end signal so we can reclaim it
	enemy_root.reached_end.connect(_on_enemy_reached_end.bind(enemy_root))

	return enemy_root

func _physics_process(delta: float) -> void:
	if not _ready_to_spawn or _waypoints.is_empty():
		return

	match _state:
		WaveState.WAITING_FOR_FIRST_WAVE:
			_wave_pause_timer -= delta
			if _wave_pause_timer <= 0.0:
				_start_next_wave()

		WaveState.SPAWNING:
			_spawn_timer -= delta
			if _spawn_timer <= 0.0 and _enemies_spawned < _enemies_to_spawn:
				_spawn_enemy()
				_enemies_spawned += 1

				if _enemies_spawned >= _enemies_to_spawn:
					# All enemies in this wave have been spawned, start pause
					_state = WaveState.WAVE_PAUSE
					_wave_pause_timer = randf_range(wave_delay_min, wave_delay_max)
					wave_completed.emit(current_wave)
				else:
					# Random delay before the next individual spawn
					_spawn_timer = randf_range(spawn_delay_min, spawn_delay_max)

		WaveState.WAVE_PAUSE:
			_wave_pause_timer -= delta
			if _wave_pause_timer <= 0.0:
				_start_next_wave()

func _start_next_wave() -> void:
	current_wave += 1
	_enemies_spawned = 0

	# Calculate enemy count: base random + scaling per wave
	var base_count = randi_range(base_enemy_count_min, base_enemy_count_max)
	var wave_bonus = (current_wave - 1) * randi_range(enemies_increase_per_wave_min, enemies_increase_per_wave_max)
	_enemies_to_spawn = base_count + wave_bonus

	_state = WaveState.SPAWNING
	# First enemy spawns immediately (or with tiny delay)
	_spawn_timer = 0.0

	wave_started.emit(current_wave)
	print("Wave %d started! Enemies: %d" % [current_wave, _enemies_to_spawn])

func _spawn_enemy() -> void:
	var enemy: Node3D

	if not _pool.is_empty():
		enemy = _pool.pop_back()
	else:
		# Pool exhausted — grow by 1 (should be rare with a well-sized pool)
		push_warning("Spawner: enemy pool exhausted, creating new instance. Consider increasing pool_size.")
		var type_index = randi() % enemy_models.size()
		enemy = _create_enemy_node(type_index)

	# Re-apply enemy type stats on each reset (the type was set on creation)
	enemy.setup_enemy_type(enemy.enemy_type_index)
	enemy.reset(_waypoints, enemy_speed)
	if enemy.has_method("set_speed_multiplier"):
		enemy.set_speed_multiplier(_speed_multiplier)
	_active_enemies.append(enemy)

func _on_enemy_reached_end(enemy: Node3D) -> void:
	# Return the enemy to the pool for reuse
	_active_enemies.erase(enemy)
	_pool.append(enemy)

func _set_extra_cull_margin_recursive(node: Node, margin: float) -> void:
	if node is GeometryInstance3D:
		node.extra_cull_margin = margin
	for child in node.get_children():
		_set_extra_cull_margin_recursive(child, margin)
