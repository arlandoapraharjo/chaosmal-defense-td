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

var _is_menu_mode: bool = false
var _home_pos_currency: Vector2
var _home_pos_wave: Vector2
var _home_pos_pause: Vector2
var _home_pos_speed: Vector2
var _home_pos_hotbar: Vector2
var _has_saved_home_positions: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if pause_overlay:
		pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	if speed_toggle:
		speed_toggle.process_mode = Node.PROCESS_MODE_ALWAYS

func set_menu_mode(menu_active: bool) -> void:
	_is_menu_mode = menu_active

	# 1. Freeze / Activate Spawner (wave manager)
	var spawner = find_child("Spawner", true, false)
	if not spawner:
		spawner = find_child("WaveManager", true, false)
	if spawner:
		spawner.set_physics_process(not menu_active)
		if not menu_active and spawner.has_method("trigger_first_wave_if_waiting"):
			spawner.call("trigger_first_wave_if_waiting")

	# 2. Hide / Show Pillar floating 3D UI
	var pillar = get_tree().get_first_node_in_group("pillar")
	if pillar and pillar.has_method("set_ui_visible"):
		pillar.set_ui_visible(not menu_active)

	# 3. Game Over Overlay stays hidden until game over/victory
	if game_over_overlay:
		game_over_overlay.visible = false

	# 4. Builder & Camera Controllers
	if builder_controller:
		builder_controller.set_process(not menu_active)
		builder_controller.set_physics_process(not menu_active)
		builder_controller.set_process_unhandled_input(not menu_active)

	if camera_3d:
		camera_3d.set_physics_process(not menu_active)
		camera_3d.set_process_unhandled_input(not menu_active)

	# 5. UI Visibility & Slide-In Animations
	if menu_active:
		if currency_ui: currency_ui.visible = false
		if wave_ui: wave_ui.visible = false
		if turret_hotbar: turret_hotbar.visible = false
		if pause_overlay: pause_overlay.visible = false
		if speed_toggle: speed_toggle.visible = false
		if pillar_shockwave: pillar_shockwave.visible = false
	else:
		if pillar_shockwave: pillar_shockwave.visible = true
		_animate_gameplay_ui_slide_in()

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

	if turret_hotbar:
		var h_panel = turret_hotbar.get_node_or_null("HotbarPanel")
		if h_panel: _home_pos_hotbar = h_panel.position

	_has_saved_home_positions = true

func _animate_gameplay_ui_slide_in() -> void:
	_save_home_positions()

	# A. Coins UI (CurrencyUI) — Slide in from TOP
	if currency_ui:
		currency_ui.visible = true
		var c_ctrl = currency_ui.get_node_or_null("Control/MarginContainer")
		if c_ctrl:
			c_ctrl.position.y = _home_pos_currency.y - 180
			var tween = create_tween()
			tween.tween_property(c_ctrl, "position:y", _home_pos_currency.y, 0.55)\
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# B. Wave UI (WaveUI) — Slide in from TOP
	if wave_ui:
		wave_ui.visible = true
		var w_ctrl = wave_ui.get_node_or_null("Control/MarginContainer")
		if w_ctrl:
			w_ctrl.position.y = _home_pos_wave.y - 180
			var tween = create_tween()
			tween.tween_property(w_ctrl, "position:y", _home_pos_wave.y, 0.55)\
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# C. Pause Button (PauseOverlay) — Slide in from TOP
	if pause_overlay:
		pause_overlay.visible = true
		var p_btn = pause_overlay.get_node_or_null("PauseButton")
		if p_btn:
			p_btn.position.y = _home_pos_pause.y - 120
			var tween = create_tween()
			tween.tween_property(p_btn, "position:y", _home_pos_pause.y, 0.55)\
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# D. Speedup Button (SpeedToggle) — Slide in from TOP
	if speed_toggle:
		speed_toggle.visible = true
		var s_btn = speed_toggle.get_node_or_null("Control/SpeedButton")
		if s_btn:
			s_btn.position.y = _home_pos_speed.y - 120
			var tween = create_tween()
			tween.tween_property(s_btn, "position:y", _home_pos_speed.y, 0.55)\
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# E. Turret Hotbar (TurretHotbar) — Slide in from BOTTOM
	if turret_hotbar:
		turret_hotbar.visible = true
		var h_panel = turret_hotbar.get_node_or_null("HotbarPanel")
		if h_panel:
			h_panel.position.y = _home_pos_hotbar.y + 220
			var tween = create_tween()
			tween.tween_property(h_panel, "position:y", _home_pos_hotbar.y, 0.6)\
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func is_menu_mode() -> bool:
	return _is_menu_mode
