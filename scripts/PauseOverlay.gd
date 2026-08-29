extends CanvasLayer
class_name PauseOverlay

@onready var color_rect: ColorRect = $ColorRect
@onready var pause_button: BaseButton = $PauseButton

var _tex_esc = preload("res://UI/Pause&Play/esc_buttonV2.png")
var _tex_play = preload("res://UI/Pause&Play/play_buttonV2.png")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if pause_button:
		pause_button.process_mode = Node.PROCESS_MODE_ALWAYS
		pause_button.pressed.connect(_toggle_pause)
	if color_rect:
		color_rect.process_mode = Node.PROCESS_MODE_ALWAYS
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		color_rect.visible = false
	get_tree().paused = false
	_update_button_appearance(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()
		if is_inside_tree() and get_viewport():
			get_viewport().set_input_as_handled()

func _toggle_pause() -> void:
	var is_paused = not get_tree().paused
	get_tree().paused = is_paused
	color_rect.visible = is_paused
	_update_button_appearance(is_paused)

	if is_paused:
		# Reset camera to default position
		var cam = get_viewport().get_camera_3d()
		if cam and cam.has_method("reset_camera"):
			cam.reset_camera()

func _update_button_appearance(is_paused: bool) -> void:
	if pause_button is TextureButton:
		var tb = pause_button as TextureButton
		tb.texture_normal = _tex_play if is_paused else _tex_esc
	else:
		pause_button.text = "▶ Resume" if is_paused else "⏸ Pause"
