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



func _ready() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = UI.BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var data: Dictionary = DataLoader.load_all()
	if not data["errors"].is_empty():
		_show_data_errors(data["errors"])
		set_process(false)
		return

	var game_seed: int = randi()
	sim = Simulation.new(data, game_seed)
	_build_ui()
	sim.message.connect(_on_message)
	sim.night_ended.connect(_on_night_ended)
	sim.bill_paid.connect(_on_bill_paid)
	_on_message("Chào chủ quán! Mục tiêu đêm nay: %s. Bấm \"MỞ CỬA ĐÓN KHÁCH\" để bắt đầu." % sim.goal_text(), "info")
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
	venue.report.connect(_report)
	venue.hint.connect(func(text: String) -> void: _set_notice(text, "info"))
	venue.choice_requested.connect(_show_choice)
	venue.inspect_requested.connect(func(_id: String) -> void: _show_venue_panel())
	_map_stage.add_child(venue)
	# Fixed right-edge scroll decoration comes from the same reference atlas.
	_reference_scroll_picture = ReferenceSkin.image(Rect2(984, 140, 40, 1264), Rect2(984, 140, 40, 1264))
	_reference_frame.add_child(_reference_scroll_picture)
	_reference_scroll = VScrollBar.new()
	_reference_scroll.position = Vector2(987, 174)
	_reference_scroll.size = Vector2(34, 790)
	_reference_scroll.custom_minimum_size.x = 34
	_reference_scroll.max_value = VenueView.VIEW_SIZE.y - 1264
	_reference_scroll.page = 0
	var track: StyleBoxFlat = UI.box(Color("#f6e4b5"), UI.TEXT, 2, 2)
	var handle: StyleBoxFlat = UI.box(UI.PURPLE, UI.TEXT, 2, 2)
	handle.content_margin_top = 48
	handle.content_margin_bottom = 48
	_reference_scroll.add_theme_stylebox_override("scroll", track)
	_reference_scroll.add_theme_stylebox_override("grabber", handle)
	_reference_scroll.add_theme_stylebox_override("grabber_highlight", handle)
	_reference_scroll.add_theme_stylebox_override("grabber_pressed", handle)
	_reference_scroll.modulate.a = 0.0
	_reference_scroll.value_changed.connect(func(value: float) -> void:
		_scroll_used = true
		_map_scroll.scroll_vertical = int(value))
	_reference_frame.add_child(_reference_scroll)
	_map_scroll.get_v_scroll_bar().value_changed.connect(func(value: float) -> void:
		_reference_scroll.set_value_no_signal(value)
		if _scroll_used:
			_reference_scroll.modulate.a = 1.0)
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
		_map_scroll.scroll_vertical = int(VenueView.ROOM_ROWS[2])
		_reference_scroll.set_value_no_signal(VenueView.ROOM_ROWS[2])


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
	_show_overlay("ledger", "NHÂN SỰ", "Nhân viên giao lưu và bảo vệ được quản lý tại đây. Khu sofa ở sảnh là chỗ nhân viên ngồi chờ.", [
		["Giao lưu âm nhạc", _show_lancan],
		["Bảo vệ", _show_guard],
		["Đóng", _close_overlay],
	])


func _show_venue_panel() -> void:
	_refresh_detail()
	var buttons: Array = []
	if sim.state.phase == "PREP":
		buttons.append(["MỞ CỬA ĐÓN KHÁCH", func() -> void:
			_close_overlay()
			_report(sim.open_doors())])
	if _btn_unlock.visible:
		buttons.append([_btn_unlock.text, func() -> void:
			var reason: String = sim.unlock_room(venue.selected_room)
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
	_task_label.text = "Việc đang chờ: %d  ·  Khách đợi: %d  ·  Cuộn lên để xem các phòng phía trên" % [venue.task_count(), sim.customers.waiting_groups().size()]
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
		text = "%s %s\nSức chứa %d người · %s/giờ\nÂm thanh cấp %d" % [room["name"].to_upper(), VenueView.STATE_TEXT[room["state"]], room["capacity"], Money.format(room["price_per_hour"]), room["sound"]]
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
			_btn_unlock.text = "Mở phòng (%s)" % Money.format(room["unlock_cost"])
			_btn_unlock.disabled = not sim.economy.can_afford(room["unlock_cost"])
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
	lines.append("Hài lòng %d/100 · \"%s\"" % [bill["satisfaction"], bill["comment"]])
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
		"THU   Phòng +%s · Đồ ăn uống +%s · Lan can +%s" % [Money.format(summary["room_revenue"]), Money.format(summary["order_revenue"]), Money.format(summary["lancan_revenue"])],
		"CHI   Nhập hàng -%s · Lương -%s · Điện nước mặt bằng -%s" % [Money.format(summary["stock_cost"]), Money.format(summary["wages"]), Money.format(summary["operating"])],
	]
	if summary["discounts"] > 0 or summary["compensation"] > 0:
		lines.append("          Giảm giá xin lỗi -%s · Đền xe -%s (%d vụ mất xe)" % [Money.format(summary["discounts"]), Money.format(summary["compensation"]), summary["thefts"]])
	lines.append("LỢI NHUẬN ĐÊM NAY: %s      Số dư: %s" % [Money.format(summary["profit"]), Money.format(sim.state.money)])
	if not summary["comments"].is_empty():
		lines.append("")
		lines.append("KHÁCH NÓI GÌ")
		for comment in summary["comments"]:
			lines.append("  %s (%d/100): \"%s\"" % [comment["who"], comment["satisfaction"], comment["text"]])
	if summary["day"] + 1 == sim.data["balance"]["theft_start_day"] and not sim.state.guard_hired:
		lines.append("")
		lines.append("Hàng xóm nhắn: dạo này khu mình hay mất xe. Từ đêm mai nên thuê bảo vệ (nút Bảo vệ).")
	lines.append("")
	lines.append("CHỌN MỘT MÓN ĐẦU TƯ CHO ĐÊM MAI (không bắt buộc):")
	_show_overlay("summary", "TỔNG KẾT ĐÊM %d" % summary["day"], "\n".join(lines), [
		["Sang đêm tiếp theo", func() -> void:
			_close_overlay()
			_report(sim.next_day())
			_on_message("Đêm %d: chuẩn bị mở cửa. Mục tiêu: %s." % [sim.state.day, sim.goal_text()], "info")],
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


func _show_guard() -> void:
	var balance: Dictionary = sim.data["balance"]
	var hired: bool = sim.state.guard_hired
	var lines: Array = [
		"Khách gửi xe ngoài sân. %s" % ("Từ đêm %d trở đi khu này có trộm xe." % balance["theft_start_day"] if not sim.theft_risk_active() else "Khu này đang có trộm xe."),
		"• Không có bảo vệ: mỗi nhóm ra về có khoảng %d%% nguy cơ mất xe." % (balance["theft_chance_permille"] / 10),
		"• Có bảo vệ: nguy cơ còn dưới 1%.",
		"• Mỗi vụ mất xe: quán đền %s, -%d danh tiếng, khách hết hài lòng." % [Money.format(balance["theft_compensation"]), balance["theft_reputation_penalty"]],
		"• Lương bảo vệ: %s/đêm, đêm nào có trực là trả đêm đó." % Money.format(balance["guard_wage"]),
		"",
		"Hiện tại: %s" % ("ĐANG CÓ bảo vệ trông xe." if hired else "CHƯA thuê bảo vệ."),
	]
	_show_overlay("ledger", "BẢO VỆ SÂN XE", "\n".join(lines), [
		["Cho nghỉ từ đêm sau" if hired else "Thuê bảo vệ", func() -> void:
			sim.set_guard(not hired)
			_show_guard()],
		["Đóng", _close_overlay],
	])


## Yêu cầu cần người chơi quyết định: phòng nóng, xin hát thêm.
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
	for i in range(maxi(0, ledger.size() - 12), ledger.size()):
		var entry: Dictionary = ledger[i]
		var sign_text: String = "+" if entry["amount"] >= 0 else "-"
		lines.append("Đêm %d %s   %s%s   %s" % [entry["day"], Clock.time_text(entry["minute"]), sign_text, Money.format(absi(entry["amount"])), entry["note"]])
	lines.append("")
	lines.append("Số dư hiện tại: %s" % Money.format(sim.state.money))
	_show_overlay("ledger", "SỔ THU CHI (12 giao dịch gần nhất)", "\n".join(lines), [["Đóng", _close_overlay]])


func _show_lancan() -> void:
	var balance: Dictionary = sim.data["balance"]
	var slots_left: int = balance["lancan_max_staff"] - sim.state.hosts.size()
	var intro: String = "Giao lưu âm nhạc, song ca và hoạt náo. Phí %s/người/%d phút, cộng riêng từng người vào hóa đơn; tip thuộc nhân viên. Nhóm gọi bao nhiêu người sẽ hiện trên phòng. Hội nam thường gọi nữ, đôi khi gọi nam; hội nữ gọi nam. Cặp đôi và gia đình không gọi.\nĐang làm %d/%d vị trí · Phí tuyển %s/người." % [
		Money.format(balance["lancan_fee"]), balance["lancan_minutes"], sim.state.hosts.size(), balance["lancan_max_staff"], Money.format(balance["lancan_hire_cost"]),
	]
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
			var working: Label = UI.label("ĐANG LÀM · tip %s" % Money.format(hired["tips_total"]), 18, UI.GOLD, true)
			working.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			working.custom_minimum_size = Vector2(0, 30)
			working.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			box.add_child(working)
		else:
			var hire: Button = UI.button("Tuyển", 22, UI.PINK)
			hire.custom_minimum_size = Vector2(0, 48)
			hire.disabled = slots_left <= 0 or not sim.economy.can_afford(balance["lancan_hire_cost"])
			hire.tooltip_text = "Hết vị trí." if slots_left <= 0 else "Phí tuyển %s." % Money.format(balance["lancan_hire_cost"])
			hire.pressed.connect(func() -> void:
				var reason: String = sim.hire_host(host_id)
				_show_lancan()
				_report(reason))
			box.add_child(hire)
		grid.add_child(card)
	_show_overlay("ledger", "NHÂN VIÊN GIAO LƯU", intro, [["Đóng", _close_overlay]], grid)


func _show_menu() -> void:
	_show_overlay("menu", "MENU", "Game đang tạm dừng.\nChưa có tính năng lưu: về màn hình chính sẽ mất tiến trình hiện tại.\n\nPhím tắt: Space tạm dừng · 1/2/3 đổi tốc độ · Esc mở menu.", [
		["Chơi tiếp", _close_overlay],
		["Về màn hình chính", func() -> void: get_tree().change_scene_to_file("res://scenes/main_menu.tscn")],
	])


## Cửa sổ nổi. Khi mở, đồng hồ tự tạm dừng; khi đóng, chạy lại đúng tốc độ trước đó.
func _show_overlay(kind: String, title: String, body: String, buttons: Array, extra: Control = null) -> void:
	_close_overlay()
	sim.clock.push_modal()
	_overlay_kind = kind
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.65)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.z_index = 50
	add_child(_overlay)

	var inset: MarginContainer = MarginContainer.new()
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		inset.add_theme_constant_override("margin_" + side, 28)
	_overlay.add_child(inset)
	var scroller: ScrollContainer = ScrollContainer.new()
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inset.add_child(scroller)
	var center: CenterContainer = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroller.add_child(center)
	var panel: PanelContainer = UI.panel(UI.PANEL, UI.BORDER)
	panel.custom_minimum_size.x = minf(820, get_viewport_rect().size.x - 80)
	center.add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	column.add_child(UI.label(title, 38, UI.PURPLE, true))
	var body_label: Label = UI.label(body, 26, UI.TEXT)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.custom_minimum_size = Vector2(minf(760, get_viewport_rect().size.x - 125), 0)
	column.add_child(body_label)
	if extra != null:
		column.add_child(extra)

	var row: HFlowContainer = HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 10)
	column.add_child(row)
	for entry in buttons:
		var button: Button = UI.button(entry[0], 26, UI.GOLD)
		button.pressed.connect(entry[1])
		row.add_child(button)


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
