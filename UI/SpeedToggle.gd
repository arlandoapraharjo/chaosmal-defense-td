extends CanvasLayer
class_name SpeedToggle

## SpeedToggle — floating top-right pill UI for controlling game speed.
## Adjusts Engine.time_scale and emits speed_changed(multiplier).

signal speed_changed(multiplier: float)

static var instance: SpeedToggle = null

const SPEEDS: Array[float] = [1.0, 2.0, 4.0]
const SPEED_LABELS: Array[String] = ["1×", "2×", "4×"]

var _current_index: int = 0
var _buttons: Array[Button] = []
var _container: HBoxContainer = null

# Style colors
const COLOR_ACTIVE_BG    := Color(0.20, 0.60, 1.00, 0.95)
const COLOR_INACTIVE_BG  := Color(0.04, 0.08, 0.18, 0.88)
const COLOR_ACTIVE_TEXT  := Color(1.00, 1.00, 1.00, 1.00)
const COLOR_INACTIVE_TEXT:= Color(0.50, 0.75, 1.00, 0.85)
const COLOR_BORDER       := Color(0.20, 0.55, 1.00, 0.70)

@onready var _ui_root = $Control if has_node("Control") else self

func _ready() -> void:
	instance = self
	Engine.time_scale = SPEEDS[_current_index]
	_build_ui()
	_refresh_buttons()

func _exit_tree() -> void:
	if instance == self:
		instance = null
	Engine.time_scale = 1.0

func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left   = 0.0
	panel.anchor_right  = 0.0
	panel.anchor_top    = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left   = 10
	panel.offset_right  = 180
	panel.offset_top    = 56
	panel.offset_bottom = 92

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.05, 0.12, 0.90)
	panel_style.border_color = COLOR_BORDER
	panel_style.set_border_width_all(1)
	panel_style.corner_radius_top_left    = 20
	panel_style.corner_radius_top_right   = 20
	panel_style.corner_radius_bottom_left = 20
	panel_style.corner_radius_bottom_right= 20
	panel_style.shadow_color = Color(0.10, 0.40, 1.00, 0.35)
	panel_style.shadow_size  = 8
	panel.add_theme_stylebox_override("panel", panel_style)
	_ui_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",  6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top",   4)
	margin.add_theme_constant_override("margin_bottom",4)
	panel.add_child(margin)

	_container = HBoxContainer.new()
	_container.add_theme_constant_override("separation", 4)
	margin.add_child(_container)

	# Speed icon label
	var icon_lbl := Label.new()
	icon_lbl.text = "⏩"
	icon_lbl.add_theme_font_size_override("font_size", 13)
	icon_lbl.add_theme_color_override("font_color", COLOR_BORDER)
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_container.add_child(icon_lbl)

	for i in range(SPEEDS.size()):
		var btn := Button.new()
		btn.text = SPEED_LABELS[i]
		btn.custom_minimum_size = Vector2(38, 26)
		btn.add_theme_font_size_override("font_size", 13)
		btn.flat = true
		btn.pressed.connect(_on_speed_pressed.bind(i))
		_container.add_child(btn)
		_buttons.append(btn)

func _on_speed_pressed(index: int) -> void:
	_current_index = index
	_refresh_buttons()
	Engine.time_scale = SPEEDS[_current_index]
	speed_changed.emit(SPEEDS[_current_index])

func reset_speed() -> void:
	_on_speed_pressed(0)

static func reset_to_default() -> void:
	if instance:
		instance.reset_speed()
	else:
		Engine.time_scale = 1.0

func _refresh_buttons() -> void:
	for i in range(_buttons.size()):
		var btn := _buttons[i]
		var active := (i == _current_index)

		var style := StyleBoxFlat.new()
		style.bg_color     = COLOR_ACTIVE_BG if active else COLOR_INACTIVE_BG
		style.border_color = COLOR_BORDER
		style.set_border_width_all(1 if active else 0)
		style.corner_radius_top_left     = 12
		style.corner_radius_top_right    = 12
		style.corner_radius_bottom_left  = 12
		style.corner_radius_bottom_right = 12
		if active:
			style.shadow_color = COLOR_ACTIVE_BG
			style.shadow_size  = 6
		btn.add_theme_stylebox_override("normal",   style)
		btn.add_theme_stylebox_override("hover",    style)
		btn.add_theme_stylebox_override("pressed",  style)
		btn.add_theme_stylebox_override("focus",    StyleBoxEmpty.new())
		btn.add_theme_color_override("font_color",
			COLOR_ACTIVE_TEXT if active else COLOR_INACTIVE_TEXT)

func get_current_multiplier() -> float:
	return SPEEDS[_current_index]
