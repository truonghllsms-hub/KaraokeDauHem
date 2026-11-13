extends SceneTree
## Chạy thử giao diện: tự chơi hai đêm bằng đúng các thao tác của người chơi (chọn khách, bấm phòng,
## giao món, đổi micro, trả lời yêu cầu, cử Lan can) và chụp ảnh. Cần màn hình hoặc xvfb.
## Chạy: godot --path . --script res://tests/ui_smoke.gd -- <thư_mục_ảnh>

var _out_dir: String = "user://ui_smoke"
var _errors: int = 0
var _game
var _sim
var _venue
var _handled: Dictionary = {"ORDER": 0, "MIC": 0, "HOT": 0, "EXTEND": 0}


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_run()


## Tua mô phỏng và phần hình ảnh cùng nhau: mỗi phút game ứng với 2 giây hình ảnh.
func _tick(minutes: int) -> void:
	for i in minutes:
		if _sim.state.phase == "OPEN":
			_sim.step_minute()
		for j in 4:
			_venue.advance_actors(0.5)


func _run() -> void:
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	await _shot("01_menu")
	menu.queue_free()

	_game = load("res://scenes/game.tscn").instantiate()
	root.add_child(_game)
	await process_frame
	_sim = _game.sim
	_venue = _game.venue
	_sim.clock.toggle_pause()
	await _shot("02_chuan_bi")

	_expect(_sim.hire_host("host_1") == "" and _sim.hire_host("host_4") == "", "Tuyển hai nhân viên Lan can")
	_venue.selected_room = "room_03"
	_game._refresh_detail()
	_game._btn_unlock.pressed.emit()
	_expect(_sim.rooms.get_room("room_03")["state"] == "AVAILABLE", "Mở phòng 03 từ bảng chi tiết")
	_game._show_stock()
	await _shot("03_kho_hang")
	_game._close_overlay()
	_venue._btn_open.pressed.emit()
	_expect(_sim.state.phase == "OPEN", "Bấm Mở cửa thì quán mở")

	while _sim.customers.waiting_groups().is_empty():
		_tick(1)
	_tick(2)
	var first: Dictionary = _sim.customers.waiting_groups()[0]
	_venue.on_group_pressed(first["id"])
	_tick(0)
	_venue.advance_actors(0.1)
	await _shot("04_chon_khach")
	_venue.on_room_pressed("room_05")
	_expect(_venue.task_count() == 0 and _venue.selected_group == first["id"], "Bấm phòng chưa mở: báo lý do, vẫn giữ nhóm đang chọn")
	_venue.on_room_pressed("room_02")
	_expect(_venue.task_count() == 1, "Bấm phòng xếp được: chủ quán nhận việc dẫn khách")
	for i in 12:
		if _sim.rooms.get_room("room_02")["state"] == "OCCUPIED":
			break
		_tick(1)
	_expect(_sim.rooms.get_room("room_02")["state"] == "OCCUPIED", "Chủ quán tới nơi thì khách vào phòng")

	# Dựng sẵn một đơn gọi món để chụp ảnh và thử thao tác giao món.
	var room: Dictionary = _sim.rooms.get_room("room_02")
	_sim.service.close_room(room)
	_sim.state.stock["trai_cay"] -= 1
	_sim.service._open(room, {"kind": "ORDER", "product_id": "trai_cay", "quantity": 1, "price": 150000, "text": "1 đĩa trái cây · 150.000đ"}, _sim.clock.minute, 14)
	_tick(1)
	await _shot("05_goi_mon")
	_venue.on_room_pressed("room_02")
	for i in 14:
		if room["request"].is_empty():
			break
		_tick(1)
	_expect(room["request"].is_empty() and first["bill_items"].size() >= 1, "Bấm phòng gọi món: chủ quán lấy món ở quầy rồi giao tới")

	_sim.service._open(room, {"kind": "EXTEND", "text": "Xin hát thêm 30'"}, _sim.clock.minute, 8)
	_venue.on_room_pressed("room_02")
	await _shot("06_xin_hat_them")
	_expect(_game._overlay_kind == "choice" and not _sim.clock.is_running(), "Bấm phòng xin hát thêm: hiện lựa chọn, đồng hồ dừng")
	_game._close_overlay()
	_sim.answer_request("room_02", "decline")

	_game._show_guard()
	await _shot("07_bao_ve")
	_game._close_overlay()

	while _sim.state.phase == "OPEN":
		_autoplay()
		_tick(1)
		if _sim.clock.minute == 150:
			await _shot("08_dang_dong")
	await _shot("09_tong_ket")
	_expect(_game._overlay != null and _game._overlay_kind == "summary", "Hiện bảng tổng kết")
	_expect(_sim.check_invariants().is_empty(), "Bất biến ổn sau đêm 1")
	_expect(_sim.state.night["served"] >= 5, "Đêm 1 phục vụ được nhiều nhóm (%d)" % _sim.state.night["served"])
	_expect(_handled["ORDER"] > 0, "Đã giao món qua giao diện (%d lần)" % _handled["ORDER"])
	_expect(_game._lbl_bill.text.contains("TỔNG"), "Bảng hóa đơn vừa thu có nội dung")

	# Đêm 2: thuê bảo vệ, chơi tiếp.
	_sim.next_day()
	_game._close_overlay()
	_sim.set_guard(true)
	_venue._btn_open.pressed.emit()
	while _sim.state.phase == "OPEN":
		_autoplay()
		_tick(1)
		if _sim.clock.minute == 200:
			await _shot("10_dem_2")
	_expect(_sim.state.day == 2 and _sim.state.history.size() == 2, "Chơi trọn đêm 2")
	_expect(_sim.state.history[1]["wages"] >= 300000 + 350000, "Đêm 2 có trả lương bảo vệ")
	_expect(_sim.check_invariants().is_empty() and _sim.economy.ledger_matches_balance(), "Bất biến và sổ thu chi ổn sau đêm 2")
	print("    Đã xử lý: %s" % str(_handled))

	print("ui_smoke: %d lỗi" % _errors)
	quit(1 if _errors > 0 else 0)


## Bot chơi bằng đúng các thao tác của người chơi; mỗi lượt chỉ giao một việc cho chủ quán.
func _autoplay() -> void:
	for room in _sim.state.rooms:
		if room["request"].is_empty():
			continue
		var kind: String = room["request"]["kind"]
		if kind == "HOT":
			_sim.answer_request(room["id"], "ac")
			_handled[kind] += 1
		elif kind == "EXTEND":
			_sim.answer_request(room["id"], "accept" if _sim.customers.waiting_groups().is_empty() else "decline")
			_handled[kind] += 1
	for host in _sim.state.hosts:
		for room in _sim.state.rooms:
			if _sim.hosts.check_assign(host, room, _sim.clock.minute) == "":
				_venue.on_host_pressed(host["id"])
				_venue.on_room_pressed(room["id"])
	if _venue.task_count() > 0:
		return
	for room in _sim.state.rooms:
		if not room["request"].is_empty() and (room["request"]["kind"] == "ORDER" or room["request"]["kind"] == "MIC"):
			_handled[room["request"]["kind"]] += 1
			_venue.on_room_pressed(room["id"])
			return
	for group in _sim.customers.waiting_groups():
		for room in _sim.state.rooms:
			if _sim.preview_assign(group["id"], room["id"])["reason"] == "":
				_venue.on_group_pressed(group["id"])
				_venue.on_room_pressed(room["id"])
				return
	for room in _sim.state.rooms:
		if room["state"] == "DIRTY":
			_venue.on_room_pressed(room["id"])
			return
	for product in _sim.data["products"]:
		if _sim.state.stock[product["id"]] < 6:
			_sim.buy_stock(product["id"])


func _expect(condition: bool, label: String) -> void:
	print(("  ok   " if condition else "  LỖI  ") + label)
	if not condition:
		_errors += 1


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out_dir.path_join(name + ".png"))
