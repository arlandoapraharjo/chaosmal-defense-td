extends Node3D

# Turret base class handling targeting, attack types, cooldowns, and animated 3D ammo projectiles.

# Exported configurable properties
@export_range(0.0, 20.0, 0.1) var attack_range: float = 1.5
@export_range(0.0, 20.0, 0.1) var min_attack_range: float = 0.0
@export var is_aoe: bool = false
@export var is_half_circle: bool = false
@export_range(0.1, 10.0, 0.1) var cooldown: float = 1.0
# How fast (deg/sec) the turret rotates to face its target
@export_range(10.0, 720.0, 5.0) var rotation_speed: float = 180.0

@export_enum("turret", "cannon", "ballista", "catapult", "heavy_turret") var weapon_type: String = "turret"
@export_range(1.0, 50.0, 0.5) var projectile_speed: float = 12.0
# Splash damage radius around the impact point (only used when is_aoe = true)
@export_range(0.5, 10.0, 0.1) var aoe_radius: float = 2.0

# Ammo scenes — preloaded once at parse time, not load()'d per shot
var _ammo_scenes: Dictionary = {}
static var _ammo_cache: Dictionary = {}

func _init() -> void:
	if _ammo_cache.is_empty():
		var paths: Dictionary = {
			"turret": "res://assets/Models/GLB format/weapon-ammo-bullet.glb",
			"heavy_turret": "res://assets/Models/GLB format/weapon-ammo-bullet.glb",
			"cannon": "res://assets/Models/GLB format/weapon-ammo-cannonball.glb",
			"ballista": "res://assets/Models/GLB format/weapon-ammo-arrow.glb",
			"catapult": "res://assets/Models/GLB format/weapon-ammo-boulder.glb"
		}
		for key in paths:
			if ResourceLoader.exists(paths[key]):
				_ammo_cache[key] = load(paths[key])
			else:
				# Try desert variant path
				var desert_path = paths[key].replace("GLB format/", "GLB format/desert/")
				if ResourceLoader.exists(desert_path):
					_ammo_cache[key] = load(desert_path)
	_ammo_scenes = _ammo_cache

# Internal timer
var _cooldown_timer: float = 0.0
# Base cooldown — speed multiplier divides this to fire faster
var _base_cooldown: float = 1.0
# Current locked target for rotation tracking
var _current_target: Node3D = null
# Initial forward direction upon placement (for 180-degree half-circle restriction)
var _initial_facing_dir: Vector3 = Vector3.FORWARD
# Catapult arm node for swing animation
var _catapult_arm: Node3D = null
var _catapult_swing_tween: Tween = null
# Recoil animation state
var _recoil_tween: Tween = null

func _ready() -> void:
	_base_cooldown = cooldown
	_base_attack_damage = attack_damage
	_auto_detect_weapon_type()
	call_deferred("_capture_initial_facing")
	call_deferred("_find_catapult_arm")

## Apply a global speed multiplier — faster speed = shorter cooldown = higher fire rate.
func set_speed_multiplier(multiplier: float) -> void:
	var level_cooldown = _base_cooldown * (1.0 - (turret_level - 1) * 0.1)
	cooldown = level_cooldown / max(multiplier, 0.1)

func _capture_initial_facing() -> void:
	_initial_facing_dir = -global_transform.basis.z.normalized()
	_initial_facing_dir.y = 0.0
	if _initial_facing_dir.length_squared() > 0.001:
		_initial_facing_dir = _initial_facing_dir.normalized()
	else:
		_initial_facing_dir = Vector3.FORWARD

func _auto_detect_weapon_type() -> void:
	if weapon_type == "heavy_turret":
		return
	var path_or_name: String = scene_file_path.to_lower() if scene_file_path != "" else name.to_lower()
	if path_or_name.find("cannon") != -1:
		weapon_type = "cannon"
		is_half_circle = true
	elif path_or_name.find("ballista") != -1:
		weapon_type = "ballista"
	elif path_or_name.find("catapult") != -1:
		weapon_type = "catapult"
		is_aoe = true
		if min_attack_range <= 0.0:
			min_attack_range = 3.0
	elif path_or_name.find("turret") != -1:
		weapon_type = "turret"

func _process(delta: float) -> void:
	# --- Clear target if it's dead/deactivated ---
	if _current_target != null:
		if not is_instance_valid(_current_target) or not _current_target.visible or _current_target.get("_is_done") == true:
			_current_target = null

	# --- Continuous rotation toward locked target ---
	if is_instance_valid(_current_target):
		_rotate_toward_target(_current_target, delta)

	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta
		return

	var enemies: Array[Node3D] = EnemyDetector.get_enemies_in_range(self, global_transform.origin, attack_range, min_attack_range)
	if is_half_circle:
		var valid_enemies: Array[Node3D] = []
		for enemy in enemies:
			var dir: Vector3 = (enemy.global_transform.origin - global_transform.origin)
			dir.y = 0.0
			if dir.length_squared() > 0.0001 and dir.normalized().dot(_initial_facing_dir) >= -0.05:
				valid_enemies.append(enemy)
		enemies = valid_enemies

	if enemies.is_empty():
		_current_target = null
		return

	_current_target = enemies[0]

	if is_aoe:
		_trigger_aoe_attack(enemies)
	else:
		_trigger_single_target_attack(_current_target)

	_cooldown_timer = cooldown

# Smoothly rotate the turret (Y-axis only) to face the target.
func _rotate_toward_target(target: Node3D, delta: float) -> void:
	var target_pos: Vector3 = target.global_transform.origin
	var my_pos: Vector3 = global_transform.origin
	# Flatten to horizontal plane
	var dir: Vector3 = Vector3(target_pos.x - my_pos.x, 0.0, target_pos.z - my_pos.z)
	if dir.length_squared() < 0.0001:
		return
	var current_scale: Vector3 = scale
	# Extract pure rotation (no scale) for a clean slerp
	var current_rot: Basis = global_transform.basis.orthonormalized()
	var target_rot: Basis = Basis.looking_at(dir.normalized(), Vector3.UP, true)
	# Slerp at rotation_speed degrees per second
	var t: float = clampf(deg_to_rad(rotation_speed) * delta, 0.0, 1.0)
	var new_rot: Basis = current_rot.slerp(target_rot, t)
	# Reapply scale after rotation
	global_transform.basis = new_rot.scaled(current_scale)

var attack_damage: float = 35.0
var _base_attack_damage: float = 35.0
var turret_level: int = 1

func get_upgrade_cost() -> int:
	if turret_level >= 3:
		return 0
	if TurretUpgradeManager.instance:
		return TurretUpgradeManager.instance.UPGRADE_COSTS[turret_level - 1]
	return 0

func upgrade() -> bool:
	if turret_level >= 3:
		return false
	turret_level += 1
	_recalculate_stats()
	
	# Visual feedback for upgrade
	var tween: Tween = create_tween()
	var original_scale: Vector3 = scale
	tween.tween_property(self, "scale", original_scale * 1.2, 0.15).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale", original_scale, 0.25)
	
	return true

func _recalculate_stats() -> void:
	attack_damage = _base_attack_damage * (1.0 + (turret_level - 1) * 0.4)
	
	# Current global speed multiplier
	var current_multiplier = 1.0
	var speed_toggle = get_node_or_null("/root/World/SpeedToggle")
	if speed_toggle and speed_toggle.has_method("get_current_multiplier"):
		current_multiplier = speed_toggle.get_current_multiplier()
		
	var level_cooldown: float = _base_cooldown * (1.0 - (turret_level - 1) * 0.1)
	cooldown = level_cooldown / max(current_multiplier, 0.1)


func _trigger_single_target_attack(target: Node3D) -> void:
	if is_instance_valid(target):
		_spawn_ammo_projectile(target.global_transform.origin, target)
		# Recoil for non-catapult weapons (pushed backward away from target)
		if weapon_type != "catapult":
			_play_recoil(target.global_transform.origin)
	print("Turret (%s) fired at %s" % [weapon_type, target.name if is_instance_valid(target) else "target"])

func _trigger_aoe_attack(targets: Array[Node3D]) -> void:
	if not targets.is_empty() and is_instance_valid(targets[0]):
		if weapon_type == "catapult":
			_play_catapult_swing(targets[0].global_transform.origin, null, targets)
		else:
			_spawn_ammo_projectile(targets[0].global_transform.origin, null, targets)
			_play_recoil(targets[0].global_transform.origin)
	print("Turret (%s AoE) fired, affecting %d enemies" % [weapon_type, targets.size()])

var _hit_particle_scenes: Dictionary = {
	"turret": preload("res://scenes/hit_particle.tscn"),
	"cannon": preload("res://scenes/hit_particle.tscn"),
	"heavy_turret": preload("res://scenes/hit_particle_cannon.tscn"),
	"ballista": preload("res://scenes/hit_particle_ballista.tscn"),
	"catapult": preload("res://scenes/boulder_impact.tscn")
}

func _get_ammo_scene(type_name: String) -> PackedScene:
	return _ammo_scenes.get(type_name, _ammo_scenes.get("turret", null))

func _spawn_hit_particle(pos: Vector3, type_name: String = "") -> void:
	var wtype = type_name if not type_name.is_empty() else weapon_type
	var hit_scene: PackedScene = _hit_particle_scenes.get(wtype, _hit_particle_scenes.get("turret", null))
	if hit_scene == null:
		return
	var hit_part = hit_scene.instantiate()
	var scene_root = get_tree().current_scene
	if scene_root:
		scene_root.add_child(hit_part)
	else:
		get_parent().add_child(hit_part)
	hit_part.global_position = pos

func _spawn_ammo_projectile(target_pos: Vector3, target_enemy: Node3D = null, aoe_enemies: Array[Node3D] = []) -> void:
	var ammo_scene: PackedScene = _get_ammo_scene(weapon_type)
	if ammo_scene == null:
		return

	var ammo_instance: Node3D = ammo_scene.instantiate()
	var spawn_pos = global_transform.origin + Vector3(0, 0.4, 0)
	
	# Add to main scene root so ammo is independent of turret rotation
	var scene_root = get_tree().current_scene
	if scene_root:
		scene_root.add_child(ammo_instance)
	else:
		get_parent().add_child(ammo_instance)

	ammo_instance.global_position = spawn_pos
	
	var distance: float = spawn_pos.distance_to(target_pos)
	var flight_time: float = clampf(distance / projectile_speed, 0.1, 2.0)
	
	if distance > 0.01:
		ammo_instance.look_at(target_pos, Vector3.UP)
		# Fix ammo models facing backwards (bullet, arrow, etc. point +Z in Kenney model assets, whereas Godot look_at uses -Z as forward)
		if weapon_type != "catapult":
			ammo_instance.rotate_y(deg_to_rad(180.0))


	var tween: Tween = create_tween()
	if weapon_type == "catapult":
		# Parabolic arc trajectory for boulder ammo
		var arc_height: float = maxf(1.0, distance * 0.5)
		tween.tween_method(func(progress: float):
			if is_instance_valid(ammo_instance):
				var current_linear = spawn_pos.lerp(target_pos, progress)
				var height_offset = Vector3.UP * sin(progress * PI) * arc_height
				ammo_instance.global_position = current_linear + height_offset
				ammo_instance.rotate_x(deg_to_rad(10.0))
		, 0.0, 1.0, flight_time)
	else:
		# Direct straight line trajectory
		tween.tween_property(ammo_instance, "global_position", target_pos, flight_time)

	tween.tween_callback(func():
		if weapon_type == "catapult":
			var ground_impact_pos = Vector3(target_pos.x, 0.0, target_pos.z)
			_spawn_hit_particle(ground_impact_pos, "catapult")
		else:
			var impact_pos = target_pos + Vector3(0, 0.3, 0)
			_spawn_hit_particle(impact_pos, weapon_type)

		if is_instance_valid(target_enemy) and target_enemy.has_method("take_damage"):
			target_enemy.take_damage(attack_damage)
		elif not aoe_enemies.is_empty():
			# Re-check enemy positions at impact time — only damage those
			# actually near the impact point, not every enemy in turret range.
			var aoe_radius_sq: float = aoe_radius * aoe_radius
			for enemy in aoe_enemies:
				if is_instance_valid(enemy) and enemy.has_method("take_damage"):
					var dist_sq: float = enemy.global_transform.origin.distance_squared_to(target_pos)
					if dist_sq <= aoe_radius_sq:
						enemy.take_damage(attack_damage)

		if is_instance_valid(ammo_instance):
			ammo_instance.queue_free()
	)

func reset_cooldown() -> void:
	_cooldown_timer = 0.0

# ── Catapult Swing Animation ────────────────────────────────────────────────────

## Locate the catapult arm child node for the swing animation.
## Searches for nodes named arm/lever/beam, then falls back to the tallest
## MeshInstance3D child, which is typically the throwing arm.
func _find_catapult_arm() -> void:
	if weapon_type != "catapult":
		return
	# Search by common arm-related name patterns
	var arm_keywords: Array[String] = ["arm", "lever", "beam", "throw", "swing", "sling"]
	for keyword in arm_keywords:
		var found: Node = _find_child_by_keyword(self, keyword)
		if found and found is Node3D:
			_catapult_arm = found as Node3D
			return
	# Fallback: use the first MeshInstance3D child (skip the base platform)
	var meshes: Array[MeshInstance3D] = []
	_collect_mesh_instances(self, meshes)
	if meshes.size() > 1:
		# Pick the mesh with the highest local Y — likely the arm
		var best: MeshInstance3D = meshes[0]
		var best_y: float = best.position.y
		for m in meshes:
			if m.position.y > best_y:
				best = m
				best_y = m.position.y
		_catapult_arm = best
	elif meshes.size() == 1:
		_catapult_arm = meshes[0]

## Recursively search for a child node whose name contains keyword (case-insensitive).
func _find_child_by_keyword(node: Node, keyword: String) -> Node:
	for child in node.get_children():
		if child.name.to_lower().find(keyword) != -1:
			return child
		var result: Node = _find_child_by_keyword(child, keyword)
		if result:
			return result
	return null

## Recursively collect all MeshInstance3D nodes.
func _collect_mesh_instances(node: Node, result: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			result.append(child)
		_collect_mesh_instances(child, result)

## Play the catapult throw animation and spawn the boulder at the peak of the swing.
## The arm winds back, swings forward fast (launching the boulder), then returns.
func _play_catapult_swing(target_pos: Vector3, target_enemy: Node3D = null, aoe_enemies: Array[Node3D] = []) -> void:
	var arm: Node3D = _catapult_arm if is_instance_valid(_catapult_arm) else self
	# Kill any existing swing so they don't stack
	if _catapult_swing_tween and _catapult_swing_tween.is_valid():
		_catapult_swing_tween.kill()

	# Store original rotation to restore after animation
	var original_rot: Vector3 = arm.rotation

	# Determine swing axis — catapult arms swing on X axis (pitch forward)
	# Wind-back: tilt arm slightly backward
	# Throw: swing arm forward past neutral to the throw angle
	# Return: ease back to original position
	var wind_back_angle: float = deg_to_rad(-15.0)  # Backward tilt
	var throw_angle: float = deg_to_rad(45.0)       # Forward throw
	var wind_back_time: float = 0.15                 # Quick wind-up
	var throw_time: float = 0.10                     # Fast throw
	var hold_time: float = 0.05                      # Brief hold at peak
	var return_time: float = 0.35                    # Slow return

	_catapult_swing_tween = create_tween()
	_catapult_swing_tween.set_ease(Tween.EASE_IN_OUT)
	_catapult_swing_tween.set_trans(Tween.TRANS_SINE)

	# Phase 1: Wind back
	_catapult_swing_tween.tween_property(arm, "rotation:x",
		original_rot.x + wind_back_angle, wind_back_time)

	# Phase 2: Fast throw forward
	_catapult_swing_tween.tween_property(arm, "rotation:x",
		original_rot.x + throw_angle, throw_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Phase 3: Spawn the boulder at the peak of the throw
	_catapult_swing_tween.tween_callback(func():
		_spawn_ammo_projectile(target_pos, target_enemy, aoe_enemies)
	)

	# Phase 4: Brief hold at peak
	_catapult_swing_tween.tween_interval(hold_time)

	# Phase 5: Slow return with a slight bounce
	_catapult_swing_tween.tween_property(arm, "rotation:x",
		original_rot.x - deg_to_rad(5.0), return_time * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_catapult_swing_tween.tween_property(arm, "rotation:x",
		original_rot.x, return_time * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# ── Recoil Animation ────────────────────────────────────────────────────────────

var _base_position: Vector3 = Vector3.ZERO
var _has_base_position: bool = false

## Push-back recoil for turret, cannon, and ballista.
## Slides the turret backward away from the target, then springs back.
func _play_recoil(target_pos: Vector3 = Vector3.ZERO) -> void:
	if not _has_base_position:
		_base_position = position
		_has_base_position = true

	if _recoil_tween and _recoil_tween.is_valid():
		_recoil_tween.kill()
		position = _base_position

	# Calculate vector pointing directly AWAY from the target (backward from firing direction)
	var dir_away: Vector3 = Vector3.ZERO
	if target_pos != Vector3.ZERO:
		dir_away = global_transform.origin - target_pos
		dir_away.y = 0.0

	if dir_away.length_squared() > 0.0001:
		dir_away = dir_away.normalized()
	else:
		# Fallback to model's reverse forward direction
		dir_away = -global_transform.basis.z.normalized()
		dir_away.y = 0.0
		if dir_away.length_squared() > 0.0001:
			dir_away = dir_away.normalized()
		else:
			dir_away = Vector3.BACK

	var recoil_strength: float = 0.10
	if weapon_type == "cannon":
		recoil_strength = 0.20
	elif weapon_type == "heavy_turret":
		recoil_strength = 0.25
	elif weapon_type == "ballista":
		recoil_strength = 0.12

	var recoil_offset_world: Vector3 = dir_away * recoil_strength
	# Convert to local space offset since we animate local position
	var parent_basis: Basis = get_parent().global_transform.basis if get_parent() else Basis.IDENTITY
	var local_offset: Vector3 = parent_basis.inverse() * recoil_offset_world

	_recoil_tween = create_tween()
	# Phase 1: Snap backward (away from target)
	_recoil_tween.tween_property(self, "position",
		_base_position + local_offset, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Phase 2: Bounce forward slightly past origin
	_recoil_tween.tween_property(self, "position",
		_base_position - local_offset * 0.2, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Phase 3: Settle cleanly back to base resting position
	_recoil_tween.tween_property(self, "position",
		_base_position, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

