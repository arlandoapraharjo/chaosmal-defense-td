extends CanvasLayer

@onready var label: Label = $Control/MarginContainer/VBoxContainer/CoinsBanner/Label
@onready var panel: TextureRect = $Control/MarginContainer/VBoxContainer/CoinsBanner

@onready var deployment_label: Label = $Control/MarginContainer/VBoxContainer/TurretBanner/Label
@onready var deployment_panel: TextureRect = $Control/MarginContainer/VBoxContainer/TurretBanner

func _ready() -> void:
	call_deferred("_connect_manager")
	call_deferred("_connect_builder_controller")

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
		label.text = str(amount)
		# Subtle punch scale animation when currency changes
		var tween = create_tween()
		tween.tween_property(panel, "scale", Vector2(1.1, 1.1), 0.1)
		tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.1)

func _connect_builder_controller() -> void:
	var builder = get_node_or_null("/root/World/BuilderController")
	if not builder:
		builder = get_tree().get_root().find_child("BuilderController", true, false)
	if builder:
		if not builder.total_deployment_updated.is_connected(_on_deployment_updated):
			builder.total_deployment_updated.connect(_on_deployment_updated)
			_on_deployment_updated(builder.get_current_deployment(), builder.get_max_deployment())

func _on_deployment_updated(current: int, max_deploy: int) -> void:
	if deployment_label:
		deployment_label.text = "%d / %d" % [current, max_deploy]
		var tween = create_tween()
		tween.tween_property(deployment_panel, "scale", Vector2(1.1, 1.1), 0.1)
		tween.tween_property(deployment_panel, "scale", Vector2(1.0, 1.0), 0.1)
