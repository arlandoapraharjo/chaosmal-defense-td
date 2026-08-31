extends CanvasLayer

signal intro_finished
signal step_changed(step_idx: int)

@onready var root_control: Control = $Control
@onready var backdrop: ColorRect = $Control/Backdrop
@onready var dialog_panel: PanelContainer = $Control/DialogPanel
@onready var speaker_name_label: Label = $Control/DialogPanel/MarginContainer/MainHBox/ContentVBox/HeaderHBox/SpeakerName
@onready var badge_label: Label = $Control/DialogPanel/MarginContainer/MainHBox/ContentVBox/HeaderHBox/BadgePill/BadgeText
@onready var dialogue_text: RichTextLabel = $Control/DialogPanel/MarginContainer/MainHBox/ContentVBox/DialogueText
@onready var next_button: Button = $Control/DialogPanel/MarginContainer/MainHBox/ContentVBox/FooterHBox/NextButton
@onready var skip_button: Button = $Control/DialogPanel/MarginContainer/MainHBox/ContentVBox/HeaderHBox/SkipButton
@onready var dots_container: HBoxContainer = $Control/DialogPanel/MarginContainer/MainHBox/ContentVBox/FooterHBox/DotsContainer

# Fox 3D Portrait Frame in Dialogue Box
@onready var fox_model_root: Node3D = $Control/DialogPanel/MarginContainer/MainHBox/FoxFrame/FoxViewportContainer/SubViewport/FoxWorld/FoxAnchor/FoxModel

const FOX_SCENE = preload("res://assets/characters/animal-fox.glb")

const DIALOGUE_STEPS: Array[Dictionary] = [
	{
		"speaker": "TACTICAL ADVISOR FOX",
		"badge": "FIELD BRIEFING",
		"text": "Greetings, Commander! I'm [b][color=#ffd166]Fox[/color][/b], deployed on the ground with you. Let's get briefed on our defensive grid before the incursion begins!"
	},
	{
		"speaker": "TACTICAL ADVISOR FOX",
		"badge": "CRITICAL ASSET",
		"text": "The crystal monolith at the center is our [b][color=#5ce1e6]Incursion Pillar[/color][/b]. Alien UFOs will follow the pathway to attack it. If the pillar falls, the sector is lost!"
	},
	{
		"speaker": "TACTICAL ADVISOR FOX",
		"badge": "TURRET DEPLOYMENT",
		"text": "Use the [b][color=#06d6a0]Turret Hotbar[/color][/b] at the bottom to select defenses. Deploy turrets along the path on valid tiles to intercept approaching invaders."
	},
	{
		"speaker": "TACTICAL ADVISOR FOX",
		"badge": "FIELD BUFFS & COINS",
		"text": "[b][color=#ffd166]Click on me in the map[/color][/b] (or press [b][color=#ffd166][F][/color][/b]) to command my position! Send me into any turret to provide [b][color=#06d6a0]+35% Attack Speed & Firepower buffs[/color][/b]!"
	},
	{
		"speaker": "TACTICAL ADVISOR FOX",
		"badge": "RADAR & SPEED",
		"text": "Pan and rotate your camera to survey the sector. You can also toggle [b][color=#38bdf8]Game Speed[/color][/b] (1x / 2x) or [b][color=#ef476f]Pause[/color][/b] anytime using the top controls."
	},
	{
		"speaker": "TACTICAL ADVISOR FOX",
		"badge": "COMBAT STATIONS",
		"text": "Incoming enemy UFO waves detected on radar! Fortify the path and protect the Incursion Pillar at all costs. [b][color=#06d6a0]Good luck, Commander![/color][/b]"
	}
]

# Adaptive docking anchor positions per tutorial step
const STEP_ANCHORS: Dictionary = {
	0: {"top": 0.73, "bottom": 0.95}, # Bottom-Center (Fox Companion Intro)
	1: {"top": 0.73, "bottom": 0.95}, # Bottom-Center (Incursion Pillar)
	2: {"top": 0.05, "bottom": 0.27}, # Top-Center (Turret Hotbar is Revealed at bottom!)
	3: {"top": 0.05, "bottom": 0.27}, # Top-Center (Fox Command & Battlefield Buffs)
	4: {"top": 0.73, "bottom": 0.95}, # Bottom-Center (Speed & Pause Controls at top!)
	5: {"top": 0.73, "bottom": 0.95}  # Bottom-Center (Combat Stations Overview)
}

var _current_step: int = 0
var _is_typing: bool = false
var _typewriter_tween: Tween = null
var _glide_tween: Tween = null
var _is_active: bool = false
var _is_exiting: bool = false
var _breath_time: float = 0.0

var _fox_anim_player: AnimationPlayer = null
var _dot_nodes: Array[ColorRect] = []

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_setup_fox_model()
	_setup_dots()
	
	if next_button:
		next_button.pressed.connect(_on_next_pressed)
	if skip_button:
		skip_button.pressed.connect(_on_skip_pressed)
	if dialog_panel:
		dialog_panel.gui_input.connect(_on_card_gui_input)
	if backdrop:
		backdrop.gui_input.connect(_on_card_gui_input)

func _on_card_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_next_pressed()

func _setup_fox_model() -> void:
	if not fox_model_root:
		return
	
	fox_model_root.scale = Vector3(0.35, 0.35, 0.35)
	fox_model_root.rotation.y = deg_to_rad(35.0)
	fox_model_root.rotation.x = deg_to_rad(-4.0)
	
	if fox_model_root.get_child_count() == 0:
		var fox_instance = FOX_SCENE.instantiate()
		fox_model_root.add_child(fox_instance)
		
		_fox_anim_player = _find_animation_player(fox_instance)
		if _fox_anim_player:
			if _fox_anim_player.has_animation("idle"):
				_fox_anim_player.play("idle")
			elif _fox_anim_player.has_animation("static"):
				_fox_anim_player.play("static")
	else:
		_fox_anim_player = _find_animation_player(fox_model_root)
		if _fox_anim_player and _fox_anim_player.has_animation("idle"):
			_fox_anim_player.play("idle")

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found = _find_animation_player(child)
		if found:
			return found
	return null

func _setup_dots() -> void:
	if not dots_container:
		return
	for child in dots_container.get_children():
		child.queue_free()
	_dot_nodes.clear()
	
	for i in range(DIALOGUE_STEPS.size()):
		var dot = ColorRect.new()
		dot.custom_minimum_size = Vector2(8, 5)
		dot.color = Color(0.3, 0.38, 0.48, 0.6)
		dots_container.add_child(dot)
		_dot_nodes.append(dot)

func _update_dots() -> void:
	for i in range(_dot_nodes.size()):
		if i == _current_step:
			_dot_nodes[i].custom_minimum_size = Vector2(18, 5)
			_dot_nodes[i].color = Color(0.3, 0.65, 0.95, 1.0)
		elif i < _current_step:
			_dot_nodes[i].custom_minimum_size = Vector2(8, 5)
			_dot_nodes[i].color = Color(0.2, 0.75, 0.5, 0.8)
		else:
			_dot_nodes[i].custom_minimum_size = Vector2(8, 5)
			_dot_nodes[i].color = Color(0.3, 0.38, 0.48, 0.6)

func _process(delta: float) -> void:
	if not _is_active or _is_exiting:
		return
	
	# Procedural Fox Breathing in Frame
	_breath_time += delta * 2.8
	if fox_model_root:
		var bob = sin(_breath_time) * 0.01
		var base_scale: float = 0.35
		fox_model_root.position.y = bob
		fox_model_root.scale.y = base_scale * (1.0 + sin(_breath_time) * 0.02)
		fox_model_root.scale.x = base_scale * (1.0 - sin(_breath_time) * 0.01)
		fox_model_root.scale.z = base_scale * (1.0 - sin(_breath_time) * 0.01)
		fox_model_root.rotation.y = deg_to_rad(35.0) + sin(_breath_time * 0.5) * 0.02
		fox_model_root.rotation.x = deg_to_rad(-4.0) + sin(_breath_time * 0.8) * 0.01

func _unhandled_input(event: InputEvent) -> void:
	if not _is_active or _is_exiting:
		return
	
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER)):
		get_viewport().set_input_as_handled()
		_on_next_pressed()
	elif event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		_on_skip_pressed()

func start_intro() -> void:
	_is_active = true
	_is_exiting = false
	_current_step = 0
	visible = true
	
	root_control.modulate.a = 0.0
	
	if dialog_panel:
		dialog_panel.anchor_top = 0.73
		dialog_panel.anchor_bottom = 0.95
		dialog_panel.position.y += 40.0
	
	var enter_tween = create_tween()
	enter_tween.set_parallel(true)
	enter_tween.tween_property(root_control, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if dialog_panel:
		enter_tween.tween_property(dialog_panel, "position:y", dialog_panel.position.y - 40.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	_show_step(_current_step)

func _show_step(step_idx: int) -> void:
	if step_idx < 0 or step_idx >= DIALOGUE_STEPS.size():
		_finish_intro()
		return
	
	_current_step = step_idx
	step_changed.emit(_current_step)
	_update_dots()
	_glide_to_step_layout(_current_step)
	
	var data = DIALOGUE_STEPS[_current_step]
	if speaker_name_label:
		speaker_name_label.text = data.speaker
	if badge_label:
		badge_label.text = data.badge
	
	if next_button:
		if _current_step == DIALOGUE_STEPS.size() - 1:
			next_button.text = "Start Battle ⚔"
		else:
			next_button.text = "Next ▸"
	
	_animate_dialogue_text(data.text)

func _glide_to_step_layout(step_idx: int) -> void:
	if not dialog_panel:
		return
	
	var target = STEP_ANCHORS.get(step_idx, {"top": 0.68, "bottom": 0.95})
	
	if _glide_tween and _glide_tween.is_running():
		_glide_tween.kill()
	
	_glide_tween = create_tween()
	_glide_tween.set_parallel(true)
	_glide_tween.tween_property(dialog_panel, "anchor_top", target["top"], 0.42)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_glide_tween.tween_property(dialog_panel, "anchor_bottom", target["bottom"], 0.42)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _animate_dialogue_text(full_bbcode: String) -> void:
	if not dialogue_text:
		return
	
	if _typewriter_tween and _typewriter_tween.is_running():
		_typewriter_tween.kill()
	
	dialogue_text.text = full_bbcode
	dialogue_text.visible_ratio = 0.0
	_is_typing = true
	
	var plain_length = dialogue_text.get_parsed_text().length()
	var duration = clampf(plain_length * 0.016, 0.4, 1.4)
	
	_typewriter_tween = create_tween()
	_typewriter_tween.tween_property(dialogue_text, "visible_ratio", 1.0, duration)\
		.set_trans(Tween.TRANS_LINEAR)
	_typewriter_tween.tween_callback(func():
		_is_typing = false
	)

func _on_next_pressed() -> void:
	if not _is_active or _is_exiting:
		return
	
	if _is_typing:
		if _typewriter_tween and _typewriter_tween.is_running():
			_typewriter_tween.kill()
		dialogue_text.visible_ratio = 1.0
		_is_typing = false
		return
	
	if _current_step < DIALOGUE_STEPS.size() - 1:
		_show_step(_current_step + 1)
	else:
		_finish_intro()

func _on_skip_pressed() -> void:
	if not _is_active or _is_exiting:
		return
	_finish_intro()

func _finish_intro() -> void:
	if _is_exiting:
		return
	_is_exiting = true
	_is_active = false
	
	if _typewriter_tween and _typewriter_tween.is_running():
		_typewriter_tween.kill()
	if _glide_tween and _glide_tween.is_running():
		_glide_tween.kill()
	
	var exit_tween = create_tween()
	exit_tween.set_parallel(true)
	exit_tween.tween_property(root_control, "modulate:a", 0.0, 0.35)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	if dialog_panel:
		exit_tween.tween_property(dialog_panel, "position:y", dialog_panel.position.y + 40.0, 0.35)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	exit_tween.chain().tween_callback(func():
		visible = false
		intro_finished.emit()
	)
