extends Node

## TurretAudio — Global autoload sound engine for all turret, weapon, enemy & UI SFX.

const AUDIO_BASE := "res://assets/Audio/"

# Sound banks configured as requested:
# 1. impactwood heavy = turret placement sfx
# 2. impactplate medium 004 = ballista sfx
# 3. impactglass medium 000 = ufo hit
# 4. impactplank medium 001 = catapult sfx
# 5. impactplate light 002 = turret sfx
# 6. impactplate heavy 004 = heavy turret sfx
# 7. switch 007 = clicking any interface
# 8. explosioncrunch 000 = ufo explodes
# 9. drop 004 = animal enters the turret
# 10. drop 002 = clicking turret hotbar

const _FIRE_BANKS: Dictionary = {
	"turret":       ["impactPlate_light_002.ogg"],
	"heavy_turret": ["impactPlate_heavy_004.ogg"],
	"cannon":       ["impactPlate_heavy_000.ogg", "impactPlate_heavy_004.ogg"],
	"ballista":     ["impactPlate_medium_004.ogg"],
	"catapult":     ["impactPlank_medium_001.ogg"],
}

const _PLACEMENT_FILES: Array[String] = ["impactWood_heavy_000.ogg"]
const _UFO_HIT_FILES: Array[String] = ["impactGlass_medium_000.ogg"]
const _UFO_EXPLODE_FILES: Array[String] = ["explosionCrunch_000.ogg"]
const _ANIMAL_ENTER_FILES: Array[String] = ["drop_004.ogg"]
const _UI_CLICK_FILES: Array[String] = ["switch_007.ogg"]
const _HOTBAR_CLICK_FILES: Array[String] = ["drop_002.ogg"]

var _fire_streams: Dictionary = {}
var _placement_streams: Array[AudioStream] = []
var _ufo_hit_streams: Array[AudioStream] = []
var _ufo_explode_streams: Array[AudioStream] = []
var _animal_enter_streams: Array[AudioStream] = []
var _ui_click_streams: Array[AudioStream] = []
var _hotbar_click_streams: Array[AudioStream] = []

# Audio player pools
var _fire_pool: Array[AudioStreamPlayer] = []
var _impact_pool: Array[AudioStreamPlayer] = []
var _ui_pool: Array[AudioStreamPlayer] = []

var _fire_idx: int = 0
var _impact_idx: int = 0
var _ui_idx: int = 0

func _ready() -> void:
	_preload_all_sounds()
	_build_pools()
	_hook_ui_buttons()
	get_tree().node_added.connect(_on_node_added)

func _preload_all_sounds() -> void:
	# 1. Fire banks
	for wtype in _FIRE_BANKS:
		var list: Array[AudioStream] = []
		for fn in _FIRE_BANKS[wtype]:
			var s = _load_stream(fn)
			if s: list.append(s)
		if not list.is_empty():
			_fire_streams[wtype] = list

	# 2. Placement
	for fn in _PLACEMENT_FILES:
		var s = _load_stream(fn)
		if s: _placement_streams.append(s)

	# 3. UFO Hit
	for fn in _UFO_HIT_FILES:
		var s = _load_stream(fn)
		if s: _ufo_hit_streams.append(s)

	# 4. UFO Explode
	for fn in _UFO_EXPLODE_FILES:
		var s = _load_stream(fn)
		if s: _ufo_explode_streams.append(s)

	# 5. Animal Enter
	for fn in _ANIMAL_ENTER_FILES:
		var s = _load_stream(fn)
		if s: _animal_enter_streams.append(s)

	# 6. UI Click
	for fn in _UI_CLICK_FILES:
		var s = _load_stream(fn)
		if s: _ui_click_streams.append(s)

	# 7. Hotbar Click
	for fn in _HOTBAR_CLICK_FILES:
		var s = _load_stream(fn)
		if s: _hotbar_click_streams.append(s)

func _load_stream(filename: String) -> AudioStream:
	var p: String = AUDIO_BASE + filename
	if ResourceLoader.exists(p):
		return load(p) as AudioStream
	return null

func _build_pools() -> void:
	var bus_name: String = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"

	for _i in range(10):
		var p := AudioStreamPlayer.new()
		p.bus = bus_name
		p.volume_db = 0.0
		add_child(p)
		_fire_pool.append(p)

	for _i in range(10):
		var p := AudioStreamPlayer.new()
		p.bus = bus_name
		p.volume_db = 0.0
		add_child(p)
		_impact_pool.append(p)

	for _i in range(8):
		var p := AudioStreamPlayer.new()
		p.bus = bus_name
		p.volume_db = -1.0
		add_child(p)
		_ui_pool.append(p)

# ---------------------------------------------------------------------------
# Public SFX Methods
# ---------------------------------------------------------------------------

## 1. Turret fire SFX (turret = impactplate light 002, heavy = impactplate heavy 004, ballista = impactplate medium 004, catapult = impactplank medium 001)
func play_fire(w_type: String, _world_pos: Vector3 = Vector3.ZERO) -> void:
	var bank: Array = _fire_streams.get(w_type, _fire_streams.get("turret", []))
	if bank.is_empty():
		return
	var player: AudioStreamPlayer = _fire_pool[_fire_idx % _fire_pool.size()]
	_fire_idx += 1
	player.stream = bank[randi() % bank.size()]
	player.volume_db = 0.0
	player.pitch_scale = randf_range(0.94, 1.06)
	player.play()

## 2. Turret placement SFX (impactwood heavy)
func play_placement(_world_pos: Vector3 = Vector3.ZERO) -> void:
	if _placement_streams.is_empty():
		return
	var player: AudioStreamPlayer = _ui_pool[_ui_idx % _ui_pool.size()]
	_ui_idx += 1
	player.stream = _placement_streams[randi() % _placement_streams.size()]
	player.volume_db = 1.0
	player.pitch_scale = randf_range(0.95, 1.05)
	player.play()

## 3. UFO Hit SFX (impactglass medium 000)
func play_ufo_hit(_world_pos: Vector3 = Vector3.ZERO) -> void:
	if _ufo_hit_streams.is_empty():
		return
	var player: AudioStreamPlayer = _impact_pool[_impact_idx % _impact_pool.size()]
	_impact_idx += 1
	player.stream = _ufo_hit_streams[randi() % _ufo_hit_streams.size()]
	player.volume_db = -1.0
	player.pitch_scale = randf_range(0.92, 1.08)
	player.play()

## 4. UFO Explodes SFX (explosioncrunch 000)
func play_ufo_explode(_world_pos: Vector3 = Vector3.ZERO) -> void:
	if _ufo_explode_streams.is_empty():
		return
	var player: AudioStreamPlayer = _impact_pool[_impact_idx % _impact_pool.size()]
	_impact_idx += 1
	player.stream = _ufo_explode_streams[randi() % _ufo_explode_streams.size()]
	player.volume_db = 2.0
	player.pitch_scale = randf_range(0.92, 1.05)
	player.play()

## 5. Animal enters turret SFX (drop 004)
func play_animal_enter_turret(_world_pos: Vector3 = Vector3.ZERO) -> void:
	if _animal_enter_streams.is_empty():
		return
	var player: AudioStreamPlayer = _ui_pool[_ui_idx % _ui_pool.size()]
	_ui_idx += 1
	player.stream = _animal_enter_streams[randi() % _animal_enter_streams.size()]
	player.volume_db = 1.0
	player.pitch_scale = randf_range(0.95, 1.05)
	player.play()

## 6. Clicking turret hotbar slot SFX (drop 002)
func play_hotbar_click() -> void:
	if _hotbar_click_streams.is_empty():
		return
	var player: AudioStreamPlayer = _ui_pool[_ui_idx % _ui_pool.size()]
	_ui_idx += 1
	player.stream = _hotbar_click_streams[randi() % _hotbar_click_streams.size()]
	player.volume_db = 1.0
	player.pitch_scale = randf_range(0.96, 1.04)
	player.play()

## 7. Clicking any interface SFX (switch 007)
func play_ui_click() -> void:
	if _ui_click_streams.is_empty():
		return
	var player: AudioStreamPlayer = _ui_pool[_ui_idx % _ui_pool.size()]
	_ui_idx += 1
	player.stream = _ui_click_streams[randi() % _ui_click_streams.size()]
	player.volume_db = -1.0
	player.pitch_scale = randf_range(0.96, 1.04)
	player.play()

## Legacy alias for compatibility
func play_impact(w_type: String = "", _world_pos: Vector3 = Vector3.ZERO) -> void:
	play_ufo_hit(_world_pos)

# ---------------------------------------------------------------------------
# Automatic UI Click Hooking
# ---------------------------------------------------------------------------

func _hook_ui_buttons() -> void:
	var root = get_tree().root
	if root:
		_traverse_and_hook_buttons(root)

func _traverse_and_hook_buttons(node: Node) -> void:
	if node is BaseButton:
		_connect_button(node as BaseButton)
	for child in node.get_children():
		_traverse_and_hook_buttons(child)

func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		_connect_button(node as BaseButton)

func _connect_button(btn: BaseButton) -> void:
	if not btn.pressed.is_connected(play_ui_click):
		btn.pressed.connect(play_ui_click)
