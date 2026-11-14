extends Control
## Màn hình chính.

const UI = preload("res://scripts/ui/ui_kit.gd")
const SaveManager = preload("res://scripts/core/save_manager.gd")
const LOAD_META: String = "karaoke_load_save"

var _new_game: Button
var _confirm_overwrite: bool = false


func _ready() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = UI.BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)

	var sign_panel: PanelContainer = UI.panel(UI.PANEL_DARK, UI.PURPLE)
	column.add_child(sign_panel)
	var sign_box: VBoxContainer = VBoxContainer.new()
	sign_panel.add_child(sign_box)
	var title: Label = UI.label("KARAOKE ĐẦU HẺM", 52, UI.PURPLE, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign_box.add_child(title)
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
	settings.disabled = true
	settings.tooltip_text = "Sẽ có ở Giai đoạn 6."
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
