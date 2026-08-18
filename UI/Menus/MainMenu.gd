extends Node2D

@onready var vbox: VBoxContainer = $CanvasLayer/Control/VBoxContainer
@onready var panel_settings: VBoxContainer = $CanvasLayer/Control/PanelSettings
@onready var check_fullscreen: CheckButton = $CanvasLayer/Control/PanelSettings/HBoxFullscreen/CheckButtonFullscreen
@onready var slider_master: HSlider = $CanvasLayer/Control/PanelSettings/HBoxMaster/SliderMaster
@onready var slider_music: HSlider = $CanvasLayer/Control/PanelSettings/HBoxMusic/SliderMusic
@onready var slider_sfx: HSlider = $CanvasLayer/Control/PanelSettings/HBoxSFX/SliderSFX

const SLIDE_DURATION := 0.5

var _viewport_width: float
var _home_pos_vbox: Vector2
var _home_pos_settings: Vector2
var _is_animating := false


func _ready() -> void:
	# Wait one frame so anchored layout is fully computed before reading positions
	await get_tree().process_frame

	_viewport_width = get_viewport_rect().size.x
	_home_pos_vbox = vbox.position
	_home_pos_settings = panel_settings.position

	# Sync UI state with actual system state
	check_fullscreen.button_pressed = \
		DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	slider_master.value = db_to_linear(
		AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))
	)
	var music_idx := AudioServer.get_bus_index("Music")
	if music_idx >= 0:
		slider_music.value = db_to_linear(AudioServer.get_bus_volume_db(music_idx))
	var sfx_idx := AudioServer.get_bus_index("SFX")
	if sfx_idx >= 0:
		slider_sfx.value = db_to_linear(AudioServer.get_bus_volume_db(sfx_idx))

	# Hide settings panel before the intro animation
	panel_settings.visible = false

	# Start VBoxContainer off-screen to the left, then slide it in
	vbox.position.x -= _viewport_width
	var tween := create_tween()
	tween.tween_property(vbox, "position:x", _home_pos_vbox.x, SLIDE_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _on_start_button_pressed() -> void:
	var canvas_layer: CanvasLayer = $CanvasLayer
	var fade_rect := ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(fade_rect)

	var tween := create_tween()
	tween.tween_property(fade_rect, "color", Color(0, 0, 0, 1), 0.3)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/map.tscn"))


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
	# TODO: Add a "Music" bus in Project > Audio settings to enable this
	var idx := AudioServer.get_bus_index("Music")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(value))


func _on_sfx_volume_changed(value: float) -> void:
	# TODO: Add an "SFX" bus in Project > Audio settings to enable this
	var idx := AudioServer.get_bus_index("SFX")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(value))


func _on_quit_button_pressed() -> void:
	get_tree().quit()
