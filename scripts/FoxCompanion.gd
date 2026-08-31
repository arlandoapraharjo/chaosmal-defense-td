class_name FoxCompanion
extends CharacterBody3D

## FoxCompanion — Player's tactical companion deployed in the 3D map.
## Scaled to match the 1x1 turret size, with tile-based movement,
## procedural idle breathing squash & stretch, poof particle transitions,
## ground selection ring, and turret buffing.
## Clean visuals with outline highlighting and responsive click controls.

signal selected_changed(is_selected: bool)
signal entered_turret(turret: Node3D)
signal left_turret(turret: Node3D)

const DEFAULT_CHARACTER_SCENE = preload("res://assets/characters/animal-fox.glb")
const SELECTION_SCENE = preload("res://assets/Models/GLB format/selection-a.glb")
const POOF_SCENE = preload("res://scenes/FoxPoofParticle.tscn")

@export var move_speed: float = 4.8
@export var model_scale: Vector3 = Vector3(0.35, 0.35, 0.35)
@export var character_model_scene: PackedScene = null

var is_selected: bool = false
var is_inside_turret: bool = false
var current_turret: Node3D = null

var _target_pos: Vector3
var _is_moving: bool = false
var _is_hovered: bool = false
var _is_dropping: bool = false
var _fox_instance: Node3D = null
var _highlighter: TurretHighlighter = null
var _anim_player: AnimationPlayer = null
var _selection_ring: Node3D = null
var _click_area: Area3D = null
var _idle_breath_time: float = 0.0

var _move_marker_instance: Node3D = null

func _ready() -> void:
	add_to_group("fox_companion")
	_target_pos = global_position
	
	_connect_biome()
	_setup_visuals()
	_setup_selection_ring()
	_setup_collision()
	
	set_selected(false)

func _connect_biome() -> void:
	var map = get_tree().get_first_node_in_group("map_generator")
	if not map:
		map = get_node_or_null("/root/World/MapGenerator")
	if not map:
		map = get_node_or_null("../Map")
	if not map:
		map = get_node_or_null("Map")
	
	if map:
		if map.has_signal("biome_changed") and not map.biome_changed.is_connected(_on_biome_changed):
			map.biome_changed.connect(_on_biome_changed)
		if "active_biome" in map and map.active_biome != null:
			_on_biome_changed(map.active_biome)
	elif BiomeManager != null and BiomeManager.current_biome != null:
		_on_biome_changed(BiomeManager.current_biome)

func _on_biome_changed(biome: BiomeData) -> void:
	if biome and biome.character_model:
		set_character_model(biome.character_model)

func set_character_model(model_scene: PackedScene) -> void:
	if model_scene == null:
		return
	character_model_scene = model_scene
	if _fox_instance and is_instance_valid(_fox_instance):
		_fox_instance.queue_free()
		_fox_instance = null
		_anim_player = null
	
	_setup_visuals()

func _setup_visuals() -> void:
	if _fox_instance == null:
		var scene_to_use = character_model_scene if character_model_scene != null else DEFAULT_CHARACTER_SCENE
		if scene_to_use:
			_fox_instance = scene_to_use.instantiate()
			_fox_instance.name = "FoxModel"
			_fox_instance.scale = model_scale
			add_child(_fox_instance)
			
			# Ensure the mesh center is aligned with the node origin (0, 0)
			var mesh_inst = _find_mesh_instance(_fox_instance)
			if mesh_inst:
				var aabb = mesh_inst.get_aabb()
				var center = aabb.position + aabb.size * 0.5
				if abs(center.x) > 0.05 or abs(center.z) > 0.05:
					_fox_instance.position.x = -center.x * model_scale.x
					_fox_instance.position.z = -center.z * model_scale.z
			
			if is_inside_turret:
				_fox_instance.visible = false
			
			_anim_player = _find_anim_player(_fox_instance)
			if _anim_player:
				if _is_moving:
					if _anim_player.has_animation("run"):
						_anim_player.play("run")
					elif _anim_player.has_animation("walk"):
						_anim_player.play("walk")
				elif _anim_player.has_animation("idle"):
					_anim_player.play("idle")
	
	_setup_highlighter()

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var res = _find_mesh_instance(child)
		if res: return res
	return null

func _setup_highlighter() -> void:
	if _highlighter == null or not is_instance_valid(_highlighter):
		_highlighter = TurretHighlighter.new()
		_highlighter.name = "CompanionHighlighter"
		add_child(_highlighter)
	if _highlighter and is_instance_valid(_highlighter):
		_highlighter.setup(self, 1)
		_highlighter.set_selected(is_selected and not is_inside_turret, 1)
		_highlighter.set_hovered(_is_hovered and not is_inside_turret)

func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var res = _find_anim_player(child)
		if res: return res
	return null

func _setup_selection_ring() -> void:
	if _selection_ring == null and SELECTION_SCENE:
		_selection_ring = SELECTION_SCENE.instantiate()
		_selection_ring.name = "SelectionRing"
		_selection_ring.scale = Vector3(0.52, 0.52, 0.52)
		_selection_ring.position = Vector3(0, 0.15, 0)
		add_child(_selection_ring)
		_selection_ring.visible = false

func _setup_collision() -> void:
	var has_body_col = false
	for child in get_children():
		if child is CollisionShape3D:
			has_body_col = true
			break
	if not has_body_col:
		var body_col = CollisionShape3D.new()
		body_col.name = "BodyCollision"
		var cyl = CylinderShape3D.new()
		cyl.radius = 0.35
		cyl.height = 0.8
		body_col.shape = cyl
		body_col.position = Vector3(0, 0.4, 0)
		add_child(body_col)

	if _click_area == null:
		_click_area = Area3D.new()
		_click_area.name = "ClickArea"
		_click_area.collision_layer = 1 | 4
		_click_area.collision_mask = 1 | 4
		_click_area.input_ray_pickable = true
		
		var col_shape = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = Vector3(1.3, 1.5, 1.3)
		col_shape.shape = box
		col_shape.position = Vector3(0, 0.6, 0)
		
		_click_area.add_child(col_shape)
		add_child(_click_area)
		
		_click_area.input_event.connect(_on_click_area_input_event)
		_click_area.mouse_entered.connect(_on_mouse_entered)
		_click_area.mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	if is_inside_turret:
		return
	var builder = get_tree().get_first_node_in_group("builder_controller")
	if not builder:
		builder = get_node_or_null("/root/World/BuilderController")
	if builder and builder.get("_is_building") == true:
		return
	
	_is_hovered = true
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	if not _highlighter or not is_instance_valid(_highlighter):
		_setup_highlighter()
	if _highlighter and is_instance_valid(_highlighter):
		_highlighter.set_hovered(true)

func _on_mouse_exited() -> void:
	_is_hovered = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if _highlighter and is_instance_valid(_highlighter):
		_highlighter.set_hovered(false)

func _on_click_area_input_event(_camera: Camera3D, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if is_inside_turret:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var builder = get_tree().get_first_node_in_group("builder_controller")
		if not builder:
			builder = get_node_or_null("/root/World/BuilderController")
		if builder and builder.get("_is_building") == true:
			return
		
		set_selected(true)
		if is_inside_tree() and get_viewport():
			get_viewport().set_input_as_handled()

func set_selected(selected: bool) -> void:
	is_selected = selected
	if _selection_ring:
		_selection_ring.visible = is_selected and not is_inside_turret
	
	if not _highlighter or not is_instance_valid(_highlighter):
		_setup_highlighter()
	if _highlighter and is_instance_valid(_highlighter):
		_highlighter.set_selected(is_selected and not is_inside_turret, 1)
	
	if is_selected and not is_inside_turret:
		var builder = get_tree().get_first_node_in_group("builder_controller")
		if not builder:
			builder = get_node_or_null("/root/World/BuilderController")
		if builder and builder.has_method("deselect_turret"):
			builder.deselect_turret()
		
		# Hop / gesture animation on selection
		if _anim_player and _anim_player.has_animation("gesture-positive"):
			_anim_player.play("gesture-positive")
			_anim_player.queue("idle")
		_spawn_move_marker(global_position, Color(0.2, 0.85, 1.0, 0.9))
	
	selected_changed.emit(is_selected)

## Play landing drop animation when deployed
func play_deployment_drop(start_height: float = 5.5) -> void:
	var landing_coords: Vector3 = global_position
	var start_pos: Vector3 = Vector3(landing_coords.x, landing_coords.y + start_height, landing_coords.z)
	global_position = start_pos
	_target_pos = landing_coords
	_is_dropping = true
	
	if _fox_instance:
		_fox_instance.position.y = 0.0
		_fox_instance.scale = model_scale
	
	if _anim_player and _anim_player.has_animation("jump"):
		_anim_player.play("jump")
	elif _anim_player and _anim_player.has_animation("fall"):
		_anim_player.play("fall")
	
	var drop_duration: float = 0.48
	var tween = create_tween()
	tween.tween_property(self, "global_position:y", landing_coords.y, drop_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# Precisely upon touching down at the landing coordinates:
	tween.tween_callback(func():
		global_position = landing_coords
		_spawn_poof(landing_coords)
		
		# Cartoon squash & stretch landing impact recovery
		if _fox_instance:
			var squash_tween = create_tween()
			squash_tween.tween_property(_fox_instance, "scale", Vector3(model_scale.x * 1.35, model_scale.y * 0.65, model_scale.z * 1.35), 0.09)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			squash_tween.tween_property(_fox_instance, "scale", Vector3(model_scale.x * 0.9, model_scale.y * 1.15, model_scale.z * 0.9), 0.12)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			squash_tween.tween_property(_fox_instance, "scale", model_scale, 0.12)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
		if _anim_player and _anim_player.has_animation("gesture-positive"):
			_anim_player.play("gesture-positive")
			_anim_player.queue("idle")
		elif _anim_player and _anim_player.has_animation("idle"):
			_anim_player.play("idle")
		
		_is_dropping = false
	)

## Move to snapped tile position (only if selected first)
func command_move_to(target_world_pos: Vector3) -> void:
	if not is_selected:
		return
	
	if is_inside_turret:
		_exit_current_turret()
	else:
		current_turret = null
	
	_target_pos = Vector3(target_world_pos.x, global_position.y, target_world_pos.z)
	_is_moving = true
	
	if _anim_player and _anim_player.has_animation("run"):
		_anim_player.play("run")
	elif _anim_player and _anim_player.has_animation("walk"):
		_anim_player.play("walk")
	
	_spawn_move_marker(_target_pos, Color(0.25, 0.9, 1.0, 0.95))

## Move to turret and buff it (only if selected first)
func command_enter_turret(turret: Node3D) -> void:
	if not is_selected or not is_instance_valid(turret):
		return
	
	if is_inside_turret:
		if current_turret == turret:
			return # Already inside this turret
		_exit_current_turret()
	
	current_turret = turret
	_target_pos = turret.global_position
	_is_moving = true
	
	if _anim_player and _anim_player.has_animation("run"):
		_anim_player.play("run")
	elif _anim_player and _anim_player.has_animation("walk"):
		_anim_player.play("walk")
	
	_spawn_move_marker(_target_pos, Color(1.0, 0.85, 0.2, 0.95))

func _exit_current_turret() -> void:
	if current_turret and is_instance_valid(current_turret):
		_spawn_poof(current_turret.global_position)
		global_position = current_turret.global_position + Vector3(0.25, 0.0, 0.25)
		if current_turret.has_method("apply_fox_buff"):
			current_turret.apply_fox_buff(false)
		left_turret.emit(current_turret)
	
	is_inside_turret = false
	current_turret = null
	if _fox_instance:
		_fox_instance.visible = true
		_fox_instance.position.y = 0.0
		_fox_instance.scale = model_scale
	if _selection_ring:
		_selection_ring.visible = is_selected
	if _highlighter and is_instance_valid(_highlighter):
		_highlighter.setup(self, 1)
		_highlighter.set_selected(is_selected, 1)

func _process(delta: float) -> void:
	if _is_dropping or is_inside_turret or not _fox_instance or not _fox_instance.visible:
		return
	
	if not _is_moving:
		# Procedural cute idle breathing squash & stretch
		_idle_breath_time += delta * 2.8
		var bob = sin(_idle_breath_time) * 0.012
		_fox_instance.position.y = bob
		_fox_instance.scale.y = model_scale.y * (1.0 + sin(_idle_breath_time) * 0.025)
		_fox_instance.scale.x = model_scale.x * (1.0 - sin(_idle_breath_time) * 0.012)
		_fox_instance.scale.z = model_scale.z * (1.0 - sin(_idle_breath_time) * 0.012)
	else:
		_fox_instance.position.y = 0.0
		_fox_instance.scale = model_scale

func _physics_process(delta: float) -> void:
	if _selection_ring and _selection_ring.visible:
		_selection_ring.rotation.y += delta * 2.0
	
	if not _is_moving:
		return
	
	var current_flat = Vector3(global_position.x, 0, global_position.z)
	var target_flat = Vector3(_target_pos.x, 0, _target_pos.z)
	var dist = current_flat.distance_to(target_flat)
	
	# Forgiving arrival distance when targeting turrets
	var arrival_dist = 0.45 if (current_turret != null and is_instance_valid(current_turret)) else 0.15
	if dist <= arrival_dist:
		_is_moving = false
		global_position.x = _target_pos.x
		global_position.z = _target_pos.z
		
		if current_turret and is_instance_valid(current_turret):
			# Poof into the turret and disappear inside
			_spawn_poof(global_position)
			is_inside_turret = true
			if _fox_instance:
				_fox_instance.visible = false
			if _selection_ring:
				_selection_ring.visible = false
			if _highlighter and is_instance_valid(_highlighter):
				_highlighter.clear_highlight()
			
			if current_turret.has_method("apply_fox_buff"):
				current_turret.apply_fox_buff(true)
			entered_turret.emit(current_turret)
		else:
			current_turret = null
			if _anim_player and _anim_player.has_animation("idle"):
				_anim_player.play("idle")
		return
	
	# Move towards target
	var dir = (target_flat - current_flat).normalized()
	velocity = dir * move_speed
	move_and_slide()
	
	# Face movement direction
	if dir.length_squared() > 0.001:
		var target_rot = atan2(dir.x, dir.z)
		rotation.y = lerp_angle(rotation.y, target_rot, delta * 12.0)

func _spawn_poof(pos: Vector3) -> void:
	if not is_inside_tree() or not POOF_SCENE:
		return
	var poof = POOF_SCENE.instantiate() as Node3D
	
	var parent_node = get_parent() if get_parent() else self
	parent_node.add_child(poof)
	
	# Precisely align global position with the companion's landing coordinates
	poof.global_position = Vector3(pos.x, pos.y + 0.15, pos.z)

func _spawn_move_marker(pos: Vector3, color: Color) -> void:
	if not is_inside_tree():
		return
	
	if _move_marker_instance and is_instance_valid(_move_marker_instance):
		_move_marker_instance.queue_free()
	
	if SELECTION_SCENE:
		var marker = SELECTION_SCENE.instantiate() as Node3D
		var parent_node = get_parent() if get_parent() else self
		parent_node.add_child(marker)
		marker.global_position = Vector3(pos.x, 0.22, pos.z)
		marker.scale = Vector3(0.55, 0.55, 0.55)
		
		_move_marker_instance = marker
		
		var tween = marker.create_tween()
		tween.set_parallel(true)
		tween.tween_property(marker, "scale", Vector3(0.75, 0.75, 0.75), 0.45)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(marker, "position:y", marker.position.y + 0.12, 0.45)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
		tween.chain().tween_callback(func():
			if is_instance_valid(marker):
				marker.queue_free()
		)
