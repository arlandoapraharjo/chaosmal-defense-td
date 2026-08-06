extends CanvasLayer
class_name PauseOverlay

@onready var color_rect: ColorRect = $ColorRect
@onready var pause_button: Button = $PauseButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	color_rect.visible = false
	pause_button.pressed.connect(_toggle_pause)
	get_tree().paused = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()
		get_viewport().set_input_as_handled()

func _toggle_pause() -> void:
	var is_paused = not get_tree().paused
	get_tree().paused = is_paused
	color_rect.visible = is_paused

	if is_paused:
		pause_button.text = "▶ Resume"
		# Reset camera to default position
		var cam = get_viewport().get_camera_3d()
		if cam and cam.has_method("reset_camera"):
			cam.reset_camera()
	else:
		pause_button.text = "⏸ Pause"
