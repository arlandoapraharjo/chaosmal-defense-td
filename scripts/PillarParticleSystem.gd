extends Node3D
class_name PillarParticleSystem

# --- Visual Colors (Neon Arcane Violet & Electric Purple) ---
const ELECTRIC_VIOLET: Color = Color(0.85, 0.40, 1.0, 1.0)
const ARCANE_PURPLE: Color = Color(0.72, 0.28, 1.0, 1.0)
const MAGENTA_ACCENT: Color = Color(0.92, 0.42, 0.98, 1.0)

# --- Node References ---
@onready var electric_sparks: GPUParticles3D = get_node_or_null("ElectricSparks")
@onready var arcane_motes: GPUParticles3D = get_node_or_null("ArcaneMotes")
@onready var base_aura: GPUParticles3D = get_node_or_null("BaseEnergyAura")
@onready var glow_light: OmniLight3D = get_node_or_null("ArcaneGlowLight")

# --- Dynamic Materials for Hue Scrolling ---
var motes_mat: StandardMaterial3D = null
var base_mat: StandardMaterial3D = null
var sparks_mat: StandardMaterial3D = null

# --- Preset Configurations per Level ---
# Progression Narrative:
# - Level 1 (Base): Highly unstable & broken -> prominent erratic electric spark leakage & dying flicker.
# - Level 2 (1st Upgrade): Calming down -> reduced spark count and velocity.
# - Level 3 (2nd Upgrade): Stabilizing -> subtle rare sparks, gentle violet/magenta hue drift starts.
# - Level 4 (3rd Upgrade): Stabilized -> sparks GONE (0 sparks), vibrant dual-tone indigo/fuchsia hue wave.
# - Level 5 (4th Upgrade / MAX): Perfect Arcane Resonance -> 0 sparks, celestial prism cycling (Cyan <-> Violet <-> Plasma Magenta).
@export var level_configs: Dictionary = {
	1: {
		"sparks_amount": 24, # Heavy short-circuit spark leakage
		"sparks_velocity": 2.8,
		"motes_amount": 14,
		"base_amount": 6,
		"light_energy": 0.45,
		"light_range": 4.0,
		"orbit_speed": 0.18,
		"upward_velocity": 0.60,
		"is_flickering": true,
		"flicker_intensity": 0.12,
	},
	2: {
		"sparks_amount": 14, # Noticeably reduced sparks
		"sparks_velocity": 2.3,
		"motes_amount": 22,
		"base_amount": 10,
		"light_energy": 0.70,
		"light_range": 5.0,
		"orbit_speed": 0.32,
		"upward_velocity": 0.75,
		"is_flickering": false,
		"flicker_intensity": 0.03,
	},
	3: {
		"sparks_amount": 5, # Stabilizing: very few subtle sparks
		"sparks_velocity": 1.8,
		"motes_amount": 34,
		"base_amount": 16,
		"light_energy": 0.95,
		"light_range": 6.5,
		"orbit_speed": 0.55,
		"upward_velocity": 0.90,
		"is_flickering": false,
		"flicker_intensity": 0.0,
	},
	4: {
		"sparks_amount": 0, # Stabilized on 3rd upgrade: sparks completely GONE
		"sparks_velocity": 0.0,
		"motes_amount": 50,
		"base_amount": 24,
		"light_energy": 1.20,
		"light_range": 8.0,
		"orbit_speed": 0.85,
		"upward_velocity": 1.10,
		"is_flickering": false,
		"flicker_intensity": 0.0,
	},
	5: {
		"sparks_amount": 0, # Fully stabilized: 0 sparks, pure serene plasma vortex
		"sparks_velocity": 0.0,
		"motes_amount": 72, # Dense, pristine luminous arcane vortex
		"base_amount": 36, # Radiant pedestal aura
		"light_energy": 1.50,
		"light_range": 9.5,
		"orbit_speed": 1.25,
		"upward_velocity": 1.35,
		"is_flickering": false,
		"flicker_intensity": 0.0,
	}
}

var current_level: int = 1
var is_active: bool = true
var is_flashing_damage: bool = false
var base_light_energy: float = 0.45

func _ready() -> void:
	_resolve_node_references()
	_setup_dynamic_materials()
	apply_level(current_level)

func _resolve_node_references() -> void:
	if not electric_sparks:
		electric_sparks = get_node_or_null("ElectricSparks")
	if not arcane_motes:
		arcane_motes = get_node_or_null("ArcaneMotes")
	if not base_aura:
		base_aura = get_node_or_null("BaseEnergyAura")
	if not glow_light:
		glow_light = get_node_or_null("ArcaneGlowLight")

func _setup_dynamic_materials() -> void:
	if arcane_motes and arcane_motes.draw_pass_1 and arcane_motes.draw_pass_1.material:
		var orig = arcane_motes.draw_pass_1.material as StandardMaterial3D
		if orig:
			motes_mat = orig.duplicate() as StandardMaterial3D
			arcane_motes.draw_pass_1 = arcane_motes.draw_pass_1.duplicate()
			arcane_motes.draw_pass_1.material = motes_mat

	if base_aura and base_aura.draw_pass_1 and base_aura.draw_pass_1.material:
		var orig = base_aura.draw_pass_1.material as StandardMaterial3D
		if orig:
			base_mat = orig.duplicate() as StandardMaterial3D
			base_aura.draw_pass_1 = base_aura.draw_pass_1.duplicate()
			base_aura.draw_pass_1.material = base_mat

	if electric_sparks and electric_sparks.draw_pass_1 and electric_sparks.draw_pass_1.material:
		var orig = electric_sparks.draw_pass_1.material as StandardMaterial3D
		if orig:
			sparks_mat = orig.duplicate() as StandardMaterial3D
			electric_sparks.draw_pass_1 = electric_sparks.draw_pass_1.duplicate()
			electric_sparks.draw_pass_1.material = sparks_mat

## Calculate smooth scrolling hue for levels 3-5
func get_current_color() -> Color:
	if current_level < 3:
		return ARCANE_PURPLE

	var time_sec: float = float(Time.get_ticks_msec()) * 0.001
	var speed: float = 0.6 + (current_level - 3) * 0.35

	if current_level == 3:
		# Subtle harmonic drift: Violet (0.74) <-> Amethyst Magenta (0.84)
		var h: float = 0.79 + 0.07 * sin(time_sec * speed)
		return Color.from_hsv(h, 0.75, 1.0)
	elif current_level == 4:
		# Vibrant dual-tone wave: Electric Indigo (0.66) <-> Radiant Fuchsia (0.88)
		var h: float = 0.77 + 0.13 * sin(time_sec * speed)
		return Color.from_hsv(h, 0.80, 1.0)
	else: # Level 5 MAX
		# Full Celestial Resonance: Mystic Cyan (0.52) <-> Arcane Violet (0.75) <-> Plasma Magenta (0.92)
		var h: float = wrapf(0.75 + 0.24 * sin(time_sec * speed), 0.0, 1.0)
		return Color.from_hsv(h, 0.85, 1.0)

func _process(_delta: float) -> void:
	if not is_active:
		return

	var current_color: Color = get_current_color()
	var cfg: Dictionary = level_configs.get(current_level, level_configs[1])

	# Update OmniLight energy & color
	if glow_light and is_instance_valid(glow_light):
		if not is_flashing_damage:
			glow_light.light_color = current_color
			var time_ms: float = float(Time.get_ticks_msec())
			if cfg.get("is_flickering", false):
				var noise_flicker: float = sin(time_ms * 0.022) * cos(time_ms * 0.009)
				glow_light.light_energy = max(0.1, base_light_energy + noise_flicker * cfg.get("flicker_intensity", 0.1))
			else:
				var pulse: float = 0.92 + 0.12 * sin(time_ms * (0.002 + current_level * 0.0005))
				glow_light.light_energy = base_light_energy * pulse

	# Update particle material colors in real time
	if motes_mat and is_instance_valid(motes_mat):
		motes_mat.albedo_color = current_color
		motes_mat.emission = current_color
	if base_mat and is_instance_valid(base_mat):
		base_mat.albedo_color = current_color.lerp(MAGENTA_ACCENT, 0.25)
		base_mat.emission = current_color.lerp(MAGENTA_ACCENT, 0.25)
	if sparks_mat and is_instance_valid(sparks_mat):
		sparks_mat.albedo_color = current_color.lerp(ELECTRIC_VIOLET, 0.3)
		sparks_mat.emission = current_color.lerp(ELECTRIC_VIOLET, 0.3)

## Set the progression level (1 to 5) and update particle emitters & lighting smoothly
func set_level(level: int) -> void:
	current_level = clamp(level, 1, 5)
	apply_level(current_level)

func apply_level(level: int) -> void:
	_resolve_node_references()
	var cfg: Dictionary = level_configs.get(level, level_configs[1])
	base_light_energy = cfg.get("light_energy", 0.45)

	# 1. Update Electric Needle Sparks (smooth, visible speeds; gone at L4 and L5)
	if electric_sparks and is_instance_valid(electric_sparks):
		var spk_amt: int = cfg.get("sparks_amount", 0)
		if spk_amt > 0 and is_active:
			electric_sparks.amount = spk_amt
			electric_sparks.emitting = true
			var spk_proc: ParticleProcessMaterial = electric_sparks.process_material as ParticleProcessMaterial
			if spk_proc:
				var vel_base: float = cfg.get("sparks_velocity", 2.5)
				spk_proc.radial_velocity_min = vel_base * 0.75
				spk_proc.radial_velocity_max = vel_base * 1.30
				spk_proc.initial_velocity_min = vel_base * 0.4
				spk_proc.initial_velocity_max = vel_base * 0.8
		else:
			electric_sparks.emitting = false

	# 2. Update Rising Arcane Energy Motes (increases as pillar stabilizes)
	if arcane_motes and is_instance_valid(arcane_motes):
		arcane_motes.amount = cfg.get("motes_amount", 14)
		var motes_proc: ParticleProcessMaterial = arcane_motes.process_material as ParticleProcessMaterial
		if motes_proc:
			var orb: float = cfg.get("orbit_speed", 0.2)
			motes_proc.orbit_velocity_min = orb * 0.75
			motes_proc.orbit_velocity_max = orb * 1.25
			var vel: float = cfg.get("upward_velocity", 0.6)
			motes_proc.initial_velocity_min = vel * 0.7
			motes_proc.initial_velocity_max = vel * 1.3

	# 3. Update Base Energy Aura
	if base_aura and is_instance_valid(base_aura):
		base_aura.amount = cfg.get("base_amount", 6)

	# 4. Smoothly update OmniLight3D
	if glow_light and is_instance_valid(glow_light) and is_inside_tree():
		var tween: Tween = create_tween()
		if tween:
			tween.set_parallel(true)
			tween.tween_property(glow_light, "light_color", get_current_color(), 0.35)
			tween.tween_property(glow_light, "light_energy", base_light_energy, 0.35)
			tween.tween_property(glow_light, "omni_range", cfg.get("light_range", 4.0), 0.35)

## Enable or disable all particle emission and lighting
func set_active(active: bool) -> void:
	is_active = active
	if electric_sparks and is_instance_valid(electric_sparks):
		var spk_amt: int = level_configs.get(current_level, {}).get("sparks_amount", 0)
		electric_sparks.emitting = active and (spk_amt > 0)
	if arcane_motes and is_instance_valid(arcane_motes):
		arcane_motes.emitting = active
	if base_aura and is_instance_valid(base_aura):
		base_aura.emitting = active
	if glow_light and is_instance_valid(glow_light):
		glow_light.visible = active

## Trigger damage flash on light & temporary instability electric spark burst
func flash_damage(duration: float = 0.25) -> void:
	if not is_inside_tree() or not glow_light or not is_instance_valid(glow_light):
		return

	is_flashing_damage = true
	var orig_color: Color = get_current_color()
	var orig_energy: float = base_light_energy

	glow_light.light_color = Color(1.0, 0.18, 0.22) # Damage Crimson
	glow_light.light_energy = orig_energy * 2.2

	# Momentary instability spark flare on hit
	if electric_sparks and is_instance_valid(electric_sparks) and is_active:
		var orig_amount: int = electric_sparks.amount
		electric_sparks.amount = max(14, orig_amount + 10)
		electric_sparks.emitting = true
		electric_sparks.restart()

	var tween: Tween = create_tween()
	if tween:
		tween.tween_property(glow_light, "light_color", orig_color, duration)
		tween.parallel().tween_property(glow_light, "light_energy", orig_energy, duration)
		tween.tween_callback(func():
			is_flashing_damage = false
			if is_active:
				apply_level(current_level)
		)
	else:
		is_flashing_damage = false
		if is_active:
			apply_level(current_level)

## Trigger defeat/destruction state
func trigger_defeat() -> void:
	set_active(false)
