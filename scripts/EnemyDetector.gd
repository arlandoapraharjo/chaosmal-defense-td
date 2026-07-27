extends Node

# Utility class for detecting enemies within a radius without using physics overlap.
# Provides a static method to query active Enemy nodes in the scene tree.
# Pass any in-scene Node as `caller` so get_tree() can be resolved at runtime.

class_name EnemyDetector

static func get_enemies_in_range(caller: Node, origin: Vector3, max_range: float, min_range: float = 0.0) -> Array[Node3D]:
	var result: Array[Node3D] = []
	var max_range_sq: float = max_range * max_range
	var min_range_sq: float = min_range * min_range
	var root = caller.get_tree().root
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node = stack.pop_back()
		if node is Node3D:
			# Identify enemy nodes by checking their script path contains "Enemy".
			var script = node.get_script()
			if script != null and "Enemy" in script.get_path():
				var distance_sq = origin.distance_squared_to(node.global_transform.origin)
				if distance_sq <= max_range_sq and distance_sq >= min_range_sq:
					result.append(node as Node3D)
		# Traverse children.
		for child in node.get_children():
			stack.append(child)
	return result
