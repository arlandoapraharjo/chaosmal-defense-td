class_name FoxHUD
extends CanvasLayer

## FoxHUD — Tactical companion action widget with 3D headshot portrait and command controls.

@export_group("3D Portrait Settings")
## Uniform scale of the 3D animal model in the portrait slot
@export var portrait_model_scale: float = 0.16
## Rotation angle in degrees (0 = front view, 28 = isometric 3/4 view)
@export var portrait_model_rotation_deg: float = 0.0
## Position offset for fine-tuning the 3D model center (X, Y, Z)
@export var portrait_model_offset: Vector3 = Vector3.ZERO

const DEFAULT_FOX_SCENE = preload("res://assets/characters/animal-fox.glb")
const CAPSULE_TEX = preload("res://UI/Menus/main menu button.png")

@onready var hero_widget: PanelContainer = get_node_or_null("Control/HeroWidget")
@onready var status_label: Label = get_node_or_null("Control/HeroWidget/MarginContainer/HBoxContainer/InfoVBox/StatusLabel")
@onready var action_button: Button = get_node_or_null("Control/HeroWidget/MarginContainer/HBoxContainer/ActionButton")
@onready var command_banner: PanelContainer = get_node_or_null("Control/CommandBanner")
@onready var hero_name_label: Label = get_node_or_null("Control/HeroWidget/MarginContainer/HBoxContainer/InfoVBox/TitleRow/NameLabel")
@onready var banner_title_label: Label = get_node_or_null("Control/CommandBanner/MarginContainer/VBoxContainer/HeaderRow/Title")
@onready var banner_move_label: Label = get_node_or_null("Control/CommandBanner/MarginContainer/VBoxContainer/LineMove")
@onready var portrait_model_root: Node3D = get_node_or_null("Control/HeroWidget/MarginContainer/HBoxContainer/PortraitFrame/SubViewportContainer/SubViewport/World3D/ModelAnchor/ModelRoot")

var _style_normal: StyleBoxTexture
var _style_selected: StyleBoxTexture
var _style_buffing: StyleBoxTexture

var _fox: FoxCompanion = null
var _banner_tween: Tween = null
var _anim_player: AnimationPlayer = null

static func _create_capsule_style(mod_color: Color) -> StyleBoxTexture:
	var sb = StyleBoxTexture.new()
	sb.texture = CAPSULE_TEX
	sb.texture_margin_left = 24.0
	sb.texture_margin_top = 12.0
	sb.texture_margin_right = 24.0
	sb.texture_margin_bottom = 12.0
	sb.content_margin_left = 6.0
	sb.content_margin_top = 2.0
	sb.content_margin_right = 10.0
	sb.content_margin_bottom = 2.0
	sb.modulate_color = mod_color
	return sb

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_style_normal = _create_capsule_style(Color(0.9, 0.9, 0.95, 0.95))
	_style_selected = _create_capsule_style(Color(1.25, 1.15, 0.65, 1.0))
	_style_buffing = _create_capsule_style(Color(0.65, 1.25, 1.2, 1.0))
	
	if action_button:
		action_button.pressed.connect(_on_action_pressed)
	if hero_widget:
		hero_widget.gui_input.connect(_on_widget_gui_input)
	
	_connect_biome()
	call_deferred("_bind_fox")

func _connect_biome() -> void:
	var map = get_tree().get_first_node_in_group("map_generator")
	if not map:
		map = get_node_or_null("/root/World/MapGenerator")
	if not map:
		map = get_node_or_null("../Map")
	if not map:
		map = get_node_or_null("Map")
	
	if map:
		if map.has_signal("biome_changed") and not map.biome_changed.is_connected(_on_biome_changed):
			map.biome_changed.connect(_on_biome_changed)
		if "active_biome" in map and map.active_biome != null:
			_on_biome_changed(map.active_biome)
	elif BiomeManager != null and BiomeManager.current_biome != null:
		_on_biome_changed(BiomeManager.current_biome)
	else:
		_setup_portrait_model(DEFAULT_FOX_SCENE)

func _on_biome_changed(biome: BiomeData) -> void:
	if not biome:
		return
	var char_name = biome.character_name if not biome.character_name.is_empty() else "Fox"
	var char_scene = biome.character_model if biome.character_model != null else DEFAULT_FOX_SCENE
	
	if hero_name_label:
		hero_name_label.text = "TACTICAL " + char_name.to_upper()
	if banner_title_label:
		banner_title_label.text = char_name.to_upper() + " COMMAND MODE"
	if banner_move_label:
		banner_move_label.text = "• Left-Click Tile : Move " + char_name
	
	_setup_portrait_model(char_scene)

func _setup_portrait_model(scene: PackedScene) -> void:
	if not portrait_model_root:
		return
	
	for child in portrait_model_root.get_children():
		child.queue_free()
	
	if scene == null:
		scene = DEFAULT_FOX_SCENE
	
	portrait_model_root.scale = Vector3(portrait_model_scale, portrait_model_scale, portrait_model_scale)
	portrait_model_root.rotation.y = deg_to_rad(portrait_model_rotation_deg)
	portrait_model_root.position = portrait_model_offset
	
	var instance = scene.instantiate()
	portrait_model_root.add_child(instance)
	
	_anim_player = _find_animation_player(instance)
	if _anim_player:
		if _anim_player.has_animation("idle"):
			_anim_player.play("idle")
		elif _anim_player.has_animation("static"):
			_anim_player.play("static")

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found = _find_animation_player(child)
		if found:
			return found
	return null

func _bind_fox() -> void:
	_fox = get_tree().get_first_node_in_group("fox_companion") as FoxCompanion
	if _fox:
		if not _fox.selected_changed.is_connected(_on_fox_selected_changed):
			_fox.selected_changed.connect(_on_fox_selected_changed)
		if not _fox.entered_turret.is_connected(_on_fox_entered_turret):
			_fox.entered_turret.connect(_on_fox_entered_turret)
		if not _fox.left_turret.is_connected(_on_fox_left_turret):
			_fox.left_turret.connect(_on_fox_left_turret)
		_update_ui_state()

func _process(_delta: float) -> void:
	if _fox == null or not is_instance_valid(_fox):
		_fox = get_tree().get_first_node_in_group("fox_companion") as FoxCompanion
		if _fox:
			_bind_fox()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		# Toggle Fox selection with [F]
		get_viewport().set_input_as_handled()
		_toggle_fox_selection()

func _on_widget_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_toggle_fox_selection()

func _on_action_pressed() -> void:
	_toggle_fox_selection()

func _toggle_fox_selection() -> void:
	if _fox == null or not is_instance_valid(_fox):
		_fox = get_tree().get_first_node_in_group("fox_companion") as FoxCompanion
	
	if _fox and is_instance_valid(_fox):
		if _fox.is_inside_turret:
			_fox.set_selected(true)
		else:
			_fox.set_selected(not _fox.is_selected)

func _on_fox_selected_changed(selected: bool) -> void:
	_update_ui_state()
	_show_command_banner(selected)

func _on_fox_entered_turret(_turret: Node3D) -> void:
	_update_ui_state()

func _on_fox_left_turret(_turret: Node3D) -> void:
	_update_ui_state()

func _update_ui_state() -> void:
	if not hero_widget or not status_label or not action_button:
		return
	
	if _fox == null or not is_instance_valid(_fox):
		return
	
	if _fox.is_selected:
		status_label.text = "COMMAND ACTIVE"
		status_label.set("theme_override_colors/font_color", Color(1.0, 0.85, 0.25, 1.0))
		action_button.text = "Cancel"
		if _style_selected:
			hero_widget.add_theme_stylebox_override("panel", _style_selected)
	elif _fox.is_inside_turret:
		status_label.text = "BUFFING TURRET (+35%)"
		status_label.set("theme_override_colors/font_color", Color(0.2, 0.9, 0.8, 1.0))
		action_button.text = "Eject"
		if _style_buffing:
			hero_widget.add_theme_stylebox_override("panel", _style_buffing)
	else:
		status_label.text = "READY ON FIELD"
		status_label.set("theme_override_colors/font_color", Color(0.2, 0.85, 0.55, 1.0))
		action_button.text = "Select"
		if _style_normal:
			hero_widget.add_theme_stylebox_override("panel", _style_normal)

func _show_command_banner(show: bool) -> void:
	if not command_banner:
		return
	
	if _banner_tween and _banner_tween.is_running():
		_banner_tween.kill()
	
	if show:
		command_banner.visible = true
		command_banner.modulate.a = 0.0
		command_banner.scale = Vector2(0.8, 0.8)
		
		_banner_tween = create_tween()
		_banner_tween.set_parallel(true)
		_banner_tween.tween_property(command_banner, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_banner_tween.tween_property(command_banner, "scale", Vector2(1.0, 1.0), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_banner_tween = create_tween()
		_banner_tween.set_parallel(true)
		_banner_tween.tween_property(command_banner, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_banner_tween.tween_property(command_banner, "scale", Vector2(0.85, 0.85), 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_banner_tween.chain().tween_callback(func():
			if is_instance_valid(command_banner):
				command_banner.visible = false
		)
