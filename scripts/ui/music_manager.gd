extends Node
## One persistent player across scenes. Audio is separate from the web game pack.
signal changed
const TRACKS: Array = [
	{"id": "dream-culture", "title": "Dream Culture", "mood": "Piano thư thái", "isrc": "USUAN1300046"},
	{"id": "bossa-antigua", "title": "Bossa Antigua", "mood": "Guitar và bossa nhẹ", "isrc": "USUAN1700069"},
	{"id": "easy-lemon", "title": "Easy Lemon", "mood": "Mộc mạc, nhẹ nhàng", "isrc": "USUAN1200076"},
]
const SETTINGS_PATH: String = "user://music_settings.cfg"
var enabled: bool = true
var volume: float = 0.28
var track_index: int = 0
var loading: bool = false
var error_text: String = ""
var _player: AudioStreamPlayer
var _request: HTTPRequest
var _cache: Dictionary = {}
var _requested_index: int = -1
var _fade: Tween

static func ensure(tree: SceneTree) -> Node:
	if Engine.has_meta("karaoke_music_player"):
		var existing = Engine.get_meta("karaoke_music_player")
		if is_instance_valid(existing):
			return existing
	var node: Node = load("res://scripts/ui/music_manager.gd").new()
	node.name = "GameMusic"
	Engine.set_meta("karaoke_music_player", node)
	tree.root.add_child.call_deferred(node)
	return node

func _ready() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		enabled = bool(config.get_value("music", "enabled", true))
		volume = clampf(float(config.get_value("music", "volume", 0.28)), 0.0, 1.0)
		track_index = clampi(int(config.get_value("music", "track", 0)), 0, TRACKS.size() - 1)
	if OS.has_feature("web"):
		var raw = JavaScriptBridge.eval("(function(){try{return localStorage.getItem('karaoke_music_preferences');}catch(e){return null;}})()", true)
		if raw is String:
			var parser: JSON = JSON.new()
			if parser.parse(raw) == OK and parser.data is Dictionary:
				var settings: Dictionary = parser.data
				enabled = bool(settings.get("enabled", enabled))
				volume = clampf(float(settings.get("volume", volume)), 0.0, 1.0)
				track_index = clampi(int(settings.get("track", track_index)), 0, TRACKS.size() - 1)
	_player = AudioStreamPlayer.new()
	_player.volume_db = -60
	_player.finished.connect(func() -> void: select_track((track_index + 1) % TRACKS.size()))
	add_child(_player)
	_request = HTTPRequest.new()
	_request.timeout = 30
	_request.request_completed.connect(_downloaded)
	add_child(_request)
	if enabled:
		select_track(track_index)
	else:
		changed.emit()

func _save() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("music", "enabled", enabled)
	config.set_value("music", "volume", volume)
	config.set_value("music", "track", track_index)
	config.save(SETTINGS_PATH)
	if OS.has_feature("web"):
		var settings: String = JSON.stringify(JSON.stringify({"enabled": enabled, "volume": volume, "track": track_index}))
		JavaScriptBridge.eval("try { localStorage.setItem('karaoke_music_preferences', " + settings + "); } catch(e) {}", true)

func set_enabled(value: bool) -> void:
	enabled = value
	if _player != null:
		_player.stream_paused = not enabled
		if enabled and not _player.playing and not loading:
			if _player.stream != null:
				_player.play()
				_apply_volume()
			else:
				select_track(track_index)
	_save()
	changed.emit()

func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	_apply_volume()
	_save()
	changed.emit()

func _apply_volume(fade: bool = false) -> void:
	if _player == null:
		return
	if _fade != null and _fade.is_valid():
		_fade.kill()
	var target: float = linear_to_db(maxf(volume, 0.0001))
	if fade:
		_player.volume_db = -60
		_fade = create_tween()
		_fade.tween_property(_player, "volume_db", target, 1.2)
	else:
		_player.volume_db = target

func select_track(index: int) -> void:
	track_index = clampi(index, 0, TRACKS.size() - 1)
	error_text = ""
	_save()
	if _player == null:
		return
	_player.stop()
	_request.cancel_request()
	loading = false
	if _cache.has(track_index):
		_play(_cache[track_index])
		return
	var filename: String = TRACKS[track_index]["id"] + ".ogg"
	if OS.has_feature("web"):
		loading = true
		_requested_index = track_index
		var origin: String = str(JavaScriptBridge.eval("window.location.origin", true))
		var result: int = _request.request(origin + "/music/" + filename)
		if result != OK:
			loading = false
			error_text = "Chưa tải được nhạc. Bạn có thể thử lại."
		changed.emit()
	else:
		var stream = load("res://assets/audio/" + filename)
		if stream == null:
			error_text = "Chưa tải được nhạc. Bạn có thể thử lại."
			changed.emit()
			return
		_cache[track_index] = stream
		_play(stream)

func _downloaded(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	loading = false
	if result != HTTPRequest.RESULT_SUCCESS or status != 200:
		error_text = "Chưa tải được nhạc. Kiểm tra kết nối rồi thử lại."
		changed.emit()
		return
	var stream: AudioStreamOggVorbis = AudioStreamOggVorbis.load_from_buffer(body)
	if stream == null:
		error_text = "Bản nhạc chưa sẵn sàng. Bạn có thể thử lại."
		changed.emit()
		return
	_cache[_requested_index] = stream
	if _requested_index == track_index:
		_play(stream)

func _play(stream: AudioStream) -> void:
	_player.stream = stream
	_player.stream_paused = not enabled
	if enabled:
		_player.play()
		_apply_volume(true)
	changed.emit()

func _notification(what: int) -> void:
	if _player == null:
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_player.stream_paused = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_player.stream_paused = not enabled

func _exit_tree() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	if _request != null:
		_request.cancel_request()
	if _player != null:
		_player.stop()
		_player.stream = null
	_cache.clear()
	if Engine.has_meta("karaoke_music_player") and Engine.get_meta("karaoke_music_player") == self:
		Engine.remove_meta("karaoke_music_player")
