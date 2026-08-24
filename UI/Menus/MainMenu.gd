extends Control


@onready var sub_viewport: SubViewport = $SubViewportContainer/SubViewport
@onready var left_panel: Control = $CanvasLayer/Control/LeftPanel
@onready var vbox: VBoxContainer = $CanvasLayer/Control/LeftPanel/VBoxContainer
@onready var panel_settings: VBoxContainer = $CanvasLayer/Control/LeftPanel/PanelSettings
@onready var check_fullscreen: CheckButton = $CanvasLayer/Control/LeftPanel/PanelSettings/HBoxFullscreen/CheckButtonFullscreen
@onready var slider_master: HSlider = $CanvasLayer/Control/LeftPanel/PanelSettings/HBoxMaster/SliderMaster
@onready var slider_music: HSlider = $CanvasLayer/Control/LeftPanel/PanelSettings/HBoxMusic/SliderMusic
@onready var slider_sfx: HSlider = $CanvasLayer/Control/LeftPanel/PanelSettings/HBoxSFX/SliderSFX

const SLIDE_DURATION := 0.45

var _world_node: Node3D = null
var _camera: Camera3D = null
var _gameplay_cam_transform: Transform3D
var _gameplay_cam_ortho_size: float = 20.0

var _viewport_width: float
var _home_pos_vbox: Vector2
var _home_pos_settings: Vector2
var _is_animating := false
var _is_game_started := false
var _orbit_angle: float = 0.75
var _orbit_center := Vector3(10.0, 0.0, 10.0)
var _orbit_radius := 22.0
var _orbit_height := 8.5

func _ready() -> void:
	# 1. Initialize BiomeManager
	if BiomeManager != null:
		BiomeManager.randomize_biome()

	# 2. Instance map scene if SubViewport is empty or get existing child
	_setup_world()

	# Wait one frame for UI anchors before reading positions
	await get_tree().process_frame

	_viewport_width = get_viewport_rect().size.x
	_home_pos_vbox = vbox.position
	_home_pos_settings = panel_settings.position

	# Sync UI state with system
	if check_fullscreen:
		check_fullscreen.button_pressed = (
			DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		)
	if slider_master:
		slider_master.value = db_to_linear(
			AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))
		)
	var music_idx := AudioServer.get_bus_index("Music")
	if music_idx >= 0 and slider_music:
		slider_music.value = db_to_linear(AudioServer.get_bus_volume_db(music_idx))
	var sfx_idx := AudioServer.get_bus_index("SFX")
	if sfx_idx >= 0 and slider_sfx:
		slider_sfx.value = db_to_linear(AudioServer.get_bus_volume_db(sfx_idx))

	# Hide settings panel before intro animation
	panel_settings.visible = false

	# Intro animation: VBoxContainer slides in from off-screen left
	vbox.position.x -= _viewport_width
	var intro_tween := create_tween()
	intro_tween.tween_property(vbox, "position:x", _home_pos_vbox.x, SLIDE_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func _setup_world() -> void:
	if sub_viewport.get_child_count() > 0:
		_world_node = sub_viewport.get_child(0) as Node3D

	if _world_node == null:
		var map_scene = load("res://scenes/map.tscn")
		if map_scene:
			_world_node = map_scene.instantiate() as Node3D
			sub_viewport.add_child(_world_node)

	if _world_node:
		if _world_node.has_method("set_menu_mode"):
			_world_node.call("set_menu_mode", true)

		_camera = _world_node.get_node_or_null("Camera3D") as Camera3D
		if _camera:
			_gameplay_cam_transform = _camera.global_transform
			_gameplay_cam_ortho_size = _camera.size
			_update_menu_camera_pose()

func _process(delta: float) -> void:
	if _is_game_started or _camera == null:
		return

	# Slow diorama orbit around map center while idling in main menu
	_orbit_angle += delta * 0.05
	_update_menu_camera_pose()

func _update_menu_camera_pose() -> void:
	if _camera == null:
		return

	var cam_x = _orbit_center.x + _orbit_radius * cos(_orbit_angle)
	var cam_z = _orbit_center.z + _orbit_radius * sin(_orbit_angle)
	_camera.global_position = Vector3(cam_x, _orbit_height, cam_z)
	_camera.look_at(_orbit_center + Vector3(0, 1.2, 0))

func _on_start_button_pressed() -> void:
	if _is_animating or _is_game_started:
		return
	_is_animating = true
	_is_game_started = true

	# Parallel tween: camera moves to top-down view + panel fades & slides out left
	var tween := create_tween()
	tween.set_parallel(true)

	if _camera:
		tween.tween_property(_camera, "global_transform", _gameplay_cam_transform, 1.4) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(_camera, "size", _gameplay_cam_ortho_size, 1.4) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	if left_panel:
		tween.tween_property(left_panel, "modulate:a", 0.0, 1.0) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	tween.tween_property(vbox, "position:x", _home_pos_vbox.x - _viewport_width, 0.6) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)

	tween.chain().tween_callback(func():
		$CanvasLayer.visible = false
		if _world_node and _world_node.has_method("set_menu_mode"):
			_world_node.call("set_menu_mode", false)
		_is_animating = false
	)

func _on_settings_button_pressed() -> void:
	if _is_animating:
		return
	_is_animating = true

	# Place PanelSettings off-screen left, then reveal it
	panel_settings.position.x = _home_pos_settings.x - _viewport_width
	panel_settings.visible = true

	var tween := create_tween()
	tween.set_parallel(false)

	# VBoxContainer slides out to the left
	tween.tween_property(vbox, "position:x", _home_pos_vbox.x - _viewport_width, SLIDE_DURATION) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)

	# Settings panel slides in from the left
	tween.tween_property(panel_settings, "position:x", _home_pos_settings.x, SLIDE_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	tween.tween_callback(func():
		vbox.visible = false
		_is_animating = false
	)

func _on_back_button_pressed() -> void:
	if _is_animating:
		return
	_is_animating = true

	# Place VBoxContainer off-screen left, then reveal it
	vbox.position.x = _home_pos_vbox.x - _viewport_width
	vbox.visible = true

	var tween := create_tween()
	tween.set_parallel(false)

	# Settings panel slides out to the left
	tween.tween_property(panel_settings, "position:x", _home_pos_settings.x - _viewport_width, SLIDE_DURATION) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)

	# VBoxContainer slides in from the left
	tween.tween_property(vbox, "position:x", _home_pos_vbox.x, SLIDE_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	tween.tween_callback(func():
		panel_settings.visible = false
		_is_animating = false
	)

func _on_fullscreen_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_master_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Master"),
		linear_to_db(value)
	)

func _on_music_volume_changed(value: float) -> void:
	var idx := AudioServer.get_bus_index("Music")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(value))

func _on_sfx_volume_changed(value: float) -> void:
	var idx := AudioServer.get_bus_index("SFX")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(value))

func _on_quit_button_pressed() -> void:
	get_tree().quit()
