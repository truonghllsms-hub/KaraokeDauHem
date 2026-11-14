extends VBoxContainer
## Shared save list for the title screen and in-game menu.
signal selected(path: String)
const UI = preload("res://scripts/ui/ui_kit.gd")
const SaveManager = preload("res://scripts/core/save_manager.gd")
const Money = preload("res://scripts/core/money.gd")
const Clock = preload("res://scripts/core/simulation_clock.gd")
var data: Dictionary
var saving: bool = false
var _confirm_path: String = ""
func _ready() -> void:
	add_theme_constant_override("separation", 16)
	if not saving:
		_add_slot(SaveManager.DEFAULT_PATH, "Tự lưu cuối đêm")
	for i in SaveManager.MANUAL_PATHS.size():
		_add_slot(SaveManager.MANUAL_PATHS[i], "Ô lưu %d" % (i + 1))
	var note: Label = UI.label("Bản lưu nằm trên trình duyệt và thiết bị này. Mỗi ô giữ một tiến trình riêng.", 19, UI.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(note)
func _add_slot(path: String, title: String) -> void:
	var saved: Dictionary = SaveManager.read_save(data, path)
	var card: PanelContainer = UI.panel(Color("#fff9e9"), UI.BORDER)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	card.add_child(row)
	var text: VBoxContainer = VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(UI.label(title, 26, UI.PURPLE, true))
	var details: String = "Chưa có bản lưu"
	if saved["ok"]:
		var snapshot: Dictionary = saved["snapshot"]
		var state: Dictionary = snapshot["state"]
		var phase: String = {"PREP": "Chuẩn bị", "OPEN": "Đang mở cửa", "SUMMARY": "Tổng kết"}.get(state["phase"], "")
		var minute: int = int(snapshot.get("clock", {}).get("minute", 360 if state["phase"] == "SUMMARY" else 0))
		details = "Đêm %d · %s · %s\n%s · %s" % [state["day"], Clock.time_text(minute), phase, Money.format(state["money"]), str(snapshot.get("saved_at", "")).replace("T", " ")]
	elif SaveManager.has_save(path):
		details = "Bản lưu chưa đọc được. " + saved["error"]
	var description: Label = UI.label(details, 20, UI.TEXT)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(description)
	var action: Button = UI.button("Lưu vào đây" if saving else "Tải game", 22)
	action.name = "Slot" + str(SaveManager.MANUAL_PATHS.find(path) + 1)
	action.custom_minimum_size = Vector2(180, 64)
	action.disabled = not saving and not saved["ok"]
	action.pressed.connect(func() -> void:
		if saving and SaveManager.has_save(path) and _confirm_path != path:
			_confirm_path = path
			action.text = "Ghi đè ô này?"
			return
		selected.emit(path))
	row.add_child(action)
	add_child(card)
