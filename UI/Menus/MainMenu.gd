extends Node2D

func _on_start_button_pressed() -> void:
	var canvas_layer = $CanvasLayer
	var fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(fade_rect)

	var tween = create_tween()
	tween.tween_property(fade_rect, "color", Color(0, 0, 0, 1), 0.3)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/map.tscn"))

func _on_settings_button_pressed() -> void:
	pass # TODO: Buka scene Settings

func _on_quit_button_pressed() -> void:
	get_tree().quit()
