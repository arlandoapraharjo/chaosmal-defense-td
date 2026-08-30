extends Node3D

@onready var currency_ui: CanvasLayer = get_node_or_null("CurrencyUI")
@onready var wave_ui: CanvasLayer = get_node_or_null("WaveUI")
@onready var turret_hotbar: CanvasLayer = get_node_or_null("TurretHotbar")
@onready var pause_overlay: CanvasLayer = get_node_or_null("PauseOverlay")
@onready var speed_toggle: CanvasLayer = get_node_or_null("SpeedToggle")
@onready var game_over_overlay: CanvasLayer = get_node_or_null("GameOverOverlay")
@onready var pillar_shockwave: CanvasLayer = get_node_or_null("PillarShockwave")
@onready var camera_3d: Camera3D = get_node_or_null("Camera3D")
@onready var builder_controller: Node = get_node_or_null("BuilderController")
@onready var intro_overlay: CanvasLayer = get_node_or_null("IntroOverlay")
@onready var fox_hud: CanvasLayer = get_node_or_null("FoxHUD")

var _is_menu_mode: bool = false
var _home_pos_currency: Vector2
var _home_pos_wave: Vector2
var _home_pos_pause: Vector2
var _home_pos_speed: Vector2
var _home_pos_hotbar: Vector2
var _has_saved_home_positions: bool = false

var _revealed_hotbar: bool = false
var _revealed_currency: bool = false
var _revealed_controls: bool = false
var _cam_default_pos: Vector3
var _cam_default_size: float = 20.0
var _cam_tween: Tween = null

const FOX_COMPANION_SCENE = preload("res://scenes/FoxCompanion.tscn")
var _fox_companion: FoxCompanion = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if pause_overlay:
		pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	if speed_toggle:
		speed_toggle.process_mode = Node.PROCESS_MODE_ALWAYS
	
	_save_home_positions()
	if camera_3d:
		_cam_default_pos = camera_3d.global_position
		_cam_default_size = camera_3d.size
	
	if intro_overlay:
		intro_overlay.intro_finished.connect(_on_intro_finished)
		intro_overlay.step_changed.connect(_on_intro_step_changed)

func set_menu_mode(menu_active: bool) -> void:
	_is_menu_mode = menu_active
	_revealed_hotbar = false
	_revealed_currency = false
	_revealed_controls = false

	# 1. Freeze Spawner while in menu or waiting for intro
	var spawner = find_child("Spawner", true, false)
	if not spawner:
		spawner = find_child("WaveManager", true, false)
	if spawner:
		spawner.set_physics_process(false)

	# 2. Hide Pillar floating 3D UI
	var pillar = get_tree().get_first_node_in_group("pillar")
	if pillar and pillar.has_method("set_ui_visible"):
		pillar.set_ui_visible(false)

	# 3. Game Over Overlay stays hidden until game over/victory
	if game_over_overlay:
		game_over_overlay.visible = false

	# 4. Disable Builder & Camera Controllers
	if builder_controller:
		builder_controller.set_process(false)
		builder_controller.set_physics_process(false)
		builder_controller.set_process_unhandled_input(false)

	if camera_3d:
		camera_3d.set_physics_process(false)
		camera_3d.set_process_unhandled_input(false)
		if not menu_active:
			_cam_default_pos = camera_3d.global_position
			_cam_default_size = camera_3d.size

	# 5. Hide all Gameplay UI
	if currency_ui: currency_ui.visible = false
	if wave_ui: wave_ui.visible = false
	if turret_hotbar: turret_hotbar.visible = false
	if pause_overlay: pause_overlay.visible = false
	if speed_toggle: speed_toggle.visible = false
	if pillar_shockwave: pillar_shockwave.visible = false
	if fox_hud: fox_hud.visible = false

	if menu_active:
		if intro_overlay:
			intro_overlay.visible = false
	else:
		_deploy_fox_companion()
		# Start Fox character intro if available
		if intro_overlay:
			intro_overlay.start_intro()
		else:
			_start_gameplay()

func _deploy_fox_companion() -> void:
	if _fox_companion == null or not is_instance_valid(_fox_companion):
		var existing = get_tree().get_first_node_in_group("fox_companion")
		if existing:
			_fox_companion = existing as FoxCompanion
		elif FOX_COMPANION_SCENE:
			_fox_companion = FOX_COMPANION_SCENE.instantiate() as FoxCompanion
			var map_gen = get_node_or_null("MapGenerator")
			if map_gen:
				map_gen.add_child(_fox_companion)
			else:
				add_child(_fox_companion)
	
	if _fox_companion and is_instance_valid(_fox_companion):
		var pillar = get_tree().get_first_node_in_group("pillar")
		var pillar_pos = pillar.global_position if pillar else Vector3(10, 0, 10)
		var spawn_pos = pillar_pos + Vector3(1.5, 0.05, 1.0)
		_fox_companion.global_position = spawn_pos
		_fox_companion.play_deployment_drop(5.5)

func _on_intro_step_changed(step_idx: int) -> void:
	if not camera_3d:
		return
	
	var pillar = get_tree().get_first_node_in_group("pillar")
	var pillar_pos = pillar.global_position if pillar else Vector3(10, 0, 10)
	
	match step_idx:
		0:
			# Step 1: Introduction - Camera zooms in tight on the deployed tiny Fox on the field!
			var fox_pos = _fox_companion.global_position if (_fox_companion and is_instance_valid(_fox_companion)) else (pillar_pos + Vector3(1.5, 0, 1.0))
			var target_cam_pos = _calc_camera_pos_for_target(fox_pos)
			_focus_camera(target_cam_pos, 8.5, 0.9)
		
		1:
			# Step 2: Mission Objective / Incursion Pillar - Zoom in on Pillar
			if pillar and pillar.has_method("set_ui_visible"):
				pillar.set_ui_visible(true)
			var target_cam_pos = _calc_camera_pos_for_target(pillar_pos)
			_focus_camera(target_cam_pos, 11.0, 0.9)
		
		2:
			# Step 3: Building Defenses - Camera frames path and Turret Hotbar slides in
			var path_target = pillar_pos + Vector3(-3.0, 0.0, -1.0)
			var target_cam_pos = _calc_camera_pos_for_target(path_target)
			_focus_camera(target_cam_pos, 14.5, 0.8)
			_reveal_hotbar_ui()
		
		3:
			# Step 4: Economy & Upgrades - Camera pulls back slightly and Currency UI (Coins) slides in
			_focus_camera(_cam_default_pos, 16.5, 0.8)
			_reveal_currency_ui()
		
		4:
			# Step 5: Battlefield Controls - Full map overview, Speed & Pause controls slide in
			_focus_camera(_cam_default_pos, _cam_default_size, 0.8)
			_reveal_controls_ui()
		
		5:
			# Step 6: Combat Stations - Full tactical view ready for battle
			_focus_camera(_cam_default_pos, _cam_default_size, 0.8)
			_reveal_all_remaining_ui()

func _calc_camera_pos_for_target(world_target: Vector3) -> Vector3:
	if not camera_3d:
		return Vector3.ZERO
	var cam_height = _cam_default_pos.y
	var forward_xz = -camera_3d.global_transform.basis.z
	forward_xz.y = 0
	forward_xz = forward_xz.normalized()
	var pitch_angle = asin(abs(camera_3d.global_transform.basis.z.y))
	if pitch_angle <= 0.001:
		pitch_angle = 0.785398
	var horizontal_offset = cam_height / tan(pitch_angle)
	var pos = Vector3(world_target.x, cam_height, world_target.z)
	pos -= forward_xz * horizontal_offset
	return pos

func _focus_camera(target_pos: Vector3, target_size: float, duration: float = 0.8) -> void:
	if not camera_3d:
		return
	if _cam_tween and _cam_tween.is_running():
		_cam_tween.kill()
	_cam_tween = create_tween()
	_cam_tween.set_parallel(true)
	_cam_tween.tween_property(camera_3d, "global_position", target_pos, duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_cam_tween.tween_property(camera_3d, "size", target_size, duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _reveal_hotbar_ui() -> void:
	if turret_hotbar and not _revealed_hotbar:
		_revealed_hotbar = true
		turret_hotbar.visible = true
		if turret_hotbar.has_method("_show_hotbar"):
			turret_hotbar._show_hotbar()

func _reveal_currency_ui() -> void:
	if currency_ui and not _revealed_currency:
		_revealed_currency = true
		currency_ui.visible = true
		var c_ctrl = currency_ui.get_node_or_null("Control/MarginContainer")
		if c_ctrl:
			c_ctrl.position.y = _home_pos_currency.y - 180
			var tween = create_tween()
			tween.tween_property(c_ctrl, "position:y", _home_pos_currency.y, 0.55)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _reveal_controls_ui() -> void:
	if not _revealed_controls:
		_revealed_controls = true
		if wave_ui:
			wave_ui.visible = true
			var w_ctrl = wave_ui.get_node_or_null("Control/MarginContainer")
			if w_ctrl:
				w_ctrl.position.y = _home_pos_wave.y - 180
				var tween = create_tween()
				tween.tween_property(w_ctrl, "position:y", _home_pos_wave.y, 0.55)\
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if pause_overlay:
			pause_overlay.visible = true
			var p_btn = pause_overlay.get_node_or_null("PauseButton")
			if p_btn:
				p_btn.position.y = _home_pos_pause.y - 120
				var tween = create_tween()
				tween.tween_property(p_btn, "position:y", _home_pos_pause.y, 0.55)\
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if speed_toggle:
			speed_toggle.visible = true
			var s_btn = speed_toggle.get_node_or_null("Control/SpeedButton")
			if s_btn:
				s_btn.position.y = _home_pos_speed.y - 120
				var tween = create_tween()
				tween.tween_property(s_btn, "position:y", _home_pos_speed.y, 0.55)\
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _reveal_all_remaining_ui() -> void:
	if not _revealed_hotbar:
		_revealed_hotbar = true
		if turret_hotbar:
			turret_hotbar.visible = true
	if not _revealed_currency:
		_reveal_currency_ui()
	if not _revealed_controls:
		_reveal_controls_ui()
	if fox_hud:
		fox_hud.visible = true

func _on_intro_finished() -> void:
	_start_gameplay()

func _start_gameplay() -> void:
	if _cam_tween and _cam_tween.is_running():
		_cam_tween.kill()

	# Ensure camera is returned to default gameplay position
	if camera_3d:
		camera_3d.global_position = _cam_default_pos
		camera_3d.size = _cam_default_size
		if "target_position" in camera_3d:
			camera_3d.target_position = _cam_default_pos
		if "target_ortho_size" in camera_3d:
			camera_3d.target_ortho_size = _cam_default_size

	# 1. Guarantee all gameplay UI is visible even if intro was skipped at step 0!
	if turret_hotbar:
		turret_hotbar.visible = true
		if turret_hotbar.has_method("_hide_hotbar"):
			turret_hotbar._hide_hotbar()
	if currency_ui:
		currency_ui.visible = true
	if wave_ui:
		wave_ui.visible = true
	if pause_overlay:
		pause_overlay.visible = true
	if speed_toggle:
		speed_toggle.visible = true
	if pillar_shockwave:
		pillar_shockwave.visible = true
	if fox_hud:
		fox_hud.visible = true

	_reveal_all_remaining_ui()

	# 2. Unfreeze / Activate Spawner (wave manager)
	var spawner = find_child("Spawner", true, false)
	if not spawner:
		spawner = find_child("WaveManager", true, false)
	if spawner:
		spawner.set_physics_process(true)
		if spawner.has_method("trigger_first_wave_if_waiting"):
			spawner.call("trigger_first_wave_if_waiting")

	# 3. Show Pillar floating 3D UI
	var pillar = get_tree().get_first_node_in_group("pillar")
	if pillar and pillar.has_method("set_ui_visible"):
		pillar.set_ui_visible(true)

	# 4. Enable Builder & Camera Controllers
	if builder_controller:
		builder_controller.set_process(true)
		builder_controller.set_physics_process(true)
		builder_controller.set_process_unhandled_input(true)

	if camera_3d:
		camera_3d.set_physics_process(true)
		camera_3d.set_process_unhandled_input(true)

func _save_home_positions() -> void:
	if _has_saved_home_positions:
		return

	if currency_ui:
		var c_ctrl = currency_ui.get_node_or_null("Control/MarginContainer")
		if c_ctrl: _home_pos_currency = c_ctrl.position

	if wave_ui:
		var w_ctrl = wave_ui.get_node_or_null("Control/MarginContainer")
		if w_ctrl: _home_pos_wave = w_ctrl.position

	if pause_overlay:
		var p_btn = pause_overlay.get_node_or_null("PauseButton")
		if p_btn: _home_pos_pause = p_btn.position

	if speed_toggle:
		var s_btn = speed_toggle.get_node_or_null("Control/SpeedButton")
		if s_btn: _home_pos_speed = s_btn.position

	_has_saved_home_positions = true

func is_menu_mode() -> bool:
	return _is_menu_mode
