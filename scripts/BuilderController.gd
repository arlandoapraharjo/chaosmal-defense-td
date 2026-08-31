extends Node

## Controller that handles grid-snapping turret placement on the map.

const PLACEMENT_PARTICLE_SCENE = preload("res://scenes/turret_placement_particle.tscn")

@export var map_generator: Node3D
@export var turret_y_offset: float = 0.1

@export_group("Deployment")
@export var base_max_deployment: int = 8
@export var deployment_increase_per_wave: int = 0

var _current_deployment: int = 0
var _max_deployment: int = 8
var _turret_cost: int = 0

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
var _current_slot_index: int = -1
var _turret_damage: float = 35.0
var _turret_cooldown: float = 1.0

# All currently placed turret nodes — used to forward speed multiplier
var _placed_turrets: Array[Node3D] = []
var _speed_multiplier: float = 1.0

signal building_stopped
## Emitted when a turret is successfully placed. Carries the hotbar slot index.
signal turret_placed(slot_index: int)
signal total_deployment_updated(current: int, max: int)

var COLOR_VALID = Color(0.2, 0.8, 1.0, 0.5)
var COLOR_INVALID = Color(1.0, 0.2, 0.2, 0.5)

func _ready() -> void:
	add_to_group("builder_controller")
	_max_deployment = base_max_deployment
	call_deferred("_connect_to_spawner")

	
	_ghost_material = ShaderMaterial.new()
	var shader = preload("res://shaders/ghost_hologram.gdshader")
	if shader:
		_ghost_material.shader = shader
		_ghost_material.set_shader_parameter("base_color", COLOR_VALID)
		
	_range_marker_node = Node3D.new()
	_range_marker_node.name = "RangeMarker"
	add_child(_range_marker_node)

func _connect_to_spawner() -> void:
	var spawner = get_tree().get_root().find_child("Spawner", true, false)
	if spawner and spawner.has_signal("wave_completed"):
		if not spawner.wave_completed.is_connected(_on_wave_completed):
			spawner.wave_completed.connect(_on_wave_completed)

func _on_wave_completed(_wave_number: int) -> void:
	# Turret slot capacity no longer increases per wave
	pass

func increase_max_deployment(amount: int) -> void:
	if amount > 0:
		_max_deployment += amount
		total_deployment_updated.emit(_current_deployment, _max_deployment)

func get_max_deployment() -> int:
	return _max_deployment

func get_current_deployment() -> int:
	return _current_deployment

var _selected_turret: Node3D = null

func start_building(_index: int, turret_scene: PackedScene, attack_range: float = 0.0, extra_data: Dictionary = {}) -> void:
	deselect_turret()

	if not map_generator:
		push_warning("BuilderController: map_generator is not assigned!")
		return

	if _is_building:
		stop_building(false)

	# Read configuration from extra_data
	_turret_scene = turret_scene
	_attack_range = attack_range
	_current_slot_index = _index
	_footprint_size = extra_data.get("footprint_size", Vector2i(1, 1))
	_min_attack_range = extra_data.get("min_attack_range", 0.0)
	_is_half_circle = extra_data.get("is_half_circle", false)
	_mesh_scale = extra_data.get("mesh_scale", Vector3(1.0, 1.0, 1.0))
	_weapon_type = extra_data.get("weapon_type", "turret")
	_is_aoe = extra_data.get("is_aoe", false)
	_turret_cost = extra_data.get("cost", 0)
	_turret_damage = extra_data.get("attack_damage", 35.0)
	_turret_cooldown = extra_data.get("cooldown", 1.0)
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
		_ghost_instance.is_ghost = true
		_ghost_instance.attack_range = _attack_range
		_ghost_instance.min_attack_range = _min_attack_range
		_ghost_instance.is_half_circle = _is_half_circle
		_ghost_instance.is_aoe = _is_aoe
		_ghost_instance.weapon_type = _weapon_type
		_ghost_instance.attack_damage = extra_data.get("attack_damage", 35.0)
		_ghost_instance.cooldown = extra_data.get("cooldown", 1.0)

	# Disable ghost logic and apply ghost material
	_disable_logic(_ghost_instance)
	_apply_ghost_material(_ghost_instance)
	add_child(_ghost_instance)
	_build_range_marker(_attack_range, _min_attack_range, _is_half_circle, _footprint_size)

func stop_building(do_emit_signal: bool = true) -> void:
	_is_building = false
	_turret_scene = null
	_footprint_size = Vector2i(1, 1)
	_mesh_scale = Vector3(1.0, 1.0, 1.0)
	_ghost_rotation_deg = 0.0
	if _ghost_instance:
		_ghost_instance.queue_free()
		_ghost_instance = null
	_clear_range_marker()
	if do_emit_signal:
		building_stopped.emit()

var _turret_interacted_frame: int = -1

func notify_turret_interacted() -> void:
	_turret_interacted_frame = Engine.get_process_frames()

func select_turret(turret: Node3D) -> void:
	if _is_building:
		return
	_turret_interacted_frame = Engine.get_process_frames()
	if _selected_turret and _selected_turret != turret and is_instance_valid(_selected_turret):
		if _selected_turret.has_method("set_selected"):
			_selected_turret.set_selected(false)
	_selected_turret = turret
	if is_instance_valid(_selected_turret) and _selected_turret.has_method("set_selected"):
		_selected_turret.set_selected(true)

func deselect_turret() -> void:
	if _selected_turret and is_instance_valid(_selected_turret):
		if _selected_turret.has_method("set_selected"):
			_selected_turret.set_selected(false)
	_selected_turret = null

func on_turret_sold(turret: Node3D) -> void:
	if _selected_turret == turret:
		_selected_turret = null
	_placed_turrets.erase(turret)
	_current_deployment = maxi(0, _current_deployment - 1)
	total_deployment_updated.emit(_current_deployment, _max_deployment)

func _unhandled_input(event: InputEvent) -> void:
	if not _is_building:
		var fox = get_tree().get_first_node_in_group("fox_companion")
		if event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed):
			if fox and fox.get("is_selected") == true:
				fox.set_selected(false)
				if is_inside_tree() and get_viewport():
					get_viewport().set_input_as_handled()
				return
			if _selected_turret:
				deselect_turret()
				if is_inside_tree() and get_viewport():
					get_viewport().set_input_as_handled()
				return
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# If this click was consumed by a turret or upgrade button this frame, do not deselect
			if _turret_interacted_frame == Engine.get_process_frames():
				return
			
			# If Fox is selected, issue command (to turret or snapped map tile)
			if fox and fox.get("is_selected") == true:
				var camera = get_viewport().get_camera_3d()
				if camera:
					var mouse_pos = get_viewport().get_mouse_position()
					var origin = camera.project_ray_origin(mouse_pos)
					var normal = camera.project_ray_normal(mouse_pos)
					
					# Find the precise turret targeted by the click
					var clicked_turret: Node3D = _find_turret_at_screen_pos(mouse_pos, camera)
					
					if clicked_turret != null and is_instance_valid(clicked_turret):
						fox.command_enter_turret(clicked_turret)
						if is_inside_tree() and get_viewport():
							get_viewport().set_input_as_handled()
						return
					
					# 2. Player clicked ground: Snap to grid tile within map boundaries
					var plane = Plane(Vector3.UP, 0.0)
					var hit = plane.intersects_ray(origin, normal)
					if hit != null:
						var local_hit = map_generator.to_local(hit) if map_generator else hit
						var grid_x = int(round(local_hit.x))
						var grid_z = int(round(local_hit.z))
						var grid_pos = Vector2i(grid_x, grid_z)
						
						# Maximum limit is the map itself (0 to 19). Coastal ring & void CANNOT be clicked!
						if grid_pos.x >= 0 and grid_pos.x < 20 and grid_pos.y >= 0 and grid_pos.y < 20:
							var snapped_world_pos = map_generator.to_global(Vector3(grid_pos.x, 0.0, grid_pos.y)) if map_generator else Vector3(grid_pos.x, 0.0, grid_pos.y)
							fox.command_move_to(snapped_world_pos)
							if is_inside_tree() and get_viewport():
								get_viewport().set_input_as_handled()
							return
						else:
							# Outside map or coastal ring: Blocked!
							if is_inside_tree() and get_viewport():
								get_viewport().set_input_as_handled()
							return
			
			# Otherwise clicking empty terrain deselects the current turret & fox
			if _selected_turret:
				deselect_turret()
			if fox and fox.get("is_selected") == true:
				fox.set_selected(false)
		return

	if event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed):
		stop_building()
		if is_inside_tree() and get_viewport():
			get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.keycode == KEY_SPACE and event.pressed and not event.echo:
		_ghost_rotation_deg = fmod(_ghost_rotation_deg + 90.0, 360.0)
		if _ghost_instance:
			_ghost_instance.rotation_degrees.y = _ghost_rotation_deg
		_range_marker_node.rotation_degrees.y = _ghost_rotation_deg
		if is_inside_tree() and get_viewport():
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_try_place_turret()
		if is_inside_tree() and get_viewport():
			get_viewport().set_input_as_handled()
		return

func _find_turret_ancestor(node: Node) -> Node3D:
	var curr = node
	while curr != null:
		if curr is Node3D and curr.has_method("apply_fox_buff"):
			return curr as Node3D
		curr = curr.get_parent()
	return null

## Robustly identifies the intended turret clicked by the player using:
## 1. Direct 3D raycast against TurretBodyArea colliders (filtering out floating UI badges)
## 2. Ground tile footprint intersection
## 3. Screen-space proximity to visual center (finding the true closest turret, not first in array)
func _find_turret_at_screen_pos(mouse_pos: Vector2, camera: Camera3D) -> Node3D:
	if not camera:
		return null
	
	var origin = camera.project_ray_origin(mouse_pos)
	var normal = camera.project_ray_normal(mouse_pos)
	
	# 1. Direct 3D raycast specifically for TurretBodyArea colliders
	var space_state = camera.get_world_3d().direct_space_state
	var ray_query = PhysicsRayQueryParameters3D.create(origin, origin + normal * 100.0)
	ray_query.collide_with_areas = true
	ray_query.collide_with_bodies = false
	var result = space_state.intersect_ray(ray_query)
	
	if not result.is_empty():
		var collider = result.collider
		if collider and collider.name == "TurretBodyArea":
			var t = _find_turret_ancestor(collider)
			if t and is_instance_valid(t):
				return t
	
	# 2. Check if the mouse ray intersects the ground plane directly on a placed turret's tile footprint
	var plane = Plane(Vector3.UP, 0.0)
	var hit = plane.intersects_ray(origin, normal)
	var ground_turret: Node3D = null
	if hit != null:
		var local_hit = map_generator.to_local(hit) if map_generator else hit
		var grid_pos = Vector2i(int(round(local_hit.x)), int(round(local_hit.z)))
		for t in _placed_turrets:
			if not is_instance_valid(t):
				continue
			var t_grid: Vector2i = t.grid_pos
			var t_fp: Vector2i = t.footprint_size if ("footprint_size" in t) else Vector2i(1, 1)
			if t_fp == Vector2i(1, 1):
				if t_grid == grid_pos:
					ground_turret = t
					break
			else:
				if grid_pos.x >= t_grid.x and grid_pos.x < t_grid.x + t_fp.x and \
				   grid_pos.y >= t_grid.y and grid_pos.y < t_grid.y + t_fp.y:
					ground_turret = t
					break
	
	# 3. Find the closest placed turret in screen-space within a strict threshold
	var closest_turret: Node3D = null
	var min_screen_dist: float = 46.0
	
	for t in _placed_turrets:
		if not is_instance_valid(t):
			continue
		var center_3d = t.global_position + Vector3(0, 0.6, 0)
		var t_screen = camera.unproject_position(center_3d)
		var d = mouse_pos.distance_to(t_screen)
		if d < min_screen_dist:
			min_screen_dist = d
			closest_turret = t
	
	# If ground tile matches a turret and cursor is reasonably near it on screen, ground hit is the most accurate
	if ground_turret != null:
		var gt_screen = camera.unproject_position(ground_turret.global_position + Vector3(0, 0.6, 0))
		if mouse_pos.distance_to(gt_screen) <= 58.0:
			return ground_turret
	
	if closest_turret != null:
		return closest_turret
	
	if ground_turret != null:
		return ground_turret
	
	return null

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
	
	var fp_mesh = QuadMesh.new()
	fp_mesh.size = Vector2(footprint.x - 0.1, footprint.y - 0.1)
	fp_mesh.orientation = PlaneMesh.FACE_Y
	
	# Draw the single footprint tile ALWAYS
	var fp_mi = MeshInstance3D.new()
	fp_mi.mesh = fp_mesh
	fp_mi.material_override = material
	fp_mi.position = Vector3(0, 0.15, 0)
	_range_marker_node.add_child(fp_mi)
	
	var r = int(ceil(attack_range))
	var r_sq = attack_range * attack_range
	var min_r_sq = min_attack_range * min_attack_range
	
	var step_x = footprint.x
	var step_y = footprint.y
	var limit_x = (int(float(r) / step_x) + 1) * step_x
	var limit_z = (int(float(r) / step_y) + 1) * step_y

	for x in range(-limit_x, limit_x + step_x, step_x):
		for z in range(-limit_z, limit_z + step_y, step_y):
			if x == 0 and z == 0:
				continue # Already drawn as the footprint
				
			var rel = Vector3(x, 0, z)
			var dist_sq = rel.x * rel.x + rel.z * rel.z
			if dist_sq <= r_sq and dist_sq >= min_r_sq:
				if is_half_circle:
					var forward_check = rel
					forward_check.y = 0.0
					if forward_check.length_squared() > 0.01 and forward_check.normalized().dot(Vector3.FORWARD) < -0.1:
						continue
				var mi = MeshInstance3D.new()
				mi.mesh = fp_mesh
				mi.material_override = material
				mi.position = rel
				mi.position.y = 0.15
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
		if _current_deployment >= _max_deployment:
			print("Max deployment reached!")
			return
			
		var currency_manager = get_node_or_null("/root/World/CurrencyManager")
		if not currency_manager and CurrencyManager.instance:
			currency_manager = CurrencyManager.instance
			
		if currency_manager and currency_manager.get_currency() < _turret_cost:
			print("Not enough currency!")
			var wave_ui = get_tree().get_first_node_in_group("wave_ui")
			if not wave_ui:
				wave_ui = get_node_or_null("/root/World/WaveUI")
			if wave_ui and wave_ui.has_method("show_insufficient_funds"):
				wave_ui.show_insufficient_funds()

			return
			
		if currency_manager:
			currency_manager.spend_currency(_turret_cost)
			
		_current_deployment += 1
		total_deployment_updated.emit(_current_deployment, _max_deployment)
		
		# Valid placement!
		var new_turret = _turret_scene.instantiate()
		var turret_script = load("res://scripts/Turret.gd")
		if turret_script != null:
			new_turret.set_script(turret_script)
			new_turret.base_cost = _turret_cost
			new_turret.total_invested_cost = _turret_cost
			new_turret.grid_pos = grid_pos
			new_turret.footprint_size = _footprint_size
			new_turret.attack_range = _attack_range
			new_turret.min_attack_range = _min_attack_range
			new_turret.is_half_circle = _is_half_circle
			new_turret.is_aoe = _is_aoe
			new_turret.weapon_type = _weapon_type
			new_turret.scale = _mesh_scale
			new_turret.attack_damage = _turret_damage
			new_turret.cooldown = _turret_cooldown
			new_turret.rotation_degrees.y = _ghost_rotation_deg
		else:
			push_error("Turret.gd failed to load")
			
		map_generator.add_child(new_turret)
		if _footprint_size == Vector2i(2, 2):
			new_turret.position = Vector3(grid_pos.x + 0.5, turret_y_offset, grid_pos.y + 0.5)
		else:
			new_turret.position = Vector3(grid_pos.x, turret_y_offset, grid_pos.y)

		print("Placed turret: attack_range=", _attack_range, " footprint=", _footprint_size)
		
		# Spawn placement particle effect
		if PLACEMENT_PARTICLE_SCENE:
			var place_part = PLACEMENT_PARTICLE_SCENE.instantiate()
			map_generator.add_child(place_part)
			place_part.global_position = new_turret.global_position
			if place_part.has_method("setup_footprint"):
				place_part.setup_footprint(_footprint_size)

		# Trigger snappy placement landing bounce
		if new_turret.has_method("play_placement_landing_animation"):
			new_turret.play_placement_landing_animation()
		
		# Apply current speed multiplier to the newly placed turret
		if new_turret.has_method("set_speed_multiplier"):
			new_turret.set_speed_multiplier(_speed_multiplier)
		_placed_turrets.append(new_turret)
		
		if map_generator.has_method("occupy_cell"):
			for dx in range(_footprint_size.x):
				for dz in range(_footprint_size.y):
					map_generator.occupy_cell(grid_pos + Vector2i(dx, dz))

		turret_placed.emit(_current_slot_index)
		_clear_range_marker()
		_build_range_marker(_attack_range, _min_attack_range, _is_half_circle, _footprint_size)
		# Do not call stop_building() here so the user can place multiple turrets
	else:
		# Invalid placement, maybe play a sound
		pass

## Apply speed multiplier to all currently placed turrets.
func set_speed_multiplier(multiplier: float) -> void:
	_speed_multiplier = multiplier
	for turret in _placed_turrets:
		if is_instance_valid(turret) and turret.has_method("set_speed_multiplier"):
			turret.set_speed_multiplier(_speed_multiplier)

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
