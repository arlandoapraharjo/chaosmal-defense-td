class_name TurretHighlighter
extends Node

## TurretHighlighter
## Manages hover highlighting and persistent RPG rarity outline overlays across placed turrets.
## Level 1 shows a White outline when hovered or selected.
## Levels 2–5 show persistent rarity outlines, plus a second outer White outline layer when hovered.

# RPG Rarity Colors (Levels 1–5: Classic RPG progression with Level 5 Gold as MAX):
const RARITY_COLORS: Dictionary = {
	1: Color(1.0, 1.0, 1.0, 1.0),     # L1: Common - White (Hover / Selection)
	2: Color(0.20, 0.88, 0.35, 1.0),   # L2: Uncommon - Vibrant Emerald Green (Persistent)
	3: Color(0.15, 0.70, 1.0, 1.0),    # L3: Rare - Radiant Azure Blue (Persistent)
	4: Color(0.75, 0.25, 1.0, 1.0),   # L4: Epic - Royal Neon Purple (Persistent)
	5: Color(1.0, 0.80, 0.10, 1.0)    # L5: Legendary (MAX) - Radiant Gold (Persistent)
}

# Squiggle / Hand-Drawn Boil profiles per upgrade level (Levels 2–5)
# Unified speed at 8.0 FPS for consistent, smooth classic hand-drawn rhythm
const UNIFIED_BOIL_FPS: float = 8.0

const RARITY_BOIL_PROFILES: Dictionary = {
	2: { # L2: Uncommon (Green)
		"width": 3.2,
		"selected_width": 4.8,
		"intensity": 0.45,
		"frequency": 10.0,
		"fps": UNIFIED_BOIL_FPS,
		"jitter": 0.8,
		"emission": 0.20
	},
	3: { # L3: Rare (Blue)
		"width": 3.8,
		"selected_width": 5.4,
		"intensity": 0.50,
		"frequency": 12.0,
		"fps": UNIFIED_BOIL_FPS,
		"jitter": 1.0,
		"emission": 0.25
	},
	4: { # L4: Epic (Purple)
		"width": 4.4,
		"selected_width": 6.2,
		"intensity": 0.55,
		"frequency": 14.0,
		"fps": UNIFIED_BOIL_FPS,
		"jitter": 1.2,
		"emission": 0.35
	},
	5: { # L5: Legendary / MAX (Gold)
		"width": 5.0,
		"selected_width": 7.0,
		"intensity": 0.65,
		"frequency": 16.0,
		"fps": UNIFIED_BOIL_FPS,
		"jitter": 1.4,
		"emission": 0.45
	}
}

@export var outline_material_res: ShaderMaterial = preload("res://shaders/outline_material.tres")
@export var idle_width: float = 3.2
@export var selected_width: float = 4.8
@export var hover_extra_width: float = 2.4
@export var upgrade_pulse_width: float = 6.5

var _target: Node3D = null
var _material: ShaderMaterial = null
var _occluded_material: ShaderMaterial = null
var _hover_material: ShaderMaterial = null
var _mesh_cache: Array[MeshInstance3D] = []
var _pulse_tween: Tween = null
var _is_hovered: bool = false
var _is_selected: bool = false
var _current_level: int = 1
var _is_static: bool = false
var _static_color: Color = Color.WHITE
var _static_width: float = 3.2
var _static_enable_xray: bool = false
var _static_max_radius: float = 0.0
var _static_min_height: float = -999.0

func _ready() -> void:
	if _target == null and get_parent() is Node3D:
		_target = get_parent() as Node3D
	_init_material()

func setup(target_node: Node3D, initial_level: int = 1) -> void:
	_target = target_node
	_is_static = false
	_current_level = initial_level
	_mesh_cache.clear()
	_init_material()
	_refresh_mesh_cache()
	_update_display()

## Sets up a static comical outline that is always visible on the target
func setup_static(target_node: Node3D, color: Color = Color(1.0, 1.0, 1.0, 1.0), width: float = 3.2, enable_xray: bool = false) -> void:
	_target = target_node
	_is_static = true
	_static_color = color
	_static_width = width
	_static_enable_xray = enable_xray
	_mesh_cache.clear()
	_init_material()
	_refresh_mesh_cache()
	_apply_static_display()

func _apply_static_display() -> void:
	_init_material()
	_refresh_mesh_cache()
	
	_material.set_shader_parameter("outline_color", _static_color)
	_material.set_shader_parameter("outline_width", _static_width)
	_material.set_shader_parameter("max_radial_distance", 0.0)
	_material.set_shader_parameter("min_height_threshold", -999.0)
	_material.set_shader_parameter("squiggly_enabled", false)
	_material.set_shader_parameter("emission_boost", 0.25)
	
	if _static_enable_xray:
		_occluded_material.set_shader_parameter("silhouette_color", _static_color)
		_occluded_material.set_shader_parameter("silhouette_alpha", 0.70)
		_occluded_material.set_shader_parameter("silhouette_enabled", true)
		_occluded_material.set_shader_parameter("obstacle_clearance_threshold", 2.2)
		_occluded_material.set_shader_parameter("max_radial_distance", 0.0)
		_occluded_material.set_shader_parameter("min_height_threshold", -999.0)
		_occluded_material.next_pass = null
		_material.next_pass = _occluded_material
	else:
		_material.next_pass = null
	
	for mesh in _mesh_cache:
		if is_instance_valid(mesh):
			mesh.material_overlay = _material

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

	if _occluded_material == null:
		_occluded_material = ShaderMaterial.new()
		var occ_sh = load("res://shaders/occluded_silhouette.gdshader") as Shader
		if occ_sh:
			_occluded_material.shader = occ_sh
		_occluded_material.set_shader_parameter("silhouette_alpha", 0.75)
		_occluded_material.set_shader_parameter("obstacle_clearance_threshold", 1.2)
		_occluded_material.render_priority = 1

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
		_hover_material.set_shader_parameter("emission_boost", 0.25)
		_hover_material.render_priority = -1

func _collect_meshes(node: Node, out_list: Array[MeshInstance3D]) -> void:
	if not is_instance_valid(node):
		return
	# Skip UI root, RangeMarker, labels, sprites, or particles if encountered
	if node.name == "TurretUIRoot" or node.name == "RangeMarker" or node.name == "LevelIndicatorPivot" or node.name == "UpgradePivot" or node.name == "HealthBarPivot" or node is GPUParticles3D or node is CPUParticles3D or node is Sprite3D or node is Label3D or node is SubViewport:
		return
	if node is MeshInstance3D:
		out_list.append(node)
	for child in node.get_children():
		_collect_meshes(child, out_list)

func _refresh_mesh_cache() -> void:
	_mesh_cache.clear()
	if _target and is_instance_valid(_target):
		_collect_meshes(_target, _mesh_cache)

## Update display based on current level, hover, and selection state
func _update_display() -> void:
	if _is_static:
		_apply_static_display()
		return

	_init_material()
	_refresh_mesh_cache()

	if _current_level <= 1:
		# Level 1 (Common):
		# Clean, solid White outline if hovered or selected (no squiggly on hover/selection)
		if _is_selected or _is_hovered:
			var target_w = selected_width if _is_selected else idle_width
			_material.set_shader_parameter("outline_color", Color(1.0, 1.0, 1.0, 1.0))
			_material.set_shader_parameter("outline_width", target_w)
			_material.set_shader_parameter("squiggly_enabled", false)
			_material.set_shader_parameter("emission_boost", 0.20)
			
			_occluded_material.set_shader_parameter("silhouette_color", Color(1.0, 1.0, 1.0, 1.0))
			_occluded_material.set_shader_parameter("silhouette_alpha", 0.70)
			_occluded_material.set_shader_parameter("silhouette_enabled", true)
			_occluded_material.next_pass = null
			_material.next_pass = _occluded_material
			
			for mesh in _mesh_cache:
				if is_instance_valid(mesh):
					mesh.material_overlay = _material
		else:
			clear_highlight()
	else:
		# Levels 2–5 (Upgraded):
		# Base layer: Persistent rarity color outline with hand-drawn line boil
		var profile: Dictionary = RARITY_BOIL_PROFILES.get(_current_level, RARITY_BOIL_PROFILES[2])
		var rarity_col = get_rarity_color(_current_level)
		var base_w: float = profile.selected_width if _is_selected else profile.width
		var intensity: float = profile.intensity + (0.15 if _is_selected else 0.0)
		var jitter: float = profile.jitter + (0.3 if _is_selected else 0.0)

		_material.set_shader_parameter("outline_color", rarity_col)
		_material.set_shader_parameter("outline_width", base_w)
		_material.set_shader_parameter("squiggly_enabled", true)
		_material.set_shader_parameter("squiggly_intensity", intensity)
		_material.set_shader_parameter("squiggly_frequency", profile.frequency)
		_material.set_shader_parameter("squiggly_fps", profile.fps)
		_material.set_shader_parameter("squiggly_jitter_amount", jitter)
		_material.set_shader_parameter("emission_boost", profile.emission)

		# Second layer: Occluded see-through silhouette behind obstacles (trees, rocks)
		_occluded_material.set_shader_parameter("silhouette_color", rarity_col)
		_occluded_material.set_shader_parameter("silhouette_alpha", 0.75)
		_occluded_material.set_shader_parameter("silhouette_enabled", true)
		_material.next_pass = _occluded_material

		# Third layer on hover: Outer White outline wrapping the rarity outline (clean solid, no squiggly)
		if _is_hovered:
			_hover_material.set_shader_parameter("outline_color", Color(1.0, 1.0, 1.0, 1.0))
			_hover_material.set_shader_parameter("outline_width", base_w + hover_extra_width)
			_hover_material.set_shader_parameter("squiggly_enabled", false)
			_hover_material.set_shader_parameter("emission_boost", 0.25)
			_occluded_material.next_pass = _hover_material
		else:
			_occluded_material.next_pass = null

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
	var profile: Dictionary = RARITY_BOIL_PROFILES.get(new_level, RARITY_BOIL_PROFILES[2])
	var target_w: float = profile.selected_width if _is_selected else profile.width
	var flash_color = Color.WHITE.lerp(target_color, 0.35)

	_init_material()
	_refresh_mesh_cache()

	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()

	_occluded_material.set_shader_parameter("silhouette_color", target_color)
	_occluded_material.set_shader_parameter("silhouette_alpha", 0.85)
	_occluded_material.set_shader_parameter("silhouette_enabled", true)
	_occluded_material.next_pass = null
	_material.next_pass = _occluded_material

	for mesh in _mesh_cache:
		if is_instance_valid(mesh):
			mesh.material_overlay = _material

	_material.set_shader_parameter("outline_color", flash_color)
	_material.set_shader_parameter("outline_width", upgrade_pulse_width)
	_material.set_shader_parameter("squiggly_enabled", true)
	_material.set_shader_parameter("squiggly_intensity", profile.intensity * 1.4)
	_material.set_shader_parameter("squiggly_frequency", profile.frequency)
	_material.set_shader_parameter("squiggly_fps", profile.fps)
	_material.set_shader_parameter("squiggly_jitter_amount", profile.jitter * 1.4)
	_material.set_shader_parameter("emission_boost", profile.emission * 1.5)

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
	if _occluded_material:
		_occluded_material.next_pass = null
	if _material:
		_material.next_pass = null
	for mesh in _mesh_cache:
		if is_instance_valid(mesh):
			mesh.material_overlay = null

func _exit_tree() -> void:
	clear_highlight()
