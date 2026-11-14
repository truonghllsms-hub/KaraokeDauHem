extends VBoxContainer
const UI = preload("res://scripts/ui/ui_kit.gd")
const Music = preload("res://scripts/ui/music_manager.gd")
var music
var _toggle: CheckButton
var _volume: HSlider
var _percent: Label
var _tracks: OptionButton
var _status: Label
var _retry: Button
func _ready() -> void:
	music = Music.ensure(get_tree())
	add_theme_constant_override("separation", 20)
	_toggle = CheckButton.new()
	_toggle.text = "Bật nhạc nền"
	_toggle.custom_minimum_size.y = 60
	_toggle.add_theme_font_size_override("font_size", 26)
	_toggle.add_theme_color_override("font_color", UI.TEXT)
	_toggle.add_theme_color_override("font_hover_color", UI.PURPLE)
	_toggle.add_theme_color_override("font_pressed_color", UI.PURPLE)
	_toggle.add_theme_color_override("font_focus_color", UI.TEXT)
	_toggle.toggled.connect(func(value: bool) -> void: music.set_enabled(value))
	add_child(_toggle)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_child(UI.label("Âm lượng", 23, UI.TEXT, true))
	_percent = UI.label("", 23, UI.MUTED)
	_percent.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_percent)
	add_child(row)
	_volume = HSlider.new()
	_volume.name = "MusicVolume"
	_volume.min_value = 0
	_volume.max_value = 100
	_volume.step = 1
	_volume.custom_minimum_size = Vector2(0, 52)
	_volume.value_changed.connect(func(value: float) -> void: music.set_volume(value / 100.0))
	add_child(_volume)
	add_child(UI.label("Chọn bản nhạc", 23, UI.TEXT, true))
	_tracks = OptionButton.new()
	_tracks.name = "MusicTracks"
	_tracks.custom_minimum_size.y = 62
	_tracks.add_theme_font_size_override("font_size", 23)
	_tracks.add_theme_color_override("font_color", UI.TEXT)
	_tracks.add_theme_color_override("font_hover_color", UI.TEXT)
	_tracks.add_theme_color_override("font_pressed_color", UI.TEXT)
	for state in ["normal", "hover", "pressed", "focus"]:
		_tracks.add_theme_stylebox_override(state, UI.box(UI.PANEL_DARK, UI.BORDER, 2, 8))
	var popup: PopupMenu = _tracks.get_popup()
	popup.add_theme_stylebox_override("panel", UI.box(UI.PANEL, UI.BORDER, 2, 8))
	popup.add_theme_color_override("font_color", UI.TEXT)
	popup.add_theme_color_override("font_hover_color", UI.PURPLE)
	popup.add_theme_font_size_override("font_size", 23)
	for track in Music.TRACKS:
		_tracks.add_item(track["title"] + " · " + track["mood"])
	_tracks.item_selected.connect(func(index: int) -> void: music.select_track(index))
	add_child(_tracks)
	_status = UI.label("", 20, UI.MUTED)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	_retry = UI.button("Thử tải lại", 22, UI.INFO)
	_retry.pressed.connect(func() -> void: music.select_track(music.track_index))
	add_child(_retry)
	var credits: Label = UI.label("Nhạc: Kevin MacLeod · incompetech.com\nGiấy phép Creative Commons Attribution 4.0.\nĐã chuyển định dạng và cân âm lượng.", 18, UI.MUTED)
	credits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(credits)
	var links: HFlowContainer = HFlowContainer.new()
	links.add_theme_constant_override("h_separation", 24)
	for entry in [["Nguồn bản đang chọn", "source"], ["Giấy phép CC BY 4.0", "license"]]:
		var link: LinkButton = LinkButton.new()
		link.text = entry[0]
		link.add_theme_font_size_override("font_size", 18)
		link.add_theme_color_override("font_color", UI.PURPLE)
		link.add_theme_color_override("font_hover_color", UI.TEXT)
		var destination: String = entry[1]
		link.pressed.connect(func() -> void:
			OS.shell_open("https://incompetech.com/music/royalty-free/index.html?isrc=" + Music.TRACKS[music.track_index]["isrc"] if destination == "source" else "https://creativecommons.org/licenses/by/4.0/"))
		links.add_child(link)
	add_child(links)
	music.changed.connect(_sync)
	_sync()
func _sync() -> void:
	_toggle.set_pressed_no_signal(music.enabled)
	_volume.set_value_no_signal(music.volume * 100)
	_percent.text = "%d%%" % roundi(music.volume * 100)
	_tracks.select(music.track_index)
	_status.text = music.error_text if music.error_text != "" else ("Đang tải nhạc…" if music.loading else ("Các bản nhạc tự chuyển, âm lượng giữ riêng với game." if music.enabled else "Nhạc đang tắt. Lựa chọn của bạn đã được lưu."))
	_retry.visible = music.error_text != ""
