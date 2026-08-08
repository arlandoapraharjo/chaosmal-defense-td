extends Node3D
class_name IncursionPillar

@export var max_level: int = 5
var current_level: int = 1

# Upgrade costs for each level transition (L1->L2, L2->L3, L3->L4, L4->L5)
var upgrade_costs: Array[int] = [10, 25, 50, 100]

var visual_model: Node3D = null
var level_label: Label3D = null
var upgrade_label: Label3D = null
var upgrade_area: Area3D = null

var particles: GPUParticles3D = null
var glow_light: OmniLight3D = null
var spinning_parts: Array[Node3D] = []

func _ready() -> void:
	_setup_visual_model()
	_setup_ui_labels()
	_update_labels()
	_update_effects()

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
	spatial_mat.emission_energy_multiplier = 2.0
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


func _setup_ui_labels() -> void:
	# 1. Level label directly above pillar top
	var level_pivot = Node3D.new()
	level_pivot.name = "LevelPivot"
	level_pivot.position = Vector3(0, 3.4, 0) # Positioned slightly higher up above the pillar
	add_child(level_pivot)

	_add_bg_plate(level_pivot, Vector2(3.6, 0.8), Color(0.08, 0.12, 0.16, 0.85))

	level_label = Label3D.new()
	level_label.name = "VegetationLevelLabel"
	level_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	level_label.no_depth_test = true
	level_label.render_priority = 10
	level_label.font_size = 36
	level_label.outline_size = 12
	level_label.outline_modulate = Color(0.02, 0.05, 0.08, 1.0)
	level_label.modulate = Color(0.4, 1.0, 0.4, 1.0) # Vibrant green
	level_pivot.add_child(level_label)

	# 2. Upgrade label & clickable area beside pillar
	var upgrade_pivot = Node3D.new()
	upgrade_pivot.name = "UpgradePivot"
	upgrade_pivot.position = Vector3(2.6, 1.0, 0) # Positioned slightly more to the right
	add_child(upgrade_pivot)

	_add_bg_plate(upgrade_pivot, Vector2(3.2, 1.2), Color(0.12, 0.1, 0.05, 0.85))

	upgrade_label = Label3D.new()
	upgrade_label.name = "UpgradeLabel"
	upgrade_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	upgrade_label.no_depth_test = true
	upgrade_label.render_priority = 10
	upgrade_label.font_size = 32
	upgrade_label.outline_size = 10
	upgrade_label.outline_modulate = Color(0.05, 0.04, 0.02, 1.0)
	upgrade_label.modulate = Color(1.0, 0.9, 0.3, 1.0) # Vibrant gold
	upgrade_pivot.add_child(upgrade_label)

	# Clickable Area3D for upgrade label
	upgrade_area = Area3D.new()
	upgrade_area.name = "UpgradeArea"
	var col_shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(3.2, 1.4, 0.5)
	col_shape.shape = box
	upgrade_area.add_child(col_shape)
	upgrade_pivot.add_child(upgrade_area)

	upgrade_area.input_event.connect(_on_upgrade_area_input_event)

func _add_bg_plate(parent: Node3D, size: Vector2, color: Color) -> void:
	var bg_mesh = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = size
	bg_mesh.mesh = quad

	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.render_priority = 9
	bg_mesh.material_override = mat

	bg_mesh.position = Vector3(0, 0, -0.05)
	parent.add_child(bg_mesh)

func get_upgrade_cost() -> int:
	if current_level >= max_level:
		return 0
	return upgrade_costs[current_level - 1]

func _update_labels() -> void:
	if level_label:
		if current_level >= max_level:
			level_label.text = "🌿 Vegetation Level: MAX (%d/%d) 🌿" % [current_level, max_level]
			level_label.modulate = Color(0.2, 1.0, 0.5, 1.0)
		else:
			level_label.text = "🌿 Vegetation Level: %d / %d" % [current_level, max_level]

	if upgrade_label:
		if current_level >= max_level:
			upgrade_label.text = "✨ FULLY RESTORED ✨"
			upgrade_label.modulate = Color(0.5, 0.9, 1.0, 0.9)
		else:
			var cost = get_upgrade_cost()
			upgrade_label.text = "⚡ UPGRADE PILLAR ⚡\nCost: %d Coins" % cost

func _update_effects() -> void:
	if glow_light:
		var target_energy = 1.0 + (current_level * 1.5)
		var target_range = 5.0 + (current_level * 2.0)
		var tween = create_tween()
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
		try_upgrade()

func try_upgrade() -> bool:
	if current_level >= max_level:
		return false

	var cost = get_upgrade_cost()
	if CurrencyManager.instance and CurrencyManager.instance.spend_currency(cost):
		current_level += 1
		_update_labels()
		_on_upgraded()
		return true
	else:
		_flash_insufficient_funds()
		return false

func _flash_insufficient_funds() -> void:
	if upgrade_label:
		var tween = create_tween()
		upgrade_label.modulate = Color(1.0, 0.2, 0.2, 1.0)
		tween.tween_property(upgrade_label, "modulate", Color(1.0, 0.9, 0.3, 1.0), 0.4)

func _on_upgraded() -> void:
	_update_effects()
	# Scale animation & glow effect — heightens Y scale while leaving X and Z width intact
	if visual_model:
		var target_scale = Vector3(1.2, 3.2 + (current_level - 1) * 0.5, 1.2)
		var tween = create_tween()
		tween.tween_property(visual_model, "scale", Vector3(1.2, (3.2 + (current_level - 1) * 0.5) * 1.2, 1.2), 0.2).set_trans(Tween.TRANS_BACK)
		tween.tween_property(visual_model, "scale", target_scale, 0.3)

	if current_level >= max_level:
		_trigger_shockwave()

func _trigger_shockwave() -> void:
	var shockwave_scene = load("res://scenes/PillarShockwave.tscn") as PackedScene
	if shockwave_scene:
		var shockwave = shockwave_scene.instantiate() as PillarShockwave
		add_child(shockwave)
		
		var camera = get_viewport().get_camera_3d()
		var screen_pos = camera.unproject_position(global_position) if camera else get_viewport().get_visible_rect().size / 2.0
		shockwave.play_shockwave(screen_pos)
