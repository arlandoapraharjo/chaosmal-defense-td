extends Node

# Utility class for detecting enemies within a radius without using physics overlap.
# Uses a static registry so turrets only iterate over active enemies (~30 max)
# instead of walking the entire scene tree every frame.

class_name EnemyDetector

# --- Static enemy registry ------------------------------------------------
# Enemies call register()/unregister() on reset/deactivate. This keeps
# the active list at ~pool_size entries instead of scanning every Node in
# the tree (which was O(total_scene_nodes) per turret per frame).

static var _active_enemies: Array[Node3D] = []

static func register(enemy: Node3D) -> void:
	if enemy not in _active_enemies:
		_active_enemies.append(enemy)

static func unregister(enemy: Node3D) -> void:
	var idx = _active_enemies.find(enemy)
	if idx >= 0:
		# Swap-remove for O(1) — order doesn't matter
		var last = _active_enemies.size() - 1
		if idx != last:
			_active_enemies[idx] = _active_enemies[last]
		_active_enemies.resize(last)

static func get_enemies_in_range(caller: Node, origin: Vector3, max_range: float, min_range: float = 0.0) -> Array[Node3D]:
	var result: Array[Node3D] = []
	var max_range_sq: float = max_range * max_range
	var min_range_sq: float = min_range * min_range
	for enemy in _active_enemies:
		if not is_instance_valid(enemy):
			continue
		# Skip dead/deactivated enemies (invisible or _is_done)
		if not enemy.visible:
			continue
		if enemy.get("_is_done") == true:
			continue
		var distance_sq = origin.distance_squared_to(enemy.global_transform.origin)
		if distance_sq <= max_range_sq and distance_sq >= min_range_sq:
			result.append(enemy as Node3D)
	return result
