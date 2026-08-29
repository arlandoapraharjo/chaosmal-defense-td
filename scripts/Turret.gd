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
static var _ui_texture_cache: Dictionary = {}

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

# Upgrade, placement & economic properties
var turret_level: int = 1
var max_level: int = 5
var base_cost: int = 1
var total_invested_cost: int = 1
var grid_pos: Vector2i = Vector2i.ZERO
var footprint_size: Vector2i = Vector2i(1, 1)
var is_ghost: bool = false
var is_selected: bool = false
var _highlighter: TurretHighlighter = null
var _recycle_lock_timer: float = 0.0
var _base_scale: Vector3 = Vector3.ONE
var _bounce_tween: Tween = null
var _ui_pop_tween: Tween = null

var attack_damage: float = 35.0
var _base_attack_damage: float = 35.0
var _base_attack_range: float = 1.5
var _base_aoe_radius: float = 2.0

# 3D Billboard UI & Selection Nodes
var _ui_root: Node3D = null
var _level_pivot: Node3D = null
var _level_sprite: Sprite3D = null
var _level_shadow_sprite: Sprite3D = null

var _upgrade_pivot: Node3D = null
var _upgrade_banner_sprite: Sprite3D = null
var _upgrade_sprite: Sprite3D = null
var _upgrade_cost_label: Label3D = null
var _upgrade_area: Area3D = null

var _sell_pivot: Node3D = null
var _sell_banner_sprite: Sprite3D = null
var _sell_sprite: Sprite3D = null
var _sell_label: Label3D = null
var _sell_area: Area3D = null

var _body_area: Area3D = null

var _level_textures: Array[Texture2D] = []
var _upgrade_banner_texture: Texture2D = null
var _upgrade_texture: Texture2D = null
var _sell_texture: Texture2D = null

const UPGRADE_CELEBRATION_SCENE := preload("res://scenes/upgrade_celebration_particle.tscn")
const DISMANTLE_PARTICLE_SCENE := preload("res://scenes/turret_dismantle_particle.tscn")

# Hold-to-Recycle (Level 5 Protection)
const RECYCLE_HOLD_DURATION: float = 0.5
var _is_holding_recycle: bool = false
var _recycle_hold_timer: float = 0.0
var _recycle_bar_sprite: Sprite3D = null
var _recycle_bar_mat: ShaderMaterial = null

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
# The node whose position is animated during recoil (barrel if found, else self)
var _recoil_node: Node3D = null

func _ready() -> void:
	_base_scale = scale
	_base_cooldown = cooldown
	_base_attack_damage = attack_damage
	_base_attack_range = attack_range
	_base_aoe_radius = aoe_radius
	total_invested_cost = base_cost
	_auto_detect_weapon_type()
	call_deferred("_capture_initial_facing")
	call_deferred("_find_catapult_arm")
	call_deferred("_find_recoil_barrel")
	# Spread heavy init work across frames to avoid placement lag
	call_deferred("_deferred_init_spread")

func _deferred_init_spread() -> void:
	if is_ghost:
		return
	_setup_3d_ui()
	if is_inside_tree():
		await get_tree().process_frame
	_setup_highlighter()

## Apply a global speed multiplier — faster speed = shorter cooldown = higher fire rate.
func set_speed_multiplier(multiplier: float) -> void:
	var level_cooldown = _base_cooldown * (1.0 - (turret_level - 1) * 0.08)
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
	elif path_or_name.find("ballista") != -1:
		weapon_type = "ballista"
	elif path_or_name.find("catapult") != -1:
		weapon_type = "catapult"
		is_aoe = true
		if min_attack_range <= 0.0:
			min_attack_range = 3.0
	elif path_or_name.find("turret") != -1:
		weapon_type = "turret"

func _get_valid_enemies() -> Array[Node3D]:
	var enemies: Array[Node3D] = EnemyDetector.get_enemies_in_range(self, global_transform.origin, attack_range, min_attack_range)
	if is_half_circle:
		var valid_enemies: Array[Node3D] = []
		for enemy in enemies:
			var dir: Vector3 = (enemy.global_transform.origin - global_transform.origin)
			dir.y = 0.0
			if dir.length_squared() > 0.0001 and dir.normalized().dot(_initial_facing_dir) >= -0.05:
				valid_enemies.append(enemy)
		enemies = valid_enemies
	return enemies

func _process(delta: float) -> void:
	if is_ghost:
		return

	var camera = get_viewport().get_camera_3d()
	if _ui_root and is_instance_valid(_ui_root) and is_selected:
		_ui_root.global_position = global_position
		_update_3d_ui_positions(camera)

	var enemies: Array[Node3D] = _get_valid_enemies()

	if enemies.is_empty():
		_current_target = null
	else:
		# Enemies are sorted by distance ascending in EnemyDetector (closest first)
		_current_target = enemies[0]

	# --- Continuous rotation toward locked target ---
	if is_instance_valid(_current_target):
		_rotate_toward_target(_current_target, delta)

	# --- Hold-to-Recycle Progress Processing (Level 5 Protection) ---
	if _is_holding_recycle:
		var valid_cursor: bool = true
		if camera and is_instance_valid(_sell_sprite):
			var icon_pos = _sell_sprite.global_position
			var sell_screen = camera.unproject_position(icon_pos)
			var mouse_pos = get_viewport().get_mouse_position()
			if mouse_pos.distance_to(sell_screen) > 55.0:
				valid_cursor = false
		if not valid_cursor or not is_selected or not is_inside_tree() or turret_level < max_level:
			_cancel_recycle_hold()
		else:
			_recycle_hold_timer += delta
			var progress: float = clampf(_recycle_hold_timer / RECYCLE_HOLD_DURATION, 0.0, 1.0)
			if _recycle_bar_mat:
				_recycle_bar_mat.set_shader_parameter("progress", progress)
			if _recycle_bar_sprite:
				_recycle_bar_sprite.visible = true
			if _sell_sprite:
				var press_scale = 1.0 - progress * 0.12 # Tactile press-in while charging
				_sell_sprite.scale = Vector3(press_scale, press_scale, press_scale)
			
			if _recycle_hold_timer >= RECYCLE_HOLD_DURATION:
				_cancel_recycle_hold()
				sell()
				return

	if _recycle_lock_timer > 0.0:
		_recycle_lock_timer -= delta

	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta
		return

	if enemies.is_empty() or _current_target == null:
		return

	if is_aoe:
		_trigger_aoe_attack(enemies)
	else:
		_trigger_single_target_attack(_current_target)

	_cooldown_timer = cooldown

# Smoothly rotate the turret (Y-axis only) to face the target.
func _rotate_toward_target(target: Node3D, delta: float) -> void:
	if scale.length_squared() < 0.001:
		return
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

# ── 3D UI & Selection System ──────────────────────────────────────────────────

static func _load_texture_file(res_path: String) -> Texture2D:
	if ResourceLoader.exists(res_path):
		var res = load(res_path)
		if res is Texture2D:
			return res
	var global_p = ProjectSettings.globalize_path(res_path)
	var check_path = global_p if FileAccess.file_exists(global_p) else res_path
	if FileAccess.file_exists(check_path):
		var img = Image.load_from_file(check_path)
		if img and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null

func _load_ui_textures() -> void:
	# Use static cache — textures load from disk only once across all turrets
	if _ui_texture_cache.has("loaded"):
		_level_textures = _ui_texture_cache.get("level_textures", []).duplicate()
		_upgrade_banner_texture = _ui_texture_cache.get("upgrade_banner", null)
		_upgrade_texture = _ui_texture_cache.get("upgrade", null)
		_sell_texture = _ui_texture_cache.get("sell", null)
		return
	
	_level_textures.clear()
	for i in range(1, 6):
		var tex = _load_texture_file("res://UI/Level Up - Indicator/turret_level_%d.png" % i)
		if not tex:
			tex = _load_texture_file("res://UI/Level Up - Indicator/turret_level_%d.gif" % i)
		if tex:
			_level_textures.append(tex)
	_upgrade_banner_texture = _load_texture_file("res://UI/Level Up - Indicator/upbutton_banner.png")
	_upgrade_texture = _load_texture_file("res://UI/Level Up - Indicator/upgrade_buttonnew.png")
	if not _upgrade_texture:
		_upgrade_texture = _load_texture_file("res://UI/Level Up - Indicator/lvl_up.png")
	_sell_texture = _load_texture_file("res://UI/Level Up - Indicator/trash_button.png")
	
	# Cache for future turrets
	_ui_texture_cache["level_textures"] = _level_textures.duplicate()
	_ui_texture_cache["upgrade_banner"] = _upgrade_banner_texture
	_ui_texture_cache["upgrade"] = _upgrade_texture
	_ui_texture_cache["sell"] = _sell_texture
	_ui_texture_cache["loaded"] = true

func _setup_highlighter() -> void:
	if is_ghost:
		return
	if _highlighter == null or not is_instance_valid(_highlighter):
		_highlighter = TurretHighlighter.new()
		_highlighter.name = "TurretHighlighter"
		add_child(_highlighter)
		_highlighter.setup(self, turret_level)
		if is_selected:
			_highlighter.set_selected(true, turret_level)

func _setup_3d_ui() -> void:
	if is_ghost:
		return
	
	_load_ui_textures()
	
	_ui_root = Node3D.new()
	_ui_root.name = "TurretUIRoot"
	_ui_root.top_level = true
	add_child(_ui_root)
	if is_inside_tree():
		_ui_root.global_position = global_position
	
	var base_h: float = 1.4
	if scale.y > 1.5:
		base_h = 2.0 # Scale for larger heavy turrets
	
	# 1. Level Badge (Top Center)
	_level_pivot = Node3D.new()
	_level_pivot.name = "LevelPivot"
	_level_pivot.visible = false
	_ui_root.add_child(_level_pivot)
	
	_level_shadow_sprite = Sprite3D.new()
	_level_shadow_sprite.name = "LevelShadow"
	_level_shadow_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_level_shadow_sprite.no_depth_test = true
	_level_shadow_sprite.render_priority = 9
	_level_shadow_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_level_shadow_sprite.pixel_size = 0.008
	_level_shadow_sprite.modulate = Color(0.0, 0.0, 0.0, 0.6)
	_level_shadow_sprite.position = Vector3(0.015, -0.015, -0.01)
	_level_pivot.add_child(_level_shadow_sprite)
	
	_level_sprite = Sprite3D.new()
	_level_sprite.name = "LevelSprite"
	_level_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_level_sprite.no_depth_test = true
	_level_sprite.render_priority = 10
	_level_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_level_sprite.pixel_size = 0.008
	_level_pivot.add_child(_level_sprite)
	
	# 2. Upgrade Button & Cost Label Banner (Bottom Right)
	_upgrade_pivot = Node3D.new()
	_upgrade_pivot.name = "UpgradePivot"
	_upgrade_pivot.visible = false
	_ui_root.add_child(_upgrade_pivot)
	
	# Background Banner
	_upgrade_banner_sprite = Sprite3D.new()
	_upgrade_banner_sprite.name = "UpgradeBanner"
	_upgrade_banner_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_upgrade_banner_sprite.no_depth_test = true
	_upgrade_banner_sprite.render_priority = 9
	_upgrade_banner_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_upgrade_banner_sprite.pixel_size = 0.008
	if _upgrade_banner_texture:
		_upgrade_banner_sprite.texture = _upgrade_banner_texture
	_upgrade_pivot.add_child(_upgrade_banner_sprite)
	
	# Circular Upgrade Button Icon (Left slot of banner, -9px 2D billboard offset)
	_upgrade_sprite = Sprite3D.new()
	_upgrade_sprite.name = "UpgradeSprite"
	_upgrade_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_upgrade_sprite.no_depth_test = true
	_upgrade_sprite.render_priority = 10
	_upgrade_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_upgrade_sprite.pixel_size = 0.008
	_upgrade_sprite.position = Vector3(0, 0, 0.005)
	_upgrade_sprite.offset = Vector2(-9, 0)
	if _upgrade_texture:
		_upgrade_sprite.texture = _upgrade_texture
	_upgrade_pivot.add_child(_upgrade_sprite)
	
	# Cost Label (Right slot of banner, vertically stacked: Coin on top, Cost number below)
	_upgrade_cost_label = Label3D.new()
	_upgrade_cost_label.name = "UpgradeCostLabel"
	_upgrade_cost_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_upgrade_cost_label.no_depth_test = true
	_upgrade_cost_label.render_priority = 11
	_upgrade_cost_label.position = Vector3(0, 0, 0.01)
	_upgrade_cost_label.offset = Vector2(30, 0)
	_upgrade_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_upgrade_cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_upgrade_cost_label.line_spacing = 0.0
	_upgrade_cost_label.font_size = 14
	_upgrade_cost_label.outline_size = 3
	_upgrade_cost_label.modulate = Color(1.0, 0.9, 0.3, 1.0)
	_upgrade_cost_label.outline_modulate = Color(0, 0, 0, 1.0)
	_upgrade_pivot.add_child(_upgrade_cost_label)
	
	# Clickable / Hover Area strictly over the circular button icon
	var up_area = Area3D.new()
	up_area.name = "UpgradeArea"
	up_area.position = Vector3(-0.116, 0, 0)
	var up_col = CollisionShape3D.new()
	var up_box = BoxShape3D.new()
	up_box.size = Vector3(0.35, 0.35, 0.35)
	up_col.shape = up_box
	up_area.add_child(up_col)
	_upgrade_pivot.add_child(up_area)
	_upgrade_area = up_area
	# input_event NOT connected — screen-space _input() handles clicks
	_upgrade_area.mouse_entered.connect(_on_upgrade_area_mouse_entered)
	_upgrade_area.mouse_exited.connect(_on_upgrade_area_mouse_exited)
	
	# 3. Sell / Recycle Button (Bottom Left)
	_sell_pivot = Node3D.new()
	_sell_pivot.name = "SellPivot"
	_sell_pivot.visible = false
	_ui_root.add_child(_sell_pivot)
	
	# Background Banner
	_sell_banner_sprite = Sprite3D.new()
	_sell_banner_sprite.name = "SellBanner"
	_sell_banner_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sell_banner_sprite.no_depth_test = true
	_sell_banner_sprite.render_priority = 9
	_sell_banner_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sell_banner_sprite.pixel_size = 0.008
	if _upgrade_banner_texture:
		_sell_banner_sprite.texture = _upgrade_banner_texture
	_sell_pivot.add_child(_sell_banner_sprite)
	
	# Trash / Recycle Button Icon (Left slot of banner, -9px 2D billboard offset)
	_sell_sprite = Sprite3D.new()
	_sell_sprite.name = "SellSprite"
	_sell_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sell_sprite.no_depth_test = true
	_sell_sprite.render_priority = 10
	_sell_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sell_sprite.pixel_size = 0.008
	_sell_sprite.position = Vector3(0, 0, 0.005)
	_sell_sprite.offset = Vector2(-9, 0)
	if _sell_texture:
		_sell_sprite.texture = _sell_texture
	_sell_pivot.add_child(_sell_sprite)
	
	# Horizontal Progress Charge Bar (Level 5 Hold-to-Recycle - Positioned on Top of Banner)
	_recycle_bar_sprite = Sprite3D.new()
	_recycle_bar_sprite.name = "RecycleBarSprite"
	_recycle_bar_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_recycle_bar_sprite.no_depth_test = true
	_recycle_bar_sprite.render_priority = 25
	_recycle_bar_sprite.sorting_offset = 5.0
	_recycle_bar_sprite.pixel_size = 0.007
	_recycle_bar_sprite.position = Vector3(0, 0.28, 0.02)
	_recycle_bar_sprite.offset = Vector2(0, 0)
	
	var bar_img = Image.create(64, 12, false, Image.FORMAT_RGBA8)
	bar_img.fill(Color.WHITE)
	_recycle_bar_sprite.texture = ImageTexture.create_from_image(bar_img)
	
	var bar_sh = Shader.new()
	bar_sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 bg_color : source_color = vec4(0.05, 0.06, 0.09, 0.95);
uniform vec4 fill_start : source_color = vec4(0.2, 0.95, 1.0, 1.0);
uniform vec4 fill_end : source_color = vec4(1.0, 0.35, 0.2, 1.0);
uniform vec4 border_color : source_color = vec4(0.35, 0.45, 0.60, 1.0);

void vertex() {
	// Full camera billboard matching BaseMaterial3D.BILLBOARD_ENABLED
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
		INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
		INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz),
		MODEL_MATRIX[3]
	);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 uv = UV;
	float aspect = 64.0 / 12.0;
	vec2 p = vec2((uv.x - 0.5) * aspect, uv.y - 0.5);
	float radius = 0.42;
	float half_w = (aspect - 1.0) * 0.5;
	float d = length(vec2(max(abs(p.x) - half_w, 0.0), p.y)) - radius;
	
	if (d > 0.0) {
		discard;
	}
	
	// Rounded border stroke
	if (d > -0.08) {
		ALBEDO = border_color.rgb;
		ALPHA = border_color.a;
	} else {
		// Interior fill
		float fill_x = clamp((uv.x - 0.04) / 0.92, 0.0, 1.0);
		if (fill_x <= progress && progress > 0.001) {
			vec4 col = mix(fill_start, fill_end, progress);
			float shine = clamp((0.5 - abs(uv.y - 0.3)) * 0.4, 0.0, 0.3);
			ALBEDO = col.rgb + vec3(shine);
			ALPHA = col.a;
		} else {
			ALBEDO = bg_color.rgb;
			ALPHA = bg_color.a;
		}
	}
}
"""
	_recycle_bar_mat = ShaderMaterial.new()
	_recycle_bar_mat.shader = bar_sh
	_recycle_bar_mat.render_priority = 25
	_recycle_bar_mat.set_shader_parameter("progress", 0.0)
	_recycle_bar_sprite.material_override = _recycle_bar_mat
	_recycle_bar_sprite.visible = false
	_sell_pivot.add_child(_recycle_bar_sprite)
	
	# Refund Label (Right slot of banner, vertically stacked: Coin on top, Refund number below)
	_sell_label = Label3D.new()
	_sell_label.name = "SellLabel"
	_sell_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sell_label.no_depth_test = true
	_sell_label.render_priority = 11
	_sell_label.position = Vector3(0, 0, 0.01)
	_sell_label.offset = Vector2(30, 0)
	_sell_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sell_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sell_label.line_spacing = 0.0
	_sell_label.font_size = 14
	_sell_label.outline_size = 3
	_sell_label.modulate = Color(0.4, 0.9, 1.0, 1.0)
	_sell_label.outline_modulate = Color(0, 0, 0, 1.0)
	_sell_pivot.add_child(_sell_label)
	
	var sell_area = Area3D.new()
	sell_area.name = "SellArea"
	sell_area.position = Vector3(-0.072, 0, 0)
	var sell_col = CollisionShape3D.new()
	var sell_box = BoxShape3D.new()
	sell_box.size = Vector3(0.35, 0.35, 0.35)
	sell_col.shape = sell_box
	sell_area.add_child(sell_col)
	_sell_pivot.add_child(sell_area)
	_sell_area = sell_area
	# input_event NOT connected — screen-space _input() handles clicks
	_sell_area.mouse_entered.connect(_on_sell_area_mouse_entered)
	_sell_area.mouse_exited.connect(_on_sell_area_mouse_exited)
	
	# 4. Clickable Body Area for Selecting Turret (AABB-based Box Hitbox)
	# Uses a fast AABB union instead of expensive per-mesh convex hull generation
	_body_area = Area3D.new()
	_body_area.name = "TurretBodyArea"
	
	var meshes: Array[MeshInstance3D] = []
	_collect_mesh_instances(self, meshes)
	var combined_aabb: AABB = AABB()
	var has_aabb: bool = false
	for m in meshes:
		if m.mesh:
			var mesh_aabb = m.mesh.get_aabb()
			var rel_xform = global_transform.affine_inverse() * m.global_transform
			var transformed_aabb = rel_xform * mesh_aabb
			if not has_aabb:
				combined_aabb = transformed_aabb
				has_aabb = true
			else:
				combined_aabb = combined_aabb.merge(transformed_aabb)
	
	var body_col = CollisionShape3D.new()
	var body_box = BoxShape3D.new()
	if has_aabb:
		body_box.size = combined_aabb.size
		body_col.position = combined_aabb.position + combined_aabb.size * 0.5
	else:
		body_box.size = Vector3(0.85, base_h, 0.85)
		body_col.position = Vector3(0, base_h / 2.0, 0)
	body_col.shape = body_box
	_body_area.add_child(body_col)
	
	add_child(_body_area)
	_body_area.input_event.connect(_on_body_area_input_event)
	_body_area.mouse_entered.connect(_on_body_area_mouse_entered)
	_body_area.mouse_exited.connect(_on_body_area_mouse_exited)
	
	_update_3d_ui()

func _on_body_area_mouse_entered() -> void:
	if is_ghost:
		return
	var builder = get_tree().get_first_node_in_group("builder_controller")
	if not builder:
		builder = get_node_or_null("/root/World/BuilderController")
	if builder and builder.get("_is_building") == true:
		return
	if not _highlighter or not is_instance_valid(_highlighter):
		_setup_highlighter()
	if _highlighter and is_instance_valid(_highlighter):
		_highlighter.set_hovered(true)

func _on_body_area_mouse_exited() -> void:
	if is_ghost:
		return
	if _highlighter and is_instance_valid(_highlighter):
		_highlighter.set_hovered(false)

func _on_body_area_input_event(camera: Camera3D, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if is_ghost:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var builder = get_tree().get_first_node_in_group("builder_controller")
		if not builder:
			builder = get_node_or_null("/root/World/BuilderController")
		if builder:
			if builder.get("_is_building") == true:
				return
			if builder.has_method("select_turret"):
				builder.select_turret(self)
				if is_inside_tree() and get_viewport():
					get_viewport().set_input_as_handled()
				return
		set_selected(not is_selected)
		if is_inside_tree() and get_viewport():
			get_viewport().set_input_as_handled()

func _update_3d_ui_positions(camera: Camera3D = null) -> void:
	if not _ui_root or not is_instance_valid(_ui_root):
		return
	if not camera:
		camera = get_viewport().get_camera_3d()
	if not camera:
		return
		
	var cam_basis = camera.global_transform.basis
	var cam_right = cam_basis.x.normalized()
	var cam_up = cam_basis.y.normalized()
	var cam_fwd = -cam_basis.z.normalized()
	
	var base_h: float = 1.05
	if scale.y > 1.5:
		base_h = 1.50
		
	var base_top = global_position + Vector3(0, base_h, 0)
	
	# Upgrade button: Right Side (beside turret body)
	if _upgrade_pivot and is_instance_valid(_upgrade_pivot):
		_upgrade_pivot.global_position = base_top + cam_right * 0.70 - cam_up * 0.35 + cam_fwd * 0.10
		
	# Sell button: Right Side (takes upper slot if max level, otherwise lower slot)
	if _sell_pivot and is_instance_valid(_sell_pivot):
		var sell_up_offset: float = -0.35 if turret_level >= max_level else -0.72
		_sell_pivot.global_position = base_top + cam_right * 0.70 + cam_up * sell_up_offset + cam_fwd * 0.10

	# Standing level banner: Right Side of Upgrade & Sell buttons (fixed vertical position)
	if _level_pivot and is_instance_valid(_level_pivot):
		_level_pivot.global_position = base_top + cam_right * 1.15 - cam_up * 0.535 + cam_fwd * 0.10

func _update_3d_ui() -> void:
	if is_ghost or not is_instance_valid(_level_pivot):
		return
	
	# Update level badge texture
	if _level_sprite and not _level_textures.is_empty():
		var idx = clamp(turret_level - 1, 0, _level_textures.size() - 1)
		var tex = _level_textures[idx]
		_level_sprite.texture = tex
		if _level_shadow_sprite:
			_level_shadow_sprite.texture = tex
	
	# Update upgrade cost label and visibility
	if _upgrade_cost_label:
		if turret_level >= max_level:
			_upgrade_cost_label.text = "MAX"
			_upgrade_cost_label.modulate = Color(0.6, 0.8, 1.0)
			if _upgrade_pivot:
				_upgrade_pivot.visible = false
		else:
			var cost = get_upgrade_cost()
			_upgrade_cost_label.text = "🪙\n%d" % cost
			_upgrade_cost_label.modulate = Color(1.0, 0.9, 0.3)
	
	# Update sell refund label
	if _sell_label:
		var refund = get_sell_refund()
		_sell_label.text = "🪙\n+%d" % refund

func _set_ui_visible(show: bool) -> void:
	if is_ghost:
		return
	
	# Kill any existing UI animation tweens
	if _ui_pop_tween and _ui_pop_tween.is_valid():
		_ui_pop_tween.kill()
	
	if show:
		# Subnautica-style staggered pop-in: each element scales from 0 → overshoot → settle
		_ui_pop_tween = create_tween()
		_ui_pop_tween.set_parallel(true)
		
		# Level badge pops in first (delay 0.0s)
		if _level_pivot and is_instance_valid(_level_pivot):
			_level_pivot.visible = true
			_level_pivot.scale = Vector3.ZERO
			_ui_pop_tween.tween_property(_level_pivot, "scale", Vector3(1.12, 1.12, 1.12), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.0)
		
		# Upgrade button pops in second (delay 0.04s)
		if _upgrade_pivot and is_instance_valid(_upgrade_pivot) and turret_level < max_level:
			_upgrade_pivot.visible = true
			_upgrade_pivot.scale = Vector3.ZERO
			_ui_pop_tween.tween_property(_upgrade_pivot, "scale", Vector3(1.12, 1.12, 1.12), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.04)
		
		# Sell button pops in third (delay 0.08s)
		if _sell_pivot and is_instance_valid(_sell_pivot):
			_sell_pivot.visible = true
			_sell_pivot.scale = Vector3.ZERO
			_ui_pop_tween.tween_property(_sell_pivot, "scale", Vector3(1.12, 1.12, 1.12), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.08)
		
		# Settle all elements to exactly 1.0 after the overshoot
		_ui_pop_tween.chain().set_parallel(true)
		if _level_pivot and is_instance_valid(_level_pivot):
			_ui_pop_tween.tween_property(_level_pivot, "scale", Vector3.ONE, 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		if _upgrade_pivot and is_instance_valid(_upgrade_pivot) and turret_level < max_level:
			_ui_pop_tween.tween_property(_upgrade_pivot, "scale", Vector3.ONE, 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		if _sell_pivot and is_instance_valid(_sell_pivot):
			_ui_pop_tween.tween_property(_sell_pivot, "scale", Vector3.ONE, 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		_cancel_recycle_hold()
		# Smooth pop-out: shrink to 0 then hide
		_ui_pop_tween = create_tween()
		_ui_pop_tween.set_parallel(true)
		
		if _level_pivot and is_instance_valid(_level_pivot) and _level_pivot.visible:
			_ui_pop_tween.tween_property(_level_pivot, "scale", Vector3.ZERO, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		if _upgrade_pivot and is_instance_valid(_upgrade_pivot) and _upgrade_pivot.visible:
			_ui_pop_tween.tween_property(_upgrade_pivot, "scale", Vector3.ZERO, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN).set_delay(0.02)
		if _sell_pivot and is_instance_valid(_sell_pivot) and _sell_pivot.visible:
			_ui_pop_tween.tween_property(_sell_pivot, "scale", Vector3.ZERO, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN).set_delay(0.04)
		
		# Hide after shrink completes
		_ui_pop_tween.chain().tween_callback(func():
			if _level_pivot and is_instance_valid(_level_pivot):
				_level_pivot.visible = false
			if _upgrade_pivot and is_instance_valid(_upgrade_pivot):
				_upgrade_pivot.visible = false
			if _sell_pivot and is_instance_valid(_sell_pivot):
				_sell_pivot.visible = false
		)

func _cancel_recycle_hold() -> void:
	_is_holding_recycle = false
	_recycle_hold_timer = 0.0
	if _recycle_bar_mat:
		_recycle_bar_mat.set_shader_parameter("progress", 0.0)
	if _recycle_bar_sprite:
		_recycle_bar_sprite.visible = false
	if _sell_sprite and is_inside_tree():
		_sell_sprite.scale = Vector3.ONE

func set_selected(selected: bool) -> void:
	if is_ghost:
		return
	is_selected = selected
	_set_ui_visible(selected)
	if not selected:
		_cancel_recycle_hold()
	
	if not _highlighter or not is_instance_valid(_highlighter):
		_setup_highlighter()
		
	if _highlighter and is_instance_valid(_highlighter):
		_highlighter.set_selected(selected, turret_level)

# ── Screen-Space Precise Click Engine ──────────────────────────────────────────
# Uses _input (not _unhandled_input) so it fires BEFORE Area3D signals can
# consume the event. The upgrade/sell pivots are pure visual nodes — their
# Area3D's are only kept for hover animations, not for click detection.

func _input(event: InputEvent) -> void:
	if is_ghost or not is_selected:
		if _is_holding_recycle:
			_cancel_recycle_hold()
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			# Left mouse released -> cancel hold if active
			if _is_holding_recycle:
				_cancel_recycle_hold()
			return

		var camera = get_viewport().get_camera_3d()
		if not camera:
			return
		var click_pos: Vector2 = event.position
		var builder = get_tree().get_first_node_in_group("builder_controller")
		if not builder:
			builder = get_node_or_null("/root/World/BuilderController")
		
		# 1. Upgrade Button Click — check first, highest priority (hits circular icon)
		if _upgrade_pivot and is_instance_valid(_upgrade_pivot) and _upgrade_pivot.visible and turret_level < max_level:
			var icon_pos = _upgrade_sprite.global_position if is_instance_valid(_upgrade_sprite) else _upgrade_pivot.global_position
			var up_screen = camera.unproject_position(icon_pos)
			if click_pos.distance_to(up_screen) <= 40.0:
				if builder and builder.has_method("notify_turret_interacted"):
					builder.notify_turret_interacted()
				if _upgrade_pivot and is_inside_tree():
					var tw = create_tween()
					tw.tween_property(_upgrade_pivot, "scale", Vector3(0.85, 0.85, 0.85), 0.05)
					tw.tween_property(_upgrade_pivot, "scale", Vector3(1.1, 1.1, 1.1), 0.12).set_trans(Tween.TRANS_BACK)
				var success = TurretUpgradeManager.instance.try_upgrade_turret(self) if TurretUpgradeManager.instance else upgrade()
				if not success:
					_flash_insufficient_funds()
				if is_inside_tree() and get_viewport():
					get_viewport().set_input_as_handled()
				return
		
		# 2. Recycle / Sell Button Click (hits circular trash icon)
		if _sell_pivot and is_instance_valid(_sell_pivot) and _sell_pivot.visible:
			var icon_pos = _sell_sprite.global_position if is_instance_valid(_sell_sprite) else _sell_pivot.global_position
			var sell_screen = camera.unproject_position(icon_pos)
			if click_pos.distance_to(sell_screen) <= 40.0:
				if is_inside_tree() and get_viewport():
					get_viewport().set_input_as_handled()
				if builder and builder.has_method("notify_turret_interacted"):
					builder.notify_turret_interacted()
				
				if turret_level >= max_level:
					# Level 5 requires 0.6s hold to confirm
					_is_holding_recycle = true
					_recycle_hold_timer = 0.0
					if _recycle_bar_sprite:
						_recycle_bar_sprite.visible = true
					if _recycle_bar_mat:
						_recycle_bar_mat.set_shader_parameter("progress", 0.0)
					return
				else:
					# Levels 1-4: Instant click
					if _sell_pivot and is_inside_tree():
						var tw = create_tween()
						tw.tween_property(_sell_pivot, "scale", Vector3(0.85, 0.85, 0.85), 0.05)
						tw.tween_property(_sell_pivot, "scale", Vector3(1.1, 1.1, 1.1), 0.12).set_trans(Tween.TRANS_BACK)
					sell()
					return

# ── Upgrade & Sell Logic ───────────────────────────────────────────────────────

func get_upgrade_cost() -> int:
	if turret_level >= max_level:
		return 0
	return TurretUpgradeManager.calculate_upgrade_cost(base_cost, turret_level)

func upgrade() -> bool:
	if turret_level >= max_level:
		return false
	
	var cost = get_upgrade_cost()
	total_invested_cost += cost
	turret_level += 1
	_recalculate_stats()
	_update_3d_ui()
	
	# 1. Outline Rarity Flare Pulse
	if _highlighter and is_instance_valid(_highlighter):
		_highlighter.play_upgrade_pulse(turret_level)
		
	# 2. 3D Sparkle Particle Burst tinted to rarity color
	_spawn_upgrade_celebration()
	
	# 3. Model Squash-and-Stretch Spring Bounce Animation
	_play_upgrade_bounce()
	
	# Activate click protection when reaching max level
	if turret_level >= max_level:
		_recycle_lock_timer = 0.5
	
	return true

func _spawn_upgrade_celebration() -> void:
	if UPGRADE_CELEBRATION_SCENE:
		var part = UPGRADE_CELEBRATION_SCENE.instantiate()
		var scene_root = get_tree().current_scene
		if scene_root:
			scene_root.add_child(part)
		else:
			get_parent().add_child(part)
		part.global_position = global_position + Vector3(0, 0.2, 0)
		if part.has_method("setup_color"):
			var rarity_color = TurretHighlighter.get_rarity_color(turret_level)
			part.setup_color(rarity_color)

func _play_upgrade_bounce() -> void:
	if is_inside_tree():
		if _bounce_tween and _bounce_tween.is_valid():
			_bounce_tween.kill()
		scale = _base_scale
		_bounce_tween = create_tween()
		# Phase 1: Quick anticipation squash
		_bounce_tween.tween_property(self, "scale", Vector3(_base_scale.x * 1.20, _base_scale.y * 0.80, _base_scale.z * 1.20), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		# Phase 2: Overshoot stretch upwards
		_bounce_tween.tween_property(self, "scale", Vector3(_base_scale.x * 0.92, _base_scale.y * 1.15, _base_scale.z * 0.92), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		# Phase 3: Settle smoothly back to original base scale
		_bounce_tween.tween_property(self, "scale", _base_scale, 0.18).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

## Subtle micro-thud when turret is placed down on the map
func play_placement_landing_animation() -> void:
	if is_inside_tree():
		if _bounce_tween and _bounce_tween.is_valid():
			_bounce_tween.kill()
		scale = _base_scale
		_bounce_tween = create_tween()
		# Gentle 5% landing compress
		_bounce_tween.tween_property(self, "scale", Vector3(_base_scale.x * 1.04, _base_scale.y * 0.95, _base_scale.z * 1.04), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		# Smooth settle back to base scale
		_bounce_tween.tween_property(self, "scale", _base_scale, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _recalculate_stats() -> void:
	attack_damage = _base_attack_damage * (1.0 + (turret_level - 1) * 0.30)
	
	# Attack range scaling (+5% at lvl 3, +10% total at lvl 5)
	var range_mult: float = 1.0
	if turret_level >= 5:
		range_mult = 1.10
	elif turret_level >= 3:
		range_mult = 1.05
	attack_range = _base_attack_range * range_mult
	
	# AoE radius scaling (+10% per level)
	if is_aoe:
		aoe_radius = _base_aoe_radius * (1.0 + (turret_level - 1) * 0.10)
	
	# Current global speed multiplier
	var current_multiplier = 1.0
	var speed_toggle = SpeedToggle.instance if SpeedToggle.instance else get_tree().get_first_node_in_group("speed_toggle")
	if speed_toggle and speed_toggle.has_method("get_current_multiplier"):
		current_multiplier = speed_toggle.get_current_multiplier()
		
	var level_cooldown: float = _base_cooldown * (1.0 - (turret_level - 1) * 0.08)
	cooldown = level_cooldown / max(current_multiplier, 0.1)

func get_sell_refund() -> int:
	return TurretUpgradeManager.calculate_sell_refund(total_invested_cost)

func sell() -> void:
	var refund = get_sell_refund()
	if CurrencyManager.instance:
		CurrencyManager.instance.add_currency(refund)
	
	# Free grid cells in map generator
	var map_gen = get_parent()
	if map_gen and map_gen.has_method("free_cell"):
		for dx in range(footprint_size.x):
			for dz in range(footprint_size.y):
				map_gen.free_cell(grid_pos + Vector2i(dx, dz))
				
	var builder = get_tree().get_first_node_in_group("builder_controller")
	if not builder:
		builder = get_node_or_null("/root/World/BuilderController")
	if builder and builder.has_method("on_turret_sold"):
		builder.on_turret_sold(self)
		
	if TurretUpgradeManager.instance:
		TurretUpgradeManager.instance.turret_sold.emit(self, refund)
		
	# Spawn dismantle particle effect at turret position before shrinking
	_spawn_dismantle_particle()
	
	# Quick shrink effect and queue_free
	var tw = create_tween()
	tw.tween_property(self, "scale", Vector3(0.001, 0.001, 0.001), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)

func _spawn_dismantle_particle() -> void:
	if DISMANTLE_PARTICLE_SCENE:
		var part = DISMANTLE_PARTICLE_SCENE.instantiate()
		var scene_root = get_tree().current_scene
		if scene_root:
			scene_root.add_child(part)
		else:
			get_parent().add_child(part)
		part.global_position = global_position + Vector3(0, 0.15, 0)


func _flash_insufficient_funds() -> void:
	if _upgrade_cost_label and is_inside_tree():
		var tw = create_tween()
		tw.tween_property(_upgrade_cost_label, "modulate", Color(1.0, 0.2, 0.2, 1.0), 0.08)
		tw.tween_property(_upgrade_cost_label, "modulate", Color(1.0, 0.9, 0.3, 1.0), 0.35)

# Note: _on_upgrade_area_input_event and _on_sell_area_input_event are intentionally
# removed — click detection is handled by the screen-space engine in _input().
# The Area3Ds below are kept ONLY for hover scale animations.

func _on_upgrade_area_mouse_entered() -> void:
	if is_ghost or not is_selected:
		return
	if turret_level < max_level and _upgrade_pivot:
		var tw = create_tween()
		tw.tween_property(_upgrade_pivot, "scale", Vector3(1.1, 1.1, 1.1), 0.1).set_trans(Tween.TRANS_QUAD)

func _on_upgrade_area_mouse_exited() -> void:
	if is_ghost or not is_selected:
		return
	if _upgrade_pivot:
		var tw = create_tween()
		tw.tween_property(_upgrade_pivot, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_QUAD)

func _on_sell_area_mouse_entered() -> void:
	if is_ghost or not is_selected:
		return
	if _sell_pivot:
		var tw = create_tween()
		tw.tween_property(_sell_pivot, "scale", Vector3(1.1, 1.1, 1.1), 0.1).set_trans(Tween.TRANS_QUAD)

func _on_sell_area_mouse_exited() -> void:
	if is_ghost or not is_selected:
		return
	if _sell_pivot:
		var tw = create_tween()
		tw.tween_property(_sell_pivot, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_QUAD)


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


	var current_weapon_type: String = weapon_type
	var current_damage: float = attack_damage
	var current_aoe_radius: float = aoe_radius
	var hit_scene: PackedScene = _hit_particle_scenes.get(current_weapon_type, _hit_particle_scenes.get("turret", null))
	var parent_for_hit: Node = scene_root if scene_root else get_parent()

	var tween: Tween = ammo_instance.create_tween()
	if current_weapon_type == "catapult":
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
		if is_instance_valid(parent_for_hit) and hit_scene:
			var hit_part = hit_scene.instantiate()
			parent_for_hit.add_child(hit_part)
			if current_weapon_type == "catapult":
				hit_part.global_position = Vector3(target_pos.x, 0.0, target_pos.z)
			else:
				hit_part.global_position = target_pos + Vector3(0, 0.3, 0)

		if is_instance_valid(target_enemy) and target_enemy.has_method("take_damage"):
			target_enemy.take_damage(current_damage)
		elif not aoe_enemies.is_empty():
			# Re-check enemy positions at impact time — only damage those
			# actually near the impact point, not every enemy in turret range.
			var aoe_radius_sq: float = current_aoe_radius * current_aoe_radius
			for enemy in aoe_enemies:
				if is_instance_valid(enemy) and enemy.has_method("take_damage"):
					var dist_sq: float = enemy.global_transform.origin.distance_squared_to(target_pos)
					if dist_sq <= aoe_radius_sq:
						enemy.take_damage(current_damage)

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

# ── Recoil Animation ────────────────────────────────────────────────────────

var _base_position: Vector3 = Vector3.ZERO
var _has_base_position: bool = false

## Locate the barrel/arrow child node so recoil only moves the gun, not the base.
## Turret/cannon models have: Root -> base mesh -> "barrel" mesh.
## Ballista models have: Root -> base mesh -> "arrow" mesh.
## If no match is found, _recoil_node stays null and we fall back to self.
func _find_recoil_barrel() -> void:
	if weapon_type == "catapult":
		return
	# Search for the gun/projectile child node (case-insensitive)
	var barrel_keywords: Array[String] = ["barrel", "arrow", "gun", "turret_top", "cannon_body"]
	for keyword in barrel_keywords:
		var found: Node = _find_child_by_keyword(self, keyword)
		if found and found is Node3D:
			_recoil_node = found as Node3D
			return

## Push-back recoil for turret, cannon, and ballista.
## Slides the barrel backward away from the target, then springs back.
## The base platform stays completely stationary.
func _play_recoil(target_pos: Vector3 = Vector3.ZERO) -> void:
	# Determine which node to animate: barrel if found, otherwise self (fallback)
	var anim_node: Node3D = _recoil_node if is_instance_valid(_recoil_node) else self

	if not _has_base_position:
		_base_position = anim_node.position
		_has_base_position = true

	if _recoil_tween and _recoil_tween.is_valid():
		_recoil_tween.kill()
		anim_node.position = _base_position

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
	# Convert world-space recoil direction into the animated node's parent local space
	var parent_node: Node3D = anim_node.get_parent() as Node3D if anim_node.get_parent() is Node3D else null
	var parent_basis: Basis = parent_node.global_transform.basis if parent_node else Basis.IDENTITY
	var local_offset: Vector3 = parent_basis.inverse() * recoil_offset_world

	_recoil_tween = create_tween()
	# Phase 1: Snap backward (away from target)
	_recoil_tween.tween_property(anim_node, "position",
		_base_position + local_offset, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Phase 2: Bounce forward slightly past origin
	_recoil_tween.tween_property(anim_node, "position",
		_base_position - local_offset * 0.2, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Phase 3: Settle cleanly back to base resting position
	_recoil_tween.tween_property(anim_node, "position",
		_base_position, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
