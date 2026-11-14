extends Control
## Màn hình chính.

const UI = preload("res://scripts/ui/ui_kit.gd")
const Music = preload("res://scripts/ui/music_manager.gd")
const MusicSettings = preload("res://scripts/ui/music_settings.gd")
const ReferenceSkin = preload("res://scripts/ui/reference_skin.gd")
const SaveManager = preload("res://scripts/core/save_manager.gd")
const LOAD_META: String = "karaoke_load_save"

var _new_game: Button
var _confirm_overwrite: bool = false
var _settings_overlay: Control


func _ready() -> void:
	Music.ensure(get_tree())
	var background: ColorRect = ColorRect.new()
	background.color = UI.BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var art: TextureRect = TextureRect.new()
	art.texture = preload("res://assets/topdown/floor1_final.webp")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(art)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.12, 0.16, 0.08, 0.65)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	var card: PanelContainer = UI.panel(UI.PANEL, UI.BORDER)
	card.custom_minimum_size.x = 650
	center.add_child(card)
	card.add_child(column)

	var sign_panel: PanelContainer = UI.panel(UI.PANEL_DARK, UI.PURPLE)
	column.add_child(sign_panel)
	var sign_box: VBoxContainer = VBoxContainer.new()
	sign_panel.add_child(sign_box)
	var brand: TextureRect = TextureRect.new()
	brand.texture = ReferenceSkin.texture(Rect2(0, 0, 220, 92))
	brand.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	brand.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	brand.custom_minimum_size = Vector2(0, 184)
	sign_box.add_child(brand)
	var tagline: Label = UI.label("Phòng lạnh · Loa hay · Trái cây tươi · Giữ xe miễn phí", 18, UI.GOLD)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign_box.add_child(tagline)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	column.add_child(spacer)

	_new_game = UI.button("Chơi mới", 22, UI.PURPLE)
	_new_game.pressed.connect(_on_new_game)
	column.add_child(_new_game)

	var resume: Button = UI.button("Tiếp tục", 22)
	resume.disabled = not SaveManager.has_save()
	resume.tooltip_text = "Tiếp tục từ lần tự lưu gần nhất (cuối đêm)." if not resume.disabled else "Chưa có bản lưu. Game tự lưu sau mỗi lần tổng kết đêm."
	resume.pressed.connect(func() -> void:
		Engine.set_meta(LOAD_META, true)
		get_tree().change_scene_to_file("res://scenes/game.tscn"))
	column.add_child(resume)

	var settings: Button = UI.button("Cài đặt", 22)
	settings.tooltip_text = "Nhạc nền, chọn bài và âm lượng"
	settings.pressed.connect(_show_settings)
	column.add_child(settings)

	var quit_button: Button = UI.button("Thoát", 22)
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	column.add_child(quit_button)

	var note: Label = UI.label("Quán nhỏ đầu hẻm · Một đêm thật vui", 13, UI.MUTED)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(note)


func _on_new_game() -> void:
	# Đã có bản lưu: hỏi lại một lần vì đêm đầu tiên kết thúc sẽ ghi đè bản lưu cũ.
	if SaveManager.has_save() and not _confirm_overwrite:
		_confirm_overwrite = true
		_new_game.text = "Bấm lần nữa: chơi mới, ghi đè bản lưu cũ"
		return
	Engine.set_meta(LOAD_META, false)
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _show_settings() -> void:
	_settings_overlay = ColorRect.new()
	_settings_overlay.color = Color(0.17, 0.12, 0.07, 0.62)
	_settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_settings_overlay)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_overlay.add_child(center)
	var panel: PanelContainer = UI.panel(UI.PANEL, UI.BORDER)
	panel.custom_minimum_size = Vector2(840, 1000)
	center.add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	panel.add_child(column)
	var row: HBoxContainer = HBoxContainer.new()
	var title: Label = UI.label("NHẠC NỀN", 32, UI.PURPLE, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var close: Button = UI.button("Đóng", 22, UI.GOLD)
	close.pressed.connect(func() -> void: _settings_overlay.queue_free())
	row.add_child(close)
	column.add_child(row)
	column.add_child(MusicSettings.new())
