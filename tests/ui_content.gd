extends SceneTree
## Kiểm tra giao diện cho đợt nội dung: phòng chưa lắp thiết bị, lý do xếp phòng, điểm sao,
## câu hát trên đầu nhân vật, nhân viên phục vụ, tổng kết và Tiếp tục từ bản lưu. Chụp ảnh vào thư mục chỉ định.
## Chạy: xvfb-run godot --path . --resolution 1024x1536 --script res://tests/ui_content.gd -- <thư_mục_ảnh>

const SaveManager = preload("res://scripts/core/save_manager.gd")

var _out_dir: String = "user://ui_content"
var _errors: int = 0
var _game
var _sim
var _venue


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_run()


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  LỖI  ") + label)
	if not ok:
		_errors += 1


func _tick(minutes: int) -> void:
	for i in minutes:
		if _sim.state.phase == "OPEN":
			_sim.step_minute()
		for j in 4:
			_venue._line_clock += 0.5
			_venue.advance_actors(0.5)
	_game._refresh()


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out_dir.path_join(name + ".png"))


func _open_game() -> void:
	_game = load("res://scenes/game.tscn").instantiate()
	root.add_child(_game)
	await process_frame
	_sim = _game.sim
	_venue = _game.venue


func _run() -> void:
	for leftover in [SaveManager.DEFAULT_PATH, SaveManager.backup_path(SaveManager.DEFAULT_PATH)]:
		if FileAccess.file_exists(leftover):
			DirAccess.remove_absolute(leftover)
	await _open_game()
	_sim.clock.toggle_pause()
	_game._refresh()
	_venue.advance_actors(0.0)
	_check(_venue._btn_open.visible, "Giai đoạn chuẩn bị: nút MỞ CỬA ĐÓN KHÁCH hiện rõ")
	_check(_venue._room_ui["room_03"]["center"].text.begins_with("CHƯA LẮP THIẾT BỊ") and _venue._room_ui["room_03"]["status"].text == "CHƯA LẮP", "Phòng chưa trang bị ghi \"Chưa lắp thiết bị\", không còn \"Khóa\"")
	_check(_game._rating_button.text == "Chưa có đánh giá" and _game._rating_button.icon != null, "Chưa có khách: huy hiệu ghi \"Chưa có đánh giá\"")
	_check(_game._tutorial_panel.visible and _game._tutorial_key == "d1_open" and _game._tutorial_label.text.contains("MỞ CỬA"), "Đêm tập 1: khung hướng dẫn chỉ cách mở cửa")
	_check(_game._debt_button.visible and _game._debt_button.text.contains("Bốc bát họ"), "Nút Bốc bát họ luôn hiện ở góc trái")
	_game._debt_button.pressed.emit()
	_check(_game._overlay_kind == "ledger" and _game._overlay.find_children("*", "Label", true, false).any(func(l): return l.text == "BỐC BÁT HỌ"), "Bấm nút vay: mở bảng vay riêng")
	await _shot("c01b_bang_vay")
	_game._close_overlay()
	await _shot("c01_chuan_bi")

	_venue.selected_room = "room_03"
	_game._show_venue_panel()
	var body: String = _game._lbl_detail.text
	_check(body.contains("THIẾT BỊ SẼ LẮP") and body.contains("LỢI ÍCH") and body.contains("Chi phí lắp: 4.000.000đ"), "Bảng phòng: thiết bị, lợi ích và chi phí lắp")
	_check(_game._btn_unlock.text == "Lắp thiết bị — 4.000.000đ" and not _game._btn_unlock.disabled, "Nút \"Lắp thiết bị — 4.000.000đ\"")
	await _shot("c02_bang_phong")
	_game._close_overlay()
	var money: int = _sim.state.money
	_check(_sim.equip_room("room_03") == "" and _sim.state.money == money - 4000000, "Lắp thiết bị trừ tiền đúng một lần")
	_venue.advance_actors(0.0)
	_check(not _venue._room_ui["room_03"]["dimmer"].visible, "Lắp xong: hiện nội thất")
	_venue.selected_room = "room_05"
	_game._refresh_detail()
	_check(not _game._btn_unlock.disabled and _game._btn_unlock.text == "Lắp thiết bị — 6.000.000đ", "Phòng VIP lắp được ngay khi đủ tiền")
	_venue.selected_room = ""
	_game._show_lancan()
	var lancan_text: String = ""
	var lancan_buttons_off: bool = true
	for node in _game._overlay.find_children("*", "Label", true, false):
		lancan_text += node.text
	for node in _game._overlay.find_children("*", "Button", true, false):
		if node.text == "Tuyển":
			lancan_buttons_off = lancan_buttons_off and node.disabled
	_check(lancan_text.contains("CHƯA MỞ DỊCH VỤ") and lancan_buttons_off, "Lan can khóa nút tuyển khi chưa lắp đủ 4 phòng tầng 1")
	_game._close_overlay()
	_game._show_ledger()
	var loan_button: Button = null
	for node in _game._overlay.find_children("*", "Button", true, false):
		if node.text.begins_with("Bốc "):
			loan_button = node
	_check(loan_button != null, "Bảng Thu chi có nút vay ngân hàng")
	money = _sim.state.money
	loan_button.pressed.emit()
	_check(_sim.state.loan_principal == 5000000 and _sim.state.money == money + 5000000, "Bấm vay: nhận 5.000.000đ, ghi dư nợ")
	await _shot("c02b_vay")
	_game._close_overlay()
	_game._refresh()
	_check(_game._debt_button.visible and _game._debt_button.text == "Nợ 5.000.000đ", "Huy hiệu nợ hiện dư nợ")
	_sim.hire_staff("staff_2")
	_sim.hire_staff("staff_5")

	_venue._btn_open.pressed.emit()
	_check(_sim.state.phase == "OPEN", "Bấm nút mở cửa thì quán mở")
	_game._refresh()
	_check(_game._tutorial_key in ["d1_wait", "d1_group"], "Mở cửa xong: hướng dẫn chuyển sang bước tiếp theo")
	while _sim.customers.waiting_groups().is_empty():
		_tick(1)
	_tick(1)
	var first: Dictionary = _sim.customers.waiting_groups()[0]
	_game._refresh()
	_check(_game._tutorial_key == "d1_group", "Có khách chờ: hướng dẫn bấm vào nhóm khách")
	await _shot("c02c_huong_dan")
	_venue.on_group_pressed(first["id"])
	_tick(0)
	_venue.advance_actors(0.0)
	_game._refresh()
	_check(_game._tutorial_key == "d1_room", "Đã chọn nhóm: hướng dẫn bấm phòng viền xanh")
	var label01: String = _venue._room_ui["room_01"]["center"].text
	_check(label01.begins_with("XẾP ĐƯỢC · dự kiến") or label01.begins_with("Khách chê đắt") or label01.begins_with("Thiếu chỗ"), "Chọn nhóm: phòng hiện giá dự kiến hoặc lý do ngắn (%s)" % label01.replace("\n", " / "))
	_check(_venue._room_ui["room_04"]["center"].text == "Chưa lắp thiết bị", "Phòng chưa lắp thiết bị: lý do đúng khi đang chọn nhóm")
	await _shot("c03_chon_nhom")

	# Trộm xe: bấm vào tên trộm để chủ quán chạy ra đuổi.
	_sim.state.day = 3
	_sim.assign_group(first["id"], "room_01")
	_check(_sim.security.spawn(_sim.clock.minute), "Tên trộm xuất hiện ở bãi xe")
	_tick(2)
	_check(_venue._thief_actor != null and _venue._thief_actor.visible, "Thấy tên trộm trên bản đồ")
	await _shot("c03b_trom")
	_venue._on_thief_pressed()
	_check(_sim.state.thief["chased_by"] == "owner", "Bấm vào trộm: chủ quán chạy ra đuổi")
	_tick(_sim.data["balance"]["chase_minutes"])
	_check(_sim.state.thief["state"] == "CAUGHT" and _sim.state.night["thefts"] == 0, "Đuổi kịp: bắt được trộm, không mất xe")
	await _shot("c03c_bat_trom")
	_tick(5)
	_check(_venue._thief_actor == null, "Tên trộm biến mất sau khi bị bắt")
	_sim.state.day = 1
	_sim.security.enabled = false

	# Chơi tiếp: bot xếp khách, giao món; nhân viên tự lo phần còn lại.
	var lines_seen: int = 0
	var song_bubble: bool = false
	var staff_moved: bool = false
	var shot_singing: bool = false
	while _sim.state.phase == "OPEN":
		for group in _sim.customers.waiting_groups():
			for room in _sim.state.rooms:
				if _sim.preview_assign(group["id"], room["id"])["reason"] == "":
					_sim.assign_group(group["id"], room["id"])
					break
		for room in _sim.state.rooms:
			if not room["request"].is_empty() and room["request"]["kind"] in ["HOT", "EXTEND"]:
				_sim.answer_request(room["id"], "ac" if room["request"]["kind"] == "HOT" else "decline")
		_tick(1)
		lines_seen = _venue._lines.size()
		for actor in _venue._group_actors.values():
			if actor._bubble.visible and actor._bubble.text.begins_with("♪"):
				song_bubble = true
				if not shot_singing and _sim.clock.minute > 60:
					shot_singing = true
					await _shot("c04_dang_hat")
		for actor in _venue._staff_actors.values():
			staff_moved = staff_moved or actor.position.distance_to(_venue.STAFF_SLOTS[0]) > 80
	_check(lines_seen > 0 and song_bubble, "Khách đang hát có bóng câu hát ♪ trên đầu")
	_check(staff_moved, "Nhân viên đi lại trên bản đồ khi có việc")
	_check(_game._overlay_kind == "summary", "Hết đêm: hiện bảng tổng kết")
	var summary_text: String = ""
	for node in _game._overlay.find_children("*", "Label", true, false):
		summary_text += node.text
	_check(summary_text.contains("ĐÁNH GIÁ SAO") and summary_text.contains("Đêm nay:") and summary_text.contains("Đã tự lưu"), "Tổng kết có điểm sao của đêm và báo đã tự lưu")
	_check(_game._rating_button.icon != null and _game._rating_button.text.contains("/5"), "Huy hiệu hiện điểm sao trung bình (%s)" % _game._rating_button.text)
	var count: int = _sim.state.rating_count
	await _shot("c05_tong_ket")
	_game._close_overlay()
	_game._show_summary()
	_check(_sim.state.rating_count == count, "Mở lại tổng kết không nhân đôi đánh giá")
	var loan_from_summary: Button = null
	for node in _game._overlay.find_children("*", "Button", true, false):
		if node.text == "Bốc bát họ":
			loan_from_summary = node
	_check(loan_from_summary != null, "Bảng tổng kết có nút Bốc bát họ")
	loan_from_summary.pressed.emit()
	var close_loan: Button = null
	for node in _game._overlay.find_children("*", "Button", true, false):
		if node.text == "Đóng":
			close_loan = node
	close_loan.pressed.emit()
	_check(_game._overlay_kind == "summary", "Đóng bảng vay thì quay lại bảng tổng kết")
	_game._close_overlay()
	_game._show_reviews()
	await _shot("c06_nhan_xet")
	_game._close_overlay()
	_game._show_waiters()
	await _shot("c07_phuc_vu")
	_game._close_overlay()
	_check(SaveManager.has_save(), "Đã có bản lưu sau tổng kết")
	var saved_money: int = _sim.state.money
	var saved_rating: String = _sim.rating_text()
	_game.queue_free()
	await process_frame

	# Tiếp tục từ màn hình chính.
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	var resume: Button = null
	for node in menu.find_children("*", "Button", true, false):
		if node.text == "Tiếp tục":
			resume = node
	_check(resume != null and not resume.disabled, "Màn hình chính: nút Tiếp tục bật khi có bản lưu")
	Engine.set_meta("karaoke_load_save", true)
	menu.queue_free()
	await process_frame
	await _open_game()
	_check(_sim.state.money == saved_money and _sim.rating_text() == saved_rating and _sim.state.staff.size() == 2 and _sim.state.loan_principal > 0, "Tiếp tục: đúng số dư, điểm sao, nhân viên và dư nợ")
	_check(_sim.state.phase == "SUMMARY" and _sim.rooms.get_room("room_03")["state"] != "LOCKED", "Tiếp tục về đúng mốc cuối đêm, phòng đã lắp vẫn còn")
	await process_frame
	_check(_game._overlay_kind == "summary", "Tiếp tục: mở lại bảng tổng kết để sang đêm mới")
	await _shot("c08_tiep_tuc")
	for leftover in [SaveManager.DEFAULT_PATH, SaveManager.backup_path(SaveManager.DEFAULT_PATH)]:
		if FileAccess.file_exists(leftover):
			DirAccess.remove_absolute(leftover)
	print("ui_content: %d lỗi" % _errors)
	quit(1 if _errors > 0 else 0)
