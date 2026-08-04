extends CanvasLayer

@onready var label: Label = $Control/MarginContainer/PanelContainer/HBoxContainer/Label
@onready var panel: PanelContainer = $Control/MarginContainer/PanelContainer

func _ready() -> void:
	call_deferred("_connect_manager")

func _connect_manager() -> void:
	var manager = CurrencyManager.instance
	if not manager:
		manager = get_node_or_null("/root/World/CurrencyManager")
	if manager:
		if not manager.currency_changed.is_connected(_on_currency_changed):
			manager.currency_changed.connect(_on_currency_changed)
		_on_currency_changed(manager.get_currency())

func _on_currency_changed(amount: int) -> void:
	if label:
		label.text = "Coins: %d" % amount
		# Subtle punch scale animation when currency changes
		var tween = create_tween()
		tween.tween_property(panel, "scale", Vector2(1.1, 1.1), 0.1)
		tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.1)
