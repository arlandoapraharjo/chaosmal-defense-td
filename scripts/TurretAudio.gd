extends Node

## TurretAudio — Global autoload audio engine for all SFX, Ambient Ocean SFX & Background Music (BGM).

const AUDIO_BASE := "res://assets/Audio/"
const MUSIC_BASE := "res://assets/Music/"

# ---------------------------------------------------------------------------
# SFX Banks
# ---------------------------------------------------------------------------

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
const _ROCKET_THRUSTER_FILES: Array[String] = ["thrusterFire_000.ogg"]
const _PILLAR_HIT_FILES: Array[String] = ["forceField_000.ogg"]
const _SEA_WAVES_FILE: String = "Sea Waves - Sound Effect.mp3"

# ---------------------------------------------------------------------------
# Background Music (BGM) & Ambient Configuration
# ---------------------------------------------------------------------------

const _MUSIC_TRACKS: Array[String] = ["float.mp3", "hover.mp3"]
const _MUSIC_FALLBACKS: Array[String] = ["float.mp3.mpeg", "hover.mp3.mpeg"]

const _BGM_TARGET_DB: float = -6.0          # Loud, rich and clear background music volume
const _BGM_CROSSFADE_TIME: float = 2.5      # Smooth fade-in / fade-out duration
const _SEA_WAVES_TARGET_DB: float = 0.0     # Loud and immersive ambient sea waves ocean volume

var _fire_streams: Dictionary = {}
var _placement_streams: Array[AudioStream] = []
var _ufo_hit_streams: Array[AudioStream] = []
var _ufo_explode_streams: Array[AudioStream] = []
var _animal_enter_streams: Array[AudioStream] = []
var _ui_click_streams: Array[AudioStream] = []
var _hotbar_click_streams: Array[AudioStream] = []
var _rocket_thruster_streams: Array[AudioStream] = []
var _pillar_hit_streams: Array[AudioStream] = []
var _music_streams: Array[AudioStream] = []
var _sea_waves_stream: AudioStream = null

# Audio player pools for SFX
var _fire_pool: Array[AudioStreamPlayer] = []
var _impact_pool: Array[AudioStreamPlayer] = []
var _ui_pool: Array[AudioStreamPlayer] = []

var _fire_idx: int = 0
var _impact_idx: int = 0
var _ui_idx: int = 0

# Dual players for seamless BGM crossfading
var _music_player_a: AudioStreamPlayer = null
var _music_player_b: AudioStreamPlayer = null
var _active_music_player: AudioStreamPlayer = null
var _current_music_idx: int = 0
var _music_tween: Tween = null
var _is_transitioning_bgm: bool = false

# Ambient Sea Waves player
var _sea_waves_player: AudioStreamPlayer = null

func _ready() -> void:
	_preload_all_sounds()
	_build_pools()
	_hook_ui_buttons()
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_start_bgm_system")
	call_deferred("_start_sea_waves")

func _preload_all_sounds() -> void:
	# 1. Fire banks
	for wtype in _FIRE_BANKS:
		var list: Array[AudioStream] = []
		for fn in _FIRE_BANKS[wtype]:
			var s = _load_stream(AUDIO_BASE + fn)
			if s: list.append(s)
		if not list.is_empty():
			_fire_streams[wtype] = list

	# 2. Placement
	for fn in _PLACEMENT_FILES:
		var s = _load_stream(AUDIO_BASE + fn)
		if s: _placement_streams.append(s)

	# 3. UFO Hit
	for fn in _UFO_HIT_FILES:
		var s = _load_stream(AUDIO_BASE + fn)
		if s: _ufo_hit_streams.append(s)

	# 4. UFO Explode
	for fn in _UFO_EXPLODE_FILES:
		var s = _load_stream(AUDIO_BASE + fn)
		if s: _ufo_explode_streams.append(s)

	# 5. Animal Enter
	for fn in _ANIMAL_ENTER_FILES:
		var s = _load_stream(AUDIO_BASE + fn)
		if s: _animal_enter_streams.append(s)

	# 6. UI Click
	for fn in _UI_CLICK_FILES:
		var s = _load_stream(AUDIO_BASE + fn)
		if s: _ui_click_streams.append(s)

	# 7. Hotbar Click
	for fn in _HOTBAR_CLICK_FILES:
		var s = _load_stream(AUDIO_BASE + fn)
		if s: _hotbar_click_streams.append(s)

	# 8. Rocket Thruster
	for fn in _ROCKET_THRUSTER_FILES:
		var s = _load_stream(AUDIO_BASE + fn)
		if s: _rocket_thruster_streams.append(s)

	# 9. Pillar ForceField Hit (forceField_000.ogg)
	for fn in _PILLAR_HIT_FILES:
		var s = _load_stream(AUDIO_BASE + fn)
		if s: _pillar_hit_streams.append(s)

	# 10. Ambient Sea Waves
	_sea_waves_stream = _load_stream(AUDIO_BASE + _SEA_WAVES_FILE)

	# 11. Background Music Tracks (float & hover)
	for i in range(_MUSIC_TRACKS.size()):
		var primary_path = MUSIC_BASE + _MUSIC_TRACKS[i]
		var fallback_path = MUSIC_BASE + _MUSIC_FALLBACKS[i]
		var s: AudioStream = _load_stream(primary_path)
		if s == null:
			s = _load_stream(fallback_path)
		if s:
			_music_streams.append(s)

func _load_stream(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path) as AudioStream
	return null

func _build_pools() -> void:
	var sfx_bus: String = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"

	for _i in range(10):
		var p := AudioStreamPlayer.new()
		p.bus = sfx_bus
		p.volume_db = 0.0
		add_child(p)
		_fire_pool.append(p)

	for _i in range(10):
		var p := AudioStreamPlayer.new()
		p.bus = sfx_bus
		p.volume_db = 0.0
		add_child(p)
		_impact_pool.append(p)

	for _i in range(8):
		var p := AudioStreamPlayer.new()
		p.bus = sfx_bus
		p.volume_db = -3.0
		add_child(p)
		_ui_pool.append(p)

# ---------------------------------------------------------------------------
# Ambient Sea Waves SFX Engine (Loops for all maps)
# ---------------------------------------------------------------------------

func _start_sea_waves() -> void:
	if _sea_waves_stream == null:
		return

	if _sea_waves_player != null:
		return

	var sfx_bus: String = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	_sea_waves_player = AudioStreamPlayer.new()
	_sea_waves_player.name = "SeaWaves_AmbientPlayer"
	_sea_waves_player.bus = sfx_bus
	_sea_waves_player.stream = _sea_waves_stream
	_sea_waves_player.volume_db = -80.0
	add_child(_sea_waves_player)

	# Infinite loop connection
	_sea_waves_player.finished.connect(func():
		if is_instance_valid(_sea_waves_player):
			_sea_waves_player.play()
	)

	_sea_waves_player.play()

	# Smooth initial fade-in
	var tw = create_tween()
	tw.tween_property(_sea_waves_player, "volume_db", _SEA_WAVES_TARGET_DB, 2.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# ---------------------------------------------------------------------------
# Background Music (BGM) Engine with Crossfade Loop
# ---------------------------------------------------------------------------

func _start_bgm_system() -> void:
	if _music_streams.is_empty():
		return

	var music_bus: String = "Music" if AudioServer.get_bus_index("Music") != -1 else "Master"

	_music_player_a = AudioStreamPlayer.new()
	_music_player_a.name = "BGM_Player_A"
	_music_player_a.bus = music_bus
	_music_player_a.volume_db = -80.0
	_music_player_a.finished.connect(_on_bgm_player_finished.bind(_music_player_a))
	add_child(_music_player_a)

	_music_player_b = AudioStreamPlayer.new()
	_music_player_b.name = "BGM_Player_B"
	_music_player_b.bus = music_bus
	_music_player_b.volume_db = -80.0
	_music_player_b.finished.connect(_on_bgm_player_finished.bind(_music_player_b))
	add_child(_music_player_b)

	_play_next_bgm_track()

func _on_bgm_player_finished(player: AudioStreamPlayer) -> void:
	if player == _active_music_player and not _is_transitioning_bgm:
		_play_next_bgm_track()

func _play_next_bgm_track() -> void:
	if _music_streams.is_empty():
		return

	_is_transitioning_bgm = true
	var incoming_stream: AudioStream = _music_streams[_current_music_idx]
	_current_music_idx = (_current_music_idx + 1) % _music_streams.size()

	var outgoing_player: AudioStreamPlayer = _active_music_player
	var incoming_player: AudioStreamPlayer = _music_player_b if _active_music_player == _music_player_a else _music_player_a
	_active_music_player = incoming_player

	incoming_player.stream = incoming_stream
	incoming_player.volume_db = -80.0
	incoming_player.play()

	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()

	_music_tween = create_tween().set_parallel(true)

	# Smooth Fade In for incoming track
	_music_tween.tween_property(incoming_player, "volume_db", _BGM_TARGET_DB, _BGM_CROSSFADE_TIME)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Smooth Fade Out for outgoing track
	if outgoing_player and outgoing_player.playing:
		_music_tween.tween_property(outgoing_player, "volume_db", -80.0, _BGM_CROSSFADE_TIME)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		
		var stop_tw = create_tween()
		stop_tw.tween_interval(_BGM_CROSSFADE_TIME)
		stop_tw.tween_callback(func():
			if is_instance_valid(outgoing_player) and outgoing_player != _active_music_player:
				outgoing_player.stop()
		)

	# Reset transitioning flag after crossfade completes
	var reset_tw = create_tween()
	reset_tw.tween_interval(_BGM_CROSSFADE_TIME + 0.1)
	reset_tw.tween_callback(func():
		_is_transitioning_bgm = false
	)

	# Pre-schedule next track crossfade before current track finishes (if stream length is known)
	var stream_len: float = incoming_stream.get_length() if incoming_stream else 0.0
	if stream_len > _BGM_CROSSFADE_TIME * 2.5:
		var schedule_delay = stream_len - _BGM_CROSSFADE_TIME
		var track_timer = get_tree().create_timer(schedule_delay)
		track_timer.timeout.connect(func():
			if _active_music_player == incoming_player and incoming_player.playing and not _is_transitioning_bgm:
				_play_next_bgm_track()
		)

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
	player.volume_db = -1.0
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
	player.volume_db = -1.0
	player.pitch_scale = randf_range(0.95, 1.05)
	player.play()

## 6. Clicking turret hotbar slot SFX (drop 002)
func play_hotbar_click() -> void:
	if _hotbar_click_streams.is_empty():
		return
	var player: AudioStreamPlayer = _ui_pool[_ui_idx % _ui_pool.size()]
	_ui_idx += 1
	player.stream = _hotbar_click_streams[randi() % _hotbar_click_streams.size()]
	player.volume_db = -1.0
	player.pitch_scale = randf_range(0.96, 1.04)
	player.play()

## Command companion / animal to move SFX (drop 002)
func play_companion_move() -> void:
	play_hotbar_click()

## 7. Rocket Thruster SFX (thrusterFire 000) — Supports exact timed playback with smooth fade out
func play_rocket_thruster(duration: float = 0.0, vol_db: float = 2.0) -> AudioStreamPlayer:
	if _rocket_thruster_streams.is_empty():
		return null
	var player := AudioStreamPlayer.new()
	player.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	player.stream = _rocket_thruster_streams[0]
	player.volume_db = vol_db
	player.pitch_scale = 1.0
	add_child(player)
	player.play()
	
	if duration > 0.0:
		var tw = create_tween()
		var fade_time = minf(0.12, duration * 0.15)
		tw.tween_interval(maxf(0.0, duration - fade_time))
		tw.tween_property(player, "volume_db", -80.0, fade_time)
		tw.tween_callback(func():
			if is_instance_valid(player):
				player.stop()
				player.queue_free()
		)
	else:
		player.finished.connect(player.queue_free)
	return player

## 8. UFO Crash into Pillar ForceField SFX (forceField 000)
func play_pillar_hit(_world_pos: Vector3 = Vector3.ZERO) -> void:
	if _pillar_hit_streams.is_empty():
		return
	var player: AudioStreamPlayer = _impact_pool[_impact_idx % _impact_pool.size()]
	_impact_idx += 1
	player.stream = _pillar_hit_streams[randi() % _pillar_hit_streams.size()]
	player.volume_db = 2.5
	player.pitch_scale = randf_range(0.95, 1.05)
	player.play()

## 9. Clicking any interface SFX (switch 007)
func play_ui_click() -> void:
	if _ui_click_streams.is_empty():
		return
	var player: AudioStreamPlayer = _ui_pool[_ui_idx % _ui_pool.size()]
	_ui_idx += 1
	player.stream = _ui_click_streams[randi() % _ui_click_streams.size()]
	player.volume_db = -3.0
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
