class_name RocketDropPod
extends Node3D

## RocketDropPod — Cinematic landing pod for companion character deployment.
## Features multi-stage flame thrusters, dynamic flickering fire light,
## touchdown dust shockwaves, companion pop-out ejection, and blast-off departure.

const ROCKET_MODEL_SCENE = preload("res://assets/characters/Rocket (wip).glb")
const POOF_SCENE = preload("res://scenes/FoxPoofParticle.tscn")

@export var base_scale: Vector3 = Vector3(0.5, 0.5, 0.5)

var _model_root: Node3D = null
var _flame_particles: GPUParticles3D = null
var _smoke_particles: GPUParticles3D = null
var _spark_particles: GPUParticles3D = null
var _thruster_light: OmniLight3D = null
var _ground_dust: GPUParticles3D = null

var _is_thrusting: bool = false
var _thrust_power: float = 1.0
var _time_passed: float = 0.0

func _ready() -> void:
	_setup_visuals()
	_setup_thruster_particles()
	_setup_thruster_light()
	_setup_ground_dust()

func _setup_visuals() -> void:
	if ROCKET_MODEL_SCENE:
		_model_root = ROCKET_MODEL_SCENE.instantiate()
		_model_root.name = "RocketModel"
		_model_root.scale = base_scale
		add_child(_model_root)
		
		# Center model so its base nozzle aligns with (0, 0, 0)
		_model_root.position = Vector3(0, 0, 0)

func _setup_thruster_particles() -> void:
	# 1. Fire Flame Core
	_flame_particles = GPUParticles3D.new()
	_flame_particles.name = "FlameCore"
	_flame_particles.amount = 45
	_flame_particles.lifetime = 0.35
	_flame_particles.randomness = 0.3
	_flame_particles.local_coords = false
	_flame_particles.position = Vector3(0, 0.1, 0)
	
	var flame_mat = ParticleProcessMaterial.new()
	flame_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	flame_mat.emission_sphere_radius = 0.18
	flame_mat.direction = Vector3(0, -1, 0)
	flame_mat.spread = 14.0
	flame_mat.initial_velocity_min = 8.0
	flame_mat.initial_velocity_max = 14.0
	flame_mat.gravity = Vector3(0, -2.0, 0)
	flame_mat.damping_min = 1.5
	flame_mat.damping_max = 3.0
	flame_mat.scale_min = 0.22
	flame_mat.scale_max = 0.42
	
	# Flame scale curve (grow then taper down)
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.4), 0.0, 3.0)
	scale_curve.add_point(Vector2(0.25, 1.2), 0.0, 0.0)
	scale_curve.add_point(Vector2(1.0, 0.0), -2.0, 0.0)
	var scale_texture = CurveTexture.new()
	scale_texture.curve = scale_curve
	flame_mat.scale_curve = scale_texture
	
	# Fiery color ramp (White-Yellow -> Bright Orange -> Deep Red -> Fade)
	var grad = Gradient.new()
	grad.set_color(0, Color(1.0, 0.95, 0.7, 1.0))
	grad.add_point(0.25, Color(1.0, 0.6, 0.1, 0.95))
	grad.add_point(0.7, Color(0.95, 0.18, 0.05, 0.8))
	grad.add_point(1.0, Color(0.3, 0.05, 0.02, 0.0))
	var grad_texture = GradientTexture1D.new()
	grad_texture.gradient = grad
	flame_mat.color_ramp = grad_texture
	
	_flame_particles.process_material = flame_mat
	
	var flame_draw_mat = StandardMaterial3D.new()
	flame_draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flame_draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_draw_mat.vertex_color_use_as_albedo = true
	flame_draw_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.9)
	flame_draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.material = flame_draw_mat
	sphere_mesh.radius = 0.18
	sphere_mesh.height = 0.36
	sphere_mesh.radial_segments = 6
	sphere_mesh.rings = 3
	_flame_particles.draw_pass_1 = sphere_mesh
	add_child(_flame_particles)
	
	# 2. Smoke Plume Trail
	_smoke_particles = GPUParticles3D.new()
	_smoke_particles.name = "ExhaustSmoke"
	_smoke_particles.amount = 35
	_smoke_particles.lifetime = 0.7
	_smoke_particles.randomness = 0.4
	_smoke_particles.local_coords = false
	_smoke_particles.position = Vector3(0, 0.1, 0)
	
	var smoke_mat = ParticleProcessMaterial.new()
	smoke_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	smoke_mat.emission_sphere_radius = 0.22
	smoke_mat.direction = Vector3(0, -1, 0)
	smoke_mat.spread = 28.0
	smoke_mat.initial_velocity_min = 3.5
	smoke_mat.initial_velocity_max = 7.0
	smoke_mat.gravity = Vector3(0, 1.5, 0)
	smoke_mat.damping_min = 2.0
	smoke_mat.damping_max = 4.0
	smoke_mat.scale_min = 0.3
	smoke_mat.scale_max = 0.65
	smoke_mat.scale_curve = scale_texture
	
	var smoke_grad = Gradient.new()
	smoke_grad.set_color(0, Color(0.8, 0.6, 0.4, 0.6))
	smoke_grad.add_point(0.4, Color(0.65, 0.65, 0.68, 0.45))
	smoke_grad.add_point(1.0, Color(0.4, 0.4, 0.45, 0.0))
	var smoke_grad_tex = GradientTexture1D.new()
	smoke_grad_tex.gradient = smoke_grad
	smoke_mat.color_ramp = smoke_grad_tex
	
	_smoke_particles.process_material = smoke_mat
	
	var smoke_draw_mat = StandardMaterial3D.new()
	smoke_draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_draw_mat.vertex_color_use_as_albedo = true
	smoke_draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	
	var smoke_mesh = SphereMesh.new()
	smoke_mesh.material = smoke_draw_mat
	smoke_mesh.radius = 0.24
	smoke_mesh.height = 0.48
	smoke_mesh.radial_segments = 6
	smoke_mesh.rings = 3
	_smoke_particles.draw_pass_1 = smoke_mesh
	add_child(_smoke_particles)
	
	# 3. Glowing Sparks
	_spark_particles = GPUParticles3D.new()
	_spark_particles.name = "Sparks"
	_spark_particles.amount = 25
	_spark_particles.lifetime = 0.4
	_spark_particles.randomness = 0.5
	_spark_particles.local_coords = false
	_spark_particles.position = Vector3(0, 0.05, 0)
	
	var spark_mat = ParticleProcessMaterial.new()
	spark_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	spark_mat.emission_sphere_radius = 0.12
	spark_mat.direction = Vector3(0, -1, 0)
	spark_mat.spread = 45.0
	spark_mat.initial_velocity_min = 6.0
	spark_mat.initial_velocity_max = 12.0
	spark_mat.gravity = Vector3(0, -5.0, 0)
	spark_mat.scale_min = 0.08
	spark_mat.scale_max = 0.18
	
	var spark_grad = Gradient.new()
	spark_grad.set_color(0, Color(1.0, 0.95, 0.4, 1.0))
	spark_grad.add_point(0.7, Color(1.0, 0.4, 0.1, 0.8))
	spark_grad.add_point(1.0, Color(0.8, 0.1, 0.0, 0.0))
	var spark_grad_tex = GradientTexture1D.new()
	spark_grad_tex.gradient = spark_grad
	spark_mat.color_ramp = spark_grad_tex
	
	_spark_particles.process_material = spark_mat
	
	var spark_draw_mat = StandardMaterial3D.new()
	spark_draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark_draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_draw_mat.vertex_color_use_as_albedo = true
	spark_draw_mat.albedo_color = Color(1.0, 0.9, 0.3, 1.0)
	
	var box_mesh = BoxMesh.new()
	box_mesh.material = spark_draw_mat
	box_mesh.size = Vector3(0.08, 0.08, 0.08)
	_spark_particles.draw_pass_1 = box_mesh
	add_child(_spark_particles)

func _setup_thruster_light() -> void:
	_thruster_light = OmniLight3D.new()
	_thruster_light.name = "ThrusterLight"
	_thruster_light.light_color = Color(1.0, 0.65, 0.25)
	_thruster_light.light_energy = 3.5
	_thruster_light.omni_range = 6.0
	_thruster_light.omni_attenuation = 1.2
	_thruster_light.position = Vector3(0, -0.2, 0)
	add_child(_thruster_light)

func _setup_ground_dust() -> void:
	_ground_dust = GPUParticles3D.new()
	_ground_dust.name = "GroundDust"
	_ground_dust.emitting = false
	_ground_dust.one_shot = true
	_ground_dust.explosiveness = 0.92
	_ground_dust.amount = 30
	_ground_dust.lifetime = 0.75
	_ground_dust.position = Vector3(0, 0.05, 0)
	
	var dust_mat = ParticleProcessMaterial.new()
	dust_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	dust_mat.emission_ring_radius = 0.8
	dust_mat.emission_ring_inner_radius = 0.2
	dust_mat.direction = Vector3(0, 0.25, 0)
	dust_mat.spread = 180.0
	dust_mat.initial_velocity_min = 3.5
	dust_mat.initial_velocity_max = 6.5
	dust_mat.gravity = Vector3(0, 0.5, 0)
	dust_mat.damping_min = 3.5
	dust_mat.damping_max = 5.5
	dust_mat.scale_min = 0.4
	dust_mat.scale_max = 0.8
	
	var dust_grad = Gradient.new()
	dust_grad.set_color(0, Color(0.9, 0.85, 0.75, 0.7))
	dust_grad.add_point(0.4, Color(0.8, 0.78, 0.72, 0.45))
	dust_grad.add_point(1.0, Color(0.7, 0.7, 0.7, 0.0))
	var dust_grad_tex = GradientTexture1D.new()
	dust_grad_tex.gradient = dust_grad
	dust_mat.color_ramp = dust_grad_tex
	
	_ground_dust.process_material = dust_mat
	
	var dust_draw_mat = StandardMaterial3D.new()
	dust_draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dust_draw_mat.vertex_color_use_as_albedo = true
	dust_draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	
	var dust_mesh = SphereMesh.new()
	dust_mesh.material = dust_draw_mat
	dust_mesh.radius = 0.3
	dust_mesh.height = 0.6
	dust_mesh.radial_segments = 6
	dust_mesh.rings = 3
	_ground_dust.draw_pass_1 = dust_mesh
	add_child(_ground_dust)

func _process(delta: float) -> void:
	_time_passed += delta
	if _is_thrusting:
		# Dynamic fire flicker & pulse
		var flicker = sin(_time_passed * 32.0) * 0.4 + cos(_time_passed * 47.0) * 0.3
		if _thruster_light:
			_thruster_light.light_energy = clamp((3.0 + flicker) * _thrust_power, 0.0, 8.0)
			_thruster_light.visible = true
	else:
		if _thruster_light:
			_thruster_light.light_energy = move_toward(_thruster_light.light_energy, 0.0, delta * 8.0)
			if _thruster_light.light_energy <= 0.05:
				_thruster_light.visible = false

func set_thrusters_active(active: bool, power: float = 1.0) -> void:
	_is_thrusting = active
	_thrust_power = power
	if _flame_particles:
		_flame_particles.emitting = active
	if _smoke_particles:
		_smoke_particles.emitting = active
	if _spark_particles:
		_spark_particles.emitting = active
	if _thruster_light:
		_thruster_light.visible = active

## Runs the full cinematic drop, character pop-out, and takeoff sequence
func execute_landing_sequence(companion: Node3D, landing_target: Vector3, on_complete: Callable = Callable()) -> void:
	if not is_inside_tree():
		await tree_entered
	
	var start_y: float = landing_target.y + 26.0
	global_position = Vector3(landing_target.x, start_y, landing_target.z)
	
	# Start with a subtle stabilizing aerodynamic tilt
	rotation_degrees = Vector3(5.0, 20.0, -3.5)
	
	# Keep companion hidden inside the rocket initially
	if companion and is_instance_valid(companion):
		companion.visible = false
		companion.global_position = Vector3(landing_target.x, landing_target.y + 1.2, landing_target.z)
	
	set_thrusters_active(true, 1.0)
	
	# 1. First 2.0 seconds: Audio plays during descent
	if TurretAudio:
		TurretAudio.play_rocket_thruster(2.0, 2.0)
	
	var seq = create_tween()
	
	# Majestic Descent Tween (2.0s)
	var descent_duration: float = 2.0
	seq.parallel().tween_property(self, "global_position:y", landing_target.y, descent_duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	seq.parallel().tween_property(self, "rotation_degrees", Vector3(0, 0, 0), descent_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# 2. Touchdown (Audio stops -> 1.5 seconds silence/pause starts)
	seq.chain().tween_callback(func():
		global_position.y = landing_target.y
		set_thrusters_active(false, 0.0)
		
		if _ground_dust:
			_ground_dust.restart()
			_ground_dust.emitting = true
		
		# Landing Squash & Stretch Cushion (0.35s)
		if _model_root:
			var cushion_tw = create_tween()
			cushion_tw.tween_property(_model_root, "scale", Vector3(base_scale.x * 1.22, base_scale.y * 0.75, base_scale.z * 1.22), 0.10)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			cushion_tw.tween_property(_model_root, "scale", Vector3(base_scale.x * 0.94, base_scale.y * 1.10, base_scale.z * 0.94), 0.12)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			cushion_tw.tween_property(_model_root, "scale", base_scale, 0.13)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)
	
	# Pause on ground (0.6s)
	seq.chain().tween_interval(0.60)
	
	# Companion Pop-Out Ejection
	seq.chain().tween_callback(func():
		if companion and is_instance_valid(companion):
			companion.visible = true
			var pop_start = Vector3(landing_target.x, landing_target.y + 1.2, landing_target.z)
			var pop_dest = landing_target
			
			if companion.has_method("play_pop_out_jump"):
				companion.call("play_pop_out_jump", pop_start, pop_dest)
			elif companion.has_method("play_deployment_drop"):
				companion.global_position = pop_start
				companion.call("play_deployment_drop", 1.2)
	)
	
	# Showcase Processing Window (0.9s) -> Total ground pause = 0.6s + 0.9s = 1.5s
	seq.chain().tween_interval(0.90)
	
	# 3. Rocket Re-ignition & Launch (Audio plays for 3.0 seconds)
	seq.chain().tween_callback(func():
		set_thrusters_active(true, 2.0)
		if TurretAudio:
			TurretAudio.play_rocket_thruster(3.0, 2.5)
		
		if _model_root:
			# Quick anticipation squish before launch
			var launch_prep_tw = create_tween()
			launch_prep_tw.tween_property(_model_root, "scale", Vector3(base_scale.x * 1.15, base_scale.y * 0.85, base_scale.z * 1.15), 0.14)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			launch_prep_tw.tween_property(_model_root, "scale", Vector3(base_scale.x * 0.85, base_scale.y * 1.25, base_scale.z * 0.85), 0.16)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	)
	
	# Blast-Off into Space (3.0s total launch window)
	seq.chain().tween_interval(0.20)
	var launch_duration: float = 2.80
	seq.chain().parallel().tween_property(self, "global_position:y", landing_target.y + 60.0, launch_duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	seq.parallel().tween_property(self, "rotation_degrees:y", rotation_degrees.y + 720.0, launch_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# 4. Complete and clean up
	seq.chain().tween_callback(func():
		if on_complete.is_valid():
			on_complete.call()
		queue_free()
	)
