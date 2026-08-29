class_name TurretHighlighter
extends Node

## TurretHighlighter
## Manages hover highlighting and persistent RPG rarity outline overlays across placed turrets.
## Level 1 shows a White outline when hovered or selected.
## Levels 2–5 show persistent rarity outlines, plus a second outer White outline layer when hovered.

# RPG Rarity Colors (Levels 1–5):
const RARITY_COLORS: Dictionary = {
	1: Color(1.0, 1.0, 1.0, 1.0),     # L1: Common - White (Hover / Selection)
	2: Color(0.15, 0.85, 1.0, 1.0),   # L2: Rare - Vibrant Cyan (Persistent)
	3: Color(0.75, 0.25, 1.0, 1.0),   # L3: Epic - Royal Neon Purple (Persistent)
	4: Color(1.0, 0.80, 0.10, 1.0),   # L4: Legendary - Radiant Gold (Persistent)
	5: Color(1.0, 0.20, 0.25, 1.0)    # L5: Mythic - Blazing Crimson Red (Persistent)
}

@export var outline_material_res: ShaderMaterial = preload("res://shaders/outline_material.tres")
@export var idle_width: float = 3.0
@export var selected_width: float = 4.5
@export var hover_extra_width: float = 3.0
@export var upgrade_pulse_width: float = 5.5

var _target: Node3D = null
var _material: ShaderMaterial = null
var _hover_material: ShaderMaterial = null
var _mesh_cache: Array[MeshInstance3D] = []
var _pulse_tween: Tween = null
var _is_hovered: bool = false
var _is_selected: bool = false
var _current_level: int = 1

func _ready() -> void:
	if _target == null and get_parent() is Node3D:
		_target = get_parent() as Node3D
	_init_material()

func setup(target_node: Node3D, initial_level: int = 1) -> void:
	_target = target_node
	_current_level = initial_level
	_mesh_cache.clear()
	_init_material()
	_refresh_mesh_cache()
	_update_display()

static func get_rarity_color(level: int) -> Color:
	var cl = clampi(level, 1, 5)
	return RARITY_COLORS.get(cl, Color(1.0, 1.0, 1.0, 1.0))

func _init_material() -> void:
	if _material == null:
		if outline_material_res:
			_material = outline_material_res.duplicate() as ShaderMaterial
			_material.next_pass = null
		else:
			_material = ShaderMaterial.new()
			var sh = load("res://shaders/outline_pixel_perfect.gdshader") as Shader
			if sh:
				_material.shader = sh

	if _hover_material == null:
		if outline_material_res:
			_hover_material = outline_material_res.duplicate() as ShaderMaterial
			_hover_material.next_pass = null
		else:
			_hover_material = ShaderMaterial.new()
			var sh = load("res://shaders/outline_pixel_perfect.gdshader") as Shader
			if sh:
				_hover_material.shader = sh
		_hover_material.set_shader_parameter("outline_color", Color(1.0, 1.0, 1.0, 1.0))
		_hover_material.set_shader_parameter("squiggly_enabled", false)
		_hover_material.render_priority = -1

func _collect_meshes(node: Node, out_list: Array[MeshInstance3D]) -> void:
	if not is_instance_valid(node):
		return
	# Skip UI root, RangeMarker, or particles if encountered
	if node.name == "TurretUIRoot" or node.name == "RangeMarker" or node is GPUParticles3D:
		return
	for child in node.get_children():
		if child is MeshInstance3D:
			out_list.append(child)
		_collect_meshes(child, out_list)

func _refresh_mesh_cache() -> void:
	_mesh_cache.clear()
	if _target and is_instance_valid(_target):
		_collect_meshes(_target, _mesh_cache)

## Update display based on current level, hover, and selection state
func _update_display() -> void:
	_init_material()
	_refresh_mesh_cache()

	if _current_level <= 1:
		# Level 1 (Common):
		# Clean, solid White outline if hovered or selected (no squiggly on hover/selection)
		if _is_selected or _is_hovered:
			var target_w = selected_width if _is_selected else idle_width
			_material.next_pass = null
			_material.set_shader_parameter("outline_color", Color(1.0, 1.0, 1.0, 1.0))
			_material.set_shader_parameter("outline_width", target_w)
			_material.set_shader_parameter("squiggly_enabled", false)
			for mesh in _mesh_cache:
				if is_instance_valid(mesh):
					mesh.material_overlay = _material
		else:
			clear_highlight()
	else:
		# Levels 2–5 (Upgraded):
		# Base layer: Persistent rarity color outline with animated squiggly effect
		var rarity_col = get_rarity_color(_current_level)
		var base_w = selected_width if _is_selected else idle_width
		_material.set_shader_parameter("outline_color", rarity_col)
		_material.set_shader_parameter("outline_width", base_w)
		_material.set_shader_parameter("squiggly_enabled", true)

		# Second layer on hover: Outer White outline wrapping the rarity outline (clean solid, no squiggly)
		if _is_hovered:
			_hover_material.set_shader_parameter("outline_color", Color(1.0, 1.0, 1.0, 1.0))
			_hover_material.set_shader_parameter("outline_width", base_w + hover_extra_width)
			_hover_material.set_shader_parameter("squiggly_enabled", false)
			_material.next_pass = _hover_material
		else:
			_material.next_pass = null

		for mesh in _mesh_cache:
			if is_instance_valid(mesh):
				mesh.material_overlay = _material

## Called when mouse enters/exits the turret hitbox
func set_hovered(hovered: bool) -> void:
	if _is_hovered == hovered:
		return
	_is_hovered = hovered
	_update_display()

## Called when turret selection changes
func set_selected(selected: bool, level: int = 1) -> void:
	_is_selected = selected
	_current_level = level
	_update_display()

## Play a celebratory flare and pulse animation on the outline when upgrading
func play_upgrade_pulse(new_level: int, duration: float = 0.50) -> void:
	if not _target or not is_instance_valid(_target):
		return

	_current_level = new_level
	var target_color = get_rarity_color(new_level)
	var target_w = selected_width if _is_selected else idle_width
	var flash_color = Color.WHITE.lerp(target_color, 0.4)

	_init_material()
	_refresh_mesh_cache()

	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()

	_material.next_pass = null
	for mesh in _mesh_cache:
		if is_instance_valid(mesh):
			mesh.material_overlay = _material

	_material.set_shader_parameter("outline_color", flash_color)
	_material.set_shader_parameter("outline_width", upgrade_pulse_width)
	_material.set_shader_parameter("squiggly_enabled", true)

	if is_inside_tree():
		_pulse_tween = create_tween()
		_pulse_tween.set_parallel(true)
		
		# Flare down from pulse width to target width
		_pulse_tween.tween_method(
			func(w: float): if _material: _material.set_shader_parameter("outline_width", w),
			upgrade_pulse_width,
			target_w,
			duration
		).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		# Transition from bright flash to the new rarity color
		_pulse_tween.tween_method(
			func(c: Color): if _material: _material.set_shader_parameter("outline_color", c),
			flash_color,
			target_color,
			duration
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
		_pulse_tween.chain().tween_callback(func(): _update_display())

func clear_highlight() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	if _material:
		_material.next_pass = null
	for mesh in _mesh_cache:
		if is_instance_valid(mesh):
			mesh.material_overlay = null

func _exit_tree() -> void:
	clear_highlight()
