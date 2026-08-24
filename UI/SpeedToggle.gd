extends CanvasLayer
class_name SpeedToggle

## SpeedToggle — floating top-left UI for controlling game speed.
## Cycles Engine.time_scale between 1x, 2x, and 4x on click, and emits speed_changed(multiplier).

signal speed_changed(multiplier: float)

static var instance: SpeedToggle = null

const SPEEDS: Array[float] = [1.0, 2.0, 4.0]

var _textures: Array[Texture2D] = []
var _current_index: int = 0
var _speed_button: TextureButton = null
var _tween: Tween = null

@onready var _ui_root: Control = $Control if has_node("Control") else null

func _ready() -> void:
	instance = self
	_load_textures()
	_setup_button()
	Engine.time_scale = SPEEDS[_current_index]
	_update_appearance()

func _exit_tree() -> void:
	if instance == self:
		instance = null
	Engine.time_scale = 1.0

func _load_textures() -> void:
	_textures.clear()
	var paths = [
		"res://UI/Speedup/speed_1x.png",
		"res://UI/Speedup/speed_2x.png",
		"res://UI/Speedup/speed_4x.png"
	]
	var fallback_gifs = [
		"res://UI/Speedup/speed_1x.gif",
		"res://UI/Speedup/speed_2x.gif",
		"res://UI/Speedup/speed_4x.gif"
	]
	for i in range(paths.size()):
		var tex: Texture2D = null
		if ResourceLoader.exists(paths[i]):
			tex = load(paths[i]) as Texture2D
		elif ResourceLoader.exists(fallback_gifs[i]):
			tex = load(fallback_gifs[i]) as Texture2D
		_textures.append(tex)

func _setup_button() -> void:
	_speed_button = get_node_or_null("Control/SpeedButton") as TextureButton
	if not _speed_button:
		if not _ui_root:
			_ui_root = Control.new()
			_ui_root.name = "Control"
			_ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
			_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(_ui_root)
		_speed_button = TextureButton.new()
		_speed_button.name = "SpeedButton"
		_speed_button.offset_left = 60.0
		_speed_button.offset_top = 12.0
		_speed_button.offset_right = 220.0
		_speed_button.offset_bottom = 52.0
		_speed_button.pivot_offset = Vector2(80, 20)
		_speed_button.ignore_texture_size = true
		_speed_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		_speed_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_ui_root.add_child(_speed_button)
	else:
		_speed_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_speed_button.pivot_offset = Vector2(80, 20)

	_speed_button.pressed.connect(_on_button_pressed)

func _on_button_pressed() -> void:
	_current_index = (_current_index + 1) % SPEEDS.size()
	_apply_speed()
	_play_click_animation()

func _apply_speed() -> void:
	_update_appearance()
	Engine.time_scale = SPEEDS[_current_index]
	speed_changed.emit(SPEEDS[_current_index])

func _update_appearance() -> void:
	if _speed_button and _current_index < _textures.size() and _textures[_current_index]:
		_speed_button.texture_normal = _textures[_current_index]

func _play_click_animation() -> void:
	if not is_instance_valid(_speed_button):
		return
	if _tween and _tween.is_valid():
		_tween.kill()
	
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_speed_button.scale = Vector2(0.92, 0.92)
	_tween.tween_property(_speed_button, "scale", Vector2.ONE, 0.18)

func reset_speed() -> void:
	_current_index = 0
	_apply_speed()

static func reset_to_default() -> void:
	if instance:
		instance.reset_speed()
	else:
		Engine.time_scale = 1.0

func get_current_multiplier() -> float:
	return SPEEDS[_current_index]

