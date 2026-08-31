extends CanvasLayer

signal intro_finished
signal step_changed(step_idx: int)

@onready var root_control: Control = $Control
@onready var backdrop: ColorRect = $Control/Backdrop
@onready var dialog_panel: TextureRect = $Control/DialogPanel
@onready var speaker_name_label: Label = $Control/DialogPanel/TopTab/SpeakerName
@onready var dialogue_text: RichTextLabel = $Control/DialogPanel/RightContent/VBoxContainer/DialogueText
@onready var next_button: Button = $Control/DialogPanel/RightContent/VBoxContainer/FooterHBox/NextButton
@onready var skip_button: Button = $Control/DialogPanel/RightContent/VBoxContainer/FooterHBox/SkipButton
@onready var dots_container: HBoxContainer = $Control/DialogPanel/RightContent/VBoxContainer/FooterHBox/DotsContainer
@onready var typewriter_sfx: AudioStreamPlayer = $TypewriterSFX

# Fox 3D Portrait in 2D Frame
@onready var fox_model_root: Node3D = $Control/DialogPanel/FoxFrame/FoxViewportContainer/SubViewport/FoxWorld/FoxAnchor/FoxModel

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

# Adaptive docking anchor positions per tutorial step (0.0 = top, 1.0 = bottom)
const STEP_DOCK: Dictionary = {
	0: "bottom", # Fox Companion Intro
	1: "bottom", # Incursion Pillar
	2: "top",    # Turret Hotbar is Revealed at bottom
	3: "top",    # Fox Command & Battlefield Buffs
	4: "bottom", # Speed & Pause Controls at top
	5: "bottom"  # Combat Stations Overview
}

var _current_step: int = 0
var _is_typing: bool = false
var _typewriter_tween: Tween = null
var _glide_tween: Tween = null
var _is_active: bool = false
var _is_exiting: bool = false
var _breath_time: float = 0.0
var _last_played_char_count: int = 0

var _fox_anim_player: AnimationPlayer = null
var _dot_nodes: Array[ColorRect] = []
var _chirp_sound: AudioStreamWAV = null

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_setup_fox_model()
	_setup_dots()
	_setup_chirp_sound()
	
	if next_button:
		next_button.pressed.connect(_on_next_pressed)
	if skip_button:
		skip_button.pressed.connect(_on_skip_pressed)
	if dialog_panel:
		dialog_panel.gui_input.connect(_on_card_gui_input)
	if backdrop:
		backdrop.gui_input.connect(_on_card_gui_input)

func _setup_chirp_sound() -> void:
	var sample_rate: int = 22050
	var duration: float = 0.020
	var num_samples: int = int(sample_rate * duration)
	var byte_data = PackedByteArray()
	byte_data.resize(num_samples)
	for i in range(num_samples):
		var t = float(i) / float(sample_rate)
		var env = exp(-t * 120.0)
		var val = sin(t * TAU * 1400.0) * env * 0.25
		var byte_val = int(clamp((val + 1.0) * 127.5, 0, 255))
		byte_data[i] = byte_val
	
	_chirp_sound = AudioStreamWAV.new()
	_chirp_sound.format = AudioStreamWAV.FORMAT_8_BITS
	_chirp_sound.mix_rate = sample_rate
	_chirp_sound.stereo = false
	_chirp_sound.data = byte_data
	
	if typewriter_sfx:
		typewriter_sfx.stream = _chirp_sound
		typewriter_sfx.volume_db = -14.0

func _play_typewriter_blip() -> void:
	if typewriter_sfx and _chirp_sound:
		typewriter_sfx.pitch_scale = randf_range(0.92, 1.12)
		typewriter_sfx.play()

func _on_card_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_next_pressed()

func _setup_fox_model() -> void:
	if not fox_model_root:
		return
	
	fox_model_root.scale = Vector3(0.5, 0.5, 0.5)
	fox_model_root.rotation.y = deg_to_rad(36.0)
	
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
		dot.custom_minimum_size = Vector2(8, 6)
		dot.color = Color(0.3, 0.4, 0.55, 0.6)
		dots_container.add_child(dot)
		_dot_nodes.append(dot)

func _update_dots() -> void:
	for i in range(_dot_nodes.size()):
		if i == _current_step:
			_dot_nodes[i].custom_minimum_size = Vector2(20, 6)
			_dot_nodes[i].color = Color(0.24, 0.72, 1.0, 1.0)
		elif i < _current_step:
			_dot_nodes[i].custom_minimum_size = Vector2(8, 6)
			_dot_nodes[i].color = Color(0.18, 0.85, 0.55, 0.8)
		else:
			_dot_nodes[i].custom_minimum_size = Vector2(8, 6)
			_dot_nodes[i].color = Color(0.3, 0.4, 0.55, 0.6)

func _process(delta: float) -> void:
	if not _is_active or _is_exiting:
		return
	
	# Procedural Fox Breathing Animation in 2D Frame
	_breath_time += delta * 2.8
	if fox_model_root:
		var bob = sin(_breath_time) * 0.025
		var base_scale: float = 0.5
		fox_model_root.position.y = bob
		fox_model_root.scale.y = base_scale * (1.0 + sin(_breath_time) * 0.025)
		fox_model_root.scale.x = base_scale * (1.0 - sin(_breath_time) * 0.012)
		fox_model_root.scale.z = base_scale * (1.0 - sin(_breath_time) * 0.012)
		fox_model_root.rotation.y = deg_to_rad(36.0) + sin(_breath_time * 0.5) * 0.04

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
	
	var target_y = _get_target_y_for_dock("bottom")
	if dialog_panel:
		dialog_panel.position.y = target_y + 70.0
	
	var enter_tween = create_tween()
	enter_tween.set_parallel(true)
	enter_tween.tween_property(root_control, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if dialog_panel:
		enter_tween.tween_property(dialog_panel, "position:y", target_y, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	_show_step(_current_step)

func _get_target_y_for_dock(dock: String) -> float:
	var vp_h: float = get_viewport().get_visible_rect().size.y if get_viewport() else 648.0
	if dock == "top":
		return 15.0
	return maxf(0.0, vp_h - 165.0)

func _show_step(step_idx: int) -> void:
	if step_idx < 0 or step_idx >= DIALOGUE_STEPS.size():
		_finish_intro()
		return
	
	_current_step = step_idx
	step_changed.emit(_current_step)
	_update_dots()
	
	var dock = STEP_DOCK.get(_current_step, "bottom")
	_glide_to_dock(dock)
	
	var data = DIALOGUE_STEPS[_current_step]
	if speaker_name_label:
		speaker_name_label.text = "🦊 " + data["speaker"] + " • " + data["badge"]
	
	if next_button:
		if _current_step == DIALOGUE_STEPS.size() - 1:
			next_button.text = "Start Defense ⚔"
		else:
			next_button.text = "Next ▸"
	
	if _fox_anim_player:
		if _current_step == 0 or _current_step == DIALOGUE_STEPS.size() - 1:
			if _fox_anim_player.has_animation("gesture-positive"):
				_fox_anim_player.play("gesture-positive")
				_fox_anim_player.queue("idle")
			elif _fox_anim_player.has_animation("idle"):
				_fox_anim_player.play("idle")
		else:
			if _fox_anim_player.has_animation("idle") and _fox_anim_player.current_animation != "idle":
				_fox_anim_player.play("idle")
	
	_animate_dialogue_text(data["text"])

func _glide_to_dock(dock: String) -> void:
	if not dialog_panel:
		return
	
	var target_y = _get_target_y_for_dock(dock)
	if is_equal_approx(dialog_panel.position.y, target_y):
		return
	
	if _glide_tween and _glide_tween.is_running():
		_glide_tween.kill()
	
	_glide_tween = create_tween()
	_glide_tween.tween_property(dialog_panel, "position:y", target_y, 0.42)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _animate_dialogue_text(full_bbcode: String) -> void:
	if not dialogue_text:
		return
	
	if _typewriter_tween and _typewriter_tween.is_running():
		_typewriter_tween.kill()
	
	dialogue_text.bbcode_enabled = true
	dialogue_text.text = full_bbcode
	dialogue_text.visible_characters = 0
	_is_typing = true
	_last_played_char_count = 0
	
	var total_chars = dialogue_text.get_total_character_count()
	var duration = clampf(total_chars * 0.020, 0.35, 1.8)
	
	_typewriter_tween = create_tween()
	_typewriter_tween.tween_method(_on_typewriter_step, 0, total_chars, duration)
	_typewriter_tween.tween_callback(func():
		_is_typing = false
		dialogue_text.visible_characters = -1
	)

func _on_typewriter_step(char_count: int) -> void:
	dialogue_text.visible_characters = char_count
	if char_count > _last_played_char_count and (char_count % 2 == 0):
		_play_typewriter_blip()
	_last_played_char_count = char_count

func _on_next_pressed() -> void:
	if not _is_active or _is_exiting:
		return
	
	if _is_typing:
		if _typewriter_tween and _typewriter_tween.is_running():
			_typewriter_tween.kill()
		dialogue_text.visible_characters = -1
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
	exit_tween.tween_property(root_control, "modulate:a", 0.0, 0.28)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	if dialog_panel:
		exit_tween.tween_property(dialog_panel, "position:y", dialog_panel.position.y + 70.0, 0.28)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	exit_tween.chain().tween_callback(func():
		visible = false
		intro_finished.emit()
	)
