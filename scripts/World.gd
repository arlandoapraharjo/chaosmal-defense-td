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

func set_menu_mode(menu_active: bool) -> void:
	_is_menu_mode = menu_active

	if currency_ui: currency_ui.visible = not menu_active
	if wave_ui: wave_ui.visible = not menu_active
	if turret_hotbar: turret_hotbar.visible = not menu_active
	if pause_overlay: pause_overlay.visible = not menu_active
	if speed_toggle: speed_toggle.visible = not menu_active
	if game_over_overlay: game_over_overlay.visible = not menu_active
	if pillar_shockwave: pillar_shockwave.visible = not menu_active

	if builder_controller:
		builder_controller.set_process(not menu_active)
		builder_controller.set_physics_process(not menu_active)
		builder_controller.set_process_unhandled_input(not menu_active)

	if camera_3d:
		camera_3d.set_physics_process(not menu_active)
		camera_3d.set_process_unhandled_input(not menu_active)

func is_menu_mode() -> bool:
	return _is_menu_mode
