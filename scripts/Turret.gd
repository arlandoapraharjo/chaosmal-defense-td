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

@export_enum("turret", "cannon", "ballista", "catapult") var weapon_type: String = "turret"
@export_range(1.0, 50.0, 0.5) var projectile_speed: float = 12.0

# Ammo scenes — preloaded once at parse time, not load()'d per shot
var _ammo_scenes: Dictionary = {}
static var _ammo_cache: Dictionary = {}

func _init() -> void:
	if _ammo_cache.is_empty():
		var paths = {
			"turret": "res://assets/Models/GLB format/weapon-ammo-bullet.glb",
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

func _ready() -> void:
	_base_cooldown = cooldown
	_base_attack_damage = attack_damage
	_auto_detect_weapon_type()
	call_deferred("_capture_initial_facing")

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
	var path_or_name = scene_file_path.to_lower() if scene_file_path != "" else name.to_lower()
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

	var enemies = EnemyDetector.get_enemies_in_range(self, global_transform.origin, attack_range, min_attack_range)
	if is_half_circle:
		var valid_enemies: Array[Node3D] = []
		for enemy in enemies:
			var dir = (enemy.global_transform.origin - global_transform.origin)
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
	var target_pos = target.global_transform.origin
	var my_pos = global_transform.origin
	# Flatten to horizontal plane
	var dir = Vector3(target_pos.x - my_pos.x, 0.0, target_pos.z - my_pos.z)
	if dir.length_squared() < 0.0001:
		return
	var current_scale = scale
	# Extract pure rotation (no scale) for a clean slerp
	var current_rot = global_transform.basis.orthonormalized()
	var target_rot = Basis.looking_at(dir.normalized(), Vector3.UP, true)
	# Slerp at rotation_speed degrees per second
	var t = clampf(deg_to_rad(rotation_speed) * delta, 0.0, 1.0)
	var new_rot = current_rot.slerp(target_rot, t)
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
	var tween = create_tween()
	var original_scale = scale
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
		
	var level_cooldown = _base_cooldown * (1.0 - (turret_level - 1) * 0.1)
	cooldown = level_cooldown / max(current_multiplier, 0.1)


func _trigger_single_target_attack(target: Node3D) -> void:
	if is_instance_valid(target):
		_spawn_ammo_projectile(target.global_transform.origin, target)
	print("Turret (%s) fired at %s" % [weapon_type, target.name if is_instance_valid(target) else "target"])

func _trigger_aoe_attack(targets: Array) -> void:
	if not targets.is_empty() and is_instance_valid(targets[0]):
		_spawn_ammo_projectile(targets[0].global_transform.origin, null, targets)
	print("Turret (%s AoE) fired, affecting %d enemies" % [weapon_type, targets.size()])

func _get_ammo_scene(type_name: String) -> PackedScene:
	return _ammo_scenes.get(type_name, _ammo_scenes.get("turret", null))

func _spawn_ammo_projectile(target_pos: Vector3, target_enemy: Node3D = null, aoe_enemies: Array = []) -> void:
	var ammo_scene = _get_ammo_scene(weapon_type)
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
	
	var distance = spawn_pos.distance_to(target_pos)
	var flight_time = clampf(distance / projectile_speed, 0.1, 2.0)
	
	if distance > 0.01:
		ammo_instance.look_at(target_pos, Vector3.UP)
		# Fix ballista arrow model facing backwards — rotate 180° on Y axis
		if weapon_type == "ballista":
			ammo_instance.rotate_y(deg_to_rad(180.0))

	var tween = create_tween()
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
		if is_instance_valid(target_enemy) and target_enemy.has_method("take_damage"):
			target_enemy.take_damage(attack_damage)
		elif not aoe_enemies.is_empty():
			for enemy in aoe_enemies:
				if is_instance_valid(enemy) and enemy.has_method("take_damage"):
					enemy.take_damage(attack_damage)

		if is_instance_valid(ammo_instance):
			ammo_instance.queue_free()
	)

func reset_cooldown() -> void:
	_cooldown_timer = 0.0
