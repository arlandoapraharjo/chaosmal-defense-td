extends CanvasLayer

@onready var container: MarginContainer = $Control/MarginContainer
@onready var wave_texture: TextureRect = $Control/MarginContainer/WaveTexture
@onready var notification_container: MarginContainer = $Control/NotificationContainer

var _wave_tween: Tween
var notification_tween: Tween

const INTRO_TEX = preload("res://UI/Wave Indicator/intro_waver.png")
const WAVE_TEXTURES = {
	1: preload("res://UI/Wave Indicator/wave_1.png"),
	2: preload("res://UI/Wave Indicator/wave_2.png"),
	3: preload("res://UI/Wave Indicator/wave_3.png"),
	4: preload("res://UI/Wave Indicator/wave_4.png"),
	5: preload("res://UI/Wave Indicator/wave_5.png"),
	6: preload("res://UI/Wave Indicator/wave_1x2.png"),
	7: preload("res://UI/Wave Indicator/wave_2x2.png"),
	8: preload("res://UI/Wave Indicator/wave_3x2.png"),
	9: preload("res://UI/Wave Indicator/wave_4x2.png"),
	10: preload("res://UI/Wave Indicator/wave_5x2.png")
}

func _ready() -> void:
	add_to_group("wave_ui")
	# Start hidden until wave 1 begins
	if container:
		container.modulate = Color(1, 1, 1, 0)
	if notification_container:
		notification_container.modulate = Color(1, 1, 1, 0)
		notification_container.position.y = 10


func update_wave(wave_number: int) -> void:
	if not container or not wave_texture:
		return

	var target_tex = WAVE_TEXTURES.get(wave_number, WAVE_TEXTURES.get(10))

	if _wave_tween and _wave_tween.is_running():
		_wave_tween.kill()

	_wave_tween = create_tween()

	# 1. Start with Intro Waver banner + pop punch
	wave_texture.texture = INTRO_TEX
	container.modulate = Color(1, 1, 1, 1)
	container.scale = Vector2(1.25, 1.25)
	_wave_tween.tween_property(container, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# 2. Wait 1.1 seconds on intro
	_wave_tween.tween_interval(1.1)

	# 3. Cross-fade & punch transition to wave_N texture
	_wave_tween.tween_property(container, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE)
	_wave_tween.tween_callback(func():
		wave_texture.texture = target_tex
		container.scale = Vector2(1.15, 1.15)
	)
	_wave_tween.tween_property(container, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE)
	_wave_tween.parallel().tween_property(container, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func show_insufficient_funds() -> void:
	if not notification_container:
		return
	if notification_tween and notification_tween.is_running():
		notification_tween.kill()
	
	notification_tween = create_tween()
	notification_container.modulate = Color(1, 1, 1, 1)
	notification_container.position.y = 10
	
	notification_tween.tween_property(notification_container, "position:y", 80.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	notification_tween.tween_interval(2.0)
	notification_tween.tween_property(notification_container, "position:y", 10.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	notification_tween.parallel().tween_property(notification_container, "modulate", Color(1, 1, 1, 0), 0.3)
