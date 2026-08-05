extends CanvasLayer

@onready var label: Label = $Control/MarginContainer/PanelContainer/HBoxContainer/Label
@onready var panel: PanelContainer = $Control/MarginContainer/PanelContainer
@onready var notification_container: MarginContainer = $Control/NotificationContainer

var notification_tween: Tween

func _ready() -> void:
	# Start hidden until wave 1 begins
	if panel:
		panel.modulate = Color(1, 1, 1, 0)
	if notification_container:
		notification_container.modulate = Color(1, 1, 1, 0)
		notification_container.position.y = 10

func update_wave(wave_number: int) -> void:
	if label:
		label.text = "Wave %d" % wave_number

	if panel:
		# Animate: scale punch + fade in
		var tween = create_tween()
		panel.modulate = Color(1, 1, 1, 1)
		panel.scale = Vector2(1.3, 1.3)
		tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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
