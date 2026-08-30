extends Node3D
# Speed in tiles per second
@export var speed: float = 0.65
## Rotations per second for the UFO spin animation
@export var spin_speed: float = 0.25

var explosion_scene: PackedScene = preload("res://scenes/explosion.tscn")

var path_waypoints: Array[Vector3] = []
var current_waypoint_index: int = 0
var _is_done: bool = false
var _spin_angle: float = 0.0
var _visual_node: Node3D = null
## Base speed set at reset time — speed multiplier is applied on top of this
var _base_speed: float = 0.65
var _speed_multiplier: float = 1.0
## How quickly the UFO turns to face the next waypoint (higher = snappier)
@export var turn_smoothing: float = 8.0
signal reached_end
signal enemy_defeated

@export var max_hp: float = 100.0
var current_hp: float = 100.0

## Coin reward when this enemy is defeated — set by setup_enemy_type()
var coin_value: int = 1
## Index of the UFO model type (0-3), used to assign stats
var enemy_type_index: int = 0

# Stats per UFO type: [coin_value, max_hp]
const ENEMY_TYPE_STATS: Array = [
	[2, 80.0],    # UFO-A: cheap, fragile
	[4, 120.0],   # UFO-B: moderate
	[7, 180.0],   # UFO-C: tough
	[10, 260.0],  # UFO-D: elite, tanky
]

# Damage dealt to the Incursion Pillar on suicide impact per UFO type
const ENEMY_TYPE_DAMAGE: Array[float] = [10.0, 15.0, 20.0, 25.0]

func get_contact_damage() -> float:
	if enemy_type_index >= 0 and enemy_type_index < ENEMY_TYPE_DAMAGE.size():
		return ENEMY_TYPE_DAMAGE[enemy_type_index]
	return 10.0

## Assign coin_value and max_hp based on the UFO model type index and wave number.
func setup_enemy_type(type_index: int, wave_number: int = 1) -> void:
	enemy_type_index = type_index
	
	var base_coins = 1
	var base_hp = 100.0
	
	if type_index >= 0 and type_index < ENEMY_TYPE_STATS.size():
		base_coins = ENEMY_TYPE_STATS[type_index][0]
		base_hp = ENEMY_TYPE_STATS[type_index][1]
		
	# Apply wave scaling
	# HP scales +15% per wave
	max_hp = base_hp * (1.0 + (wave_number - 1) * 0.15)
	
	# Coins scale slower: base + 1 coin every 3 waves
	coin_value = base_coins + int(wave_number / 3.0)
	
	current_hp = max_hp

func setup(waypoints: Array[Vector3]) -> void:
	path_waypoints = waypoints
	current_waypoint_index = 0
	_is_done = false
	current_hp = max_hp
	_cache_visual_node()

## Cache the first child node to apply the spin rotation to,
## so we don't interfere with the parent's path-following orientation.
func _cache_visual_node() -> void:
	if _visual_node != null:
		return
	for child in get_children():
		if child is Node3D:
			_visual_node = child
			break

## Apply a global speed multiplier (1.0 = normal, 2.0 = double, 4.0 = quad).
func set_speed_multiplier(multiplier: float) -> void:
	_speed_multiplier = multiplier
	speed = _base_speed * _speed_multiplier

## Re-initialize this enemy for reuse from the pool.
## Places it at the first waypoint and makes it visible/active.
func reset(waypoints: Array[Vector3], new_speed: float) -> void:
	path_waypoints = waypoints
	current_waypoint_index = 0
	_is_done = false
	current_hp = max_hp
	_base_speed = new_speed
	speed = _base_speed * _speed_multiplier
	visible = true
	set_physics_process(true)
	EnemyDetector.register(self)
	
	# Pop-up animation
	scale = Vector3(0.001, 0.001, 0.001)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	if not waypoints.is_empty():
		position = waypoints[0]
		if waypoints.size() > 1:
			var dir = waypoints[1] - waypoints[0]
			var look_dir = Vector3(dir.x, 0, dir.z)
			if look_dir.length() > 0.001:
				rotation.y = atan2(look_dir.x, look_dir.z)
	_cache_visual_node()
	_spin_angle = 0.0

## Hide and stop processing — the Spawner will reclaim this node.
func deactivate() -> void:
	_is_done = true
	EnemyDetector.unregister(self)
	visible = false
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	if _is_done or path_waypoints.is_empty():
		return

	# UFO spin animation — counter-rotate by parent heading so the spin
	# stays fixed in world space regardless of the enemy's travel direction
	if _visual_node:
		_spin_angle += spin_speed * TAU * delta
		_visual_node.rotation.y = _spin_angle - rotation.y

	if current_waypoint_index >= path_waypoints.size():
		_hit_pillar_and_explode()
		return

	# How far this enemy is allowed to travel this tick. Any distance left
	# over after reaching a waypoint gets spent on the NEXT waypoint in the
	# same tick, rather than being allowed to overshoot past the current
	# one — that overshoot is what was letting enemies keep travelling in
	# their old direction straight through corner tiles instead of turning.
	var remaining_move = speed * delta

	while remaining_move > 0.0 and current_waypoint_index < path_waypoints.size():
		var target = path_waypoints[current_waypoint_index]
		var to_target = target - position
		var dist = to_target.length()

		if dist <= remaining_move:
			# Snap exactly onto the waypoint (never past it), spend only
			# the distance it actually took to get there, and move on.
			position = target
			remaining_move -= dist
			current_waypoint_index += 1

			if current_waypoint_index < path_waypoints.size():
				var next_target = path_waypoints[current_waypoint_index]
				var look_dir = Vector3(next_target.x - position.x, 0, next_target.z - position.z)
				if look_dir.length() > 0.001:
					var target_angle = atan2(look_dir.x, look_dir.z)
					rotation.y = lerp_angle(rotation.y, target_angle, turn_smoothing * delta)
		else:
			var dir = to_target / dist # already-normalized direction, reusing the length we computed
			position += dir * remaining_move

			var look_dir = Vector3(dir.x, 0, dir.z)
			if look_dir.length() > 0.001:
				var target_angle = atan2(look_dir.x, look_dir.z)
				rotation.y = lerp_angle(rotation.y, target_angle, turn_smoothing * delta)

			remaining_move = 0.0

	if current_waypoint_index >= path_waypoints.size():
		_hit_pillar_and_explode()

func _spawn_explosion() -> void:
	var explosion = explosion_scene.instantiate()
	var scene_root = get_tree().current_scene
	if scene_root:
		scene_root.add_child(explosion)
	else:
		get_parent().add_child(explosion)
	explosion.global_position = global_position
	for child in explosion.get_children():
		if child is GPUParticles3D:
			child.emitting = true
	get_tree().create_timer(2.0).timeout.connect(explosion.queue_free)

func _hit_pillar_and_explode() -> void:
	if _is_done:
		return
	_is_done = true
	_spawn_explosion()
	
	# Find pillar in scene and apply suicide attack damage
	var pillar = get_tree().get_first_node_in_group("pillar")
	if not pillar:
		var scene_root = get_tree().current_scene
		if scene_root:
			pillar = scene_root.find_child("IncursionPillar", true, false)
	if pillar and pillar.has_method("take_damage"):
		pillar.take_damage(get_contact_damage())
		
	reached_end.emit()
	deactivate()

func destroy_by_shockwave(delay: float = 0.0) -> void:
	if _is_done or not visible:
		return
	if delay > 0.0:
		get_tree().create_timer(delay).timeout.connect(_on_shockwave_explode)
	else:
		_on_shockwave_explode()

func _on_shockwave_explode() -> void:
	if _is_done or not is_inside_tree() or not visible:
		return
	_is_done = true
	_spawn_explosion()
	enemy_defeated.emit()
	reached_end.emit()
	deactivate()

func take_damage(amount: float) -> void:
	if _is_done:
		return
	current_hp -= amount
	if current_hp <= 0:
		current_hp = 0
		_is_done = true
		_spawn_explosion()
		
		enemy_defeated.emit()
		if CurrencyManager.instance:
			CurrencyManager.instance.add_currency(coin_value)
		reached_end.emit()
		deactivate()

