extends Control
## Màn hình kinh doanh. Chỉ hiển thị trạng thái và gửi yêu cầu tới Simulation;
## không tự sửa tiền hay trạng thái phòng.

const DataLoader = preload("res://scripts/core/data_loader.gd")
const Simulation = preload("res://scripts/core/simulation.gd")
const Money = preload("res://scripts/core/money.gd")
const Clock = preload("res://scripts/core/simulation_clock.gd")
const UI = preload("res://scripts/ui/ui_kit.gd")
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
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)
	root.add_child(_build_top_bar())
	var goal: PanelContainer = UI.panel(Color("#e7ebc5"), UI.PURPLE)
	root.add_child(goal)
	var goal_row: HBoxContainer = HBoxContainer.new()
	goal.add_child(goal_row)
	_goal_label = UI.label("", 16, UI.TEXT, true)
	_goal_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	goal_row.add_child(_goal_label)
	var lobby: Button = UI.button("Sảnh ↓", 14, UI.PURPLE)
	lobby.pressed.connect(scroll_to_lobby)
	goal_row.add_child(lobby)
	_map_scroll = ScrollContainer.new()
	_map_scroll.name = "VenueScroll"
	_map_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_map_scroll.follow_focus = false
	root.add_child(_map_scroll)
	_map_stage = Control.new()
	_map_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_stage.mouse_filter = Control.MOUSE_FILTER_PASS
	_map_scroll.add_child(_map_stage)
	venue = VenueView.new()
	venue.setup(sim)
	venue.report.connect(_report)
	venue.hint.connect(func(text: String) -> void: _set_notice(text, "info"))
	venue.choice_requested.connect(_show_choice)
	venue.inspect_requested.connect(func(_id: String) -> void: _show_venue_panel())
	_map_stage.add_child(venue)
	_map_scroll.resized.connect(_fit_map)
	# Backing labels retain the inspector, journal and bill without occupying the map.
	var backing: Control = _build_side_panel()
	backing.visible = false
	add_child(backing)
	var notice_panel: PanelContainer = UI.panel(UI.PANEL_DARK, UI.BORDER)
	root.add_child(notice_panel)
	var notice_box: VBoxContainer = VBoxContainer.new()
	notice_panel.add_child(notice_box)
	_task_label = UI.label("", 14, UI.PURPLE, true)
	notice_box.add_child(_task_label)
	_notice_label = UI.label("Bấm MỞ CỬA ở sảnh để đón khách.", 16, UI.TEXT)
	_notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice_label.custom_minimum_size.y = 22
	notice_box.add_child(_notice_label)
	root.add_child(_build_bottom_bar())
	call_deferred("_fit_map")
	call_deferred("_show_starting_rooms")


func _fit_map() -> void:
	if not is_instance_valid(_map_scroll) or not is_instance_valid(venue):
		return
	var available: float = maxf(100, _map_scroll.size.x - 22)
	var factor: float = minf(1.15, available / VenueView.VIEW_SIZE.x)
	venue.scale = Vector2.ONE * factor
	venue.position.x = maxf(0, (available - VenueView.VIEW_SIZE.x * factor) * 0.5)
	_map_stage.custom_minimum_size = Vector2(0, VenueView.VIEW_SIZE.y * factor)


func _show_starting_rooms() -> void:
	if is_instance_valid(_map_scroll):
		_map_scroll.scroll_vertical = int(740 * venue.scale.y)


func scroll_to_lobby() -> void:
	if is_instance_valid(_map_scroll):
		_map_scroll.scroll_vertical = int(_map_stage.custom_minimum_size.y)


func _build_top_bar() -> Control:
	var panel: PanelContainer = UI.panel()
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var heading: HBoxContainer = HBoxContainer.new()
	box.add_child(heading)
	var title: Label = UI.label("KARAOKE ĐẦU HẺM", 23, UI.PURPLE, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	_lbl_status = UI.label("", 13, UI.MUTED)
	heading.add_child(_lbl_status)
	var menu: Button = UI.button("Menu", 14, UI.PURPLE)
	menu.pressed.connect(_show_menu)
	heading.add_child(menu)
	var stats: HBoxContainer = HBoxContainer.new()
	stats.add_theme_constant_override("separation", 18)
	box.add_child(stats)
	_lbl_money = UI.label("", 22, UI.PURPLE, true)
	_lbl_money.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_rep = UI.label("", 18, UI.GOLD, true)
	_lbl_day = UI.label("", 17, UI.TEXT, true)
	_lbl_time = UI.label("", 19, UI.TEXT, true)
	for node in [_lbl_money, _lbl_rep, _lbl_day, _lbl_time]:
		stats.add_child(node)
	var controls: HBoxContainer = HBoxContainer.new()
	controls.add_theme_constant_override("separation", 6)
	stats.add_child(controls)
	_btn_pause = UI.button("Dừng", 14, UI.PURPLE)
	_btn_pause.tooltip_text = "Space: tạm dừng hoặc tiếp tục"
	_btn_pause.pressed.connect(func() -> void: sim.clock.toggle_pause())
	controls.add_child(_btn_pause)
	for speed in [1, 2, 4]:
		var button: Button = UI.button("%dx" % speed, 14)
		button.toggle_mode = true
		button.pressed.connect(func() -> void: sim.clock.set_speed(speed))
		controls.add_child(button)
		_speed_buttons[speed] = button
	return panel


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
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	var entries: Array = [
		["Quán", "shop", _show_venue_panel],
		["Nhân sự", "staff", _show_staff],
		["Kho", "stock", _show_stock],
		["Nâng cấp", "upgrade", _show_upgrades],
		["Thu chi", "ledger", _show_ledger],
	]
	for entry in entries:
		var button: Button = UI.button(entry[0], 17, UI.PURPLE)
		button.name = "Nav_" + entry[1]
		button.icon = load("res://assets/topdown/icon_%s.svg" % entry[1])
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 40)
		button.custom_minimum_size = Vector2(0, 90)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(entry[2])
		row.add_child(button)
	return row


func _show_staff() -> void:
	_show_overlay("ledger", "NHÂN SỰ", "Nhân viên giao lưu và bảo vệ được quản lý tại đây. Khu sofa ở sảnh là chỗ nhân viên ngồi chờ.", [
		["Giao lưu âm nhạc", _show_lancan],
		["Bảo vệ", _show_guard],
		["Đóng", _close_overlay],
	])


func _show_venue_panel() -> void:
	_refresh_detail()
	var buttons: Array = []
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
	_btn_pause.text = "Chạy" if sim.clock.paused else "Dừng"
	for speed in _speed_buttons:
		_speed_buttons[speed].set_pressed_no_signal(sim.clock.speed == speed)

	_goal_label.text = "Phục vụ %d nhóm · %d/%d hoàn thành" % [state.night["goal_served"], state.night["served"], state.night["goal_served"]]
	_task_label.text = "Việc đang chờ: %d  ·  Khách đợi: %d  ·  Cuộn lên để xem các phòng phía trên" % [venue.task_count(), sim.customers.waiting_groups().size()]
	_refresh_detail()


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
	var intro: String = "\"Điểm tựa cho những giọng ca chênh vênh.\" Nhân viên giao lưu âm nhạc: song ca, làm MC, khuấy động sinh nhật. Khách tự gọi mới phục vụ; phí %s cho %d phút báo trước, thu vào hóa đơn; tip là của riêng nhân viên.\nĐang làm %d/%d vị trí · Phí tuyển %s/người." % [
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
		var box: VBoxContainer = VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		card.add_child(box)
		var portrait: TextureRect = TextureRect.new()
		portrait.texture = load("res://assets/sprites/%s.svg" % def["sprite"])
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.custom_minimum_size = Vector2(0, 92)
		box.add_child(portrait)
		var name_label: Label = UI.label(def["name"], 15, UI.PINK, true)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(name_label)
		var about: Label = UI.label(def["personality"], 11, UI.MUTED)
		about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		about.custom_minimum_size = Vector2(150, 32)
		box.add_child(about)
		var stats: Label = UI.label("Giao tiếp %d · Song ca %d\n%s · %s/đêm" % [def["talk"], def["duet"], sim.customers.music_name(def["music"]), Money.format(def["wage"])], 11, UI.TEXT)
		stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(stats)
		if hired != null:
			var working: Label = UI.label("ĐANG LÀM · tip %s" % Money.format(hired["tips_total"]), 11, UI.GOLD, true)
			working.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			working.custom_minimum_size = Vector2(0, 30)
			working.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			box.add_child(working)
		else:
			var hire: Button = UI.button("Tuyển", 13, UI.PINK)
			hire.custom_minimum_size = Vector2(0, 30)
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
	column.add_child(UI.label(title, 24, UI.PURPLE, true))
	var body_label: Label = UI.label(body, 16, UI.TEXT)
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
		var button: Button = UI.button(entry[0], 17, UI.GOLD)
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
