extends Node3D
class_name IncursionPillar

@export var max_level: int = 5
var current_level: int = 1

# Upgrade costs for each level transition (L1->L2, L2->L3, L3->L4, L4->L5)
var upgrade_costs: Array[int] = [100, 250, 1000, 5000]

# --- Health & Defense ---
@export_group("Health & Defense")
@export var max_hp: float = 100.0
var current_hp: float = 100.0
var is_destroyed: bool = false

signal pillar_damaged(current_hp: float, max_hp: float)
signal pillar_destroyed

# --- UI & Drop Shadow Customization (@export) ---
@export_group("UI Layout & Sizing")
@export var hp_bar_position: Vector3 = Vector3(0.0, 3.6, 0.0)
@export var indicator_position: Vector3 = Vector3(1.4, 2.8, 0.0)
@export var indicator_pixel_size: float = 0.014
@export var upgrade_btn_position: Vector3 = Vector3(1.4, 1.4, 0.0)
@export var upgrade_btn_pixel_size: float = 0.008

@export_group("UI Drop Shadow")
@export var shadow_offset: Vector2 = Vector2(0.04, -0.04) # X (right), Y (down) offset in 3D units
@export var shadow_color: Color = Color(0.0, 0.0, 0.0, 0.6) # Dark translucent silhouette

var visual_model: Node3D = null
var level_pivot: Node3D = null
var level_sprite: Sprite3D = null
var level_shadow_sprite: Sprite3D = null

var hp_pivot: Node3D = null
var hp_viewport: SubViewport = null
var hp_progress_bar: ProgressBar = null
var hp_label: Label = null
var hp_sprite: Sprite3D = null

var upgrade_pivot: Node3D = null
var upgrade_shadow_sprite: Sprite3D = null
var upgrade_banner_sprite: Sprite3D = null
var upgrade_sprite: Sprite3D = null
var upgrade_cost_label: Label3D = null
var upgrade_area: Area3D = null

var level_textures: Array[Texture2D] = []
var upgrade_banner_texture: Texture2D = null
var upgrade_texture: Texture2D = null

# Unified Signature Arcane Amethyst Purple
const ARCANE_PURPLE: Color = Color(0.72, 0.35, 1.0, 1.0)

# Power Progression Profiles (Broken L1 -> Patching L2 -> Bridging L3 -> Harmonic L4 -> Perfect Resonance L5)
# Controls crystal facets, spinning velocity, and crystal breathing emissions
const PILLAR_POWER_PROFILES: Dictionary = {
	1: { # Broken / Short-Circuiting
		"spin_speed": 0.20,
		"emission_base": 0.20,
		"flicker_intensity": 0.15,
		"is_flickering": true,
	},
	2: { # Patching / Calming
		"spin_speed": 0.65,
		"emission_base": 0.35,
		"flicker_intensity": 0.04,
		"is_flickering": false,
	},
	3: { # Bridging / Stabilized Arcs
		"spin_speed": 1.10,
		"emission_base": 0.50,
		"flicker_intensity": 0.0,
		"is_flickering": false,
	},
	4: { # Harmonic Plasma Flow
		"spin_speed": 1.50,
		"emission_base": 0.68,
		"flicker_intensity": 0.0,
		"is_flickering": false,
	},
	5: { # Perfect Arcane Resonance (MAX)
		"spin_speed": 2.00,
		"emission_base": 0.85,
		"flicker_intensity": 0.0,
		"is_flickering": false,
	}
}

static func get_scrolling_color(level: int, time_ms: float = 0.0) -> Color:
	if level < 3:
		return ARCANE_PURPLE

	var time_sec: float = (time_ms if time_ms > 0.0 else float(Time.get_ticks_msec())) * 0.001
	var speed: float = 0.6 + (level - 3) * 0.35

	if level == 3:
		# Subtle harmonic drift: Violet (0.74) <-> Amethyst Magenta (0.84)
		var h: float = 0.79 + 0.07 * sin(time_sec * speed)
		return Color.from_hsv(h, 0.75, 1.0)
	elif level == 4:
		# Vibrant dual-tone wave: Electric Indigo (0.66) <-> Radiant Fuchsia (0.88)
		var h: float = 0.77 + 0.13 * sin(time_sec * speed)
		return Color.from_hsv(h, 0.80, 1.0)
	else: # Level 5 MAX
		# Full Celestial Resonance: Mystic Cyan (0.52) <-> Arcane Violet (0.75) <-> Plasma Magenta (0.92)
		var h: float = wrapf(0.75 + 0.24 * sin(time_sec * speed), 0.0, 1.0)
		return Color.from_hsv(h, 0.85, 1.0)

static func get_pillar_color(level: int = 1) -> Color:
	return get_scrolling_color(level)

var particle_system: PillarParticleSystem = null
var glow_light: OmniLight3D = null
var spinning_parts: Array[Node3D] = []
var bed_parts: Array[Node3D] = []
var _initial_crystal_positions: Dictionary = {}
var _initial_crystal_scales: Dictionary = {}
var crystal_materials: Array[StandardMaterial3D] = []

func _ready() -> void:
	add_to_group("pillar")
	current_hp = max_hp
	_load_textures()
	_setup_visual_model()
	_setup_ui()
	_setup_health_bar()
	_update_ui()
	_update_effects()
	_update_health_bar(false)

func set_ui_visible(is_vis: bool) -> void:
	if level_pivot: level_pivot.visible = is_vis
	if hp_pivot: hp_pivot.visible = is_vis
	if upgrade_pivot: upgrade_pivot.visible = is_vis


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

func _load_textures() -> void:
	level_textures.clear()
	# Load level indicator textures (lvl_1 to lvl_5)
	for i in range(1, 6):
		var tex: Texture2D = _load_texture_file("res://UI/Level Up - Indicator/turret_level_%d.png" % i)
		if not tex:
			tex = _load_texture_file("res://UI/Level Up - Indicator/lvl_%d.png" % i)
		if not tex:
			tex = _load_texture_file("res://UI/Level Up - Indicator/lvl_%d.gif" % i)
		if tex:
			level_textures.append(tex)
	
	# Load banner and level up button texture
	upgrade_banner_texture = _load_texture_file("res://UI/Level Up - Indicator/upbutton_banner.png")
	upgrade_texture = _load_texture_file("res://UI/Level Up - Indicator/upgrade_buttonnew.png")
	if not upgrade_texture:
		upgrade_texture = _load_texture_file("res://UI/Level Up - Indicator/lvl_up.png")

func _process(delta: float) -> void:
	var prof: Dictionary = PILLAR_POWER_PROFILES.get(current_level, PILLAR_POWER_PROFILES[1])
	var spin_spd: float = prof.spin_speed

	for part in spinning_parts:
		if is_instance_valid(part):
			part.rotate_y(delta * spin_spd)

	# Tamed dynamic crystal emission:
	# Level 1 has subtle erratic dying flicker; Levels 2-5 have gentle, clean breathing pulse
	var em_mult: float = prof.emission_base
	if prof.is_flickering:
		var noise_flicker = sin(Time.get_ticks_msec() * 0.022) * cos(Time.get_ticks_msec() * 0.009)
		em_mult = max(0.08, em_mult + noise_flicker * prof.flicker_intensity)
	else:
		var breath = 0.90 + 0.15 * sin(Time.get_ticks_msec() * (0.0018 + current_level * 0.0006))
		em_mult *= breath

	# Dynamic hue scrolling for crystals (Levels 3-5):
	var current_color: Color = get_scrolling_color(current_level)
	for c_mat in crystal_materials:
		if is_instance_valid(c_mat):
			c_mat.emission = current_color
			c_mat.emission_energy_multiplier = em_mult

func _setup_visual_model() -> void:
	var model_scene = load("res://assets/Models/GLB format/tower-round-crystals.glb") as PackedScene
	if model_scene:
		visual_model = model_scene.instantiate()
		visual_model.scale = Vector3(1.2, 3.2, 1.2) # Taller pillar height without changing X and Z width
		add_child(visual_model)
		_find_spinning_parts(visual_model)
	else:
		# Fallback CSGCylinder if model fails to load
		var cylinder = CSGCylinder3D.new()
		cylinder.height = 5.0
		cylinder.radius = 0.6
		add_child(cylinder)
		visual_model = cylinder
		spinning_parts.append(cylinder)
	
	# 1. Apply comical white outline ONLY to the bed (no x-ray silhouette)
	for bed in bed_parts:
		if is_instance_valid(bed):
			var bed_hl = TurretHighlighter.new()
			bed_hl.name = "BedHighlighter"
			bed.add_child(bed_hl)
			bed_hl.setup_static(bed, Color(1.0, 1.0, 1.0, 1.0), 3.2, false)

	# 2. Apply comical white outline WITH x-ray silhouette strictly to the floating crystals
	for part in spinning_parts:
		if is_instance_valid(part):
			var crystal_hl = TurretHighlighter.new()
			crystal_hl.name = "CrystalHighlighter"
			part.add_child(crystal_hl)
			crystal_hl.setup_static(part, Color(1.0, 1.0, 1.0, 1.0), 3.2, true)
			
	if bed_parts.is_empty() and spinning_parts.is_empty():
		var fallback_hl = TurretHighlighter.new()
		fallback_hl.name = "FallbackHighlighter"
		add_child(fallback_hl)
		fallback_hl.setup_static(visual_model, Color(1.0, 1.0, 1.0, 1.0), 3.2, false)
		
	_setup_particles_and_light()


func _find_spinning_parts(node: Node) -> void:
	var n_name = node.name.to_lower()
	# The base is named "tower-round-crystals" or starts with "tower". Only identify nodes that are specifically crystals.
	var is_crystal_node = n_name.begins_with("crystal") or (("crystal" in n_name or "gem" in n_name or "glass" in n_name) and not "tower" in n_name and not "round" in n_name)
	if node is Node3D and is_crystal_node:
		if not spinning_parts.has(node):
			spinning_parts.append(node)
			_initial_crystal_positions[node] = node.position
			_initial_crystal_scales[node] = node.scale
	elif node is MeshInstance3D and not is_crystal_node:
		if not bed_parts.has(node):
			bed_parts.append(node)
	if node is MeshInstance3D and is_crystal_node:
		var mat = node.get_active_material(0)
		if mat is StandardMaterial3D:
			var dup = mat.duplicate() as StandardMaterial3D
			dup.emission_enabled = true
			dup.emission = ARCANE_PURPLE
			dup.emission_energy_multiplier = 0.4
			node.set_surface_override_material(0, dup)
			crystal_materials.append(dup)
	for child in node.get_children():
		_find_spinning_parts(child)


func _setup_particles_and_light() -> void:
	var particle_scene = load("res://scenes/pillar_ambient_particles.tscn") as PackedScene
	if particle_scene:
		particle_system = particle_scene.instantiate() as PillarParticleSystem
		add_child(particle_system)
		if particle_system:
			particle_system.set_level(current_level)
			glow_light = particle_system.glow_light
	else:
		push_warning("Failed to load pillar_ambient_particles.tscn")

func _setup_ui() -> void:
	# 1. Level Indicator Sprite (Top on Right Side)
	level_pivot = Node3D.new()
	level_pivot.name = "LevelIndicatorPivot"
	level_pivot.position = indicator_position
	add_child(level_pivot)

	# Shadow Sprite (rendered behind the main sprite)
	level_shadow_sprite = Sprite3D.new()
	level_shadow_sprite.name = "LevelShadowSprite"
	level_shadow_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	level_shadow_sprite.no_depth_test = true
	level_shadow_sprite.render_priority = 9
	level_shadow_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	level_shadow_sprite.pixel_size = indicator_pixel_size
	level_shadow_sprite.modulate = shadow_color
	level_shadow_sprite.position = Vector3(shadow_offset.x, shadow_offset.y, -0.01)
	level_pivot.add_child(level_shadow_sprite)

	# Main Level Sprite
	level_sprite = Sprite3D.new()
	level_sprite.name = "LevelSprite"
	level_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	level_sprite.no_depth_test = true
	level_sprite.render_priority = 10
	level_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	level_sprite.pixel_size = indicator_pixel_size
	level_pivot.add_child(level_sprite)

	# Hover Area3D for level indicator
	var indicator_area = Area3D.new()
	indicator_area.name = "IndicatorArea"
	var ind_shape = CollisionShape3D.new()
	var ind_box = BoxShape3D.new()
	ind_box.size = Vector3(1.6, 0.6, 0.5)
	ind_shape.shape = ind_box
	indicator_area.add_child(ind_shape)
	level_pivot.add_child(indicator_area)
	indicator_area.mouse_entered.connect(_on_indicator_area_mouse_entered)
	indicator_area.mouse_exited.connect(_on_indicator_area_mouse_exited)

	# 2. Upgrade Button (Below Level Indicator on Right Side)
	upgrade_pivot = Node3D.new()
	upgrade_pivot.name = "UpgradePivot"
	upgrade_pivot.position = upgrade_btn_position
	add_child(upgrade_pivot)

	# Banner Drop Shadow Sprite
	upgrade_shadow_sprite = Sprite3D.new()
	upgrade_shadow_sprite.name = "UpgradeShadowSprite"
	upgrade_shadow_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	upgrade_shadow_sprite.no_depth_test = true
	upgrade_shadow_sprite.render_priority = 8
	upgrade_shadow_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	upgrade_shadow_sprite.pixel_size = upgrade_btn_pixel_size
	upgrade_shadow_sprite.modulate = shadow_color
	upgrade_shadow_sprite.position = Vector3(shadow_offset.x * 0.5, shadow_offset.y * 0.5, -0.01)
	if upgrade_banner_texture:
		upgrade_shadow_sprite.texture = upgrade_banner_texture
	upgrade_pivot.add_child(upgrade_shadow_sprite)

	# Banner Background Sprite
	upgrade_banner_sprite = Sprite3D.new()
	upgrade_banner_sprite.name = "UpgradeBannerSprite"
	upgrade_banner_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	upgrade_banner_sprite.no_depth_test = true
	upgrade_banner_sprite.render_priority = 9
	upgrade_banner_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	upgrade_banner_sprite.pixel_size = upgrade_btn_pixel_size
	if upgrade_banner_texture:
		upgrade_banner_sprite.texture = upgrade_banner_texture
	upgrade_pivot.add_child(upgrade_banner_sprite)

	# Main Upgrade Button Sprite (Left slot of banner, -14.5px 2D billboard offset)
	upgrade_sprite = Sprite3D.new()
	upgrade_sprite.name = "UpgradeSprite"
	upgrade_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	upgrade_sprite.no_depth_test = true
	upgrade_sprite.render_priority = 10
	upgrade_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	upgrade_sprite.pixel_size = upgrade_btn_pixel_size
	upgrade_sprite.position = Vector3(0, 0, 0.005)
	upgrade_sprite.offset = Vector2(-9, 0)
	if upgrade_texture:
		upgrade_sprite.texture = upgrade_texture
	upgrade_pivot.add_child(upgrade_sprite)

	# Cost Label (Right slot of banner, vertically stacked: Coin on top, Cost number below)
	upgrade_cost_label = Label3D.new()
	upgrade_cost_label.name = "UpgradeCostLabel"
	upgrade_cost_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	upgrade_cost_label.no_depth_test = true
	upgrade_cost_label.render_priority = 11
	upgrade_cost_label.position = Vector3(0, 0, 0.01)
	upgrade_cost_label.offset = Vector2(30, 0)
	upgrade_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upgrade_cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	upgrade_cost_label.line_spacing = 0.0
	upgrade_cost_label.font_size = 14
	upgrade_cost_label.outline_size = 4
	upgrade_cost_label.outline_modulate = Color(0.05, 0.04, 0.02, 1.0)
	upgrade_cost_label.modulate = Color(1.0, 0.9, 0.3, 1.0) # Gold
	upgrade_pivot.add_child(upgrade_cost_label)

	# Clickable Area3D strictly for the circular button icon
	upgrade_area = Area3D.new()
	upgrade_area.name = "UpgradeArea"
	upgrade_area.position = Vector3(-0.145, 0, 0)
	var col_shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(0.45, 0.45, 0.45)
	col_shape.shape = box
	upgrade_area.add_child(col_shape)
	upgrade_pivot.add_child(upgrade_area)

	upgrade_area.input_event.connect(_on_upgrade_area_input_event)
	upgrade_area.mouse_entered.connect(_on_upgrade_area_mouse_entered)
	upgrade_area.mouse_exited.connect(_on_upgrade_area_mouse_exited)

func _setup_health_bar() -> void:
	hp_pivot = Node3D.new()
	hp_pivot.name = "HealthBarPivot"
	hp_pivot.position = Vector3(hp_bar_position.x, hp_bar_position.y + (current_level - 1) * 0.5, hp_bar_position.z)
	add_child(hp_pivot)

	# SubViewport to render clean, customized 2D progress bar in 3D
	hp_viewport = SubViewport.new()
	hp_viewport.name = "HPViewport"
	hp_viewport.size = Vector2i(200, 36)
	hp_viewport.transparent_bg = true
	hp_viewport.gui_disable_input = true
	hp_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(hp_viewport)

	var bg_panel = Panel.new()
	bg_panel.custom_minimum_size = Vector2(200, 36)
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.08, 0.08, 0.12, 0.9)
	bg_style.border_color = Color(0.3, 0.3, 0.45, 1.0)
	bg_style.set_border_width_all(2)
	bg_style.set_corner_radius_all(6)
	bg_panel.add_theme_stylebox_override("panel", bg_style)
	hp_viewport.add_child(bg_panel)

	hp_progress_bar = ProgressBar.new()
	hp_progress_bar.custom_minimum_size = Vector2(192, 28)
	hp_progress_bar.position = Vector2(4, 4)
	hp_progress_bar.show_percentage = false
	hp_progress_bar.max_value = 100.0
	hp_progress_bar.value = 100.0

	var bar_bg_style = StyleBoxFlat.new()
	bar_bg_style.bg_color = Color(0.18, 0.05, 0.05, 0.8)
	bar_bg_style.set_corner_radius_all(4)
	hp_progress_bar.add_theme_stylebox_override("background", bar_bg_style)

	var bar_fill_style = StyleBoxFlat.new()
	bar_fill_style.bg_color = Color(0.2, 0.85, 0.35, 1.0) # Vibrant green
	bar_fill_style.set_corner_radius_all(4)
	hp_progress_bar.add_theme_stylebox_override("fill", bar_fill_style)
	bg_panel.add_child(hp_progress_bar)

	hp_label = Label.new()
	hp_label.custom_minimum_size = Vector2(200, 36)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_label.text = "100 / 100"
	hp_label.add_theme_font_size_override("font_size", 16)
	hp_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	hp_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	hp_label.add_theme_constant_override("outline_size", 4)
	bg_panel.add_child(hp_label)

	# 3D Sprite displaying the SubViewport texture
	hp_sprite = Sprite3D.new()
	hp_sprite.name = "HPSprite"
	hp_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hp_sprite.no_depth_test = true
	hp_sprite.render_priority = 10
	hp_sprite.pixel_size = 0.0075
	hp_sprite.texture = hp_viewport.get_texture()
	hp_pivot.add_child(hp_sprite)

func _update_health_bar(animate: bool = true) -> void:
	if not hp_progress_bar:
		return
	var target_val = (current_hp / max_hp) * 100.0
	if animate and is_inside_tree():
		var tween = create_tween()
		if tween:
			var prop_tw = tween.tween_property(hp_progress_bar, "value", target_val, 0.2)
			if prop_tw:
				prop_tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		hp_progress_bar.value = target_val
		
	# Change fill bar color dynamically based on health
	var fill_style = hp_progress_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill_style:
		if target_val > 50.0:
			fill_style.bg_color = Color(0.2, 0.85, 0.35) # Green
		elif target_val > 25.0:
			fill_style.bg_color = Color(0.95, 0.75, 0.15) # Orange/Yellow
		else:
			fill_style.bg_color = Color(0.95, 0.2, 0.2) # Red

	if hp_label:
		hp_label.text = "❤️ %d / %d" % [int(ceil(current_hp)), int(max_hp)]

func take_damage(amount: float) -> void:
	if is_destroyed:
		return
	current_hp = max(0.0, current_hp - amount)
	pillar_damaged.emit(current_hp, max_hp)
	_update_health_bar(true)
	_play_shambles_effect()

	if current_hp <= 0.0:
		_trigger_defeat()

func _play_shambles_effect() -> void:
	if is_destroyed or not visual_model or not is_inside_tree():
		return

	# 1. Decaying rapid wobble / shake tween on visual_model
	var shake_tween = create_tween()
	if shake_tween:
		var base_pos = Vector3.ZERO
		shake_tween.tween_property(visual_model, "position", base_pos + Vector3(randf_range(-0.18, 0.18), randf_range(0.0, 0.1), randf_range(-0.18, 0.18)), 0.04)
		shake_tween.tween_property(visual_model, "rotation:z", deg_to_rad(randf_range(-5.0, 5.0)), 0.04)
		shake_tween.tween_property(visual_model, "position", base_pos + Vector3(randf_range(-0.1, 0.1), 0, randf_range(-0.1, 0.1)), 0.04)
		shake_tween.tween_property(visual_model, "rotation:z", deg_to_rad(randf_range(-2.5, 2.5)), 0.04)
		shake_tween.tween_property(visual_model, "position", base_pos, 0.06)
		shake_tween.tween_property(visual_model, "rotation:z", 0.0, 0.06)

	# 2. Emissive damage flash on light & particles
	if particle_system and is_instance_valid(particle_system):
		particle_system.flash_damage(0.25)

	# 3. Flash health bar sprite
	if hp_sprite:
		var hp_tween = create_tween()
		if hp_tween:
			hp_sprite.modulate = Color(1.0, 0.3, 0.3, 1.0)
			hp_tween.tween_property(hp_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2)

	# 4. Spawn crumbling debris & hit sparks
	_spawn_debris_burst()

func _spawn_debris_burst() -> void:
	var debris_scene = load("res://scenes/pillar_hit_particle.tscn") as PackedScene
	if debris_scene:
		var deb = debris_scene.instantiate()
		add_child(deb)
		deb.position = Vector3(randf_range(-0.2, 0.2), randf_range(1.2, 2.5), randf_range(-0.2, 0.2))

func _trigger_defeat() -> void:
	if is_destroyed:
		return
	is_destroyed = true

	var destruction_scene = load("res://scenes/pillar_destruction.tscn") as PackedScene
	if destruction_scene:
		var explosion = destruction_scene.instantiate()
		get_parent().add_child(explosion)
		explosion.global_position = global_position + Vector3(0, 1.5, 0)


	if visual_model:
		visual_model.visible = false
	if particle_system and is_instance_valid(particle_system):
		particle_system.trigger_defeat()
	if hp_pivot:
		hp_pivot.visible = false
	if level_pivot:
		level_pivot.visible = false
	if upgrade_pivot:
		upgrade_pivot.visible = false

	if WaveManager.instance:
		WaveManager.instance.stop_spawning()

	pillar_destroyed.emit()

	var defeat_timer = get_tree().create_timer(1.2)
	defeat_timer.timeout.connect(_show_defeat_modal)

func _show_defeat_modal() -> void:
	var overlay = get_tree().get_first_node_in_group("game_over_overlay")
	if not overlay:
		var scene_root = get_tree().current_scene
		if scene_root:
			overlay = scene_root.find_child("GameOverOverlay", true, false)
	if overlay and overlay.has_method("show_defeat"):
		var stats = WaveManager.instance.get_game_stats() if WaveManager.instance else {}
		overlay.show_defeat(stats)

func _on_indicator_area_mouse_entered() -> void:
	if not is_instance_valid(level_sprite) or not is_inside_tree():
		return
	var tween = create_tween()
	if tween:
		tween.set_parallel(true)
		var tw = tween.tween_property(level_sprite, "scale", Vector3(0.92, 0.92, 0.92), 0.1)
		if tw:
			tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if level_shadow_sprite:
			tween.tween_property(level_shadow_sprite, "scale", Vector3(0.92, 0.92, 0.92), 0.1)
			tween.tween_property(level_shadow_sprite, "position", Vector3(shadow_offset.x * 0.5, shadow_offset.y * 0.5, -0.01), 0.1)

func _on_indicator_area_mouse_exited() -> void:
	if not is_instance_valid(level_sprite) or not is_inside_tree():
		return
	var tween = create_tween()
	if tween:
		tween.set_parallel(true)
		var tw = tween.tween_property(level_sprite, "scale", Vector3(1.0, 1.0, 1.0), 0.15)
		if tw:
			tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if level_shadow_sprite:
			tween.tween_property(level_shadow_sprite, "scale", Vector3(1.0, 1.0, 1.0), 0.15)
			tween.tween_property(level_shadow_sprite, "position", Vector3(shadow_offset.x, shadow_offset.y, -0.01), 0.15)

func _on_upgrade_area_mouse_entered() -> void:
	if current_level >= max_level or not is_instance_valid(upgrade_pivot) or not is_inside_tree():
		return
	var tween = create_tween()
	if tween:
		var tw = tween.tween_property(upgrade_pivot, "scale", Vector3(1.1, 1.1, 1.1), 0.1)
		if tw:
			tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_upgrade_area_mouse_exited() -> void:
	if not is_instance_valid(upgrade_pivot) or not is_inside_tree():
		return
	var tween = create_tween()
	if tween:
		var tw = tween.tween_property(upgrade_pivot, "scale", Vector3.ONE, 0.15)
		if tw:
			tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func get_upgrade_cost() -> int:
	if current_level >= max_level:
		return 0
	return upgrade_costs[current_level - 1]

func _update_ui() -> void:
	# Update level indicator texture and shadow
	if level_sprite:
		if level_textures.size() > 0:
			var idx = clamp(current_level - 1, 0, level_textures.size() - 1)
			if idx >= 0 and idx < level_textures.size() and level_textures[idx] != null:
				var tex = level_textures[idx]
				level_sprite.texture = tex
				level_sprite.visible = true
				if level_shadow_sprite:
					level_shadow_sprite.texture = tex
					level_shadow_sprite.visible = true
			else:
				level_sprite.visible = false
				if level_shadow_sprite:
					level_shadow_sprite.visible = false
		else:
			level_sprite.visible = false
			if level_shadow_sprite:
				level_shadow_sprite.visible = false

	# Update upgrade button & cost
	if upgrade_pivot and upgrade_cost_label:
		if current_level >= max_level:
			# Hide or disable upgrade button at MAX level
			upgrade_pivot.visible = false
			if upgrade_area:
				upgrade_area.input_ray_pickable = false
		else:
			upgrade_pivot.visible = true
			if upgrade_shadow_sprite and upgrade_banner_texture:
				upgrade_shadow_sprite.texture = upgrade_banner_texture
				upgrade_shadow_sprite.visible = true
			if upgrade_banner_sprite and upgrade_banner_texture:
				upgrade_banner_sprite.texture = upgrade_banner_texture
			if upgrade_area:
				upgrade_area.input_ray_pickable = true
			var cost = get_upgrade_cost()
			upgrade_cost_label.text = "🪙\n%d" % cost

func _update_effects() -> void:
	if particle_system and is_instance_valid(particle_system):
		particle_system.set_level(current_level)

	# Update Crystal Materials base color
	for c_mat in crystal_materials:
		if is_instance_valid(c_mat):
			c_mat.emission = ARCANE_PURPLE

func _on_upgrade_area_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if upgrade_pivot and is_inside_tree():
			var tween = create_tween()
			if tween:
				tween.tween_property(upgrade_pivot, "scale", Vector3(0.85, 0.85, 0.85), 0.05)
				tween.tween_property(upgrade_pivot, "scale", Vector3(1.1, 1.1, 1.1), 0.12).set_trans(Tween.TRANS_BACK)
		try_upgrade()

func try_upgrade() -> bool:
	if current_level >= max_level:
		return false

	var cost = get_upgrade_cost()
	if CurrencyManager.instance and CurrencyManager.instance.spend_currency(cost):
		current_level += 1
		_update_ui()
		_on_upgraded()
		return true
	else:
		_flash_insufficient_funds()
		return false

func _flash_insufficient_funds() -> void:
	if upgrade_cost_label and is_inside_tree():
		var tween = create_tween()
		if tween:
			upgrade_cost_label.modulate = Color(1.0, 0.2, 0.2, 1.0)
			tween.tween_property(upgrade_cost_label, "modulate", Color(1.0, 0.9, 0.3, 1.0), 0.4)

func _on_upgraded() -> void:
	_update_effects()
	
	# Increase turret deployment capacity on BuilderController (+2 at L2, +4 at L3, +8 at L4)
	var bonus_slots: int = 0
	match current_level:
		2: bonus_slots = 2
		3: bonus_slots = 4
		4: bonus_slots = 8
		_: bonus_slots = 0
		
	if bonus_slots > 0:
		var builder = get_tree().get_first_node_in_group("builder_controller")
		if not builder:
			var scene_root = get_tree().current_scene
			if scene_root:
				builder = scene_root.find_child("BuilderController", true, false)
		if builder and builder.has_method("increase_max_deployment"):
			builder.increase_max_deployment(bonus_slots)
	
	# Bed gets slightly taller only up to level 2
	var target_model_scale = Vector3(1.2, 3.2 + min(current_level - 1, 1) * 0.35, 1.2)
	# Crystals grow slightly for levels 3 to 5 (tiny bit)
	var crystal_extra: float = max(current_level - 2, 0) * 0.08

	if is_inside_tree():
		var tween = create_tween()
		if tween:
			tween.set_parallel(true)
			if visual_model:
				tween.tween_property(visual_model, "scale", target_model_scale, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			for part in spinning_parts:
				if is_instance_valid(part):
					var orig_pos = _initial_crystal_positions.get(part, part.position)
					var orig_scale = _initial_crystal_scales.get(part, Vector3.ONE)
					var target_scale = orig_scale * Vector3(1.0 + crystal_extra * 0.4, 1.0 + crystal_extra, 1.0 + crystal_extra * 0.4)
					var target_pos_y = orig_pos.y + max(current_level - 2, 0) * 0.05
					tween.tween_property(part, "scale", target_scale, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
					tween.tween_property(part, "position:y", target_pos_y, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		if visual_model:
			visual_model.scale = target_model_scale
		for part in spinning_parts:
			if is_instance_valid(part):
				var orig_pos = _initial_crystal_positions.get(part, part.position)
				var orig_scale = _initial_crystal_scales.get(part, Vector3.ONE)
				part.scale = orig_scale * Vector3(1.0 + crystal_extra * 0.4, 1.0 + crystal_extra, 1.0 + crystal_extra * 0.4)
				part.position.y = orig_pos.y + max(current_level - 2, 0) * 0.05

	if hp_pivot and is_inside_tree():
		var target_hp_y = hp_bar_position.y + min(current_level - 1, 1) * 0.35 + max(current_level - 2, 0) * 0.20
		var hp_tw = create_tween()
		if hp_tw:
			hp_tw.tween_property(hp_pivot, "position:y", target_hp_y, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	if current_level >= max_level:
		_trigger_endgame_victory()

func _trigger_endgame_victory() -> void:
	SpeedToggle.reset_to_default()
	_trigger_shockwave()
	if WaveManager.instance:
		WaveManager.instance.wipe_all_active_enemies(global_position)
		
	var victory_timer = get_tree().create_timer(1.8)
	victory_timer.timeout.connect(_show_victory_modal)

func _show_victory_modal() -> void:
	var overlay = get_tree().get_first_node_in_group("game_over_overlay")
	if not overlay:
		var scene_root = get_tree().current_scene
		if scene_root:
			overlay = scene_root.find_child("GameOverOverlay", true, false)
	if overlay and overlay.has_method("show_victory"):
		var stats = WaveManager.instance.get_game_stats() if WaveManager.instance else {}
		overlay.show_victory(stats)

func _trigger_shockwave() -> void:
	SpeedToggle.reset_to_default()

	# Zoom camera out to default position
	var camera = get_viewport().get_camera_3d()
	if camera and camera.has_method("reset_camera"):
		camera.reset_camera()

	# Trigger visual shockwave distortion
	var shockwave_scene = load("res://scenes/PillarShockwave.tscn") as PackedScene
	if shockwave_scene:
		var shockwave = shockwave_scene.instantiate() as PillarShockwave
		add_child(shockwave)
		
		var screen_pos = camera.unproject_position(global_position) if camera else get_viewport().get_visible_rect().size / 2.0
		shockwave.play_shockwave(screen_pos)

	# Explode all active enemies on the map
	var active_enemies: Array[Node3D] = []
	for enemy in EnemyDetector._active_enemies:
		if is_instance_valid(enemy) and enemy.visible and enemy.get("_is_done") != true:
			active_enemies.append(enemy)

	for enemy in active_enemies:
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			enemy.take_damage(999999.0)
