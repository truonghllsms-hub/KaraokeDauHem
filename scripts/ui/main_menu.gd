extends Control
## Màn hình chính.

const UI = preload("res://scripts/ui/ui_kit.gd")
const Music = preload("res://scripts/ui/music_manager.gd")
const MusicSettings = preload("res://scripts/ui/music_settings.gd")
const ReferenceSkin = preload("res://scripts/ui/reference_skin.gd")
const SaveManager = preload("res://scripts/core/save_manager.gd")
const LOAD_META: String = "karaoke_load_save"

const SaveSlots = preload("res://scripts/ui/save_slots.gd")
const DataLoader = preload("res://scripts/core/data_loader.gd")
var _data: Dictionary
var _latest_path: String = ""
var _loading: bool = false
var _progress: ProgressBar
var _new_game: Button
var _confirm_overwrite: bool = false
var _settings_overlay: Control


func _ready() -> void:
	Music.ensure(get_tree())
	_data = DataLoader.load_all()
	_latest_path = SaveManager.latest_path(_data)
	var art: TextureRect = TextureRect.new()
	art.texture = preload("res://assets/topdown/menu_exterior.webp")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(art)
	# Keep art, sign and menu on the same 1024 x 1536 canvas.
	var sign: VBoxContainer = VBoxContainer.new()
	sign.position = Vector2(230, 363)
	sign.size = Vector2(564, 146)
	sign.add_theme_constant_override("separation", -18)
	sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sign)
	for entry in [["KARAOKE", 48], ["ĐẦU HẺM", 68]]:
		var title: Label = UI.label(entry[0], entry[1], Color("#4b5c30"), true)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sign.add_child(title)
	var card: PanelContainer = UI.panel(Color("#fff3da"), UI.BORDER)
	card.position = Vector2(136, 1120)
	card.size = Vector2(752, 360)
	add_child(card)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	card.add_child(column)
	var tagline: Label = UI.label("Đèn đã lên, mở cửa quán thôi!", 27, UI.PURPLE, true)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(tagline)
	_new_game = UI.button("Chơi mới", 29, UI.PURPLE)
	_new_game.custom_minimum_size.y = 72
	_new_game.pressed.connect(_on_new_game)
	column.add_child(_new_game)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	column.add_child(row)
	var resume: Button = UI.button("Tiếp tục", 24)
	resume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resume.custom_minimum_size.y = 62
	resume.disabled = _latest_path == ""
	resume.pressed.connect(func() -> void: _enter_game(_latest_path))
	row.add_child(resume)
	var load_button: Button = UI.button("Tải game", 24, UI.GOLD)
	load_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_button.pressed.connect(_show_loads)
	row.add_child(load_button)
	var settings: Button = UI.button("Cài đặt âm thanh", 23, UI.GOLD)
	settings.pressed.connect(_show_settings)
	column.add_child(settings)
	var note: Label = UI.label("Tự lưu cuối đêm · 3 ô lưu riêng trong lúc chơi", 18, UI.MUTED)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(note)

func _enter_game(path: String = "") -> void:
	if _loading:
		return
	if path != "":
		var saved: Dictionary = SaveManager.read_save(_data, path)
		if not saved["ok"]:
			_show_panel("KHÔNG TẢI ĐƯỢC", UI.label(saved["error"], 23, UI.BAD))
			return
	Engine.set_meta(LOAD_META, path != "")
	Engine.set_meta("karaoke_load_path", path)
	_loading = true
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.12, 0.15, 0.07, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var card: PanelContainer = UI.panel(UI.PANEL, UI.BORDER)
	card.custom_minimum_size = Vector2(640, 220)
	center.add_child(card)
	var column: VBoxContainer = VBoxContainer.new()
	card.add_child(column)
	var title: Label = UI.label("Đang mở cửa quán…", 34, UI.PURPLE, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	_progress = ProgressBar.new()
	_progress.custom_minimum_size = Vector2(0, 24)
	_progress.show_percentage = false
	_progress.add_theme_stylebox_override("background", UI.box(UI.PANEL_DARK, UI.BORDER, 1, 0))
	_progress.add_theme_stylebox_override("fill", UI.box(UI.PURPLE, UI.PURPLE, 0, 0))
	column.add_child(_progress)
	ResourceLoader.load_threaded_request("res://scenes/game.tscn")

func _process(_delta: float) -> void:
	if not _loading:
		return
	var progress: Array = []
	var status: int = ResourceLoader.load_threaded_get_status("res://scenes/game.tscn", progress)
	if not progress.is_empty():
		_progress.value = progress[0] * 100
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		_loading = false
		var scene: PackedScene = ResourceLoader.load_threaded_get("res://scenes/game.tscn")
		get_tree().change_scene_to_packed(scene)

func _show_loads() -> void:
	var slots = SaveSlots.new()
	slots.data = _data
	slots.selected.connect(_enter_game)
	_show_panel("TẢI GAME", slots)

func _show_panel(title_text: String, body: Control) -> void:
	if is_instance_valid(_settings_overlay):
		_settings_overlay.queue_free()
	_settings_overlay = ColorRect.new()
	_settings_overlay.color = Color(0.17, 0.12, 0.07, 0.62)
	_settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_settings_overlay)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_overlay.add_child(center)
	var panel: PanelContainer = UI.panel(UI.PANEL, UI.BORDER)
	panel.custom_minimum_size = Vector2(900, 0)
	center.add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	panel.add_child(column)
	var row: HBoxContainer = HBoxContainer.new()
	var title: Label = UI.label(title_text, 32, UI.PURPLE, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var close: Button = UI.button("Đóng", 22, UI.GOLD)
	close.pressed.connect(func() -> void: _settings_overlay.queue_free())
	row.add_child(close)
	column.add_child(row)
	column.add_child(body)


func _on_new_game() -> void:
	# Đã có bản lưu: hỏi lại một lần vì đêm đầu tiên kết thúc sẽ ghi đè bản lưu cũ.
	if _latest_path != "" and not _confirm_overwrite:
		_confirm_overwrite = true
		_new_game.text = "Bắt đầu ván mới? Bấm thêm lần nữa"
		return
	_enter_game()


func _show_settings() -> void:
	_show_panel("NHẠC NỀN", MusicSettings.new())
