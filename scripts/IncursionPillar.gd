extends Node3D
class_name IncursionPillar

@export var max_level: int = 5
var current_level: int = 1

# Upgrade costs for each level transition (L1->L2, L2->L3, L3->L4, L4->L5)
var upgrade_costs: Array[int] = [10, 25, 50, 100]

# --- Health & Defense ---
@export_group("Health & Defense")
@export var max_hp: float = 100.0
var current_hp: float = 100.0
var is_destroyed: bool = false

signal pillar_damaged(current_hp: float, max_hp: float)
signal pillar_destroyed

# --- UI & Drop Shadow Customization (@export) ---
@export_group("UI Layout & Sizing")
@export var hp_bar_position: Vector3 = Vector3(2.4, 3.65, 0)
@export var indicator_position: Vector3 = Vector3(2.4, 2.8, 0)
@export var indicator_pixel_size: float = 0.01
@export var upgrade_btn_position: Vector3 = Vector3(1.25, 1.25, 0)
@export var upgrade_btn_pixel_size: float = 0.01

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
var upgrade_sprite: Sprite3D = null
var upgrade_shadow_sprite: Sprite3D = null
var upgrade_cost_label: Label3D = null
var upgrade_area: Area3D = null

var level_textures: Array[Texture2D] = []
var upgrade_texture: Texture2D = null

var particles: GPUParticles3D = null
var glow_light: OmniLight3D = null
var spinning_parts: Array[Node3D] = []

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

func _load_textures() -> void:
	level_textures.clear()
	# Load level indicator textures (lvl_1 to lvl_5)
	for i in range(1, 6):
		var tex: Texture2D = null
		if ResourceLoader.exists("res://UI/Level Up - Indicator/lvl_%d.png" % i):
			tex = load("res://UI/Level Up - Indicator/lvl_%d.png" % i) as Texture2D
		elif ResourceLoader.exists("res://UI/Level Up - Indicator/lvl_%d.gif" % i):
			tex = load("res://UI/Level Up - Indicator/lvl_%d.gif" % i) as Texture2D
		elif ResourceLoader.exists("res://ui/lvl indicator/lvl_%d.png" % i):
			tex = load("res://ui/lvl indicator/lvl_%d.png" % i) as Texture2D
		
		if tex:
			level_textures.append(tex)
	
	# Load level up button texture
	if ResourceLoader.exists("res://UI/Level Up - Indicator/lvl_up.png"):
		upgrade_texture = load("res://UI/Level Up - Indicator/lvl_up.png") as Texture2D
	elif ResourceLoader.exists("res://ui/lvl indicator/lvl_up.png"):
		upgrade_texture = load("res://ui/lvl indicator/lvl_up.png") as Texture2D

func _process(delta: float) -> void:
	for part in spinning_parts:
		if is_instance_valid(part):
			part.rotate_y(delta * 1.0) # Spin the crystals

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
		
	_setup_particles_and_light()

func _find_spinning_parts(node: Node) -> void:
	if node is Node3D and node.name.to_lower().begins_with("crystal"):
		spinning_parts.append(node)
	for child in node.get_children():
		_find_spinning_parts(child)

func _setup_particles_and_light() -> void:
	# Add Purple Particles
	particles = GPUParticles3D.new()
	particles.amount = 40
	particles.lifetime = 1.5
	particles.position = Vector3(0, 1.5, 0)
	
	var process_mat = ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_mat.emission_sphere_radius = 1.5
	process_mat.gravity = Vector3(0, 0.5, 0)
	process_mat.direction = Vector3(0, 1, 0)
	process_mat.spread = 180.0
	process_mat.initial_velocity_min = 0.2
	process_mat.initial_velocity_max = 0.8
	process_mat.scale_min = 0.2
	process_mat.scale_max = 0.6
	particles.process_material = process_mat
	
	var pass_mesh = QuadMesh.new()
	pass_mesh.size = Vector2(0.3, 0.3)
	var spatial_mat = StandardMaterial3D.new()
	spatial_mat.albedo_color = Color(0.7, 0.2, 1.0, 1.0) # Purple
	spatial_mat.emission_enabled = true
	spatial_mat.emission = Color(0.7, 0.2, 1.0, 1.0)
	spatial_mat.emission_energy_multiplier = 0.3
	spatial_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	spatial_mat.billboard_keep_scale = true
	spatial_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pass_mesh.material = spatial_mat
	particles.draw_pass_1 = pass_mesh
	add_child(particles)
	
	# Add Glow Light
	glow_light = OmniLight3D.new()
	glow_light.light_color = Color(0.7, 0.2, 1.0, 1.0) # Purple
	glow_light.position = Vector3(0, 2.0, 0)
	add_child(glow_light)

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

	# Button Shadow Sprite
	upgrade_shadow_sprite = Sprite3D.new()
	upgrade_shadow_sprite.name = "UpgradeShadowSprite"
	upgrade_shadow_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	upgrade_shadow_sprite.no_depth_test = true
	upgrade_shadow_sprite.render_priority = 9
	upgrade_shadow_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	upgrade_shadow_sprite.pixel_size = upgrade_btn_pixel_size
	upgrade_shadow_sprite.modulate = shadow_color
	upgrade_shadow_sprite.position = Vector3(shadow_offset.x, shadow_offset.y, -0.01)
	if upgrade_texture:
		upgrade_shadow_sprite.texture = upgrade_texture
	upgrade_pivot.add_child(upgrade_shadow_sprite)

	# Main Upgrade Button Sprite
	upgrade_sprite = Sprite3D.new()
	upgrade_sprite.name = "UpgradeSprite"
	upgrade_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	upgrade_sprite.no_depth_test = true
	upgrade_sprite.render_priority = 10
	upgrade_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	upgrade_sprite.pixel_size = upgrade_btn_pixel_size
	if upgrade_texture:
		upgrade_sprite.texture = upgrade_texture
	upgrade_pivot.add_child(upgrade_sprite)

	# Cost Label positioned right below the Upgrade Sprite
	upgrade_cost_label = Label3D.new()
	upgrade_cost_label.name = "UpgradeCostLabel"
	upgrade_cost_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	upgrade_cost_label.no_depth_test = true
	upgrade_cost_label.render_priority = 11
	upgrade_cost_label.font_size = 28
	upgrade_cost_label.outline_size = 8
	upgrade_cost_label.outline_modulate = Color(0.05, 0.04, 0.02, 1.0)
	upgrade_cost_label.modulate = Color(1.0, 0.9, 0.3, 1.0) # Gold
	upgrade_cost_label.position = Vector3(0, -0.6, 0)
	upgrade_pivot.add_child(upgrade_cost_label)

	# Clickable Area3D for upgrade button
	upgrade_area = Area3D.new()
	upgrade_area.name = "UpgradeArea"
	var col_shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(1.2, 1.5, 0.5)
	col_shape.shape = box
	upgrade_area.add_child(col_shape)
	upgrade_pivot.add_child(upgrade_area)

	upgrade_area.input_event.connect(_on_upgrade_area_input_event)
	upgrade_area.mouse_entered.connect(_on_upgrade_area_mouse_entered)
	upgrade_area.mouse_exited.connect(_on_upgrade_area_mouse_exited)

func _setup_health_bar() -> void:
	hp_pivot = Node3D.new()
	hp_pivot.name = "HealthBarPivot"
	hp_pivot.position = hp_bar_position
	add_child(hp_pivot)

	# SubViewport to render clean, customized 2D progress bar in 3D
	hp_viewport = SubViewport.new()
	hp_viewport.name = "HPViewport"
	hp_viewport.size = Vector2i(200, 36)
	hp_viewport.transparent_bg = true
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
	hp_label.text = "❤️ 100 / 100"
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

	# 2. Emissive damage flash on light & crystals
	if glow_light:
		var orig_light_col = glow_light.light_color
		var orig_energy = glow_light.light_energy
		glow_light.light_color = Color(1.0, 0.15, 0.15)
		glow_light.light_energy = orig_energy * 2.2
		var light_tween = create_tween()
		if light_tween:
			light_tween.tween_property(glow_light, "light_color", orig_light_col, 0.25)
			light_tween.tween_property(glow_light, "light_energy", orig_energy, 0.25)

	# 3. Flash health bar sprite
	if hp_sprite:
		var hp_tween = create_tween()
		if hp_tween:
			hp_sprite.modulate = Color(1.0, 0.3, 0.3, 1.0)
			hp_tween.tween_property(hp_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2)

	# 4. Spawn crumbling debris & hit sparks
	_spawn_debris_burst()

func _spawn_debris_burst() -> void:
	var debris_scene = load("res://scenes/explosion.tscn") as PackedScene
	if debris_scene:
		var deb = debris_scene.instantiate()
		deb.scale = Vector3(0.6, 0.6, 0.6)
		add_child(deb)
		deb.position = Vector3(randf_range(-0.25, 0.25), randf_range(1.2, 2.5), randf_range(-0.25, 0.25))
		for child in deb.get_children():
			if child is GPUParticles3D:
				child.emitting = true
		get_tree().create_timer(1.2).timeout.connect(deb.queue_free)

func _trigger_defeat() -> void:
	if is_destroyed:
		return
	is_destroyed = true

	var explosion_scene = load("res://scenes/explosion.tscn") as PackedScene
	if explosion_scene:
		var exp = explosion_scene.instantiate()
		exp.scale = Vector3(2.5, 2.5, 2.5)
		get_parent().add_child(exp)
		exp.global_position = global_position + Vector3(0, 1.5, 0)
		for child in exp.get_children():
			if child is GPUParticles3D:
				child.emitting = true
		get_tree().create_timer(3.0).timeout.connect(exp.queue_free)

	if visual_model:
		visual_model.visible = false
	if particles:
		particles.emitting = false
	if glow_light:
		glow_light.visible = false
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
	if current_level >= max_level or not is_instance_valid(upgrade_sprite) or not is_inside_tree():
		return
	var tween = create_tween()
	if tween:
		tween.set_parallel(true)
		var tw = tween.tween_property(upgrade_sprite, "scale", Vector3(0.9, 0.9, 0.9), 0.1)
		if tw:
			tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if upgrade_shadow_sprite:
			tween.tween_property(upgrade_shadow_sprite, "scale", Vector3(0.9, 0.9, 0.9), 0.1)
			tween.tween_property(upgrade_shadow_sprite, "position", Vector3(shadow_offset.x * 0.5, shadow_offset.y * 0.5, -0.01), 0.1)

func _on_upgrade_area_mouse_exited() -> void:
	if not is_instance_valid(upgrade_sprite) or not is_inside_tree():
		return
	var tween = create_tween()
	if tween:
		tween.set_parallel(true)
		var tw = tween.tween_property(upgrade_sprite, "scale", Vector3(1.0, 1.0, 1.0), 0.15)
		if tw:
			tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if upgrade_shadow_sprite:
			tween.tween_property(upgrade_shadow_sprite, "scale", Vector3(1.0, 1.0, 1.0), 0.15)
			tween.tween_property(upgrade_shadow_sprite, "position", Vector3(shadow_offset.x, shadow_offset.y, -0.01), 0.15)

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
			if upgrade_area:
				upgrade_area.input_ray_pickable = true
			var cost = get_upgrade_cost()
			upgrade_cost_label.text = "⚡ %d" % cost

func _update_effects() -> void:
	if glow_light and is_inside_tree():
		var target_energy = 1.0 + (current_level * 1.5)
		var target_range = 5.0 + (current_level * 2.0)
		var tween = create_tween()
		if tween:
			tween.set_parallel(true)
			tween.tween_property(glow_light, "light_energy", target_energy, 0.5)
			tween.tween_property(glow_light, "omni_range", target_range, 0.5)
		
	if particles:
		particles.amount = 30 + (current_level * 15)
		if current_level >= max_level:
			var pass_mesh = particles.draw_pass_1 as QuadMesh
			if pass_mesh and pass_mesh.material:
				var mat = pass_mesh.material as StandardMaterial3D
				mat.albedo_color = Color(0.2, 0.5, 1.0, 1.0) # Blue
				mat.emission = Color(0.2, 0.5, 1.0, 1.0)
			if glow_light:
				glow_light.light_color = Color(0.2, 0.5, 1.0, 1.0)

func _on_upgrade_area_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if upgrade_sprite and is_inside_tree():
			var tween = create_tween()
			if tween:
				tween.tween_property(upgrade_sprite, "scale", Vector3(0.8, 0.8, 0.8), 0.06)
				tween.tween_property(upgrade_sprite, "scale", Vector3(0.9, 0.9, 0.9), 0.1)
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
	if visual_model and is_inside_tree():
		var target_scale = Vector3(1.2, 3.2 + (current_level - 1) * 0.5, 1.2)
		var tween = create_tween()
		if tween:
			var tw = tween.tween_property(visual_model, "scale", Vector3(1.2, (3.2 + (current_level - 1) * 0.5) * 1.2, 1.2), 0.2)
			if tw:
				tw.set_trans(Tween.TRANS_BACK)
			tween.tween_property(visual_model, "scale", target_scale, 0.3)

	if current_level >= max_level:
		_trigger_endgame_victory()

func _trigger_endgame_victory() -> void:
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
	var shockwave_scene = load("res://scenes/PillarShockwave.tscn") as PackedScene
	if shockwave_scene:
		var shockwave = shockwave_scene.instantiate() as PillarShockwave
		add_child(shockwave)
		
		var camera = get_viewport().get_camera_3d()
		var screen_pos = camera.unproject_position(global_position) if camera else get_viewport().get_visible_rect().size / 2.0
		shockwave.play_shockwave(screen_pos)
