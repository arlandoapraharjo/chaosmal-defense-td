extends CanvasLayer
class_name GameOverOverlay

@onready var backdrop: ColorRect = $Backdrop
@onready var modal_panel: PanelContainer = $CenterContainer/ModalPanel
@onready var title_label: Label = $CenterContainer/ModalPanel/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $CenterContainer/ModalPanel/VBoxContainer/SubtitleLabel

@onready var wave_stat_label: Label = $CenterContainer/ModalPanel/VBoxContainer/StatsGrid/WaveValLabel
@onready var enemies_stat_label: Label = $CenterContainer/ModalPanel/VBoxContainer/StatsGrid/EnemiesValLabel
@onready var currency_stat_label: Label = $CenterContainer/ModalPanel/VBoxContainer/StatsGrid/CurrencyValLabel

@onready var retry_button: Button = $CenterContainer/ModalPanel/VBoxContainer/ButtonContainer/RetryButton
@onready var menu_button: Button = $CenterContainer/ModalPanel/VBoxContainer/ButtonContainer/MenuButton

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

func _setup_button_effects(btn: Button) -> void:
	btn.pivot_offset = btn.size / 2.0
	btn.mouse_entered.connect(func():
		if not is_inside_tree():
			return
		var tween = create_tween()
		if tween:
			var tw = tween.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1)
			if tw:
				tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
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

func show_victory(stats: Dictionary = {}) -> void:
	_is_victory = true
	visible = true
	_populate_stats(stats)
	
	title_label.text = "🏆 VICTORY!"
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2)) # Gold
	subtitle_label.text = "The Incursion Pillar has reached maximum power and purified the realm!"
	
	if retry_button:
		retry_button.text = "🔄 Play Again"
		
	_animate_presentation(Color(0.12, 0.08, 0.25, 0.85), Color(0.6, 0.35, 1.0))

func show_defeat(stats: Dictionary = {}) -> void:
	_is_victory = false
	visible = true
	_populate_stats(stats)
	
	title_label.text = "💀 DEFEAT!"
	title_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25)) # Crimson
	subtitle_label.text = "The Incursion Pillar has been overwhelmed and destroyed by invaders."
	
	if retry_button:
		retry_button.text = "🔄 Retry"
		
	_animate_presentation(Color(0.18, 0.05, 0.06, 0.88), Color(0.9, 0.2, 0.2))

func _populate_stats(stats: Dictionary) -> void:
	var waves = stats.get("waves_cleared", 0)
	var enemies = stats.get("enemies_defeated", 0)
	var cur = stats.get("currency", 0)
	
	if wave_stat_label:
		wave_stat_label.text = "%d Waves" % waves
	if enemies_stat_label:
		enemies_stat_label.text = "%d Defeated" % enemies
	if currency_stat_label:
		currency_stat_label.text = "⚡ %d Essence" % cur

func _animate_presentation(panel_bg: Color, border_glow: Color) -> void:
	# Animate backdrop fade
	if backdrop:
		backdrop.modulate.a = 0.0
		var fade_tween = create_tween()
		fade_tween.tween_property(backdrop, "modulate:a", 1.0, 0.4)
		
	# Apply card stylebox
	if modal_panel:
		var style = StyleBoxFlat.new()
		style.bg_color = panel_bg
		style.border_color = border_glow
		style.set_border_width_all(3)
		style.set_corner_radius_all(14)
		style.shadow_color = Color(0, 0, 0, 0.7)
		style.shadow_size = 20
		style.content_margin_left = 32
		style.content_margin_top = 28
		style.content_margin_right = 32
		style.content_margin_bottom = 28
		modal_panel.add_theme_stylebox_override("panel", style)
		
		# Animate pop-in
		modal_panel.pivot_offset = modal_panel.size / 2.0
		modal_panel.scale = Vector2(0.7, 0.7)
		modal_panel.modulate.a = 0.0
		var pop_tween = create_tween()
		pop_tween.set_parallel(true)
		pop_tween.tween_property(modal_panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pop_tween.tween_property(modal_panel, "modulate:a", 1.0, 0.25)

func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene.call_deferred()

func _on_menu_pressed() -> void:
	get_tree().paused = false
	if ResourceLoader.exists("res://UI/Menus/MainMenu.tscn"):
		get_tree().change_scene_to_file.call_deferred("res://UI/Menus/MainMenu.tscn")
	else:
		get_tree().reload_current_scene.call_deferred()
