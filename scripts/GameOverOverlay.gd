extends CanvasLayer
class_name GameOverOverlay

@onready var backdrop: ColorRect = $Backdrop
@onready var modal_container: VBoxContainer = $CenterContainer/ModalContainer
@onready var banner_rect: TextureRect = $CenterContainer/ModalContainer/BannerRect
@onready var title_label: Label = $CenterContainer/ModalContainer/BannerRect/TitleLabel
@onready var map_label: Label = $CenterContainer/ModalContainer/BannerRect/MapLabel

@onready var retry_button: TextureButton = $CenterContainer/ModalContainer/ButtonMargin/ButtonContainer/RetryButton
@onready var retry_label: Label = $CenterContainer/ModalContainer/ButtonMargin/ButtonContainer/RetryButton/RetryLabel
@onready var menu_button: TextureButton = $CenterContainer/ModalContainer/ButtonMargin/ButtonContainer/MenuButton
@onready var menu_label: Label = $CenterContainer/ModalContainer/ButtonMargin/ButtonContainer/MenuButton/MenuLabel

var _is_victory: bool = false

func _ready() -> void:
	add_to_group("game_over_overlay")
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	if retry_button:
		retry_button.pressed.connect(_on_retry_pressed)
		_setup_button_effects(retry_button)
	if menu_button:
		menu_button.pressed.connect(_on_menu_pressed)
		_setup_button_effects(menu_button)

func _setup_button_effects(btn: Control) -> void:
	btn.pivot_offset = btn.size * 0.5
	btn.mouse_entered.connect(func():
		if not is_inside_tree():
			return
		var tween = create_tween()
		if tween:
			var tw = tween.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.12)
			if tw:
				tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)
	btn.mouse_exited.connect(func():
		if not is_inside_tree():
			return
		var tween = create_tween()
		if tween:
			var tw = tween.tween_property(btn, "scale", Vector2.ONE, 0.15)
			if tw:
				tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)

func show_victory(_stats: Dictionary = {}) -> void:
	_is_victory = true
	visible = true
	
	if title_label:
		title_label.text = "VICTORY"
		title_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0)) # White
	
	_update_map_label()
	
	if retry_label:
		retry_label.text = "Play Again"
		
	_animate_presentation(Color(1.0, 1.0, 1.0))

func show_defeat(_stats: Dictionary = {}) -> void:
	_is_victory = false
	visible = true
	
	if title_label:
		title_label.text = "DEFEAT"
		title_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25)) # Crimson
	
	_update_map_label()
	
	if retry_label:
		retry_label.text = "Retry"
		
	_animate_presentation(Color(1.0, 0.25, 0.25))

func _update_map_label() -> void:
	if not map_label:
		return
	map_label.text = _get_current_map_name()

func _get_current_map_name() -> String:
	var bm = get_node_or_null("/root/BiomeManager")
	if bm != null and bm.get("current_biome") != null:
		var path = bm.current_biome.resource_path.to_lower()
		if path.find("snow") != -1 or path.find("ice") != -1:
			return "SNOW"
		elif path.find("desert") != -1:
			return "DESERT"
		elif path.find("grass") != -1:
			return "GRASS"
	return "UNKNOWN"

func _animate_presentation(_accent_color: Color) -> void:
	# Animate backdrop fade
	if backdrop:
		backdrop.modulate.a = 0.0
		var fade_tween = create_tween()
		fade_tween.tween_property(backdrop, "modulate:a", 1.0, 0.35)
		
	if modal_container:
		modal_container.pivot_offset = modal_container.size * 0.5
		modal_container.scale = Vector2(0.65, 0.65)
		modal_container.modulate.a = 0.0
		var pop_tween = create_tween()
		pop_tween.set_parallel(true)
		pop_tween.tween_property(modal_container, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pop_tween.tween_property(modal_container, "modulate:a", 1.0, 0.22)

func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene.call_deferred()

func _on_menu_pressed() -> void:
	get_tree().paused = false
	if ResourceLoader.exists("res://UI/Menus/MainMenu.tscn"):
		get_tree().change_scene_to_file.call_deferred("res://UI/Menus/MainMenu.tscn")
	else:
		get_tree().reload_current_scene.call_deferred()
