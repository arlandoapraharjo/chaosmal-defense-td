extends Node3D
# Speed in tiles per second
@export var speed: float = 0.35
## Rotations per second for the UFO spin animation
@export var spin_speed: float = 0.25

var explosion_scene: PackedScene = preload("res://scenes/explosion.tscn")

var path_waypoints: Array[Vector3] = []
var current_waypoint_index: int = 0
var _is_done: bool = false
var _spin_angle: float = 0.0
var _visual_node: Node3D = null
## Base speed set at reset time — speed multiplier is applied on top of this
var _base_speed: float = 0.65
var _speed_multiplier: float = 1.0
var _rage_multiplier: float = 1.0
var _rage_timer: float = 0.0
var _has_boosted_hp: bool = false

# ─── Ability & Shield Properties ─────────────────────────────────────────────
var has_shield: bool = false
var is_boss: bool = false
var boss_ability_type: int = 0 # 0 = Speed Boost (Rage), 1 = 1-Hit Shield

# ─── Shader Overlay Components ───────────────────────────────────────────────
var _outline_shader: Shader = preload("res://shaders/outline_pixel_perfect.gdshader")
var _outline_material: ShaderMaterial = null
var _mesh_nodes: Array[MeshInstance3D] = []

# ─── Health Bar Components ──────────────────────────────────────────────────
var _hp_viewport: SubViewport = null
var _hp_bar: ProgressBar = null
var _hp_sprite: Sprite3D = null
var _hp_bar_fill_style: StyleBoxFlat = null

## How quickly the UFO turns to face the next waypoint (higher = snappier)
@export var turn_smoothing: float = 8.0
signal reached_end
signal enemy_defeated

@export var max_hp: float = 100.0
var current_hp: float = 100.0

## Coin reward when this enemy is defeated — set by setup_enemy_type()
var coin_value: int = 1
## Index of the UFO model type (0-3), used to assign stats
var enemy_type_index: int = 0

# Stats per UFO type: [coin_value, max_hp]
const ENEMY_TYPE_STATS: Array = [
	[2, 80.0],    # UFO-A: cheap, fragile
	[4, 120.0],   # UFO-B: moderate
	[7, 180.0],   # UFO-C: tough
	[10, 260.0],  # UFO-D: elite, tanky
]

# Damage dealt to the Incursion Pillar on suicide impact per UFO type
const ENEMY_TYPE_DAMAGE: Array[float] = [10.0, 15.0, 20.0, 25.0]

func get_contact_damage() -> float:
	if enemy_type_index >= 0 and enemy_type_index < ENEMY_TYPE_DAMAGE.size():
		return ENEMY_TYPE_DAMAGE[enemy_type_index]
	return 10.0

## Assign coin_value and max_hp based on the UFO model type index, wave number, and boss flag.
func setup_enemy_type(type_index: int, wave_number: int = 1, is_boss_unit: bool = false) -> void:
	enemy_type_index = type_index
	is_boss = is_boss_unit
	
	var base_coins = 1
	var base_hp = 100.0
	
	if type_index >= 0 and type_index < ENEMY_TYPE_STATS.size():
		base_coins = ENEMY_TYPE_STATS[type_index][0]
		base_hp = ENEMY_TYPE_STATS[type_index][1]
		
	# Apply wave scaling
	var scaled_hp = base_hp * (1.0 + (wave_number - 1) * 0.15)
	
	if is_boss:
		max_hp = scaled_hp * 3.5 # 3.5x HP for Boss
		coin_value = (base_coins + int(wave_number / 3.0)) * 3
		boss_ability_type = randi() % 2 # 0 = Speed Boost (Rage), 1 = 1-Hit Shield
		has_shield = (boss_ability_type == 1)
	else:
		max_hp = scaled_hp
		coin_value = base_coins + int(wave_number / 3.0)
		boss_ability_type = 0
		has_shield = (type_index == 2) # UFO-C has 1-Hit Shield
		
	current_hp = max_hp

func setup(waypoints: Array[Vector3]) -> void:
	path_waypoints = waypoints
	current_waypoint_index = 0
	_is_done = false
	current_hp = max_hp
	_cache_visual_node()

## Cache the first child node to apply the spin rotation to,
## so we don't interfere with the parent's path-following orientation.
func _cache_visual_node() -> void:
	if _visual_node != null:
		return
	for child in get_children():
		if child is Node3D:
			_visual_node = child
			break

# ─── Shader & Outline Overlay Helper Methods ─────────────────────────────────
func _collect_mesh_nodes(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if node is MeshInstance3D:
		if node not in _mesh_nodes:
			_mesh_nodes.append(node)
	for child in node.get_children():
		_collect_mesh_nodes(child)

func _apply_ability_outline(color: Color, width: float = 4.0) -> void:
	if _outline_material == null:
		_outline_material = ShaderMaterial.new()
		_outline_material.shader = _outline_shader
		
	_outline_material.set_shader_parameter("outline_color", color)
	_outline_material.set_shader_parameter("outline_width", width)
	_outline_material.set_shader_parameter("emission_boost", 0.4)
	
	if _mesh_nodes.is_empty():
		_collect_mesh_nodes(self)
		
	for mesh in _mesh_nodes:
		if is_instance_valid(mesh):
			mesh.material_overlay = _outline_material

func _remove_ability_outline() -> void:
	for mesh in _mesh_nodes:
		if is_instance_valid(mesh):
			mesh.material_overlay = null

## Apply a global speed multiplier (1.0 = normal, 2.0 = double, 4.0 = quad).
func set_speed_multiplier(multiplier: float) -> void:
	_speed_multiplier = multiplier
	speed = _base_speed * _speed_multiplier * _rage_multiplier

## Re-initialize this enemy for reuse from the pool.
## Places it at the first waypoint and makes it visible/active.
func reset(waypoints: Array[Vector3], new_speed: float) -> void:
	path_waypoints = waypoints
	current_waypoint_index = 0
	_is_done = false
	current_hp = max_hp
	_base_speed = new_speed
	_rage_multiplier = 1.0
	_rage_timer = 0.0
	_has_boosted_hp = false
	speed = _base_speed * _speed_multiplier * _rage_multiplier
	visible = true
	set_physics_process(true)
	EnemyDetector.register(self)
	
	_cache_visual_node()
	_mesh_nodes.clear()
	_collect_mesh_nodes(self)
	_remove_ability_outline()
	
	# Apply shield outline on spawn if shield is active
	if has_shield:
		if is_boss:
			_apply_ability_outline(Color(1.0, 0.85, 0.2), 5.0) # Gold Shield Outline for Boss
		else:
			_apply_ability_outline(Color(0.2, 0.85, 1.0), 4.5) # Cyan Shield Outline for UFO-C
			
	_update_health_bar()
	
	# Pop-up animation & Boss scale
	var target_scale = Vector3(1.35, 1.35, 1.35) if is_boss else Vector3.ONE
	scale = Vector3(0.001, 0.001, 0.001)
	var tween = create_tween()
	tween.tween_property(self, "scale", target_scale, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	if not waypoints.is_empty():
		position = waypoints[0]
		if waypoints.size() > 1:
			var dir = waypoints[1] - waypoints[0]
			var look_dir = Vector3(dir.x, 0, dir.z)
			if look_dir.length() > 0.001:
				rotation.y = atan2(look_dir.x, look_dir.z)
	_spin_angle = 0.0

## Hide and stop processing — the Spawner will reclaim this node.
func deactivate() -> void:
	_is_done = true
	EnemyDetector.unregister(self)
	_remove_ability_outline()
	if _hp_sprite:
		_hp_sprite.visible = false
	visible = false
	set_physics_process(false)

# ─── 3D Billboard Health Bar ──────────────────────────────────────────────────
func _setup_health_bar() -> void:
	if _hp_sprite != null:
		return
		
	_hp_viewport = SubViewport.new()
	_hp_viewport.transparent_bg = true
	_hp_viewport.size = Vector2i(128, 20)
	_hp_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_hp_viewport)

	var bg_panel = Panel.new()
	bg_panel.custom_minimum_size = Vector2(128, 20)
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.08, 0.08, 0.12, 0.85)
	bg_style.border_color = Color(0.3, 0.3, 0.45, 0.9)
	bg_style.set_border_width_all(2)
	bg_style.set_corner_radius_all(4)
	bg_panel.add_theme_stylebox_override("panel", bg_style)
	_hp_viewport.add_child(bg_panel)

	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(120, 12)
	_hp_bar.position = Vector2(4, 4)
	_hp_bar.show_percentage = false
	_hp_bar.max_value = max_hp
	_hp_bar.value = current_hp

	var bar_bg_style = StyleBoxFlat.new()
	bar_bg_style.bg_color = Color(0.15, 0.05, 0.05, 0.8)
	bar_bg_style.set_corner_radius_all(3)
	_hp_bar.add_theme_stylebox_override("background", bar_bg_style)

	_hp_bar_fill_style = StyleBoxFlat.new()
	_hp_bar_fill_style.bg_color = Color(0.2, 0.85, 0.35, 1.0)
	_hp_bar_fill_style.set_corner_radius_all(3)
	_hp_bar.add_theme_stylebox_override("fill", _hp_bar_fill_style)
	bg_panel.add_child(_hp_bar)

	_hp_sprite = Sprite3D.new()
	_hp_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_sprite.double_sided = true
	_hp_sprite.no_depth_test = true
	_hp_sprite.texture = _hp_viewport.get_texture()
	_hp_sprite.pixel_size = 0.008
	_hp_sprite.position = Vector3(0, 0.85, 0)
	_hp_sprite.visible = false
	add_child(_hp_sprite)

func _update_health_bar() -> void:
	if _hp_sprite == null:
		_setup_health_bar()
		
	if _hp_bar != null:
		_hp_bar.max_value = max_hp
		_hp_bar.value = clamp(current_hp, 0.0, max_hp)
		
		var ratio = current_hp / max_hp if max_hp > 0.0 else 0.0
		if ratio >= 0.999 or current_hp <= 0.0:
			_hp_sprite.visible = false
		else:
			_hp_sprite.visible = true
			if ratio > 0.5:
				_hp_bar_fill_style.bg_color = Color(0.2, 0.85, 0.35, 1.0) # Vibrant Green
			elif ratio > 0.25:
				_hp_bar_fill_style.bg_color = Color(0.95, 0.75, 0.2, 1.0) # Yellow/Orange
			else:
				_hp_bar_fill_style.bg_color = Color(0.9, 0.2, 0.2, 1.0) # Danger Red

# ─── Speed Boost (Rage Dash) ──────────────────────────────────────────────────
func _trigger_speed_boost() -> void:
	_rage_multiplier = 5.0
	_rage_timer = 0.8
	speed = _base_speed * _speed_multiplier * _rage_multiplier
	
	# Apply Outline Shader: Gold for Boss, Red/Orange for UFO-A
	if is_boss:
		_apply_ability_outline(Color(1.0, 0.85, 0.2), 5.5)
	else:
		_apply_ability_outline(Color(1.0, 0.35, 0.1), 4.5)
	
	# Visual rage pulse animation
	if _visual_node:
		var target_s = Vector3(1.35, 1.35, 1.35) if is_boss else Vector3.ONE
		var tween = create_tween()
		tween.tween_property(_visual_node, "scale", target_s * 1.4, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(_visual_node, "scale", target_s, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _physics_process(delta: float) -> void:
	if _is_done or path_waypoints.is_empty():
		return

	# Handle speed boost duration (0.8s timer)
	if _rage_timer > 0.0:
		_rage_timer -= delta
		if _rage_timer <= 0.0:
			_rage_timer = 0.0
			_rage_multiplier = 1.0
			speed = _base_speed * _speed_multiplier * _rage_multiplier
			_remove_ability_outline()

	# UFO spin animation — counter-rotate by parent heading so the spin
	# stays fixed in world space regardless of the enemy's travel direction
	if _visual_node:
		_spin_angle += spin_speed * TAU * delta
		_visual_node.rotation.y = _spin_angle - rotation.y

	if current_waypoint_index >= path_waypoints.size():
		_hit_pillar_and_explode()
		return

	# How far this enemy is allowed to travel this tick. Any distance left
	# over after reaching a waypoint gets spent on the NEXT waypoint in the
	# same tick, rather than being allowed to overshoot past the current
	# one — that overshoot is what was letting enemies keep travelling in
	# their old direction straight through corner tiles instead of turning.
	var remaining_move = speed * delta

	while remaining_move > 0.0 and current_waypoint_index < path_waypoints.size():
		var target = path_waypoints[current_waypoint_index]
		var to_target = target - position
		var dist = to_target.length()

		if dist <= remaining_move:
			# Snap exactly onto the waypoint (never past it), spend only
			# the distance it actually took to get there, and move on.
			position = target
			remaining_move -= dist
			current_waypoint_index += 1

			if current_waypoint_index < path_waypoints.size():
				var next_target = path_waypoints[current_waypoint_index]
				var look_dir = Vector3(next_target.x - position.x, 0, next_target.z - position.z)
				if look_dir.length() > 0.001:
					var target_angle = atan2(look_dir.x, look_dir.z)
					rotation.y = lerp_angle(rotation.y, target_angle, turn_smoothing * delta)
		else:
			var dir = to_target / dist # already-normalized direction, reusing the length we computed
			position += dir * remaining_move

			var look_dir = Vector3(dir.x, 0, dir.z)
			if look_dir.length() > 0.001:
				var target_angle = atan2(look_dir.x, look_dir.z)
				rotation.y = lerp_angle(rotation.y, target_angle, turn_smoothing * delta)

			remaining_move = 0.0

	if current_waypoint_index >= path_waypoints.size():
		_hit_pillar_and_explode()

func _spawn_explosion() -> void:
	var explosion = explosion_scene.instantiate()
	var scene_root = get_tree().current_scene
	if scene_root:
		scene_root.add_child(explosion)
	else:
		get_parent().add_child(explosion)
	explosion.global_position = global_position
	for child in explosion.get_children():
		if child is GPUParticles3D:
			child.emitting = true
	get_tree().create_timer(2.0).timeout.connect(explosion.queue_free)

func _hit_pillar_and_explode() -> void:
	if _is_done:
		return
	_is_done = true
	_remove_ability_outline()
	_spawn_explosion()
	
	# Find pillar in scene and apply suicide attack damage
	var pillar = get_tree().get_first_node_in_group("pillar")
	if not pillar:
		var scene_root = get_tree().current_scene
		if scene_root:
			pillar = scene_root.find_child("IncursionPillar", true, false)
	if pillar and pillar.has_method("take_damage"):
		pillar.take_damage(get_contact_damage())
		
	reached_end.emit()
	deactivate()

func destroy_by_shockwave(delay: float = 0.0) -> void:
	if _is_done or not visible:
		return
	if delay > 0.0:
		get_tree().create_timer(delay).timeout.connect(_on_shockwave_explode)
	else:
		_on_shockwave_explode()

func _on_shockwave_explode() -> void:
	if _is_done or not is_inside_tree() or not visible:
		return
	_is_done = true
	_remove_ability_outline()
	_spawn_explosion()
	enemy_defeated.emit()
	reached_end.emit()
	deactivate()

func take_damage(amount: float) -> void:
	if _is_done:
		return
		
	# 1-Hit Shield Check (UFO-C or Shield Boss)
	if has_shield:
		has_shield = false
		_remove_ability_outline()
		
		# Shield block pulse effect
		if _visual_node:
			var s = Vector3(1.35, 1.35, 1.35) if is_boss else Vector3.ONE
			var tw = create_tween()
			tw.tween_property(_visual_node, "scale", s * 1.25, 0.1).set_trans(Tween.TRANS_BACK)
			tw.tween_property(_visual_node, "scale", s, 0.2).set_trans(Tween.TRANS_SINE)
		return # Damage is 100% blocked!
		
	current_hp -= amount
	_update_health_bar()
	
	# Speed boost trigger (5x speed for 0.8s under 40% HP)
	var can_rage = (enemy_type_index == 0) or (is_boss and boss_ability_type == 0)
	if can_rage and not _has_boosted_hp and current_hp > 0.0:
		if (current_hp / max_hp) < 0.4:
			_has_boosted_hp = true
			_trigger_speed_boost()

	if current_hp <= 0:
		current_hp = 0
		_is_done = true
		_remove_ability_outline()
		_spawn_explosion()
		
		enemy_defeated.emit()
		if CurrencyManager.instance:
			CurrencyManager.instance.add_currency(coin_value)
		reached_end.emit()
		deactivate()

