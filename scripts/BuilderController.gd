extends Node

## Controller that handles grid-snapping turret placement on the map.

@export var map_generator: Node3D
@export var turret_y_offset: float = 0.1

var _is_building: bool = false
var _turret_scene: PackedScene = null
var _ghost_instance: Node3D = null
var _ghost_material: ShaderMaterial = null
var _range_marker_node: Node3D = null
var _attack_range: float = 0.0
var _footprint_size: Vector2i = Vector2i(1, 1)
var _min_attack_range: float = 0.0
var _is_half_circle: bool = false
var _mesh_scale: Vector3 = Vector3(1.0, 1.0, 1.0)
var _weapon_type: String = "turret"
var _is_aoe: bool = false
var _ghost_rotation_deg: float = 0.0

signal building_stopped

var COLOR_VALID = Color(0.2, 0.8, 1.0, 0.5)
var COLOR_INVALID = Color(1.0, 0.2, 0.2, 0.5)

func _ready() -> void:
	_ghost_material = ShaderMaterial.new()
	var shader = preload("res://shaders/ghost_hologram.gdshader")
	if shader:
		_ghost_material.shader = shader
		_ghost_material.set_shader_parameter("base_color", COLOR_VALID)
		
	_range_marker_node = Node3D.new()
	_range_marker_node.name = "RangeMarker"
	add_child(_range_marker_node)

func start_building(_index: int, turret_scene: PackedScene, attack_range: float = 0.0, extra_data: Dictionary = {}) -> void:
	if not map_generator:
		push_warning("BuilderController: map_generator is not assigned!")
		return

	if _is_building:
		stop_building(false)

	# Read configuration from extra_data
	_turret_scene = turret_scene
	_attack_range = attack_range
	_footprint_size = extra_data.get("footprint_size", Vector2i(1, 1))
	_min_attack_range = extra_data.get("min_attack_range", 0.0)
	_is_half_circle = extra_data.get("is_half_circle", false)
	_mesh_scale = extra_data.get("mesh_scale", Vector3(1.0, 1.0, 1.0))
	_weapon_type = extra_data.get("weapon_type", "turret")
	_is_aoe = extra_data.get("is_aoe", false)
	_ghost_rotation_deg = 0.0

	_is_building = true
	_ghost_instance = turret_scene.instantiate()
	_ghost_instance.name = "GhostTurret"
	_ghost_instance.scale = _mesh_scale

	# Assign Turret base script and configure properties
	var turret_script = load("res://scripts/Turret.gd")
	if turret_script == null:
		push_error("Failed to load Turret script at res://scripts/Turret.gd")
	else:
		_ghost_instance.set_script(turret_script)
		_ghost_instance.attack_range = _attack_range
		_ghost_instance.min_attack_range = _min_attack_range
		_ghost_instance.is_half_circle = _is_half_circle
		_ghost_instance.is_aoe = _is_aoe
		_ghost_instance.weapon_type = _weapon_type
		_ghost_instance.cooldown = 1.0

	# Disable ghost logic and apply ghost material
	_disable_logic(_ghost_instance)
	_apply_ghost_material(_ghost_instance)
	add_child(_ghost_instance)
	_build_range_marker(_attack_range, _min_attack_range, _is_half_circle, _footprint_size)

func stop_building(emit_signal: bool = true) -> void:
	_is_building = false
	_turret_scene = null
	_footprint_size = Vector2i(1, 1)
	_mesh_scale = Vector3(1.0, 1.0, 1.0)
	_ghost_rotation_deg = 0.0
	if _ghost_instance:
		_ghost_instance.queue_free()
		_ghost_instance = null
	_clear_range_marker()
	if emit_signal:
		building_stopped.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not _is_building:
		return

	if event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed):
		stop_building()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.keycode == KEY_SPACE and event.pressed and not event.echo:
		_ghost_rotation_deg = fmod(_ghost_rotation_deg + 90.0, 360.0)
		if _ghost_instance:
			_ghost_instance.rotation_degrees.y = _ghost_rotation_deg
		_range_marker_node.rotation_degrees.y = _ghost_rotation_deg
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_try_place_turret()
		get_viewport().set_input_as_handled()
		return

func _is_footprint_buildable(grid_pos: Vector2i, footprint: Vector2i) -> bool:
	if not map_generator.has_method("is_buildable"):
		return true
	for dx in range(footprint.x):
		for dz in range(footprint.y):
			if not map_generator.is_buildable(grid_pos + Vector2i(dx, dz)):
				return false
	return true

func _process(_delta: float) -> void:
	if not _is_building or not _ghost_instance:
		return

	var camera = get_viewport().get_camera_3d()
	if not camera:
		return

	var mouse_pos = get_viewport().get_mouse_position()
	var origin = camera.project_ray_origin(mouse_pos)
	var normal = camera.project_ray_normal(mouse_pos)
	var plane = Plane(Vector3.UP, 0.0)
	
	var hit = plane.intersects_ray(origin, normal)
	if hit != null:
		var local_hit = map_generator.to_local(hit)
		var grid_pos: Vector2i
		var local_snap_pos: Vector3

		if _footprint_size == Vector2i(2, 2):
			# 2x2 grid snapping aligns to cell boundaries
			grid_pos = Vector2i(int(floor(local_hit.x)), int(floor(local_hit.z)))
			local_snap_pos = Vector3(grid_pos.x + 0.5, turret_y_offset, grid_pos.y + 0.5)
		else:
			grid_pos = Vector2i(int(round(local_hit.x)), int(round(local_hit.z)))
			local_snap_pos = Vector3(grid_pos.x, turret_y_offset, grid_pos.y)
		
		_ghost_instance.global_position = map_generator.to_global(local_snap_pos)
		_range_marker_node.global_position = _ghost_instance.global_position
		
		var can_build = _is_footprint_buildable(grid_pos, _footprint_size)

		_ghost_instance.visible = true
		_range_marker_node.visible = true
		if can_build:
			_ghost_material.set_shader_parameter("base_color", COLOR_VALID)
		else:
			_ghost_material.set_shader_parameter("base_color", COLOR_INVALID)
	else:
		_ghost_instance.visible = false
		_range_marker_node.visible = false

func _build_range_marker(attack_range: float, min_attack_range: float = 0.0, is_half_circle: bool = false, footprint: Vector2i = Vector2i(1, 1)) -> void:
	_clear_range_marker()
	if attack_range <= 0.0:
		return
		
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.0, 0.0, 0.0, 0.35)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	material.render_priority = 1
	
	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.9, 0.9)
	mesh.orientation = PlaneMesh.FACE_Y
	
	var r = int(ceil(attack_range))
	var r_sq = attack_range * attack_range
	var min_r_sq = min_attack_range * min_attack_range
	var center_offset = Vector3((footprint.x - 1) * 0.5, 0.0, (footprint.y - 1) * 0.5)

	for x in range(-r, r + footprint.x):
		for z in range(-r, r + footprint.y):
			var tile_pos = Vector3(x, 0.15, z)
			var dist_sq = (tile_pos - center_offset).length_squared()
			if dist_sq <= r_sq and dist_sq >= min_r_sq:
				if is_half_circle:
					var rel = tile_pos - center_offset
					rel.y = 0.0
					if rel.length_squared() > 0.01 and rel.normalized().dot(Vector3.FORWARD) < -0.1:
						continue
				var mi = MeshInstance3D.new()
				mi.mesh = mesh
				mi.material_override = material
				mi.position = tile_pos
				_range_marker_node.add_child(mi)

func _clear_range_marker() -> void:
	for child in _range_marker_node.get_children():
		_range_marker_node.remove_child(child)
		child.free()

func _try_place_turret() -> void:
	if not is_instance_valid(_ghost_instance) or not _ghost_instance.visible:
		return

	var local_ghost_pos = map_generator.to_local(_ghost_instance.global_position)
	var grid_pos: Vector2i
	if _footprint_size == Vector2i(2, 2):
		grid_pos = Vector2i(int(round(local_ghost_pos.x - 0.5)), int(round(local_ghost_pos.z - 0.5)))
	else:
		grid_pos = Vector2i(int(round(local_ghost_pos.x)), int(round(local_ghost_pos.z)))
	
	if _is_footprint_buildable(grid_pos, _footprint_size):
		# Valid placement!
		var new_turret = _turret_scene.instantiate()
		var turret_script = load("res://scripts/Turret.gd")
		if turret_script != null:
			new_turret.set_script(turret_script)
			new_turret.attack_range = _attack_range
			new_turret.min_attack_range = _min_attack_range
			new_turret.is_half_circle = _is_half_circle
			new_turret.is_aoe = _is_aoe
			new_turret.weapon_type = _weapon_type
			new_turret.scale = _mesh_scale
			new_turret.cooldown = 1.0
			new_turret.rotation_degrees.y = _ghost_rotation_deg
		else:
			push_error("Turret.gd failed to load")
			
		map_generator.add_child(new_turret)
		if _footprint_size == Vector2i(2, 2):
			new_turret.position = Vector3(grid_pos.x + 0.5, turret_y_offset, grid_pos.y + 0.5)
		else:
			new_turret.position = Vector3(grid_pos.x, turret_y_offset, grid_pos.y)

		print("Placed turret: attack_range=", _attack_range, " footprint=", _footprint_size)
		
		if map_generator.has_method("occupy_cell"):
			for dx in range(_footprint_size.x):
				for dz in range(_footprint_size.y):
					map_generator.occupy_cell(grid_pos + Vector2i(dx, dz))

		_clear_range_marker()
		_build_range_marker(_attack_range, _min_attack_range, _is_half_circle, _footprint_size)
		# Do not call stop_building() here so the user can place multiple turrets
	else:
		# Invalid placement, maybe play a sound
		pass

func _disable_logic(node: Node) -> void:
	# Disable processing, physics, and collisions for the ghost
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if node is CollisionObject3D:
		node.collision_layer = 0
		node.collision_mask = 0
	for child in node.get_children():
		_disable_logic(child)

func _apply_ghost_material(node: Node) -> void:
	if node is MeshInstance3D:
		node.material_override = _ghost_material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_apply_ghost_material(child)
