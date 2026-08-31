extends Node3D
class_name WaveManager

## WaveManager — standalone wave-based enemy spawner.
##
## Manages the entire wave lifecycle: wave state machine, enemy count scaling,
## spawn timers, enemy object pooling, and speed multiplier forwarding.
##
## Signals:
##   wave_started(wave_number)  — emitted when a new wave begins
##   wave_completed(wave_number) — emitted when all enemies in a wave have spawned

# ─── Enemy Models ───────────────────────────────────────────────────────────────
# Preloaded once — not load()'d per spawn
var enemy_models: Array[PackedScene] = [
	preload("res://assets/Models/GLB format/enemy-ufo-a.glb"),
	preload("res://assets/Models/GLB format/enemy-ufo-b.glb"),
	preload("res://assets/Models/GLB format/enemy-ufo-c.glb"),
	preload("res://assets/Models/GLB format/enemy-ufo-d.glb"),
]

var enemy_script = preload("res://scripts/Enemy.gd")

# ─── Movement ───────────────────────────────────────────────────────────────────
@export var enemy_speed: float = 1.5     # Tiles per second
@export var pool_size: int = 120         # Pre-allocated enemy count (expanded for 3x enemy multiplier)

static var instance = null

# ─── Statistics Tracking ───────────────────────────────────────────────────────
var total_enemies_defeated: int = 0
var total_enemies_spawned: int = 0
var waves_cleared: int = 0
var is_game_over: bool = false

# ─── Wave Configuration ────────────────────────────────────────────────────────
@export var base_enemy_count_min: int = 9
@export var base_enemy_count_max: int = 15
@export var enemies_increase_per_wave_min: int = 3
@export var enemies_increase_per_wave_max: int = 6
@export var wave_delay_min: float = 3.0
@export var wave_delay_max: float = 8.0
@export var spawn_delay_min: float = 0.2
@export var spawn_delay_max: float = 1.5

# ─── Signals ────────────────────────────────────────────────────────────────────
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)

# ─── Wave State Machine ────────────────────────────────────────────────────────
enum WaveState { WAITING_FOR_FIRST_WAVE, SPAWNING, WAVE_PAUSE, STOPPED }
var _state: int = WaveState.WAITING_FOR_FIRST_WAVE
var current_wave: int = 0
var _enemies_to_spawn: int = 0
var _enemies_spawned: int = 0

# ─── Timers ─────────────────────────────────────────────────────────────────────
var _spawn_timer: float = 0.0
var _wave_pause_timer: float = 0.0
var _first_wave_delay: float = 3.0  # Short delay before wave 1 starts

# ─── Path & Readiness ──────────────────────────────────────────────────────────
var _waypoints: Array[Vector3] = []
var _ready_to_spawn: bool = false

# ─── Speed Multiplier (set by SpeedToggle) ──────────────────────────────────────
var _speed_multiplier: float = 1.0

# ─── Object Pool ────────────────────────────────────────────────────────────────
# Avoids allocation hitches during waves
var _pool: Array[Node3D] = []
var _active_enemies: Array[Node3D] = []

func _enter_tree() -> void:
	instance = self

func _ready() -> void:
	instance = self



# ═══════════════════════════════════════════════════════════════════════════════
#  PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════

## Call once after adding this node to the tree.
## Converts grid coordinates to world-space waypoints and builds the enemy pool.
func setup(path: Array[Vector2i]) -> void:
	# Convert grid coordinates to world-space Vector3 waypoints
	for grid_pos in path:
		_waypoints.append(Vector3(grid_pos.x * 1.0, 0.5, grid_pos.y * 1.0))

	_build_pool()
	_ready_to_spawn = true
	_state = WaveState.WAITING_FOR_FIRST_WAVE
	_wave_pause_timer = _first_wave_delay

func trigger_first_wave_if_waiting() -> void:
	if _state == WaveState.WAITING_FOR_FIRST_WAVE:
		_wave_pause_timer = 0.5


## Applies the speed multiplier to all currently active enemies and stores
## it for future spawns.
func set_speed_multiplier(multiplier: float) -> void:
	_speed_multiplier = multiplier
	for enemy in _active_enemies:
		if is_instance_valid(enemy) and enemy.has_method("set_speed_multiplier"):
			enemy.set_speed_multiplier(_speed_multiplier)


# ═══════════════════════════════════════════════════════════════════════════════
#  WAVE STATE MACHINE
# ═══════════════════════════════════════════════════════════════════════════════

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
					_wave_pause_timer = max(3.0, 8.0 - current_wave * 0.3)
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

	# Calculate enemy count (tripled x3 per wave): base + scaling + random variance, capped at 120
	var base_count = randi_range(4, 6)
	var wave_bonus = floor(current_wave * 1.5)
	var variance = randi_range(0, max(1, int(current_wave / 3.0)))
	var base_enemies = base_count + wave_bonus + variance
	_enemies_to_spawn = int(min(base_enemies * 3, 120))

	_state = WaveState.SPAWNING
	# First enemy spawns immediately (or with tiny delay)
	_spawn_timer = 0.0

	# Pass enemy count in the signal if needed (WaveUI might not take it, but it's safe)
	wave_started.emit(current_wave)
	print("Wave %d started! Enemies: %d (3x Multiplier)" % [current_wave, _enemies_to_spawn])

func _pick_enemy_type_for_wave() -> int:
	var roll = randf()
	if current_wave <= 2:
		return 0 if roll < 0.8 else 1
	elif current_wave <= 5:
		return 0 if roll < 0.5 else (1 if roll < 0.9 else 2)
	elif current_wave <= 8:
		return 0 if roll < 0.3 else (1 if roll < 0.6 else (2 if roll < 0.9 else 3))
	else:
		return 0 if roll < 0.2 else (1 if roll < 0.4 else (2 if roll < 0.7 else 3))


# ═══════════════════════════════════════════════════════════════════════════════
#  ENEMY POOL & SPAWNING
# ═══════════════════════════════════════════════════════════════════════════════

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
	_set_extra_cull_margin_recursive(model_instance, 2.0)
	enemy_root.add_child(model_instance)

	# Parent to the Map node
	get_parent().add_child(enemy_root)

	# Set enemy type stats (coin_value, max_hp) based on model type
	enemy_root.setup_enemy_type(type_index)

	# Connect signals
	enemy_root.reached_end.connect(_on_enemy_reached_end.bind(enemy_root))
	enemy_root.enemy_defeated.connect(_on_enemy_defeated)

	return enemy_root

func _on_enemy_defeated() -> void:
	total_enemies_defeated += 1

func _spawn_enemy() -> void:
	var enemy: Node3D = null
	var chosen_type = _pick_enemy_type_for_wave()
	
	# Try to find an enemy of the chosen type in the pool
	for i in range(_pool.size()):
		if _pool[i].enemy_type_index == chosen_type:
			enemy = _pool[i]
			_pool.remove_at(i)
			break

	if enemy == null:
		if not _pool.is_empty():
			# Just grab any if the exact type isn't available to avoid allocations if possible
			# But for true scaling, we might want to just allocate one. Let's just allocate
			enemy = _create_enemy_node(chosen_type)
		else:
			push_warning("WaveManager: enemy pool exhausted, creating new instance. Consider increasing pool_size.")
			enemy = _create_enemy_node(chosen_type)

	# Re-apply enemy type stats with wave scaling
	enemy.setup_enemy_type(enemy.enemy_type_index, current_wave)
	
	total_enemies_spawned += 1
	var wave_speed = enemy_speed * (1.0 + current_wave * 0.03)
	enemy.reset(_waypoints, wave_speed)
	if enemy.has_method("set_speed_multiplier"):
		enemy.set_speed_multiplier(_speed_multiplier)
	_active_enemies.append(enemy)

func _on_enemy_reached_end(enemy: Node3D) -> void:
	# Return the enemy to the pool for reuse
	_active_enemies.erase(enemy)
	_pool.append(enemy)

## Stop spawning new waves (used on game over or victory)
func stop_spawning() -> void:
	_ready_to_spawn = false
	_state = WaveState.STOPPED
	set_physics_process(false)

## Destroys all currently active enemies in expanding shockwave cascade
func wipe_all_active_enemies(pillar_world_pos: Vector3) -> void:
	stop_spawning()
	var active_copy = _active_enemies.duplicate()
	for enemy in active_copy:
		if is_instance_valid(enemy) and enemy.visible and enemy.has_method("destroy_by_shockwave"):
			var dist = enemy.global_position.distance_to(pillar_world_pos)
			var delay = clamp(dist * 0.035, 0.05, 0.75)
			enemy.destroy_by_shockwave(delay)

## Retrieves summary game stats for victory and defeat screens
func get_game_stats() -> Dictionary:
	var cur = 0
	if CurrencyManager.instance:
		cur = CurrencyManager.instance.current_currency
	return {
		"waves_cleared": waves_cleared,
		"current_wave": current_wave,
		"enemies_defeated": total_enemies_defeated,
		"currency": cur
	}


# ═══════════════════════════════════════════════════════════════════════════════
#  UTILITIES
# ═══════════════════════════════════════════════════════════════════════════════


func _set_extra_cull_margin_recursive(node: Node, margin: float) -> void:
	if node is GeometryInstance3D:
		node.extra_cull_margin = margin
	for child in node.get_children():
		_set_extra_cull_margin_recursive(child, margin)
