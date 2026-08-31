extends Control

@onready var sub_viewport: SubViewport = $SubViewportContainer/SubViewport
@onready var card_panel: Control = $CanvasLayer/Control/CardPanel
@onready var vbox_main: VBoxContainer = $CanvasLayer/Control/CardPanel/CardMargin/VBoxMain
@onready var panel_settings: VBoxContainer = $CanvasLayer/Control/CardPanel/CardMargin/PanelSettings

@onready var button_start: Button = $CanvasLayer/Control/CardPanel/CardMargin/VBoxMain/ButtonVBox/ButtonStart
@onready var button_settings: Button = $CanvasLayer/Control/CardPanel/CardMargin/VBoxMain/ButtonVBox/ButtonSettings
@onready var button_quit: Button = $CanvasLayer/Control/CardPanel/CardMargin/VBoxMain/ButtonVBox/ButtonQuit
@onready var button_back: Button = $CanvasLayer/Control/CardPanel/CardMargin/PanelSettings/ButtonBack

@onready var check_fullscreen: CheckButton = $CanvasLayer/Control/CardPanel/CardMargin/PanelSettings/OptionsVBox/HBoxFullscreen/CheckButtonFullscreen
@onready var slider_master: HSlider = $CanvasLayer/Control/CardPanel/CardMargin/PanelSettings/OptionsVBox/HBoxMaster/SliderMaster
@onready var slider_music: HSlider = $CanvasLayer/Control/CardPanel/CardMargin/PanelSettings/OptionsVBox/HBoxMusic/SliderMusic
@onready var slider_sfx: HSlider = $CanvasLayer/Control/CardPanel/CardMargin/PanelSettings/OptionsVBox/HBoxSFX/SliderSFX

var _world_node: Node3D = null
var _camera: Camera3D = null
var _gameplay_cam_transform: Transform3D
var _gameplay_cam_ortho_size: float = 20.0

var _home_card_pos: Vector2
var _is_animating := false
var _is_game_started := false

var _showcase_root: Node3D = null
var _pillar_ref: Node3D = null
var _dir_light: DirectionalLight3D = null
var _saved_light_energy: float = 1.0
var _saved_light_color: Color = Color.WHITE

func _ready() -> void:
	# 1. Initialize BiomeManager
	if BiomeManager != null:
		BiomeManager.randomize_biome()

	# 2. Instance map scene if SubViewport is empty or get existing child
	_setup_world()

	# Wait one frame for UI anchors before reading positions
	await get_tree().process_frame

	_home_card_pos = card_panel.position

	# Setup smooth hover & click feedback on buttons
	_setup_button_hover(button_start)
	_setup_button_hover(button_settings)
	_setup_button_hover(button_quit)
	_setup_button_hover(button_back)

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
	panel_settings.modulate.a = 0.0
	vbox_main.visible = true
	vbox_main.modulate.a = 1.0

	# Intro animation: Card slides and bounces in from the left
	card_panel.position.x = _home_card_pos.x - 320.0
	card_panel.modulate.a = 0.0
	var intro_tween := create_tween().set_parallel(true)
	intro_tween.tween_property(card_panel, "position:x", _home_card_pos.x, 0.6) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	intro_tween.tween_property(card_panel, "modulate:a", 1.0, 0.4) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func _setup_button_hover(btn: Button) -> void:
	if btn == null:
		return

	btn.mouse_entered.connect(func():
		var tw = create_tween()
		tw.tween_property(btn, "modulate", Color(1.15, 1.12, 1.05, 1.0), 0.15)
	)
	btn.mouse_exited.connect(func():
		var tw = create_tween()
		tw.tween_property(btn, "modulate", Color.WHITE, 0.15)
	)
	btn.button_down.connect(func():
		var tw = create_tween()
		tw.tween_property(btn, "modulate", Color(0.85, 0.85, 0.9, 1.0), 0.08)
	)
	btn.button_up.connect(func():
		var tw = create_tween()
		tw.tween_property(btn, "modulate", Color(1.15, 1.12, 1.05, 1.0) if btn.is_hovered() else Color.WHITE, 0.12)
	)

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

		_dir_light = _world_node.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
		if _dir_light:
			_saved_light_energy = _dir_light.light_energy
			_saved_light_color = _dir_light.light_color
			# Warm golden late-afternoon sunlight matching Tower Factory reference
			_dir_light.light_color = Color(1.0, 0.95, 0.86)
			_dir_light.light_energy = 1.35
			_dir_light.shadow_enabled = true

		_setup_showcase_and_focus()

func _setup_showcase_and_focus() -> void:
	if _world_node == null or _camera == null:
		return

	# Locate IncursionPillar (the central tower)
	_pillar_ref = _world_node.find_child("IncursionPillar", true, false)
	if _pillar_ref == null:
		var nodes = _world_node.find_children("*Pillar*", "Node3D", true, false)
		if not nodes.is_empty():
			_pillar_ref = nodes[0]

	var pillar_pos := Vector3(10.0, 0.0, 10.0)
	if _pillar_ref and is_instance_valid(_pillar_ref):
		pillar_pos = _pillar_ref.global_position

	# Set fixed, static dramatic isometric camera pose (no rotation)
	var orbit_center = pillar_pos + Vector3(0.0, 1.4, 0.0)
	var orbit_radius = 11.5
	var orbit_height = 6.2
	var fixed_angle = 0.785398 # 45 degrees
	var screen_right_offset = -2.7

	_camera.size = 11.8

	var cam_x = orbit_center.x + orbit_radius * cos(fixed_angle)
	var cam_z = orbit_center.z + orbit_radius * sin(fixed_angle)
	_camera.global_position = Vector3(cam_x, orbit_height, cam_z)
	_camera.look_at(orbit_center + Vector3(0.0, 0.4, 0.0))

	# Shift camera to the left along local X so the tower is framed on the right side of the screen
	var right_vec = _camera.global_transform.basis.x
	_camera.global_position += right_vec * screen_right_offset

	# Build showcase defense outpost around the tower
	_build_menu_showcase(pillar_pos)

func _build_menu_showcase(pillar_pos: Vector3) -> void:
	if _showcase_root != null and is_instance_valid(_showcase_root):
		_showcase_root.queue_free()

	_showcase_root = Node3D.new()
	_showcase_root.name = "MenuShowcaseOutpost"
	_world_node.add_child(_showcase_root)

	# 1. Warm Golden Beacon Light at the Tower
	var beacon_light := OmniLight3D.new()
	beacon_light.name = "ShowcaseBeaconLight"
	beacon_light.light_color = Color(1.0, 0.82, 0.45)
	beacon_light.light_energy = 2.2
	beacon_light.omni_range = 8.0
	beacon_light.omni_attenuation = 1.2
	beacon_light.position = pillar_pos + Vector3(0.0, 3.2, 0.0)
	_showcase_root.add_child(beacon_light)

	# 2. Spawn showcase turrets flanking the tower
	var models_to_spawn := [
		{
			"path": "res://assets/Models/GLB format/weapon-ballista.glb",
			"offset": Vector3(-2.0, 0.1, 0.8),
			"rotation_y": deg_to_rad(35.0),
			"scale": Vector3(1.1, 1.1, 1.1)
		},
		{
			"path": "res://assets/Models/GLB format/weapon-cannon.glb",
			"offset": Vector3(2.2, 0.1, -1.2),
			"rotation_y": deg_to_rad(-120.0),
			"scale": Vector3(1.1, 1.1, 1.1)
		},
		{
			"path": "res://assets/Models/GLB format/weapon-turret.glb",
			"offset": Vector3(1.8, 0.1, 2.0),
			"rotation_y": deg_to_rad(75.0),
			"scale": Vector3(1.0, 1.0, 1.0)
		},
		{
			"path": "res://assets/Models/GLB format/wood-structure.glb",
			"offset": Vector3(-1.8, 0.05, -1.8),
			"rotation_y": deg_to_rad(45.0),
			"scale": Vector3(1.0, 1.0, 1.0)
		},
		{
			"path": "res://assets/Models/GLB format/wood-structure-high.glb",
			"offset": Vector3(-2.2, 0.05, 0.8),
			"rotation_y": deg_to_rad(0.0),
			"scale": Vector3(0.9, 0.9, 0.9)
		}
	]

	for item in models_to_spawn:
		if ResourceLoader.exists(item.path):
			var scn: PackedScene = load(item.path)
			if scn:
				var inst := scn.instantiate() as Node3D
				inst.position = pillar_pos + item.offset
				inst.rotation.y = item.rotation_y
				inst.scale = item.scale
				_showcase_root.add_child(inst)

func _process(_delta: float) -> void:
	# Camera stays static as requested (no rotation in main menu)
	pass

func _on_start_button_pressed() -> void:
	if _is_animating or _is_game_started:
		return
	_is_animating = true
	_is_game_started = true

	# Restore directional light settings if altered
	if _dir_light and is_instance_valid(_dir_light):
		var light_tw := create_tween().set_parallel(true)
		light_tw.tween_property(_dir_light, "light_color", _saved_light_color, 1.2)
		light_tw.tween_property(_dir_light, "light_energy", _saved_light_energy, 1.2)

	# Clean up showcase preview nodes
	if _showcase_root and is_instance_valid(_showcase_root):
		_showcase_root.queue_free()

	# Parallel tween: camera moves to top-down view + card fades & slides out smoothly
	var tween := create_tween().set_parallel(true)

	if _camera:
		tween.tween_property(_camera, "global_transform", _gameplay_cam_transform, 1.4) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(_camera, "size", _gameplay_cam_ortho_size, 1.4) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	if card_panel:
		tween.tween_property(card_panel, "modulate:a", 0.0, 0.7) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(card_panel, "position:x", _home_card_pos.x - 300.0, 0.8) \
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

	# Robust cross-fade without mutating container child positions
	var tw := create_tween()
	tw.tween_property(vbox_main, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func():
		vbox_main.visible = false
		panel_settings.visible = true
		panel_settings.modulate.a = 0.0
	)
	tw.tween_property(panel_settings, "modulate:a", 1.0, 0.18)
	tw.tween_callback(func():
		_is_animating = false
	)

func _on_back_button_pressed() -> void:
	if _is_animating:
		return
	_is_animating = true

	# Robust cross-fade back to main menu
	var tw := create_tween()
	tw.tween_property(panel_settings, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func():
		panel_settings.visible = false
		vbox_main.visible = true
		vbox_main.modulate.a = 0.0
	)
	tw.tween_property(vbox_main, "modulate:a", 1.0, 0.18)
	tw.tween_callback(func():
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
