class_name FoxCompanion
extends CharacterBody3D

## FoxCompanion — Player's tactical companion deployed in the 3D map.
## Scaled to match the 1x1 turret size, with tile-based movement,
## procedural idle breathing squash & stretch, poof particle transitions,
## ground selection ring, and turret buffing.
## Clean visuals without artificial outline lighting.

signal selected_changed(is_selected: bool)
signal entered_turret(turret: Node3D)
signal left_turret(turret: Node3D)

const FOX_SCENE = preload("res://assets/characters/animal-fox.glb")
const SELECTION_SCENE = preload("res://assets/Models/GLB format/selection-a.glb")
const POOF_SCENE = preload("res://scenes/FoxPoofParticle.tscn")

@export var move_speed: float = 4.8
@export var model_scale: Vector3 = Vector3(0.35, 0.35, 0.35)

var is_selected: bool = false
var is_inside_turret: bool = false
var current_turret: Node3D = null

var _target_pos: Vector3
var _is_moving: bool = false
var _fox_instance: Node3D = null
var _anim_player: AnimationPlayer = null
var _selection_ring: Node3D = null
var _click_area: Area3D = null
var _idle_breath_time: float = 0.0

var _move_marker_instance: Node3D = null

func _ready() -> void:
	add_to_group("fox_companion")
	_target_pos = global_position
	
	_setup_visuals()
	_setup_selection_ring()
	_setup_collision()
	
	set_selected(false)

func _setup_visuals() -> void:
	if _fox_instance == null:
		_fox_instance = FOX_SCENE.instantiate()
		_fox_instance.name = "FoxModel"
		_fox_instance.scale = model_scale
		add_child(_fox_instance)
		
		_anim_player = _find_anim_player(_fox_instance)
		if _anim_player:
			if _anim_player.has_animation("idle"):
				_anim_player.play("idle")

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
	if _click_area == null:
		_click_area = Area3D.new()
		_click_area.name = "ClickArea"
		
		var col_shape = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = Vector3(0.8, 0.8, 0.8)
		col_shape.shape = box
		col_shape.position = Vector3(0, 0.35, 0)
		
		_click_area.add_child(col_shape)
		add_child(_click_area)
		
		_click_area.input_event.connect(_on_click_area_input_event)

func _on_click_area_input_event(_camera: Camera3D, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if is_inside_turret:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var builder = get_tree().get_first_node_in_group("builder_controller")
		if builder and builder.get("_is_building") == true:
			return
		
		set_selected(not is_selected)
		if is_inside_tree() and get_viewport():
			get_viewport().set_input_as_handled()

func set_selected(selected: bool) -> void:
	is_selected = selected
	if _selection_ring:
		_selection_ring.visible = is_selected and not is_inside_turret
	
	if is_selected and not is_inside_turret:
		# Hop / gesture animation on selection
		if _anim_player and _anim_player.has_animation("gesture-positive"):
			_anim_player.play("gesture-positive")
			_anim_player.queue("idle")
		_spawn_move_marker(global_position, Color(0.2, 0.85, 1.0, 0.9))
	
	selected_changed.emit(is_selected)

## Play landing drop animation when deployed
func play_deployment_drop(start_height: float = 6.0) -> void:
	var target_y = global_position.y
	global_position.y += start_height
	
	var tween = create_tween()
	tween.tween_property(self, "global_position:y", target_y, 0.65)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	tween.chain().tween_callback(func():
		_spawn_poof(global_position)
		if _anim_player and _anim_player.has_animation("gesture-positive"):
			_anim_player.play("gesture-positive")
			_anim_player.queue("idle")
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

func _process(delta: float) -> void:
	if is_inside_turret or not _fox_instance or not _fox_instance.visible:
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
	poof.position = pos + Vector3(0, 0.35, 0)
	var parent_node = get_parent() if get_parent() else self
	parent_node.add_child(poof)

func _spawn_move_marker(pos: Vector3, color: Color) -> void:
	if not is_inside_tree():
		return
	
	if _move_marker_instance and is_instance_valid(_move_marker_instance):
		_move_marker_instance.queue_free()
	
	if SELECTION_SCENE:
		var marker = SELECTION_SCENE.instantiate() as Node3D
		marker.position = Vector3(pos.x, 0.22, pos.z)
		marker.scale = Vector3(0.55, 0.55, 0.55)
		
		get_parent().add_child(marker)
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
