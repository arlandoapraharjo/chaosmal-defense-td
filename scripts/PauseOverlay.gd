extends CanvasLayer
class_name PauseOverlay

@onready var color_rect: ColorRect = $ColorRect
@onready var pause_button: BaseButton = $PauseButton
@onready var control_root: Control = $Control
@onready var card_panel: Control = $Control/CardPanel
@onready var vbox_main: VBoxContainer = $Control/CardPanel/CardMargin/VBoxMain
@onready var panel_settings: VBoxContainer = $Control/CardPanel/CardMargin/PanelSettings

@onready var button_resume: Button = $Control/CardPanel/CardMargin/VBoxMain/ButtonVBox/ButtonResume
@onready var button_settings: Button = $Control/CardPanel/CardMargin/VBoxMain/ButtonVBox/ButtonSettings
@onready var button_main_menu: Button = $Control/CardPanel/CardMargin/VBoxMain/ButtonVBox/ButtonMainMenu
@onready var button_quit: Button = $Control/CardPanel/CardMargin/VBoxMain/ButtonVBox/ButtonQuit
@onready var button_back: Button = $Control/CardPanel/CardMargin/PanelSettings/ButtonBack

@onready var check_fullscreen: CheckButton = $Control/CardPanel/CardMargin/PanelSettings/OptionsVBox/HBoxFullscreen/CheckButtonFullscreen
@onready var slider_master: HSlider = $Control/CardPanel/CardMargin/PanelSettings/OptionsVBox/HBoxMaster/SliderMaster
@onready var slider_music: HSlider = $Control/CardPanel/CardMargin/PanelSettings/OptionsVBox/HBoxMusic/SliderMusic
@onready var slider_sfx: HSlider = $Control/CardPanel/CardMargin/PanelSettings/OptionsVBox/HBoxSFX/SliderSFX

var _tex_esc = preload("res://UI/Pause&Play/esc_buttonV2.png")
var _tex_play = preload("res://UI/Pause&Play/play_buttonV2.png")

var _home_card_pos: Vector2
var _is_animating: bool = false
var _slide_tween: Tween = null
var _settings_tween: Tween = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if pause_button:
		pause_button.process_mode = Node.PROCESS_MODE_ALWAYS
		pause_button.pressed.connect(_toggle_pause)
	
	if color_rect:
		color_rect.process_mode = Node.PROCESS_MODE_ALWAYS
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		color_rect.visible = false
	
	if control_root:
		control_root.process_mode = Node.PROCESS_MODE_ALWAYS
		control_root.visible = false
		control_root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if button_resume:
		button_resume.pressed.connect(_on_resume_pressed)
		_setup_button_hover(button_resume)
	if button_settings:
		button_settings.pressed.connect(_on_settings_pressed)
		_setup_button_hover(button_settings)
	if button_main_menu:
		button_main_menu.pressed.connect(_on_main_menu_pressed)
		_setup_button_hover(button_main_menu)
	if button_quit:
		button_quit.pressed.connect(_on_quit_pressed)
		_setup_button_hover(button_quit)
	if button_back:
		button_back.pressed.connect(_on_back_pressed)
		_setup_button_hover(button_back)

	if check_fullscreen:
		check_fullscreen.toggled.connect(_on_fullscreen_toggled)
	if slider_master:
		slider_master.value_changed.connect(_on_master_volume_changed)
	if slider_music:
		slider_music.value_changed.connect(_on_music_volume_changed)
	if slider_sfx:
		slider_sfx.value_changed.connect(_on_sfx_volume_changed)

	_sync_settings_ui()

	get_tree().paused = false
	_update_button_appearance(false)

	await get_tree().process_frame
	if card_panel:
		_home_card_pos = card_panel.position

func _setup_button_hover(btn: Button) -> void:
	if btn == null:
		return
	btn.mouse_entered.connect(func():
		var tw = create_tween()
		tw.tween_property(btn, "modulate", Color(1.08, 1.08, 1.1, 1.0), 0.15)
	)
	btn.mouse_exited.connect(func():
		var tw = create_tween()
		tw.tween_property(btn, "modulate", Color.WHITE, 0.15)
	)

func _sync_settings_ui() -> void:
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

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		if get_tree().paused and panel_settings and panel_settings.visible:
			_on_back_pressed()
			if is_inside_tree() and get_viewport():
				get_viewport().set_input_as_handled()
			return

		_toggle_pause()
		if is_inside_tree() and get_viewport():
			get_viewport().set_input_as_handled()

func _toggle_pause() -> void:
	if _is_animating:
		return
	if get_tree().paused:
		_resume_game()
	else:
		_pause_game()

func _pause_game() -> void:
	get_tree().paused = true
	_update_button_appearance(true)
	_sync_settings_ui()

	if color_rect:
		color_rect.visible = true
		color_rect.modulate.a = 0.0

	if control_root:
		control_root.visible = true
		control_root.mouse_filter = Control.MOUSE_FILTER_STOP

	if vbox_main:
		vbox_main.visible = true
		vbox_main.modulate.a = 1.0
	if panel_settings:
		panel_settings.visible = false
		panel_settings.modulate.a = 0.0

	if card_panel:
		if _home_card_pos == Vector2.ZERO:
			_home_card_pos = card_panel.position
		card_panel.position.x = _home_card_pos.x - 380.0
		card_panel.modulate.a = 0.0

		if _slide_tween and _slide_tween.is_valid():
			_slide_tween.kill()
		_slide_tween = create_tween().set_parallel(true)
		_slide_tween.tween_property(card_panel, "position:x", _home_card_pos.x, 0.45)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_slide_tween.tween_property(card_panel, "modulate:a", 1.0, 0.3)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if color_rect:
			_slide_tween.tween_property(color_rect, "modulate:a", 1.0, 0.3)

	# Reset camera to default view while paused
	var cam = get_viewport().get_camera_3d()
	if cam and cam.has_method("reset_camera"):
		cam.reset_camera()

func _resume_game() -> void:
	if not get_tree().paused:
		return
	_is_animating = true

	if _slide_tween and _slide_tween.is_valid():
		_slide_tween.kill()
	_slide_tween = create_tween().set_parallel(true)
	
	if card_panel:
		_slide_tween.tween_property(card_panel, "position:x", _home_card_pos.x - 380.0, 0.22)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_slide_tween.tween_property(card_panel, "modulate:a", 0.0, 0.2)
	if color_rect:
		_slide_tween.tween_property(color_rect, "modulate:a", 0.0, 0.2)

	_slide_tween.chain().tween_callback(func():
		if control_root:
			control_root.visible = false
			control_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if color_rect:
			color_rect.visible = false
		get_tree().paused = false
		_update_button_appearance(false)
		_is_animating = false
	)

func _on_resume_pressed() -> void:
	_resume_game()

func _on_settings_pressed() -> void:
	if _settings_tween and _settings_tween.is_valid():
		_settings_tween.kill()
	
	_settings_tween = create_tween()
	_settings_tween.tween_property(vbox_main, "modulate:a", 0.0, 0.12)
	_settings_tween.tween_callback(func():
		vbox_main.visible = false
		panel_settings.visible = true
		panel_settings.modulate.a = 0.0
	)
	_settings_tween.tween_property(panel_settings, "modulate:a", 1.0, 0.16)

func _on_back_pressed() -> void:
	if _settings_tween and _settings_tween.is_valid():
		_settings_tween.kill()
	
	_settings_tween = create_tween()
	_settings_tween.tween_property(panel_settings, "modulate:a", 0.0, 0.12)
	_settings_tween.tween_callback(func():
		panel_settings.visible = false
		vbox_main.visible = true
		vbox_main.modulate.a = 0.0
	)
	_settings_tween.tween_property(vbox_main, "modulate:a", 1.0, 0.16)

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	if ResourceLoader.exists("res://UI/Menus/MainMenu.tscn"):
		get_tree().change_scene_to_file.call_deferred("res://UI/Menus/MainMenu.tscn")
	else:
		get_tree().reload_current_scene.call_deferred()

func _on_quit_pressed() -> void:
	get_tree().quit()

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

func _update_button_appearance(is_paused: bool) -> void:
	if pause_button is TextureButton:
		var tb = pause_button as TextureButton
		tb.texture_normal = _tex_play if is_paused else _tex_esc
	else:
		pause_button.text = "▶ Resume" if is_paused else "⏸ Pause"
