extends Control
## Màn hình kinh doanh. Chỉ hiển thị trạng thái và gửi yêu cầu tới Simulation;
## không tự sửa tiền hay trạng thái phòng.

const DataLoader = preload("res://scripts/core/data_loader.gd")
const Simulation = preload("res://scripts/core/simulation.gd")
const Money = preload("res://scripts/core/money.gd")
const Clock = preload("res://scripts/core/simulation_clock.gd")
const UI = preload("res://scripts/ui/ui_kit.gd")
const ReferenceSkin = preload("res://scripts/ui/reference_skin.gd")
const CharacterArt = preload("res://scripts/ui/character_art.gd")
const VenueView = preload("res://scripts/ui/venue_view.gd")
const Music = preload("res://scripts/ui/music_manager.gd")
const MusicSettings = preload("res://scripts/ui/music_settings.gd")
const SaveManager = preload("res://scripts/core/save_manager.gd")
## Màn hình chính đặt khóa này trên Engine trước khi chuyển cảnh để báo "Tiếp tục" từ bản lưu.
const SaveSlots = preload("res://scripts/ui/save_slots.gd")
const LOAD_META: String = "karaoke_load_save"

const KIND_COLOR: Dictionary = {"info": UI.TEXT, "good": UI.GOOD, "bad": UI.BAD, "money": UI.GOLD}
const LATER_TEXT: String = "Sẽ có ở giai đoạn sau."

var sim

var venue

var _lbl_day: Label
var _lbl_time: Label
var _lbl_money: Label
var _lbl_rep: Label
var _lbl_status: Label
var _btn_pause: Button
var _speed_buttons: Dictionary = {}
var _btn_unlock: Button
var _lbl_bill: Label
var _last_summary: Dictionary = {}
var _lbl_detail: Label
var _price_row: HBoxContainer
var _log: RichTextLabel
var _overlay: Control = null
var _overlay_kind: String = ""
var _map_scroll: ScrollContainer
var _map_stage: Control
var _goal_label: Label
var _task_label: Label
var _notice_label: Label
var _last_notice: String = ""
var _touch_origin: Vector2 = Vector2.ZERO
var _touch_on_map: bool = false
var _touch_scrolling: bool = false
var _reference_frame: Control
var _hud_money: Label
var _hud_rep: Label
var _hud_clock: Label
var _reference_scroll: VScrollBar
var _reference_scroll_picture: TextureRect
var _scroll_used: bool = false
var _last_speed_skin: int = -1
var _last_pause_skin: bool = false
var _rating_button: Button
var _debt_button: Button
var _tutorial_panel: PanelContainer
var _tutorial_label: Label
var _tutorial_key: String = ""
var _tutorial_hidden: Dictionary = {}
var _music
var _music_button: Button
var _help_button: Button



func _ready() -> void:
	_music = Music.ensure(get_tree())
	var background: ColorRect = ColorRect.new()
	background.color = UI.BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var data: Dictionary = DataLoader.load_all()
	if not data["errors"].is_empty():
		_show_data_errors(data["errors"])
		set_process(false)
		return

	var load_notice: String = ""
	var saved_view: Dictionary = {}
	if Engine.has_meta(LOAD_META) and Engine.get_meta(LOAD_META):
		Engine.set_meta(LOAD_META, false)
		var path: String = str(Engine.get_meta("karaoke_load_path", SaveManager.DEFAULT_PATH))
		if path == "": path = SaveManager.DEFAULT_PATH
		var loaded: Dictionary = Simulation.create_from_save(data, path)
		if loaded["ok"]:
			sim = loaded["sim"]
			saved_view = loaded.get("view", {})
			load_notice = loaded["notice"] if loaded["notice"] != "" else "Đã tải bản lưu: đêm %d, số dư %s." % [sim.state.day, Money.format(sim.state.money)]
		else:
			load_notice = loaded["error"] + " Bắt đầu ván mới."
	if sim == null:
		sim = Simulation.new(data, randi())
	# Tự lưu sau mỗi lần tổng kết đêm.
	sim.autosave_path = SaveManager.DEFAULT_PATH
	sim.game_saved.connect(func(_path: String, error: String) -> void:
		if error != "":
			_set_notice("Không lưu được: " + error, "bad"))
	_build_ui()
	venue.restore_view(saved_view)
	sim.message.connect(_on_message)
	sim.night_ended.connect(_on_night_ended)
	sim.bill_paid.connect(_on_bill_paid)
	_on_message("Chào chủ quán! Mục tiêu đêm nay: %s. Bấm \"MỞ CỬA ĐÓN KHÁCH\" để bắt đầu." % sim.goal_text(), "info")
	if load_notice != "":
		_on_message(load_notice, "bad" if load_notice.contains("Bắt đầu ván mới") else "good")
	if sim.state.phase == "SUMMARY" and not sim.last_summary().is_empty():
		_last_summary = sim.last_summary()
		call_deferred("_show_summary")
	_refresh()


func _process(delta: float) -> void:
	sim.advance(delta)
	_refresh()


## Explicit touch panning also supports touch-capable desktop browsers.
## Once a drag starts, suppress the emulated mouse release so a room is not tapped.
func _input(event: InputEvent) -> void:
	if _overlay != null or not is_instance_valid(_map_scroll):
		return
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_scroll_used = true
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_origin = event.position
			_touch_on_map = _map_scroll.get_global_rect().has_point(event.position)
			_touch_scrolling = false
		elif _touch_scrolling:
			get_viewport().set_input_as_handled()
			call_deferred("_finish_touch_pan")
	elif event is InputEventScreenDrag and _touch_on_map:
		if _touch_scrolling or event.position.distance_to(_touch_origin) > 12:
			_touch_scrolling = true
			_scroll_used = true
			_map_scroll.scroll_vertical -= int(event.relative.y)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.device == -1 and _touch_scrolling:
		get_viewport().set_input_as_handled()


func _finish_touch_pan() -> void:
	_touch_on_map = false
	_touch_scrolling = false


func _unhandled_key_input(event: InputEvent) -> void:
	if sim == null or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_ESCAPE:
			if _overlay == null:
				_show_menu()
			elif _overlay_kind == "menu" or _overlay_kind == "ledger":
				_close_overlay()
		KEY_SPACE:
			if _overlay == null:
				sim.clock.toggle_pause()
		KEY_1:
			sim.clock.set_speed(1)
		KEY_2:
			sim.clock.set_speed(2)
		KEY_3:
			sim.clock.set_speed(4)


# ---------------------------------------------------------------- Dựng giao diện

func _build_ui() -> void:
	_reference_frame = Control.new()
	_reference_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_reference_frame)
	_reference_frame.add_child(ReferenceSkin.image(Rect2(0, 0, 1024, 140), Rect2(0, 0, 1024, 140)))
	# All numbers remain actual labels once their value differs from the initial art.
	_hud_money = _hud_value(Rect2(274, 19, 139, 53), 30)
	_hud_rep = _hud_value(Rect2(476, 19, 100, 53), 30)
	_hud_clock = _hud_value(Rect2(640, 19, 161, 53), 29)
	_goal_label = _hud_value(Rect2(120, 94, 784, 44), 28)
	_goal_label.add_theme_stylebox_override("normal", UI.box(Color("#e4e7b7"), Color.TRANSPARENT, 0, 0))
	var logo: Button = ReferenceSkin.hit(Rect2(0, 0, 220, 92), "Menu · Esc")
	logo.pressed.connect(_show_menu)
	_reference_frame.add_child(logo)
	# Backing HUD labels keep the simulation display contract for tests and dialogs.
	var backing_hud: Control = Control.new()
	backing_hud.visible = false
	add_child(backing_hud)
	_lbl_money = UI.label("")
	_lbl_rep = UI.label("")
	_lbl_day = UI.label("")
	_lbl_time = UI.label("")
	_lbl_status = UI.label("")
	for label in [_lbl_money, _lbl_rep, _lbl_day, _lbl_time, _lbl_status]:
		backing_hud.add_child(label)
	_btn_pause = ReferenceSkin.hit(Rect2(799, 17, 49, 56), "Mở cửa / Tạm dừng · Space")
	_btn_pause.pressed.connect(func() -> void:
		if sim.state.phase == "PREP":
			_report(sim.open_doors())
		else:
			sim.clock.toggle_pause())
	_reference_frame.add_child(_btn_pause)
	var x_positions: Array = [860, 911, 960]
	for i in 3:
		var speed: int = [1, 2, 4][i]
		var button: Button = ReferenceSkin.hit(Rect2(x_positions[i], 19, 49, 52), "%dx" % speed)
		button.toggle_mode = true
		button.pressed.connect(func() -> void: sim.clock.set_speed(speed))
		_reference_frame.add_child(button)
		_speed_buttons[speed] = button
	_rating_button = UI.button("", 22, UI.GOLD)
	_rating_button.name = "RatingBadge"
	_rating_button.position = Vector2(772, 149)
	_rating_button.custom_minimum_size = Vector2(236, 44)
	_rating_button.size = Vector2(236, 44)
	_rating_button.icon = preload("res://assets/icons/star.svg")
	_rating_button.add_theme_constant_override("icon_max_width", 25)
	_rating_button.clip_text = true
	_rating_button.z_index = 5
	_rating_button.tooltip_text = "Đánh giá sao của khách (khác với danh tiếng /100). Bấm để xem nhận xét."
	_rating_button.pressed.connect(_show_reviews)
	_debt_button = UI.button("", 20, UI.GOOD)
	_debt_button.name = "DebtBadge"
	_debt_button.position = Vector2(16, 149)
	_debt_button.custom_minimum_size = Vector2(236, 44)
	_debt_button.size = Vector2(236, 44)
	_debt_button.icon = preload("res://assets/icons/bank.svg")
	_debt_button.add_theme_constant_override("icon_max_width", 25)
	_debt_button.clip_text = true
	_debt_button.z_index = 5
	_debt_button.tooltip_text = "Vay ngân hàng để lắp thêm phòng sớm. Bấm để vay hoặc trả nợ."
	# Nút đặc màu để dễ thấy.
	_debt_button.add_theme_font_override("font", UI.BOLD_FONT)
	_debt_button.add_theme_color_override("font_color", Color("#fff6d8"))
	_debt_button.add_theme_color_override("font_hover_color", Color.WHITE)
	_debt_button.add_theme_stylebox_override("normal", UI.box(Color("#6d7d42"), Color("#4b5a2b"), 2, 6))
	_debt_button.add_theme_stylebox_override("hover", UI.box(Color("#7d8f4c"), Color("#4b5a2b"), 2, 6))
	_debt_button.add_theme_stylebox_override("pressed", UI.box(Color("#5b6a36"), Color("#4b5a2b"), 2, 6))
	_debt_button.pressed.connect(_show_loan)
	# Khung hướng dẫn cho người mới, nằm trên thanh điều hướng.
	_tutorial_panel = UI.panel(Color("#fff6d8"), UI.GOLD)
	_tutorial_panel.name = "TutorialPanel"
	_tutorial_panel.position = Vector2(18, 1278)
	_tutorial_panel.size = Vector2(988, 112)
	_tutorial_panel.custom_minimum_size = Vector2(988, 0)
	_tutorial_panel.z_index = 6
	_tutorial_panel.visible = false
	var tutorial_row: HBoxContainer = HBoxContainer.new()
	tutorial_row.add_theme_constant_override("separation", 12)
	_tutorial_panel.add_child(tutorial_row)
	_tutorial_label = UI.label("", 22, UI.TEXT)
	_tutorial_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tutorial_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tutorial_label.custom_minimum_size = Vector2(748, 0)
	tutorial_row.add_child(_tutorial_label)
	var tutorial_icon: TextureRect = TextureRect.new()
	tutorial_icon.texture = preload("res://assets/icons/help.svg")
	tutorial_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tutorial_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tutorial_icon.custom_minimum_size = Vector2(40, 48)
	tutorial_row.move_child(_tutorial_label, 0)
	tutorial_row.add_child(tutorial_icon)
	tutorial_row.move_child(tutorial_icon, 0)
	var tutorial_close: Button = UI.button("Thu gọn", 20, UI.GOLD)
	tutorial_close.custom_minimum_size = Vector2(130, 52)
	tutorial_close.pressed.connect(func() -> void:
		_tutorial_hidden[_tutorial_key] = true
		_tutorial_panel.visible = false)
	tutorial_row.add_child(tutorial_close)
	_map_scroll = ScrollContainer.new()
	_map_scroll.name = "VenueScroll"
	_map_scroll.position = Vector2(0, 140)
	_map_scroll.size = Vector2(1024, 1264)
	_map_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_map_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_map_scroll.follow_focus = false
	_reference_frame.add_child(_map_scroll)
	_map_stage = Control.new()
	_map_stage.custom_minimum_size = VenueView.VIEW_SIZE
	_map_stage.mouse_filter = Control.MOUSE_FILTER_PASS
	_map_scroll.add_child(_map_stage)
	venue = VenueView.new()
	venue.setup(sim)
	sim.staff.visual_delivery = true
	sim.security.visual_chase = true
	venue.report.connect(_report)
	venue.hint.connect(func(text: String) -> void: _set_notice(text, "info"))
	venue.choice_requested.connect(_show_choice)
	venue.next_day_requested.connect(_advance_day)
	venue.inspect_requested.connect(func(_id: String) -> void: _show_venue_panel())
	_map_stage.add_child(venue)
	_reference_scroll = VScrollBar.new()
	_reference_scroll.visible = false
	_reference_frame.add_child(_reference_scroll)
	var backing: Control = _build_side_panel()
	backing.visible = false
	add_child(backing)
	_task_label = UI.label("")
	_notice_label = UI.label("")
	_task_label.visible = false
	_notice_label.visible = false
	add_child(_task_label)
	add_child(_notice_label)
	_reference_frame.add_child(_build_bottom_bar())
	_reference_frame.add_child(_rating_button)
	_reference_frame.add_child(_debt_button)
	_reference_frame.add_child(_tutorial_panel)
	var save_button: Button = UI.button("Lưu", 18, UI.GOLD)
	save_button.position = Vector2(16, 97)
	save_button.size = Vector2(90, 34)
	save_button.icon = preload("res://assets/icons/save.svg")
	save_button.expand_icon = true
	save_button.add_theme_constant_override("icon_max_width", 20)
	for state in ["normal", "hover", "pressed", "focus"]:
		save_button.add_theme_stylebox_override(state, UI.box(Color("#f3e8be"), Color("#cdb87a"), 1, 4))
	save_button.pressed.connect(_show_saves)
	_reference_frame.add_child(save_button)
	_music_button = UI.button("Nhạc", 18, UI.GOLD)
	_music_button.name = "MusicButton"
	_music_button.position = Vector2(928, 97)
	_music_button.custom_minimum_size = Vector2(80, 34)
	_music_button.size = Vector2(80, 34)
	_music_button.icon = preload("res://assets/icons/music.svg")
	_music_button.add_theme_constant_override("icon_max_width", 18)
	_music_button.add_theme_stylebox_override("normal", UI.box(Color("#f3e8be"), Color("#cdb87a"), 1, 4))
	_music_button.tooltip_text = "Nhạc nền · bật/tắt, âm lượng và chọn bài"
	_music_button.pressed.connect(_show_music)
	_reference_frame.add_child(_music_button)
	_help_button = UI.button("Hướng dẫn", 18, UI.GOLD)
	_help_button.name = "TutorialReopen"
	_help_button.position = Vector2(18, 1340)
	_help_button.custom_minimum_size = Vector2(156, 46)
	_help_button.size = Vector2(156, 46)
	_help_button.icon = preload("res://assets/icons/help.svg")
	_help_button.add_theme_constant_override("icon_max_width", 24)
	_help_button.z_index = 6
	_help_button.pressed.connect(func() -> void:
		_tutorial_hidden.erase(_tutorial_key)
		_refresh_tutorial())
	_reference_frame.add_child(_help_button)
	call_deferred("_fit_map")
	call_deferred("_show_starting_rooms")


func _hud_value(at: Rect2, font_size: int) -> Label:
	var result: Label = UI.label("", font_size, Color("#51361e"), true)
	result.position = at.position
	result.size = at.size
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result.add_theme_stylebox_override("normal", UI.box(Color("#ffedc7"), Color.TRANSPARENT, 0, 0))
	result.visible = false
	result.clip_text = true
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reference_frame.add_child(result)
	return result


func _fit_map() -> void:
	if is_instance_valid(venue):
		venue.scale = Vector2.ONE
		_map_stage.custom_minimum_size = VenueView.VIEW_SIZE


func _show_starting_rooms() -> void:
	if is_instance_valid(_map_scroll):
		_map_scroll.scroll_vertical = 0
		_reference_scroll.set_value_no_signal(0)


func scroll_to_lobby() -> void:
	_show_starting_rooms()


func _build_top_bar() -> Control:
	return Control.new()


func _build_side_panel() -> Control:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.custom_minimum_size = Vector2(270, 0)

	var detail_panel: PanelContainer = UI.panel()
	column.add_child(detail_panel)
	var detail_box: VBoxContainer = VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 6)
	detail_panel.add_child(detail_box)
	detail_box.add_child(UI.label("CHI TIẾT", 16, UI.GOLD, true))
	_lbl_detail = UI.label("", 13, UI.TEXT)
	_lbl_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_detail.custom_minimum_size = Vector2(0, 170)
	detail_box.add_child(_lbl_detail)

	_price_row = HBoxContainer.new()
	_price_row.add_theme_constant_override("separation", 6)
	detail_box.add_child(_price_row)
	var step: int = sim.data["balance"]["price_step"]
	var cheaper: Button = UI.button("Giảm giá", 13)
	cheaper.tooltip_text = "Giảm %s mỗi giờ" % Money.format(step)
	cheaper.pressed.connect(func() -> void: _report(sim.change_price(venue.selected_room, -1)))
	var pricier: Button = UI.button("Tăng giá", 13)
	pricier.tooltip_text = "Tăng %s mỗi giờ" % Money.format(step)
	pricier.pressed.connect(func() -> void: _report(sim.change_price(venue.selected_room, 1)))
	_price_row.add_child(cheaper)
	_price_row.add_child(pricier)
	_btn_unlock = UI.button("", 13, UI.GOLD)
	_btn_unlock.tooltip_text = "Thêm một phòng để nhận nhiều khách hơn. Khách cũng sẽ tới đông hơn."
	_btn_unlock.pressed.connect(func() -> void: _report(sim.unlock_room(venue.selected_room)))
	detail_box.add_child(_btn_unlock)

	var bill_panel: PanelContainer = UI.panel(UI.PANEL_DARK, UI.GOLD)
	column.add_child(bill_panel)
	var bill_box: VBoxContainer = VBoxContainer.new()
	bill_panel.add_child(bill_box)
	bill_box.add_child(UI.label("HÓA ĐƠN VỪA THU", 14, UI.GOLD, true))
	_lbl_bill = UI.label("Chưa có nhóm nào thanh toán.", 12, UI.TEXT)
	_lbl_bill.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bill_box.add_child(_lbl_bill)

	var log_panel: PanelContainer = UI.panel()
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(log_panel)
	var log_box: VBoxContainer = VBoxContainer.new()
	log_panel.add_child(log_box)
	log_box.add_child(UI.label("NHẬT KÝ QUÁN", 14, UI.GOLD, true))
	_log = RichTextLabel.new()
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_size_override("normal_font_size", 12)
	log_box.add_child(_log)
	return column


func _build_bottom_bar() -> Control:
	var bar: Control = Control.new()
	bar.position = Vector2(0, 1404)
	bar.size = Vector2(1024, 132)
	bar.add_child(ReferenceSkin.image(Rect2(0, 1404, 1024, 132), Rect2(0, 0, 1024, 132)))
	var entries: Array = [
		["Quán", "shop", _show_venue_panel], ["Nhân sự", "staff", _show_staff],
		["Kho", "stock", _show_stock], ["Nâng cấp", "upgrade", _show_upgrades],
		["Thu chi", "ledger", _show_ledger],
	]
	for i in 5:
		var entry: Array = entries[i]
		var button: Button = ReferenceSkin.hit(Rect2(18 + i * 200, 10, 192, 114), entry[0])
		button.name = "Nav_" + entry[1]
		button.pressed.connect(entry[2])
		bar.add_child(button)
	return bar


func _show_staff() -> void:
	_show_overlay("ledger", "NHÂN SỰ", "Nhân viên phục vụ, giao lưu và bảo vệ được quản lý tại đây. Khu sofa ở sảnh là chỗ nhân viên ngồi chờ.", [
		["Nhân viên quán", _show_waiters],
		["Giao lưu âm nhạc", _show_lancan],
		["Đóng", _close_overlay],
	])


func _show_waiters() -> void:
	var balance: Dictionary = sim.data["balance"]
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 20)
	content.add_child(UI.section("Đang làm tại quán", "Tạp vụ dọn phòng · Phục vụ mang món, đổi micro · Lễ tân đón khách"))
	var roster: GridContainer = GridContainer.new()
	roster.columns = 2
	roster.add_theme_constant_override("h_separation", 14)
	roster.add_theme_constant_override("v_separation", 14)
	for member in sim.state.staff:
		roster.add_child(_staff_card(member, true))
	if sim.state.guard_hired:
		roster.add_child(_guard_card())
	if roster.get_child_count() == 0:
		content.add_child(UI.label("Bạn đang tự điều hành quán. Chưa tuyển nhân viên.", 22, UI.MUTED))
	content.add_child(roster)
	content.add_child(UI.section("Tuyển thêm người", "Phí tuyển %s · Tối đa %d người mỗi vai trò" % [Money.format(balance["staff_hire_cost"]), balance["staff_max_per_role"]]))
	var candidates: GridContainer = GridContainer.new()
	candidates.columns = 2
	candidates.add_theme_constant_override("h_separation", 14)
	candidates.add_theme_constant_override("v_separation", 14)
	for candidate in sim.staff.candidates():
		candidates.add_child(_staff_card(candidate, false))
	if not sim.state.guard_hired:
		candidates.add_child(_guard_card())
	content.add_child(candidates)
	_show_overlay("ledger", "NHÂN VIÊN QUÁN", "Nhân viên chờ 2–3 phút để bạn ra tay trước, rồi tự làm. Mệt thì làm chậm và xin nghỉ.", [["Đóng", _close_overlay]], content)

func _staff_card(member: Dictionary, hired: bool) -> Control:
	var accent: Color = {"janitor": UI.GOLD, "waiter": UI.INFO, "receptionist": UI.GOOD}.get(member["role"], UI.GOOD)
	var card: PanelContainer = UI.panel(Color("#fff9e9"), Color("#cfba93"))
	card.custom_minimum_size = Vector2(360, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	card.add_child(column)
	var heading: HBoxContainer = HBoxContainer.new()
	var portrait: TextureRect = TextureRect.new()
	portrait.texture = CharacterArt.texture(CharacterArt.staff_sprite(member))
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(84, 118)
	heading.add_child(portrait)
	var identity: VBoxContainer = VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_child(UI.label(sim.staff.role_name(member["role"]), 19, accent, true))
	identity.add_child(UI.label(member["name"], 27, UI.TEXT, true))
	identity.add_child(UI.label("%s/đêm" % Money.format(member["wage"]), 19, UI.MUTED))
	heading.add_child(identity)
	column.add_child(heading)
	if hired:
		var task: Dictionary = member["task"]
		var doing: String = "Đang rảnh" if task.is_empty() else VenueView.STAFF_BUBBLE.get(task["kind"], "Đang làm việc")
		if task.get("room_id", "") != "":
			doing += " · " + sim.rooms.get_room(task["room_id"])["name"]
		var state: Label = UI.label(doing, 20, accent, true)
		state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(state)
		column.add_child(UI.label("Năng lượng %d/100 · Đã làm %d việc" % [member["energy"], member["tasks_done"]], 18, UI.MUTED))
		var energy: ProgressBar = UI.progress(accent)
		energy.max_value = 100
		energy.value = member["energy"]
		column.add_child(energy)
	else:
		var about: Label = UI.label(member["about"], 19, UI.MUTED)
		about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(about)
		column.add_child(UI.label("Tốc độ %d%%" % member["speed"], 19, accent, true))
		var staff_id: String = member["id"]
		var hire: Button = UI.button("Tuyển %s %s" % [sim.staff.role_name(member["role"]).to_lower(), member["name"]], 20, accent)
		hire.custom_minimum_size.y = 56
		hire.clip_text = true
		hire.disabled = not sim.economy.can_afford(sim.data["balance"]["staff_hire_cost"])
		hire.pressed.connect(func() -> void:
			var reason: String = sim.hire_staff(staff_id)
			_show_waiters()
			_report(reason))
		column.add_child(hire)
	return card


func _show_reviews() -> void:
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	var metrics: HBoxContainer = HBoxContainer.new()
	metrics.add_theme_constant_override("separation", 14)
	metrics.add_child(UI.metric("Đánh giá của khách", sim.rating_text().replace("★", "").strip_edges(), UI.GOLD))
	metrics.add_child(UI.metric("Lượng khách đến", "%d%%" % sim.customers.arrival_percent(), UI.GOOD))
	content.add_child(metrics)
	var reviews: Array = sim.recent_reviews(12)
	if reviews.is_empty():
		content.add_child(UI.section("Chưa có nhận xét", "Khách sẽ để lại đánh giá sau khi thanh toán. Phục vụ chu đáo để có thêm khách ghé quán."))
	for review in reviews:
		var card: PanelContainer = UI.panel(Color("#fff9e9"), Color("#d8c39d"))
		var column: VBoxContainer = VBoxContainer.new()
		column.add_theme_constant_override("separation", 8)
		column.add_child(UI.label(review["who"], 25, UI.TEXT, true))
		var stars: HBoxContainer = HBoxContainer.new()
		for i in 5:
			var star: TextureRect = TextureRect.new()
			star.texture = preload("res://assets/icons/star.svg")
			star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			star.custom_minimum_size = Vector2(25, 25)
			star.modulate.a = 1.0 if i < review["stars"] else 0.22
			stars.add_child(star)
		stars.add_child(UI.label("  Đêm %d · %s" % [review["day"], review.get("badge", "")], 18, UI.MUTED))
		column.add_child(stars)
		var quote: Label = UI.label(review["text"], 23, UI.TEXT)
		quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(quote)
		card.add_child(column)
		content.add_child(card)
	_show_overlay("ledger", "ĐÁNH GIÁ TRÊN BẢN ĐỒ", "Điểm sao phản ánh trải nghiệm của khách. Mốc 3,0 sao tương ứng lượng khách bình thường.", [["Đóng", _close_overlay]], content)


func _show_venue_panel() -> void:
	_refresh_detail()
	var buttons: Array = []
	if sim.state.phase == "PREP":
		buttons.append(["MỞ CỬA ĐÓN KHÁCH", func() -> void:
			_close_overlay()
			_report(sim.open_doors())])
	if _btn_unlock.visible and venue.selected_room != "":
		var info: Dictionary = sim.room_info(venue.selected_room)
		var loan: Dictionary = sim.loan_info()
		if info["missing_money"] > 0 and loan["can_change"] and loan["available"] >= info["missing_money"]:
			var borrow: int = mini(loan["available"], ((info["missing_money"] + 999999) / 1000000) * 1000000)
			buttons.append(["Vay %s để lắp" % Money.format(borrow), func() -> void:
				var reason: String = sim.take_loan(borrow)
				_show_venue_panel()
				_report(reason)])
	if _btn_unlock.visible:
		buttons.append([_btn_unlock.text, func() -> void:
			var reason: String = sim.equip_room(venue.selected_room)
			_show_venue_panel()
			_report(reason)])
	if _price_row.visible:
		buttons.append(["Giảm giá giờ", func() -> void:
			_report(sim.change_price(venue.selected_room, -1))
			_show_venue_panel()])
		buttons.append(["Tăng giá giờ", func() -> void:
			_report(sim.change_price(venue.selected_room, 1))
			_show_venue_panel()])
	buttons.append(["Nhật ký", _show_journal])
	buttons.append(["Đóng", _close_overlay])
	_show_overlay("ledger", "QUẢN LÝ QUÁN", _lbl_detail.text + "\n\nHÓA ĐƠN VỪA THU\n" + _lbl_bill.text, buttons)


func _show_journal() -> void:
	var lines: Array = []
	for entry in sim.state.messages:
		lines.append("%s  %s" % [Clock.time_text(entry["minute"]), entry["text"]])
	_show_overlay("ledger", "NHẬT KÝ QUÁN", "\n".join(lines), [["Đóng", _close_overlay]])


# ---------------------------------------------------------------- Cập nhật hiển thị

func _refresh() -> void:
	var state = sim.state
	_lbl_day.text = "Đêm %d" % state.day
	_lbl_time.text = Clock.time_text(sim.clock.minute)
	_lbl_money.text = Money.format(state.money)
	_lbl_rep.text = "★ %d/100" % state.reputation

	match state.phase:
		"PREP":
			_lbl_status.text = "Chưa mở cửa"
		"SUMMARY":
			_lbl_status.text = "Đã đóng cửa"
		_:
			_lbl_status.text = "TẠM DỪNG" if sim.clock.paused else "Đang mở cửa · %dx" % sim.clock.speed
	_btn_pause.tooltip_text = "Mở cửa" if state.phase == "PREP" else ("Tiếp tục" if sim.clock.paused else "Tạm dừng")
	for speed in _speed_buttons:
		_speed_buttons[speed].set_pressed_no_signal(sim.clock.speed == speed)

	if _last_speed_skin != sim.clock.speed:
		_last_speed_skin = sim.clock.speed
		for value in _speed_buttons:
			var control: Button = _speed_buttons[value]
			control.text = "" if sim.clock.speed == 1 else "%dx" % value
			control.add_theme_font_override("font", UI.BOLD_FONT)
			control.add_theme_font_size_override("font_size", 28)
			control.add_theme_color_override("font_color", Color("#fff0c9") if value == sim.clock.speed else UI.TEXT)
			for style_name in ["normal", "hover", "pressed"]:
				control.add_theme_stylebox_override(style_name, StyleBoxEmpty.new() if sim.clock.speed == 1 else UI.box(UI.PURPLE if value == sim.clock.speed else Color("#ffe6b5"), UI.BORDER, 2, 0))
	if _last_pause_skin != sim.clock.paused and state.phase != "PREP":
		_last_pause_skin = sim.clock.paused
		_btn_pause.text = "▶" if sim.clock.paused else ""
		_btn_pause.add_theme_color_override("font_color", Color("#fff0c9"))
		_btn_pause.add_theme_font_size_override("font_size", 26)
		_btn_pause.add_theme_stylebox_override("normal", UI.box(UI.PURPLE, UI.BORDER, 2, 0) if sim.clock.paused else StyleBoxEmpty.new())

	_goal_label.text = "Phục vụ %d nhóm khách · %d/%d" % [state.night["goal_served"], state.night["served"], state.night["goal_served"]]
	_goal_label.visible = state.night["goal_served"] != 4 or state.night["served"] != 0
	_hud_money.visible = state.money != 15000000
	_fit_hud_text(_hud_money, Money.format(state.money), 30)
	_hud_rep.visible = state.reputation != 40
	_fit_hud_text(_hud_rep, "%d/100" % state.reputation, 30)
	_hud_clock.visible = state.day != 1 or sim.clock.minute != 0
	_fit_hud_text(_hud_clock, "Đêm %d · %s" % [state.day, Clock.time_text(sim.clock.minute)], 29)
	var rating: String = sim.rating_text()
	_rating_button.text = rating.replace("★", "").strip_edges().replace(" đánh giá", "") if rating.begins_with("★") else "Chưa có đánh giá"
	_rating_button.tooltip_text = "Đánh giá sao của khách (khác danh tiếng /100). Khách đến: %d%% bình thường. Bấm để xem nhận xét." % sim.customers.arrival_percent()
	_debt_button.get_theme_stylebox("normal").bg_color = Color("#b0473c") if state.money < 0 else Color("#6d7d42")
	if state.money < 0:
		_debt_button.text = "SỐ DƯ ÂM! Vay gỡ"
	elif state.loan_principal > 0:
		_debt_button.text = "Nợ %s" % Money.format(state.loan_principal)
	else:
		_debt_button.text = "Vay ngân hàng"
	_refresh_tutorial()
	_task_label.text = "Việc đang chờ: %d  ·  Khách đợi: %d  ·  Bấm Tầng 1 / Tầng 2 để đổi tầng" % [venue.task_count(), sim.customers.waiting_groups().size()]
	_refresh_detail()


func _fit_hud_text(label: Label, text: String, preferred_size: int) -> void:
	label.text = text
	var font: Font = label.get_theme_font("font")
	var fitted: int = preferred_size
	while fitted > 18 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x > label.size.x - 4:
		fitted -= 1
	label.add_theme_font_size_override("font_size", fitted)


func _refresh_detail() -> void:
	var text: String = "MỤC TIÊU ĐÊM NAY\n%s.\n\nCách chơi:\n• Bấm nhóm khách ở chỗ chờ, rồi bấm phòng viền xanh.\n• Phòng hiện nhãn màu là khách đang cần: bấm vào để xử lý.\n• Bấm phòng bẩn để dọn.\n• Chủ quán làm từng việc một, hãy chọn việc nào trước." % sim.goal_text()
	var show_price: bool = false
	var show_unlock: bool = false
	var group = sim.customers.get_group(venue.selected_group) if venue.selected_group != 0 else null
	var host = sim.hosts.get_host(venue.selected_host) if venue.selected_host != "" else null
	if group != null:
		text = "NHÓM %s · %d người\nMuốn hát %d phút · %s\nNgân sách: khoảng %s/giờ\nCòn chờ được: %d phút\nHài lòng: %d/100\n\nĐặc điểm: %s\n\nPhòng viền xanh là xếp được; trên phòng có tiền dự kiến và cảnh báo nếu đắt hơn ngân sách của nhóm." % [
			group["type_name"].to_upper(), group["size"], group["planned_minutes"], sim.customers.music_name(group["music"]),
			Money.format(group["budget_per_hour"]), maxi(0, group["patience"] - group["wait_minutes"]), group["satisfaction"], group["trait"],
		]
	elif host != null:
		text = "%s · Lan can\n%s\nGiao tiếp %d/5 · Song ca %d/5\nGu nhạc: %s (hợp gu khách thì thêm điểm)\nNăng lượng: %d/100\nTip đêm nay: %s\nDịch vụ: %s cho %d phút, khách tự gọi mới tính.\n\nBấm vào phòng đang gọi Lan can để cử vào." % [
			host["name"].to_upper(), host["personality"], host["talk"], host["duet"], sim.customers.music_name(host["music"]),
			host["energy"], Money.format(host["tips_tonight"]), Money.format(sim.data["balance"]["lancan_fee"]), sim.data["balance"]["lancan_minutes"],
		]
	elif venue.selected_room != "":
		var room = sim.rooms.get_room(venue.selected_room)
		var info: Dictionary = sim.room_info(room["id"])
		text = "%s · %s · %s\nSức chứa %d người · %s/giờ\nÂm thanh cấp %d · cách âm cấp %d" % [room["name"].to_upper(), info["tier_name"], info["status_text"] if room["state"] == "LOCKED" else VenueView.STATE_TEXT[room["state"]], room["capacity"], Money.format(room["price_per_hour"]), room["sound"], room["soundproof"]]
		if room["state"] == "LOCKED":
			text += "\n\nTHIẾT BỊ SẼ LẮP\n• " + "\n• ".join(info["equipment"])
			text += "\n\nLỢI ÍCH\n• " + "\n• ".join(info["perks"])
			text += "\n\nChi phí lắp: %s" % Money.format(info["equip_cost"])
			if info["upkeep_per_night"] > 0:
				text += " · vận hành thêm %s/đêm" % Money.format(info["upkeep_per_night"])
			if info["missing_money"] > 0:
				text += "\nCòn thiếu %s." % Money.format(info["missing_money"])
			if info["locked_reason"] != "":
				text += "\n" + info["locked_reason"]
			elif sim.state.phase != "PREP":
				text += "\nChỉ lắp được trước giờ mở cửa."
		var occupant = sim.customers.get_group(room["group_id"]) if room["group_id"] != 0 else null
		if occupant != null:
			text += "\n\nKhách: %s · %d người · %s\nĐặc điểm: %s\nHài lòng: %d/100\n\nTạm tính:\n  Phòng: %s" % [
				occupant["type_name"], occupant["size"], sim.customers.music_name(occupant["music"]), occupant["trait"], occupant["satisfaction"],
				Money.format(Money.room_fee(room["session_price"], sim.clock.minute - room["session_start"])),
			]
			for item in occupant["bill_items"]:
				text += "\n  %s: %s" % [item["note"], Money.format(item["amount"])]
			if sim.hosts.can_request(occupant) and (occupant["wants_host"] or occupant["host_request"] != "NONE"):
				var preference: String = {"male": "nam", "female": "nữ", "any": "giao lưu"}[occupant["host_gender"]]
				text += "\n\nGọi %d nhân viên %s · đã cử %d · đang phục vụ %d\nPhí %s/người/%d phút." % [occupant["host_requested_count"], preference, occupant["host_assigned_count"], room["host_ids"].size(), Money.format(sim.data["balance"]["lancan_fee"]), sim.data["balance"]["lancan_minutes"]]
			if occupant["discount_percent"] > 0:
				text += "\n  Giảm %d%% tiền phòng (xin lỗi khách)" % occupant["discount_percent"]
		show_unlock = room["state"] == "LOCKED"
		show_price = not show_unlock and sim.state.phase == "PREP"
		if not show_unlock and sim.state.phase != "PREP" and occupant == null:
			text += "\n(Chỉ chỉnh giá được trước khi mở cửa.)"
		if show_unlock:
			_btn_unlock.text = sim.room_info(room["id"])["equip_button_text"]
			_btn_unlock.disabled = not sim.room_info(room["id"])["can_equip_now"]
	_lbl_detail.text = text
	_price_row.visible = show_price
	_btn_unlock.visible = show_unlock


# ---------------------------------------------------------------- Xử lý thao tác

## Hiển thị lý do khi một thao tác bị từ chối.
func _report(reason: String) -> void:
	if reason != "":
		_set_notice(reason, "bad")


func _set_notice(text: String, kind: String) -> void:
	venue.set_toast(text, KIND_COLOR.get(kind, UI.TEXT))
	_last_notice = text
	if is_instance_valid(_notice_label):
		_notice_label.text = text
		_notice_label.add_theme_color_override("font_color", KIND_COLOR.get(kind, UI.TEXT))


func _on_message(text: String, kind: String) -> void:
	_set_notice(text, kind)
	_log.push_color(KIND_COLOR.get(kind, UI.TEXT))
	_log.add_text("%s  %s\n" % [Clock.time_text(sim.clock.minute), text])
	_log.pop()


## Hóa đơn ngắn mỗi khi một nhóm thanh toán: phòng, món, dịch vụ, giảm giá.
func _on_bill_paid(bill: Dictionary) -> void:
	var lines: Array = [
		"%s · %s" % [bill["group_name"], bill["room_name"]],
		"Phòng %d phút × %s/giờ: %s" % [bill["minutes"], Money.format(bill["price_per_hour"]), Money.format(bill["room_fee"])],
	]
	for item in bill["items"]:
		lines.append("%s: %s" % [item["note"], Money.format(item["amount"])])
	if bill["discount"] > 0:
		lines.append("Giảm %d%% tiền phòng: -%s" % [bill["discount_percent"], Money.format(bill["discount"])])
	lines.append("TỔNG: %s (làm tròn 1.000đ)" % Money.format(bill["total"]))
	lines.append("%s · hài lòng %d/100 · \"%s\"" % ["★".repeat(bill.get("stars", 0)) + "☆".repeat(5 - bill.get("stars", 0)), bill["satisfaction"], bill["comment"]])
	_lbl_bill.text = "\n".join(lines)


func _on_night_ended(summary: Dictionary) -> void:
	_last_summary = summary
	_show_summary()


func _show_summary() -> void:
	var summary: Dictionary = _last_summary
	var lines: Array = [
		"Mục tiêu: %s — %s" % [summary["goal"], "ĐẠT (+%d danh tiếng)" % sim.data["balance"]["goal_reputation_bonus"] if summary["goal_met"] else "chưa đạt"],
		"Phục vụ %d nhóm · bỏ về %d nhóm · hài lòng trung bình %d/100 · danh tiếng %d/100 (%+d)" % [summary["served"], summary["unserved"], summary["avg_satisfaction"], summary["reputation"], summary["reputation_change"]],
		"",
		"THU   Phòng +%s · Đồ ăn uống +%s · Lan can +%s · Chia tip +%s" % [Money.format(summary["room_revenue"]), Money.format(summary["order_revenue"]), Money.format(summary["lancan_revenue"]), Money.format(summary.get("tip_share", 0))],
		"CHI   Nhập hàng -%s · Lương -%s · Điện nước mặt bằng -%s" % [Money.format(summary["stock_cost"]), Money.format(summary["wages"]), Money.format(summary["operating"])],
	]
	if summary["discounts"] > 0 or summary["compensation"] > 0:
		lines.append("          Giảm giá xin lỗi -%s · Đền xe -%s (%d vụ mất xe)" % [Money.format(summary["discounts"]), Money.format(summary["compensation"]), summary["thefts"]])
	if summary.get("loan_interest", 0) > 0 or summary.get("loan_principal_paid", 0) > 0:
		lines.append("NỢ    Lãi -%s · Trả gốc -%s · Dư nợ còn %s · Đêm tới trả %s" % [Money.format(summary["loan_interest"]), Money.format(summary["loan_principal_paid"]), Money.format(summary["loan_balance"]), Money.format(summary["next_loan_payment"])])
	if summary.get("thieves_caught", 0) > 0 or summary["thefts"] > 0:
		lines.append("TRỘM  Bắt được %d · Mất xe %d" % [summary.get("thieves_caught", 0), summary["thefts"]])
	lines.append("LỢI NHUẬN ĐÊM NAY: %s      Số dư: %s" % [Money.format(summary["profit"]), Money.format(sim.state.money)])
	if summary.get("bankrupt", false):
		lines.append("")
		lines.append("QUÁN ĐÃ PHÁ SẢN: số dư âm %d đêm liền. Ngân hàng thu hồi quán." % sim.data["balance"]["bankrupt_after_negative_nights"])
	elif summary.get("negative_nights", 0) > 0:
		lines.append("")
		lines.append("CẢNH BÁO NỢ: số dư đang âm. Nếu hết đêm mai vẫn âm, quán sẽ phá sản. Có thể vay thêm ở Thu chi hoặc cắt chi phí.")
	if summary.has("night_rating_text"):
		lines.append("")
		var before: int = summary["rating_before_x10"]
		var after: int = summary["rating_after_x10"]
		lines.append("ĐÁNH GIÁ SAO   Đêm nay: %s" % summary["night_rating_text"])
		lines.append("               Cả quán: %s%s" % [summary["rating_text"], "" if before == 0 else " (trước đó %d,%d)" % [before / 10, before % 10]])
		lines.append("               Khách đến đêm sau: %d%% so với bình thường" % sim.customers.arrival_percent())
	if not summary["comments"].is_empty():
		lines.append("")
		lines.append("KHÁCH NÓI GÌ")
		for comment in summary["comments"]:
			lines.append("  %s %s: \"%s\"" % ["★".repeat(comment.get("stars", 0)), comment["who"], comment["text"]])
	lines.append("")
	lines.append("Đã tự lưu tiến trình.")
	lines.append("CHỌN MỘT MÓN ĐẦU TƯ CHO ĐÊM MAI (không bắt buộc):")
	if summary.get("bankrupt", false) or sim.state.bankrupt:
		_show_overlay("summary", "PHÁ SẢN · ĐÊM %d" % summary["day"], "\n".join(lines), [
			["Chơi lại từ đầu", func() -> void:
				for path in [SaveManager.DEFAULT_PATH, SaveManager.backup_path(SaveManager.DEFAULT_PATH)]:
					if FileAccess.file_exists(path):
						DirAccess.remove_absolute(path)
				get_tree().reload_current_scene()],
			["Về màn hình chính", func() -> void: get_tree().change_scene_to_file("res://scenes/main_menu.tscn")],
		])
		return
	_show_overlay("summary", "TỔNG KẾT ĐÊM %d" % summary["day"], "\n".join(lines), [
		["Vay ngân hàng", _show_loan],
		["Sang đêm tiếp theo", _advance_day],
	], _upgrade_list(_show_summary))


## Danh sách nâng cấp dùng chung cho bảng tổng kết và nút Nâng cấp.
func _upgrade_list(reopen: Callable) -> Control:
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	for upgrade in sim.data["upgrades"]:
		var upgrade_id: String = upgrade["id"]
		var level: int = sim.service.upgrade_level(upgrade_id)
		var card: PanelContainer = UI.panel(UI.PANEL, UI.BORDER)
		card.custom_minimum_size = Vector2(240, 0)
		var box: VBoxContainer = VBoxContainer.new()
		card.add_child(box)
		box.add_child(UI.label("%s (cấp %d/%d)" % [upgrade["name"], level, upgrade["max_level"]], 14, UI.GOLD, true))
		var effect: Label = UI.label(upgrade["effect"], 12, UI.TEXT)
		effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		effect.custom_minimum_size = Vector2(216, 36)
		box.add_child(effect)
		var buy: Button = UI.button("Đã tối đa" if level >= upgrade["max_level"] else "Mua · %s" % Money.format(upgrade["cost"]), 13, UI.GOLD)
		buy.disabled = level >= upgrade["max_level"] or not sim.economy.can_afford(upgrade["cost"])
		buy.pressed.connect(func() -> void:
			var reason: String = sim.buy_upgrade(upgrade_id)
			reopen.call()
			_report(reason))
		box.add_child(buy)
		grid.add_child(card)
	return grid


func _show_upgrades() -> void:
	_show_overlay("ledger", "NÂNG CẤP", "Số dư: %s. Hiệu quả ghi rõ trên từng món." % Money.format(sim.state.money), [["Đóng", _close_overlay]], _upgrade_list(_show_upgrades))


func _show_stock() -> void:
	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 6)
	for header in ["Mặt hàng", "Tồn kho", "Nhập / Bán", ""]:
		grid.add_child(UI.label(header, 13, UI.MUTED, true))
	for product in sim.data["products"]:
		var product_id: String = product["id"]
		var stock: int = sim.state.stock[product_id]
		grid.add_child(UI.label(product["name"].capitalize() + " (" + product["unit"] + ")", 14, UI.TEXT))
		grid.add_child(UI.label("%d %s" % [stock, product["unit"]], 14, UI.BAD if stock == 0 else (UI.GOLD if stock < 5 else UI.GOOD), true))
		grid.add_child(UI.label("%s / %s" % [Money.format(product["cost"]), Money.format(product["price"])], 13, UI.TEXT))
		var cost: int = product["cost"] * product["pack_size"]
		var buy: Button = UI.button("Nhập %d %s · %s" % [product["pack_size"], product["unit"], Money.format(cost)], 13, UI.GOLD)
		buy.disabled = not sim.economy.can_afford(cost)
		buy.pressed.connect(func() -> void:
			var reason: String = sim.buy_stock(product_id)
			_show_stock()
			_report(reason))
		grid.add_child(buy)
	_show_overlay("ledger", "KHO HÀNG", "Khách gọi món nào mà kho hết thì mất hài lòng. Hàng được giữ chỗ ngay khi khách gọi; khách hủy thì trả lại kho.\nSố dư: %s." % Money.format(sim.state.money), [["Đóng", _close_overlay]], grid)


func _show_loan() -> void:
	var loan: Dictionary = sim.loan_info()
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	var metrics: GridContainer = GridContainer.new()
	metrics.columns = 2
	metrics.add_theme_constant_override("h_separation", 14)
	metrics.add_theme_constant_override("v_separation", 14)
	metrics.add_child(UI.metric("Số dư hiện tại", Money.format(sim.state.money), UI.GOOD if sim.state.money >= 0 else UI.BAD))
	metrics.add_child(UI.metric("Dư nợ", Money.format(loan["principal"]), UI.GOLD))
	metrics.add_child(UI.metric("Hạn mức", Money.format(loan["limit"]), UI.INFO))
	metrics.add_child(UI.metric("Còn có thể vay", Money.format(loan["available"]), UI.GOOD))
	content.add_child(metrics)
	var lines: Array = [
		"Lãi %d,%d%% mỗi đêm · trả tối thiểu %d%% tiền gốc." % [loan["rate_permille"] / 10, loan["rate_permille"] % 10, loan["min_principal_percent"]],
		"Ngân hàng tự thu cuối đêm. Lắp thêm phòng sẽ tăng hạn mức theo 50% giá trị thiết bị.",
	]
	if loan["principal"] > 0:
		lines.append("Cuối đêm tới sẽ trả: %s (lãi %s + gốc %s)." % [Money.format(loan["next_payment"]["total"]), Money.format(loan["next_payment"]["interest"]), Money.format(loan["next_payment"]["principal"])])
	lines.append("")
	lines.append("⚠ Số dư âm sau quyết toán %d đêm liền là PHÁ SẢN. Đừng vay quá sức trả." % sim.data["balance"]["bankrupt_after_negative_nights"])
	if not loan["can_change"]:
		lines.append("(Đang mở cửa: chỉ vay hoặc trả nợ được trước giờ mở cửa hoặc sau tổng kết.)")
	var buttons: Array = []
	if loan["can_change"]:
		for amount in [loan["step"], loan["step"] * 2]:
			var value: int = mini(amount, loan["available"])
			if value > 0 and not buttons.any(func(b: Array) -> bool: return b[0] == "Vay %s" % Money.format(value)):
				buttons.append(["Vay %s" % Money.format(value), func() -> void:
					var reason: String = sim.take_loan(value)
					_show_loan()
					_report(reason)])
		if loan["principal"] > 0:
			var repay_amount: int = mini(loan["principal"], maxi(0, sim.state.money))
			if repay_amount > 0:
				buttons.append(["Trả nợ %s" % Money.format(repay_amount), func() -> void:
					var reason: String = sim.repay_loan(repay_amount)
					_show_loan()
					_report(reason)])
	# Mở từ bảng tổng kết thì đóng xong quay lại tổng kết (để còn nút sang đêm sau).
	buttons.append(["Đóng", func() -> void:
		if sim.state.phase == "SUMMARY" and not _last_summary.is_empty():
			_show_summary()
		else:
			_close_overlay()])
	var note: Label = UI.label("\n\n".join(lines), 22, UI.TEXT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(note)
	_show_overlay("ledger", "VAY NGÂN HÀNG", "Vay để mở rộng quán, trả dần bằng tiền lời mỗi đêm.", buttons, content)


## Hướng dẫn từng bước cho hai đêm tập và lần đầu gặp trộm. Mỗi mẹo hiện đúng lúc, bấm "Đã hiểu" để ẩn.
func _tutorial_step() -> Array:
	var state = sim.state
	if state.bankrupt or sim.security.is_active():
		return []
	var waiting: Array = sim.customers.waiting_groups()
	var any_order: bool = false
	var any_mic: bool = false
	var any_dirty: bool = false
	var any_choice: bool = false
	var any_locked_floor1: bool = false
	for room in state.rooms:
		if not room["request"].is_empty():
			any_order = any_order or room["request"]["kind"] == "ORDER"
			any_mic = any_mic or room["request"]["kind"] == "MIC"
			any_choice = any_choice or room["request"]["kind"] in ["HOT", "EXTEND"]
		any_dirty = any_dirty or room["state"] == "DIRTY"
		any_locked_floor1 = any_locked_floor1 or (room["floor"] == 1 and room["state"] == "LOCKED")
	if state.day == 1:
		match state.phase:
			"PREP":
				return ["d1_open", "Đêm tập 1 · Chào chủ quán! Hai đêm đầu khách còn thưa để bạn làm quen. Bấm nút ▶ MỞ CỬA ĐÓN KHÁCH ở sảnh để bắt đầu."]
			"OPEN":
				if venue.selected_group != 0:
					return ["d1_room", "Phòng viền xanh là xếp được (có ghi giá dự kiến). Bấm vào phòng đó, chủ quán sẽ dẫn khách vào."]
				if not waiting.is_empty():
					return ["d1_group", "Khách đang chờ ở sảnh (thanh trên đầu là độ kiên nhẫn). Bấm vào nhóm khách để chọn."]
				if any_order:
					return ["d1_order", "Phòng có nhãn vàng là khách gọi món. Bấm vào phòng: chủ quán ra tủ lạnh lấy món rồi mang tới. Giao nhanh thì khách vui hơn."]
				if any_mic:
					return ["d1_mic", "Khách gọi đổi micro trong bong bóng thoại. Bấm vào phòng để đổi micro, để lâu khách sẽ bực và quán phải giảm giá."]
				if any_choice:
					return ["d1_choice", "Phòng có yêu cầu đặc biệt (nóng, xin hát thêm). Bấm vào phòng để chọn cách xử lý."]
				if any_dirty:
					return ["d1_dirty", "Khách về để lại phòng bẩn. Bấm vào phòng để tự dọn. Khi muốn có người phụ, bạn có thể vào Nhân sự để tuyển."]
				if state.night["served"] == 0:
					return ["d1_wait", "Khách sẽ tới cổng sau ít phút. Bấm 2x hoặc 4x ở góc trên để tua nhanh."]
				return ["d1_rating", "Mỗi nhóm trả tiền xong sẽ để lại đánh giá sao (góc phải). Nhiều sao thì khách tới đông hơn."]
	if state.day == 2 and state.phase == "PREP":
		if any_locked_floor1:
			return ["d2_expand", "Đêm tập 2 · Muốn đón nhiều khách hơn? Bấm một phòng \"Chưa lắp thiết bị\" để lắp. Thiếu tiền thì bấm \"Vay ngân hàng\" ở góc trái. Nhớ vào Kho nhập thêm hàng."]
		return ["d2_staff", "Đêm tập 2 · Vào Nhân sự để thuê phục vụ (mang món) hoặc lễ tân (tự xếp khách vào phòng)."]
	if state.money < 0:
		return ["negative", "Số dư đang âm! Nếu hết đêm sau vẫn âm, quán phá sản. Bấm nút đỏ ở góc trái để vay gỡ, hoặc cắt bớt chi phí."]
	return []


func _refresh_tutorial() -> void:
	var step: Array = _tutorial_step()
	_help_button.visible = not step.is_empty() and _tutorial_hidden.has(step[0]) and _overlay == null
	if step.is_empty() or _tutorial_hidden.has(step[0]) or _overlay != null:
		_tutorial_panel.visible = false
		return
	_tutorial_key = step[0]
	_tutorial_label.text = step[1]
	_tutorial_panel.position.y = 214
	_tutorial_panel.visible = true


func _show_guard() -> void:
	_show_waiters()

func _guard_card() -> Control:
	var card: PanelContainer = UI.panel(Color("#fff9e9"), UI.BORDER)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	card.add_child(column)
	var row: HBoxContainer = HBoxContainer.new()
	var portrait: TextureRect = TextureRect.new()
	portrait.texture = CharacterArt.texture("guard")
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(92, 118)
	row.add_child(portrait)
	var details: VBoxContainer = VBoxContainer.new()
	details.add_child(UI.label("Bảo vệ · Chú Sáu", 24, UI.PURPLE, true))
	details.add_child(UI.label("Trông xe ngoài quán", 20, UI.TEXT))
	details.add_child(UI.label(Money.format(sim.data["balance"]["guard_wage"]) + "/đêm", 20, UI.MUTED))
	row.add_child(details)
	column.add_child(row)
	var hired: bool = sim.state.guard_hired
	var action: Button = UI.button("Cho nghỉ" if hired else "Thuê bảo vệ", 22)
	action.pressed.connect(func() -> void:
		_report(sim.set_guard(not hired))
		_show_waiters())
	column.add_child(action)
	return card

func _advance_day() -> void:
	var error: String = sim.next_day()
	if error != "":
		_report(error)
		return
	_close_overlay()
	_last_summary = {}
	venue.begin_day()
	venue.set_floor(1)
	venue.advance_actors(0)
	_refresh()
	sim.save_game(SaveManager.DEFAULT_PATH, venue.save_view())
	_on_message("Đêm %d: chuẩn bị mở cửa." % sim.state.day, "info")


func _show_choice(room_id: String) -> void:
	var room = sim.rooms.get_room(room_id)
	if room == null or room["request"].is_empty():
		return
	var balance: Dictionary = sim.data["balance"]
	var group = sim.customers.get_group(room["group_id"])
	var answer: Callable = func(choice: String) -> void:
		_close_overlay()
		_report(sim.answer_request(room_id, choice))
	if room["request"]["kind"] == "HOT":
		_show_overlay("choice", "%s: \"PHÒNG NÓNG QUÁ EM ƠI!\"" % room["name"].to_upper(),
			"Nhóm %s đang đổ mồ hôi.\n\n• Tăng điều hòa: tốn %s tiền điện, +%d hài lòng.\n• Xin khách thông cảm: không tốn tiền, -%d hài lòng." % [group["type_name"], Money.format(balance["ac_cost"]), balance["ac_bonus"], balance["hot_penalty"]],
			[["Tăng điều hòa", answer.bind("ac")], ["Xin khách thông cảm", answer.bind("ignore")]])
	else:
		var waiting: int = sim.customers.waiting_groups().size()
		var extra: int = Money.room_fee(room["session_price"], balance["extend_minutes"])
		_show_overlay("choice", "%s: \"CHO HÁT THÊM %d PHÚT NHA?\"" % [room["name"].to_upper(), balance["extend_minutes"]],
			"Nhóm %s đang hát hay.\n\n• Đồng ý: thu thêm khoảng %s, +%d hài lòng, nhưng phòng bận thêm %d phút.\n• Từ chối khéo: -%d hài lòng, phòng trống đúng giờ.\n\nĐang có %d nhóm chờ ngoài sân." % [group["type_name"], Money.format(extra), balance["extend_bonus"], balance["extend_minutes"], balance["extend_decline_penalty"], waiting],
			[["Đồng ý cho hát thêm", answer.bind("accept")], ["Từ chối khéo", answer.bind("decline")]])


func _show_ledger() -> void:
	var lines: Array = []
	var ledger: Array = sim.state.ledger
	for i in range(maxi(0, ledger.size() - 10), ledger.size()):
		var entry: Dictionary = ledger[i]
		var sign_text: String = "+" if entry["amount"] >= 0 else "-"
		lines.append("Đêm %d %s   %s%s   %s" % [entry["day"], Clock.time_text(entry["minute"]), sign_text, Money.format(absi(entry["amount"])), entry["note"]])
	lines.append("")
	lines.append("Số dư hiện tại: %s" % Money.format(sim.state.money))
	var loan: Dictionary = sim.loan_info()
	lines.append("")
	lines.append("VAY NGÂN HÀNG")
	lines.append("Dư nợ: %s · hạn mức %s (còn vay được %s)" % [Money.format(loan["principal"]), Money.format(loan["limit"]), Money.format(loan["available"])])
	lines.append("Lãi %d,%d%%/đêm trên dư nợ; cuối mỗi đêm tự trả lãi và %d%% gốc. Lắp thêm phòng thì hạn mức tăng." % [loan["rate_permille"] / 10, loan["rate_permille"] % 10, loan["min_principal_percent"]])
	if loan["principal"] > 0:
		lines.append("Cuối đêm tới sẽ trả: %s (lãi %s + gốc %s)." % [Money.format(loan["next_payment"]["total"]), Money.format(loan["next_payment"]["interest"]), Money.format(loan["next_payment"]["principal"])])
	lines.append("Cảnh báo: số dư âm sau quyết toán %d đêm liền là phá sản." % sim.data["balance"]["bankrupt_after_negative_nights"])
	if not loan["can_change"]:
		lines.append("(Chỉ vay hoặc trả nợ được trước giờ mở cửa hoặc sau tổng kết.)")
	var buttons: Array = []
	if loan["can_change"]:
		var step_amount: int = mini(loan["step"], loan["available"])
		if step_amount > 0:
			buttons.append(["Vay %s" % Money.format(step_amount), func() -> void:
				var reason: String = sim.take_loan(step_amount)
				_show_ledger()
				_report(reason)])
		if loan["principal"] > 0:
			var repay_amount: int = mini(loan["principal"], maxi(0, sim.state.money))
			if repay_amount > 0:
				buttons.append(["Trả nợ %s" % Money.format(repay_amount), func() -> void:
					var reason: String = sim.repay_loan(repay_amount)
					_show_ledger()
					_report(reason)])
	buttons.append(["Đóng", _close_overlay])
	_show_overlay("ledger", "THU CHI & VAY", "\n".join(lines), buttons)


func _show_lancan() -> void:
	var balance: Dictionary = sim.data["balance"]
	var slots_left: int = balance["lancan_max_staff"] - sim.state.hosts.size()
	var locked_reason: String = sim.lancan_lock_reason()
	var intro: String = "Giao lưu âm nhạc, song ca và hoạt náo. Phí %s/người/%d phút, cộng riêng từng người vào hóa đơn; tip chia đôi giữa nhân viên và quán; chọn người hợp gu nhạc của khách thì dễ được tip hơn. Nhóm gọi bao nhiêu người sẽ hiện trên phòng. Hội nam thường gọi nữ, đôi khi gọi nam; hội nữ gọi nam. Cặp đôi và gia đình không gọi.\nĐang làm %d/%d vị trí · Phí tuyển %s/người." % [
		Money.format(balance["lancan_fee"]), balance["lancan_minutes"], sim.state.hosts.size(), balance["lancan_max_staff"], Money.format(balance["lancan_hire_cost"]),
	]
	if locked_reason != "":
		intro = "CHƯA MỞ DỊCH VỤ: " + locked_reason + "\n\n" + intro
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for def in sim.data["hosts"]:
		var host_id: String = def["id"]
		var hired = sim.hosts.get_host(host_id)
		var card: PanelContainer = UI.panel(UI.PANEL, UI.GOLD if hired != null else UI.BORDER)
		card.custom_minimum_size = Vector2(320, 0)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var box: VBoxContainer = VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		card.add_child(box)
		var portrait: TextureRect = TextureRect.new()
		portrait.texture = CharacterArt.texture(def["sprite"])
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.custom_minimum_size = Vector2(0, 184)
		box.add_child(portrait)
		var name_label: Label = UI.label(def["name"] + (" · Nam" if def["gender"] == "male" else " · Nữ"), 24, UI.PINK, true)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(name_label)
		var about: Label = UI.label(def["personality"], 18, UI.MUTED)
		about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		about.custom_minimum_size = Vector2(150, 32)
		box.add_child(about)
		var stats: Label = UI.label("Giao tiếp %d · Song ca %d\n%s · %s/đêm" % [def["talk"], def["duet"], sim.customers.music_name(def["music"]), Money.format(def["wage"])], 18, UI.TEXT)
		stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(stats)
		if hired != null:
			var working: Label = UI.label("ĐANG LÀM · tip nhận %s" % Money.format(hired["tips_total"]), 18, UI.GOLD, true)
			working.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			working.custom_minimum_size = Vector2(0, 30)
			working.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			box.add_child(working)
		else:
			var hire: Button = UI.button("Tuyển", 22, UI.PINK)
			hire.custom_minimum_size = Vector2(0, 48)
			hire.disabled = locked_reason != "" or slots_left <= 0 or not sim.economy.can_afford(balance["lancan_hire_cost"])
			hire.tooltip_text = locked_reason if locked_reason != "" else ("Hết vị trí." if slots_left <= 0 else "Phí tuyển %s." % Money.format(balance["lancan_hire_cost"]))
			hire.pressed.connect(func() -> void:
				var reason: String = sim.hire_host(host_id)
				_show_lancan()
				_report(reason))
			box.add_child(hire)
		grid.add_child(card)
	_show_overlay("ledger", "NHÂN VIÊN GIAO LƯU", intro, [["Đóng", _close_overlay]], grid)


func _show_menu() -> void:
	_show_overlay("menu", "QUÁN ĐANG TẠM DỪNG", "Lưu tiến trình vào một trong 3 ô riêng để quay lại đúng ca đang chơi. Game vẫn tự lưu sau tổng kết đêm.", [
		["Chơi tiếp", _close_overlay],
		["Lưu game", _show_saves],
		["Tải game", _show_loads],
		["Nhạc nền & âm lượng", _show_music],
		["Về màn hình chính", _confirm_exit],
	])

func _show_saves() -> void:
	var slots = SaveSlots.new()
	slots.data = sim.data
	slots.saving = true
	slots.selected.connect(func(path: String) -> void:
		var error: String = sim.save_game(path, venue.save_view())
		if error == "":
			_show_overlay("menu", "ĐÃ LƯU GAME", "Đêm %d · %s\nBạn có thể tiếp tục từ mục Tải game ở màn hình ngoài quán." % [sim.state.day, Clock.time_text(sim.clock.minute)], [["Chơi tiếp", _close_overlay], ["Về màn hình chính", func() -> void: get_tree().change_scene_to_file("res://scenes/main_menu.tscn")]])
		else:
			_show_overlay("menu", "CHƯA LƯU ĐƯỢC", error, [["Quay lại", _show_saves]]))
	_show_overlay("menu", "LƯU GAME", "Chọn một ô lưu. Ô đã có dữ liệu sẽ yêu cầu bấm thêm lần nữa để ghi đè.", [["Quay lại", _show_menu]], slots)

func _show_loads() -> void:
	var slots = SaveSlots.new()
	slots.data = sim.data
	slots.selected.connect(func(path: String) -> void:
		_show_overlay("menu", "TẢI BẢN LƯU NÀY?", "Tiến trình chưa lưu trong ca hiện tại sẽ được thay bằng bản đã chọn.", [["Tải game", func() -> void:
			Engine.set_meta(LOAD_META, true)
			Engine.set_meta("karaoke_load_path", path)
			get_tree().reload_current_scene()], ["Quay lại", _show_loads]]))
	_show_overlay("menu", "TẢI GAME", "Chọn bản tự lưu hoặc một ô đã lưu thủ công.", [["Quay lại", _show_menu]], slots)

func _confirm_exit() -> void:
	_show_overlay("menu", "VỀ MÀN HÌNH CHÍNH?", "Bạn muốn lưu ca đang chơi trước khi ra ngoài quán?", [["Lưu game", _show_saves], ["Về, không lưu", func() -> void: get_tree().change_scene_to_file("res://scenes/main_menu.tscn")], ["Chơi tiếp", _close_overlay]])


## Cửa sổ nổi. Khi mở, đồng hồ tự tạm dừng; khi đóng, chạy lại đúng tốc độ trước đó.
func _show_music() -> void:
	_show_overlay("menu", "NHẠC NỀN", "Một chút nhạc nhẹ cho ca làm ở đầu hẻm.", [["Đóng", _close_overlay]], MusicSettings.new())

func _show_overlay(kind: String, title: String, body: String, buttons: Array, extra: Control = null) -> void:
	_close_overlay()
	sim.clock.push_modal()
	_overlay_kind = kind
	_overlay = ColorRect.new()
	_overlay.color = Color(0.17, 0.12, 0.07, 0.58)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.z_index = 50
	add_child(_overlay)
	var frame: CenterContainer = CenterContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(frame)
	var panel: PanelContainer = UI.panel(Color("#fff3da"), UI.BORDER)
	var width: float = minf(900, get_viewport_rect().size.x - 64)
	var estimate: float = 300 + maxf(body.length() / 55.0, body.count("\n") + 1) * 31 + ceilf(buttons.size() / 2.0) * 76
	var height: float = minf(1260, get_viewport_rect().size.y - 100) if extra != null else clampf(estimate, 460, minf(1260, get_viewport_rect().size.y - 100))
	panel.custom_minimum_size = Vector2(width, height)
	frame.add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	panel.add_child(column)
	var header: HBoxContainer = HBoxContainer.new()
	var title_label: Label = UI.label(title, 32, UI.PURPLE, true)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.clip_text = true
	header.add_child(title_label)
	var close_action: Callable = _close_overlay
	for entry in buttons:
		if entry[0] == "Đóng":
			close_action = entry[1]
	var close: Button = UI.button("Đóng", 21, UI.BORDER)
	close.custom_minimum_size = Vector2(105, 52)
	close.pressed.connect(close_action)
	header.add_child(close)
	column.add_child(header)
	var line: HSeparator = HSeparator.new()
	line.add_theme_stylebox_override("separator", UI.box(Color("#dbc6a0"), Color.TRANSPARENT, 0, 0))
	column.add_child(line)
	var scroller: ScrollContainer = ScrollContainer.new()
	scroller.name = "DialogScroll"
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroller)
	var content: VBoxContainer = VBoxContainer.new()
	content.custom_minimum_size.x = width - 44
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 22)
	scroller.add_child(content)
	if body != "":
		var body_label: Label = UI.label(body, 23, UI.TEXT)
		body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(body_label)
	if extra != null:
		content.add_child(extra)
	var actions: GridContainer = GridContainer.new()
	actions.columns = 2 if buttons.size() > 2 else 1
	actions.add_theme_constant_override("h_separation", 14)
	actions.add_theme_constant_override("v_separation", 14)
	for entry in buttons:
		if entry[0] == "Đóng":
			continue
		var button: Button = UI.button(entry[0], 22, UI.GOLD)
		button.custom_minimum_size = Vector2((width - 62) / 2 if actions.columns == 2 else width - 44, 62)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.tooltip_text = entry[0]
		button.pressed.connect(entry[1])
		actions.add_child(button)
	column.add_child(actions)
	_fit_dialog.call_deferred(panel, content, actions)


func _fit_dialog(panel: PanelContainer, content: VBoxContainer, actions: Control) -> void:
	await get_tree().process_frame
	if not is_instance_valid(panel) or not is_instance_valid(content):
		return
	panel.custom_minimum_size.y = clampf(content.get_combined_minimum_size().y + actions.get_combined_minimum_size().y + 150, 460, minf(1260, get_viewport_rect().size.y - 100))
	panel.reset_size()


func _close_overlay() -> void:
	if _overlay == null:
		return
	_overlay.queue_free()
	_overlay = null
	_overlay_kind = ""
	sim.clock.pop_modal()


func _show_data_errors(errors: Array) -> void:
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column: VBoxContainer = VBoxContainer.new()
	center.add_child(column)
	column.add_child(UI.label("Không đọc được dữ liệu game", 24, UI.BAD, true))
	column.add_child(UI.label("\n".join(errors), 16, UI.TEXT))
	var back: Button = UI.button("Về màn hình chính", 18)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	column.add_child(back)
