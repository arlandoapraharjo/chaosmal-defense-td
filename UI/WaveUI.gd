extends CanvasLayer

@onready var label: Label = $Control/MarginContainer/PanelContainer/HBoxContainer/Label
@onready var panel: PanelContainer = $Control/MarginContainer/PanelContainer

func _ready() -> void:
	# Start hidden until wave 1 begins
	if panel:
		panel.modulate = Color(1, 1, 1, 0)

func update_wave(wave_number: int) -> void:
	if label:
		label.text = "Wave %d" % wave_number

	if panel:
		# Animate: scale punch + fade in
		var tween = create_tween()
		panel.modulate = Color(1, 1, 1, 1)
		panel.scale = Vector2(1.3, 1.3)
		tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
