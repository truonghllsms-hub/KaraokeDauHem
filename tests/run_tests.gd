extends SceneTree
## Kiểm thử headless, dùng chính bộ mô phỏng của game.
## Chạy: godot --headless --path . --script res://tests/run_tests.gd

const DataLoader = preload("res://scripts/core/data_loader.gd")
const Simulation = preload("res://scripts/core/simulation.gd")
const Money = preload("res://scripts/core/money.gd")
const Clock = preload("res://scripts/core/simulation_clock.gd")
const SaveManager = preload("res://scripts/core/save_manager.gd")

var _failures: int = 0
var _checks: int = 0
var _data: Dictionary


func _init() -> void:
	_data = DataLoader.load_all()
	check(_data["errors"].is_empty(), "Dữ liệu hợp lệ: " + str(_data["errors"]))
	if _data["errors"].is_empty():
		test_money()
		test_clock()
		test_three_sessions()
		test_assignment_rules()
		test_waiting_and_unlock()
		test_closing_time()
		test_lancan()
		test_service()
		test_yard_and_goals()
		test_staff()
		test_regulars()
		test_save_load()
		test_full_nights()
	print("\n%d kiểm tra, %d lỗi." % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  ok   " + label)
	else:
		_failures += 1
		print("  LỖI  " + label)


func new_sim(p_seed: int = 1, spawning: bool = false):
	var sim = Simulation.new(_data, p_seed)
	sim.customers.spawning_enabled = spawning
	sim.service.enabled = spawning
	sim.staff.enabled = spawning
	return sim


func step(sim, minutes: int) -> void:
	for i in minutes:
		sim.step_minute()


func test_money() -> void:
	print("Tiền tệ")
	check(Money.format(250000) == "250.000đ", "Định dạng 250.000đ")
	check(Money.format(15000000) == "15.000.000đ", "Định dạng 15.000.000đ")
	check(Money.format(-1500) == "-1.500đ", "Định dạng số âm")
	check(Money.format(0) == "0đ", "Định dạng 0đ")
	check(Money.round_to_thousand(187499) == 187000, "Làm tròn xuống dưới 500đ")
	check(Money.round_to_thousand(187500) == 188000, "Làm tròn lên từ 500đ")
	check(Money.room_fee(250000, 60) == 250000, "60 phút = đúng giá giờ")
	check(Money.room_fee(250000, 45) == 188000, "45 phút phòng 250.000đ = 188.000đ")
	check(Money.room_fee(350000, 75) == 438000, "75 phút phòng 350.000đ = 438.000đ")
	check(Money.room_fee(250000, 0) == 0, "0 phút = 0đ")


func test_clock() -> void:
	print("Đồng hồ")
	var clock = Clock.new()
	check(clock.advance(2.0) == 1, "1x: 2 giây thực = 1 phút game")
	clock.set_speed(2)
	check(clock.advance(2.0) == 2, "2x: 2 giây thực = 2 phút game")
	clock.set_speed(4)
	check(clock.advance(2.0) == 4, "4x: 2 giây thực = 4 phút game")
	clock.toggle_pause()
	check(clock.advance(10.0) == 0, "Tạm dừng: không trôi thời gian")
	clock.toggle_pause()
	clock.push_modal()
	check(clock.advance(10.0) == 0, "Cửa sổ đang mở: tự tạm dừng")
	clock.pop_modal()
	check(clock.speed == 4 and clock.advance(0.5) == 1, "Đóng cửa sổ: chạy lại đúng tốc độ 4x")
	check(Clock.time_text(0) == "18:00" and Clock.time_text(95) == "19:35" and Clock.time_text(360) == "24:00", "Hiển thị giờ")

	var sim = new_sim()
	sim.advance(100.0)
	check(sim.clock.minute == 0, "Chưa mở cửa thì đồng hồ đứng yên")
	sim.open_doors()
	sim.clock.toggle_pause()
	sim.advance(100.0)
	check(sim.clock.minute == 0, "Tạm dừng thì mô phỏng không chạy")


func test_three_sessions() -> void:
	print("Ba lượt khách liên tiếp")
	var sim = new_sim()
	var start_money: int = sim.state.money
	check(start_money == 15000000, "Vốn ban đầu 15.000.000đ")
	sim.open_doors()
	var expected: int = 0
	var plans: Array = [45, 60, 45]
	for i in plans.size():
		var group = sim.customers.add_group("friends", 4, plans[i], sim.clock.minute)
		check(sim.assign_group(group["id"], "room_01") == "", "Lượt %d: xếp được phòng" % (i + 1))
		var room = sim.rooms.get_room("room_01")
		check(room["state"] == "OCCUPIED", "Lượt %d: phòng đang có khách" % (i + 1))
		step(sim, plans[i])
		expected += Money.room_fee(250000, plans[i])
		check(room["state"] == "DIRTY", "Lượt %d: hết giờ, phòng cần dọn" % (i + 1))
		check(sim.state.money == start_money + expected, "Lượt %d: thu đúng một hóa đơn" % (i + 1))
		check(sim.clean_room("room_01") == "", "Lượt %d: bắt đầu dọn" % (i + 1))
		check(sim.clean_room("room_01") != "", "Lượt %d: không dọn trùng" % (i + 1))
		step(sim, _data["balance"]["clean_minutes"])
		check(room["state"] == "AVAILABLE", "Lượt %d: phòng sẵn sàng trở lại" % (i + 1))
		check(sim.check_invariants().is_empty(), "Lượt %d: bất biến ổn" % (i + 1))
	check(sim.economy.total_for_day(1, "ROOM_FEE") == expected, "Tổng tiền phòng khớp sổ")
	check(sim.state.night["served"] == 3, "Đã phục vụ 3 nhóm")
	check(not sim.economy.record("ROOM_FEE", 99000, "group:1"), "Chặn ghi trùng hóa đơn")
	check(sim.state.money == start_money + expected, "Ghi trùng không làm đổi tiền")


func test_assignment_rules() -> void:
	print("Quy tắc xếp phòng")
	var sim = new_sim()
	var early = sim.customers.add_group("friends", 3, 45, 0)
	check(sim.assign_group(early["id"], "room_01") != "", "Chưa mở cửa: không xếp phòng")
	sim.open_doors()
	var big = sim.customers.add_group("company", 8, 60, 0)
	var reason: String = sim.assign_group(big["id"], "room_01")
	check(reason.contains("chỉ chứa 6 người"), "Vượt sức chứa: báo rõ lý do (%s)" % reason)
	check(sim.assign_group(big["id"], "room_04").contains("chưa mở"), "Phòng chưa mở: từ chối kèm lý do")
	var preview: Dictionary = sim.preview_assign(big["id"], "room_02")
	check(preview["reason"] == "" and preview["estimate"] == 350000 and not preview["over_budget"], "Xem trước: phòng 02 vừa nhóm 8 người, dự kiến 350.000đ")
	check(sim.preview_assign(early["id"], "room_02")["over_budget"], "Xem trước: báo vượt ngân sách của nhóm bạn bè")
	check(sim.assign_group(early["id"], "room_01") == "", "Nhóm vừa sức chứa: xếp được")
	var other = sim.customers.add_group("friends", 2, 45, 0)
	check(sim.assign_group(other["id"], "room_01") != "", "Phòng có khách: không xếp nhóm thứ hai")
	check(sim.assign_group(early["id"], "room_01") != "", "Nhóm đang hát: không xếp lại")
	step(sim, 45)
	check(sim.assign_group(other["id"], "room_01") != "", "Phòng bẩn: không nhận khách")
	sim.clean_room("room_01")
	check(sim.assign_group(other["id"], "room_01") != "", "Phòng đang dọn: không nhận khách")
	check(sim.check_invariants().is_empty(), "Bất biến ổn")


func test_waiting_and_unlock() -> void:
	print("Hàng chờ, giá và mở phòng")
	var sim = new_sim()
	check(sim.change_price("room_01", 1) == "" and sim.rooms.get_room("room_01")["price_per_hour"] == 260000, "Tăng giá một nấc")
	check(sim.change_price("room_01", -100) != "", "Chặn giá dưới mức tối thiểu")
	check(sim.change_price("room_03", 1) != "", "Phòng chưa mở: không chỉnh giá")
	sim.change_price("room_01", -1)
	sim.open_doors()
	check(sim.change_price("room_01", 1) != "", "Đang mở cửa: không chỉnh giá")

	var rep: int = sim.state.reputation
	var group = sim.customers.add_group("friends", 2, 45, 0)
	step(sim, group["patience"])
	check(sim.customers.get_group(group["id"]) == null, "Hết kiên nhẫn: nhóm bỏ về")
	check(sim.state.night["unserved"] == 1 and sim.state.reputation == rep - 1, "Bỏ về: -1 danh tiếng")

	var money: int = sim.state.money
	check(sim.unlock_room("room_03") == "" and sim.state.money == money - 4000000, "Mở phòng 03 trừ 4.000.000đ")
	check(sim.unlock_room("room_03") != "" and sim.state.money == money - 4000000, "Không mở trùng, không trừ tiền lần hai")
	check(sim.unlock_room("room_04") == "", "Mở phòng 04")
	sim.economy.record("TEST", -sim.state.money, "drain")
	check(sim.unlock_room("room_05").contains("Không đủ tiền"), "Thiếu tiền: không mở được phòng")
	check(sim.state.rooms.size() == 6 and sim.rooms.unlocked_count() == 4, "Quán có 6 phòng, mở sẵn 2 và vừa mở thêm 2")


func test_closing_time() -> void:
	print("Giờ đóng cửa")
	var sim = new_sim()
	sim.open_doors()
	step(sim, 300)
	var late = sim.customers.add_group("friends", 2, 90, sim.clock.minute)
	check(sim.assign_group(late["id"], "room_01").contains("đóng cửa"), "Không nhận lượt vượt quá 24:00")
	var fits = sim.customers.add_group("friends", 2, 60, sim.clock.minute)
	check(sim.assign_group(fits["id"], "room_01") == "", "Lượt kết thúc đúng 24:00 vẫn nhận")
	step(sim, 1)
	check(sim.customers.get_group(late["id"]) == null, "Nhóm không còn kịp giờ tự rời hàng chờ")
	var money: int = sim.state.money
	step(sim, 59)
	check(sim.state.phase == "SUMMARY", "24:00: chuyển sang tổng kết")
	var summary: Dictionary = sim.state.history[0]
	check(summary["room_revenue"] == 250000, "Doanh thu phòng trong báo cáo")
	check(sim.state.money == money + 250000 - 300000 - 400000, "Trừ lương và chi phí vận hành đúng một lần")
	check(summary["profit"] == 250000 - 700000, "Lợi nhuận = thu - chi")
	check(sim.rooms.get_room("room_01")["state"] == "AVAILABLE", "Kết ca: phòng được dọn")
	check(sim.state.groups.is_empty(), "Kết ca: không còn nhóm khách nào")
	var minute: int = sim.clock.minute
	sim.step_minute()
	check(sim.clock.minute == minute, "Sau tổng kết đồng hồ không chạy tiếp")
	check(sim.next_day() == "" and sim.state.day == 2 and sim.state.phase == "PREP" and sim.clock.minute == 0, "Sang đêm 2")
	check(sim.check_invariants().is_empty(), "Bất biến ổn")


func test_lancan() -> void:
	print("Lan can")
	check(_data["hosts"].size() == 8 and _data["customers"]["types"].size() == 9, "Có 8 ứng viên Lan can và 9 nhóm khách")
	var has_students: bool = false
	for t in _data["customers"]["types"]:
		has_students = has_students or t["id"] == "students"
	check(not has_students, "Đã bỏ nhóm sinh viên")
	for def in _data["hosts"]:
		check(ResourceLoader.exists("res://assets/sprites/%s.svg" % def["sprite"]), "Có hình cho " + def["name"])
	for t in _data["customers"]["types"]:
		var all_found: bool = true
		for sprite_name in t["sprites"]:
			all_found = all_found and ResourceLoader.exists("res://assets/sprites/%s.svg" % sprite_name)
		check(all_found and t["greetings"].size() >= 2, "Có hình và câu thoại cho nhóm " + t["name"])
	var sim = new_sim()
	var fee: int = _data["balance"]["lancan_fee"]
	var money: int = sim.state.money
	check(sim.hire_host("host_1") == "" and sim.state.money == money - 1500000, "Tuyển trừ 1.500.000đ")
	check(sim.hire_host("host_1") != "" and sim.state.money == money - 1500000, "Không tuyển trùng")
	check(sim.hire_host("host_2") == "", "Tuyển người thứ hai")
	check(sim.hire_host("host_3") == "", "Tuyển người thứ ba")
	check(sim.hire_host("host_4").contains("3 vị trí"), "Tối đa ba vị trí")
	check(sim.hosts.candidates().size() == 5, "Còn 5 ứng viên chưa tuyển")
	sim.open_doors()
	var g1 = sim.customers.add_group("birthday", 4, 90, 0)
	var g2 = sim.customers.add_group("friends", 4, 90, 0)
	g1["wants_host"] = true
	g2["wants_host"] = false
	sim.assign_group(g1["id"], "room_01")
	sim.assign_group(g2["id"], "room_02")
	check(sim.assign_host("host_1", "room_01").contains("không gọi"), "Khách chưa gọi: không phân công")
	step(sim, 5)
	check(g1["host_request"] == "PENDING" and g2["host_request"] == "NONE", "Sau 5 phút nhóm muốn Lan can sẽ gọi")
	check(sim.assign_host("host_1", "room_02") != "", "Phòng không gọi: từ chối")
	check(sim.assign_host("host_1", "room_01") == "", "Phân công vào phòng đang gọi")
	check(sim.assign_host("host_2", "room_01").contains("đã có"), "Mỗi phòng tối đa một nhân viên")
	g2["host_request"] = "PENDING"
	check(sim.assign_host("host_1", "room_02").contains("đang phục vụ"), "Một người không phục vụ hai phòng")
	g2["host_request"] = "NONE"
	check(sim.check_invariants().is_empty(), "Bất biến ổn khi đang phục vụ")
	var before: int = g1["satisfaction"]
	step(sim, 30)
	var host = sim.hosts.get_host("host_1")
	check(host["state"] != "SERVING" and sim.rooms.get_room("room_01")["host_id"] == "", "Hết 30 phút: nhân viên được giải phóng")
	check(g1["satisfaction"] > before, "Phục vụ xong: hài lòng tăng")
	check(g1["bill_items"].size() == 1 and g1["host_request"] == "DONE", "Phí vào hóa đơn đúng một lần, không tự gia hạn")
	money = sim.state.money
	step(sim, 55)
	check(sim.economy.total_for_day(1, "LANCAN_FEE") == fee, "Thu đúng một lần phí Lan can")
	check(sim.state.money == money + 2 * Money.room_fee(250000, 90) - Money.room_fee(250000, 90) + Money.room_fee(350000, 90) + fee, "Số dư = tiền hai phòng + phí Lan can")
	check(host["tips_total"] == host["tips_tonight"] and sim.economy.total_for_day(1, "TIP") == 0, "Tip thuộc về nhân viên, không vào doanh thu quán")

	# Khách gọi mà không ai tới, và phiên bị cắt ngang thì không thu phí.
	var g3 = sim.customers.add_group("birthday", 4, 90, sim.clock.minute)
	g3["wants_host"] = true
	sim.clean_room("room_01")
	step(sim, 8)
	sim.assign_group(g3["id"], "room_01")
	step(sim, 5)
	var sat: int = g3["satisfaction"]
	step(sim, 20)
	check(g3["host_request"] == "MISSED" and g3["satisfaction"] == sat - 3, "Gọi không ai tới: -3 hài lòng")
	g3["host_request"] = "PENDING"
	sim.hosts.get_host("host_2")["state"] = "READY"
	check(sim.assign_host("host_2", "room_01") == "", "Phân công lại")
	sim.rooms.get_room("room_01")["session_end"] = sim.clock.minute + 3
	step(sim, 3)
	check(g3["bill_items"].is_empty() and sim.hosts.get_host("host_2")["room_id"] == "", "Khách về sớm: không thu phí, nhân viên không bị kẹt")
	check(sim.check_invariants().is_empty(), "Bất biến ổn")
	step(sim, 400)
	var summary: Dictionary = sim.state.history[0]
	check(summary["lancan_revenue"] == fee and summary["wages"] == 300000 + 250000 + 250000 + 300000, "Báo cáo có doanh thu Lan can và lương")
	check(sim.economy.ledger_matches_balance(), "Số dư khớp sổ")


func test_service() -> void:
	print("Phục vụ khi khách đang hát")
	var sim = new_sim()
	var balance: Dictionary = _data["balance"]
	sim.open_doors()
	var group = sim.customers.add_group("company", 6, 90, 0)
	sim.assign_group(group["id"], "room_02")
	var room = sim.rooms.get_room("room_02")
	check(sim.deliver_order("room_02") != "" and sim.fix_mic("room_02") != "" and sim.answer_request("room_02", "ac") != "", "Không có yêu cầu: mọi thao tác phục vụ bị từ chối kèm lý do")

	# Gọi món: giữ chỗ hàng, giao thì vào hóa đơn, quá hạn thì trả kho.
	var stock: int = sim.state.stock["trai_cay"]
	sim.state.stock["trai_cay"] -= 2
	sim.service._open(room, {"kind": "ORDER", "product_id": "trai_cay", "quantity": 2, "price": 300000, "text": ""}, sim.clock.minute, balance["order_timeout"])
	var sat: int = group["satisfaction"]
	step(sim, 2)
	check(sim.deliver_order("room_02") == "" and room["request"].is_empty(), "Giao món: đóng yêu cầu")
	check(sim.deliver_order("room_02") != "", "Không giao trùng một món")
	check(group["bill_items"].size() == 1 and group["bill_items"][0]["amount"] == 300000, "Món đã giao vào hóa đơn đúng một lần")
	check(group["satisfaction"] == sat + balance["order_bonus"] + balance["fast_service_bonus"], "Giao nhanh: cộng hài lòng")
	check(sim.state.stock["trai_cay"] == stock - 2, "Tồn kho giảm đúng số đã giao")

	sim.state.stock["da"] -= 1
	sim.service._open(room, {"kind": "ORDER", "product_id": "da", "quantity": 1, "price": 15000, "text": ""}, sim.clock.minute, balance["order_timeout"])
	var ice: int = sim.state.stock["da"]
	sat = group["satisfaction"]
	step(sim, balance["order_timeout"])
	check(room["request"].is_empty() and sim.state.stock["da"] == ice + 1, "Quá hạn: hủy đơn, trả hàng giữ chỗ về kho")
	check(group["satisfaction"] == sat - balance["order_late_penalty"] and group["bill_items"].size() == 1, "Quá hạn: trừ hài lòng, không tính tiền món chưa giao")

	# Micro: sửa kịp thì thôi, bỏ mặc thì trừ hài lòng và giảm giá.
	sim.service._open(room, {"kind": "MIC", "text": ""}, sim.clock.minute, balance["mic_timeout"])
	check(sim.fix_mic("room_02") == "" and group["discount_percent"] == 0, "Đổi micro kịp: không giảm giá")
	sim.service._open(room, {"kind": "MIC", "text": ""}, sim.clock.minute, balance["mic_timeout"])
	sat = group["satisfaction"]
	step(sim, balance["mic_timeout"])
	check(group["satisfaction"] == sat - balance["mic_penalty"] and group["discount_percent"] == 10, "Bỏ mặc micro: -8 hài lòng và giảm 10% tiền phòng")

	# Phòng nóng: bật điều hòa tốn điện.
	sim.service._open(room, {"kind": "HOT", "text": ""}, sim.clock.minute, balance["hot_timeout"])
	var money: int = sim.state.money
	check(sim.answer_request("room_02", "ac") == "" and sim.state.money == money - balance["ac_cost"], "Tăng điều hòa: tốn 20.000đ tiền điện")

	# Hát thêm: gia hạn 30 phút, không vượt 24:00.
	var session_end: int = room["session_end"]
	sim.service._open(room, {"kind": "EXTEND", "text": ""}, sim.clock.minute, balance["extend_timeout"])
	check(sim.answer_request("room_02", "accept") == "" and room["session_end"] == session_end + 30, "Đồng ý hát thêm: +30 phút")
	room["session_end"] = 350
	sim.service._open(room, {"kind": "EXTEND", "text": ""}, sim.clock.minute, 300)
	check(sim.answer_request("room_02", "accept").contains("đóng cửa") and room["session_end"] == 350, "Không gia hạn quá giờ đóng cửa")
	check(sim.answer_request("room_02", "decline") == "", "Từ chối hát thêm")

	# Hóa đơn: tiền phòng + món - giảm giá, mỗi khoản một giao dịch.
	room["session_end"] = sim.clock.minute + 1
	sim.state.stock["khan_lanh"] -= 6
	sim.service._open(room, {"kind": "ORDER", "product_id": "khan_lanh", "quantity": 6, "price": 30000, "text": ""}, sim.clock.minute, 30)
	var towels: int = sim.state.stock["khan_lanh"]
	money = sim.state.money
	step(sim, 1)
	var bill: Dictionary = sim.state.last_bill
	var fee: int = Money.room_fee(350000, bill["minutes"])
	check(bill["room_fee"] == fee and bill["discount"] == Money.round_to_thousand(fee / 10), "Hóa đơn: tiền phòng và giảm 10% làm tròn 1.000đ")
	check(bill["items"].size() == 1 and bill["total"] == fee + 300000 - bill["discount"], "Hóa đơn: tổng = phòng + món - giảm giá")
	check(sim.state.money == money + bill["total"], "Thu đúng bằng tổng hóa đơn")
	check(sim.state.stock["khan_lanh"] == towels + 6 and room["request"].is_empty(), "Khách về: đơn chưa giao bị hủy, trả hàng về kho")
	check(bill["comment"] == "Micro hú hoài mà không ai lo.", "Lời nhận xét phản ánh đúng trải nghiệm")
	check(sim.check_invariants().is_empty(), "Bất biến ổn")

	# Kho và nâng cấp.
	money = sim.state.money
	stock = sim.state.stock["nuoc_ngot"]
	check(sim.buy_stock("nuoc_ngot") == "" and sim.state.stock["nuoc_ngot"] == stock + 24 and sim.state.money == money - 24 * 8000, "Nhập một thùng nước ngọt: +24 lon, trừ 192.000đ")
	money = sim.state.money
	check(sim.buy_upgrade("spare_mics") == "" and sim.state.money == money - 1500000 and sim.service.upgrade_level("spare_mics") == 1, "Mua micro dự phòng")
	check(sim.buy_upgrade("spare_mics").contains("cao nhất"), "Không mua quá cấp tối đa")
	check(sim.buy_upgrade("sound") == "" and sim.rooms.get_room("room_05")["sound"] == 2, "Dàn loa mới: mọi phòng lên cấp âm thanh 2")
	sim.state.stock["da"] = 0
	var thirsty = sim.customers.add_group("drinking", 3, 60, sim.clock.minute)
	sim.assign_group(thirsty["id"], "room_01")
	sat = thirsty["satisfaction"]
	for i in 40:
		sim.service._open_order(sim.rooms.get_room("room_01"), thirsty, sim.clock.minute)
		if thirsty["tags"].has("het_hang"):
			break
		sim.service.close_room(sim.rooms.get_room("room_01"))
	check(thirsty["tags"].has("het_hang") and thirsty["satisfaction"] == sat - balance["out_of_stock_penalty"] and sim.state.stock["da"] == 0, "Hết hàng: báo khách, -3 hài lòng, kho không âm")


func test_yard_and_goals() -> void:
	print("Sân xe, bảo vệ và mục tiêu đêm")
	var balance: Dictionary = _data["balance"]
	var sim = new_sim()
	check(not sim.theft_risk_active(), "Đêm 1 chưa có nguy cơ mất xe")
	check(sim.goal_text().contains("4 nhóm"), "Mục tiêu đêm 1: phục vụ 4 nhóm")
	sim.open_doors()
	for i in 4:
		var group = sim.customers.add_group("couple", 2, 45, sim.clock.minute)
		sim.assign_group(group["id"], "room_01")
		step(sim, 45)
		sim.clean_room("room_01")
		step(sim, 8)
	var rep: int = sim.state.reputation
	step(sim, 400)
	var first: Dictionary = sim.state.history[0]
	check(first["goal_met"] and sim.state.reputation == rep + balance["goal_reputation_bonus"], "Đạt mục tiêu đêm: +2 danh tiếng")
	check(first["comments"].size() == 3 and first["thefts"] == 0, "Tổng kết có 3 lời nhận xét, đêm 1 không mất xe")
	check(first["wages"] == 300000, "Chưa thuê bảo vệ: không trả lương bảo vệ")

	# Đêm 2, không bảo vệ, ép xác suất mất xe 100%.
	sim.next_day()
	check(sim.theft_risk_active(), "Từ đêm 2 có nguy cơ mất xe")
	var saved: int = balance["theft_chance_permille"]
	balance["theft_chance_permille"] = 1000
	sim.open_doors()
	var victim = sim.customers.add_group("friends", 3, 45, 0)
	sim.assign_group(victim["id"], "room_01")
	var money: int = sim.state.money
	rep = sim.state.reputation
	step(sim, 45)
	var fee: int = Money.room_fee(250000, 45)
	check(sim.state.night["thefts"] == 1 and sim.state.money == money + fee - balance["theft_compensation"], "Mất xe: quán đền 1.000.000đ")
	check(sim.state.reputation == rep - balance["theft_reputation_penalty"] - 3, "Mất xe: -3 danh tiếng và khách hết hài lòng")
	check(sim.state.last_bill["comment"].contains("mất xe"), "Khách nhận xét về chuyện mất xe")
	balance["theft_chance_permille"] = saved

	# Thuê bảo vệ giữa ca: trả lương đêm đó, xác suất dùng mức có bảo vệ.
	check(sim.set_guard(true) == "" and sim.state.night["guard_on_duty"], "Thuê bảo vệ")
	saved = balance["theft_chance_guard_permille"]
	balance["theft_chance_guard_permille"] = 0
	sim.clean_room("room_01")
	step(sim, 8)
	var safe = sim.customers.add_group("friends", 3, 45, sim.clock.minute)
	sim.assign_group(safe["id"], "room_01")
	step(sim, 45)
	check(sim.state.night["thefts"] == 1, "Có bảo vệ: xe an toàn")
	balance["theft_chance_guard_permille"] = saved
	step(sim, 400)
	var second: Dictionary = sim.state.history[1]
	check(second["wages"] == 300000 + balance["guard_wage"] and second["compensation"] == balance["theft_compensation"], "Tổng kết đêm 2: có lương bảo vệ và tiền đền xe")
	check(not second["goal_met"], "Không đủ số nhóm: trượt mục tiêu")
	check(second["profit"] == second["room_revenue"] - second["wages"] - second["operating"] - second["compensation"], "Lợi nhuận = thu - lương - vận hành - đền xe")
	check(sim.economy.ledger_matches_balance(), "Số dư khớp sổ")


func open_request(sim, room_id: String, request: Dictionary, timeout: int) -> void:
	if request["kind"] == "ORDER":
		sim.state.stock[request["product_id"]] -= request["quantity"]
	request["text"] = ""
	sim.service._open(sim.rooms.get_room(room_id), request, sim.clock.minute, timeout)


func test_staff() -> void:
	print("Nhân viên phục vụ")
	var balance: Dictionary = _data["balance"]
	var sim = new_sim()
	sim.staff.enabled = true
	check(sim.state.staff.size() == 1 and sim.state.staff[0]["name"] == "Tí", "Quán có sẵn một nhân viên phục vụ")
	var ti: Dictionary = sim.state.staff[0]
	sim.open_doors()

	# Tự dọn phòng: chờ 2 phút, đi 2 phút, dọn 8 phút.
	var first = sim.customers.add_group("couple", 2, 45, 0)
	sim.assign_group(first["id"], "room_01")
	step(sim, 45)
	var room1: Dictionary = sim.rooms.get_room("room_01")
	check(room1["state"] == "DIRTY" and ti["task"].is_empty(), "Khách vừa về: phòng bẩn, nhân viên chưa nhận việc (nhường chủ quán)")
	step(sim, balance["staff_delay_clean"])
	check(ti["task"].get("kind", "") == "CLEAN" and ti["task"]["room_id"] == "room_01", "Sau 2 phút: nhân viên nhận việc dọn")
	step(sim, balance["staff_travel_minutes"])
	check(room1["state"] == "CLEANING", "Tới nơi: phòng chuyển sang đang dọn")
	check(sim.clean_room("room_01") != "", "Chủ quán không dọn trùng phòng nhân viên đang dọn")
	step(sim, balance["clean_minutes"])
	check(room1["state"] == "AVAILABLE" and ti["task"].is_empty() and ti["tasks_done"] == 1, "Dọn xong: phòng sẵn sàng, nhân viên rảnh")
	check(ti["energy"] == 100 - balance["staff_energy_clean"], "Dọn phòng tốn năng lượng")

	# Giao món: món vào hóa đơn đúng một lần, tồn kho đúng.
	var party = sim.customers.add_group("company", 6, 90, sim.clock.minute)
	sim.assign_group(party["id"], "room_02")
	var room2: Dictionary = sim.rooms.get_room("room_02")
	var stock: int = sim.state.stock["nuoc_ngot"]
	open_request(sim, "room_02", {"kind": "ORDER", "product_id": "nuoc_ngot", "quantity": 6, "price": 150000}, 14)
	step(sim, balance["staff_delay_order"])
	check(ti["task"].get("kind", "") == "DELIVER" and ti["task"]["request_id"] == room2["request"]["id"], "Sau 3 phút: nhân viên nhận đơn gọi món")
	step(sim, balance["staff_deliver_minutes"])
	check(room2["request"].is_empty() and ti["task"].is_empty(), "Giao xong: đóng yêu cầu, nhân viên rảnh")
	check(party["bill_items"].size() == 1 and party["bill_items"][0]["amount"] == 150000 and sim.state.stock["nuoc_ngot"] == stock - 6, "Món vào hóa đơn một lần, tồn kho giảm đúng 6")

	# Chủ quán giao trước: nhân viên bỏ việc, không giao trùng, không kẹt.
	open_request(sim, "room_02", {"kind": "ORDER", "product_id": "da", "quantity": 1, "price": 15000}, 14)
	step(sim, balance["staff_delay_order"] + 1)
	check(ti["task"].get("kind", "") == "DELIVER", "Nhân viên đang đi lấy món")
	check(sim.deliver_order("room_02") == "", "Chủ quán giao trước")
	step(sim, 1)
	check(ti["task"].is_empty() and party["bill_items"].size() == 2, "Việc đã có người lo: nhân viên rảnh ngay, hóa đơn không bị ghi trùng")
	step(sim, 6)
	check(party["bill_items"].size() == 2 and ti["tasks_done"] == 2, "Không phát sinh giao món ma")

	# Thứ tự ưu tiên: micro trước, món sau; mỗi người một việc.
	open_request(sim, "room_02", {"kind": "MIC"}, 30)
	var other = sim.customers.add_group("friends", 3, 90, sim.clock.minute)
	sim.assign_group(other["id"], "room_01")
	open_request(sim, "room_01", {"kind": "ORDER", "product_id": "da", "quantity": 1, "price": 15000}, 30)
	step(sim, 3)
	check(ti["task"].get("kind", "") == "FIX" and not room1["request"].is_empty(), "Hai việc cùng lúc: lo micro trước, đơn món chờ")
	check(sim.check_invariants().is_empty(), "Bất biến ổn khi đang có việc")
	step(sim, balance["staff_fix_minutes"])
	check(room2["request"].is_empty() and ti["task"].get("kind", "") == "DELIVER", "Đổi micro xong thì nhận tiếp đơn món")
	step(sim, balance["staff_deliver_minutes"])
	check(room1["request"].is_empty() and other["bill_items"].size() == 1, "Đơn món còn lại cũng được giao")

	# Khách về giữa chừng: việc bị hủy, hàng trả kho.
	open_request(sim, "room_01", {"kind": "ORDER", "product_id": "trai_cay", "quantity": 1, "price": 150000}, 30)
	var fruit: int = sim.state.stock["trai_cay"]
	step(sim, 3)
	check(ti["task"].get("kind", "") == "DELIVER", "Nhân viên nhận đơn trái cây")
	room1["session_end"] = sim.clock.minute + 1
	step(sim, 2)
	check(ti["task"].is_empty() and sim.state.stock["trai_cay"] == fruit + 1, "Khách về trước khi giao: hủy việc, trả hàng về kho")

	# Ưu tiên do người chơi chọn: nhận ngay, không chờ nhịp.
	check(sim.prioritize_job("room_03").contains("không có việc"), "Phòng không có việc: không ưu tiên được")
	check(room1["state"] == "DIRTY" and sim.prioritize_job("room_01") == "", "Người chơi ưu tiên phòng bẩn")
	step(sim, 1)
	check(ti["task"].get("kind", "") == "CLEAN" and sim.state.staff_priority.is_empty(), "Phòng được ưu tiên: nhân viên nhận ngay")
	check(sim.prioritize_job("room_01").contains("đã có nhân viên"), "Phòng đã có người lo: không ưu tiên lại")
	step(sim, 10)

	# Mệt thì chậm, kiệt sức thì nghỉ.
	ti["energy"] = 30
	check(sim.staff._duration(ti, 4) == 6, "Năng lượng thấp: làm chậm gấp rưỡi")
	ti["energy"] = 15
	step(sim, 1)
	check(ti["task"].get("kind", "") == "REST", "Kiệt sức: tự xin nghỉ")
	open_request(sim, "room_02", {"kind": "MIC"}, 40)
	step(sim, balance["staff_rest_minutes"] - 1)
	check(ti["task"].get("kind", "") == "REST" and not room2["request"].is_empty(), "Đang nghỉ thì không nhận việc")
	step(sim, 1)
	check(ti["energy"] == 15 + balance["staff_rest_recovery"], "Nghỉ xong: hồi năng lượng")

	# Tuyển thêm: phí, giới hạn, hai người hai việc, lương cuối đêm.
	var money: int = sim.state.money
	check(sim.hire_staff("staff_2") == "" and sim.state.money == money - balance["staff_hire_cost"], "Tuyển Mận: trừ 800.000đ")
	check(sim.hire_staff("staff_2") != "" and sim.state.money == money - balance["staff_hire_cost"], "Không tuyển trùng, không trừ tiền lần hai")
	check(sim.hire_staff("staff_3") == "" and sim.staff.candidates().is_empty(), "Tuyển người thứ ba, hết ứng viên")
	sim.economy.record("TEST", -sim.state.money, "drain_staff")
	check(sim.state.staff.size() == 3 and sim.hire_staff("staff_1") != "", "Đủ ba người thì không tuyển thêm")
	sim.economy.record("TEST", 5000000, "refill_staff")
	open_request(sim, "room_02", {"kind": "ORDER", "product_id": "da", "quantity": 1, "price": 15000}, 40) if room2["request"].is_empty() else null
	step(sim, 4)
	var busy_rooms: Dictionary = {}
	for member in sim.state.staff:
		if not member["task"].is_empty() and member["task"]["kind"] != "REST":
			check(not busy_rooms.has(member["task"]["room_id"]), "%s không nhận trùng việc của người khác" % member["name"])
			busy_rooms[member["task"]["room_id"]] = true
	check(sim.check_invariants().is_empty(), "Bất biến ổn với ba nhân viên")
	step(sim, 400)
	var summary: Dictionary = sim.state.history[0]
	check(summary["wages"] == 300000 + 380000 + 240000, "Cuối đêm trả lương đủ ba người")
	var all_idle: bool = true
	for member in sim.state.staff:
		all_idle = all_idle and member["task"].is_empty() and member["energy"] == 100
	check(all_idle and sim.economy.ledger_matches_balance(), "Kết ca: không ai còn việc dở, năng lượng hồi đầy, sổ khớp")


func test_regulars() -> void:
	print("Khách quen")
	var balance: Dictionary = _data["balance"]
	var chances: Dictionary = _data["regulars"]["become_chance"]
	var saved_chance: int = chances["bolero_regular"]
	var saved_return: int = balance["regular_return_chance"]
	var saved_favorite: int = balance["regular_favorite_product_chance"]
	var saved_theft: int = balance["theft_chance_permille"]
	balance["theft_chance_permille"] = 0
	chances["bolero_regular"] = 100
	balance["regular_return_chance"] = 100
	balance["regular_favorite_product_chance"] = 100

	var sim = new_sim()
	sim.open_doors()
	var so_so = sim.customers.add_group("bolero_regular", 3, 45, 0)
	sim.assign_group(so_so["id"], "room_02")
	so_so["satisfaction"] = 70
	var birthday = sim.customers.add_group("birthday", 4, 45, 0)
	sim.assign_group(birthday["id"], "room_01")
	birthday["satisfaction"] = 100
	step(sim, 45)
	check(sim.state.regulars.is_empty(), "Hài lòng dưới 80 hoặc nhóm sinh nhật: chưa thành khách quen")

	sim.clean_room("room_01")
	step(sim, 8)
	var happy = sim.customers.add_group("bolero_regular", 3, 45, sim.clock.minute)
	sim.assign_group(happy["id"], "room_01")
	open_request(sim, "room_01", {"kind": "ORDER", "product_id": "nuoc_ngot", "quantity": 3, "price": 75000}, 14)
	sim.deliver_order("room_01")
	happy["satisfaction"] = 90
	step(sim, 45)
	check(sim.state.regulars.size() == 1, "Nhóm rất hài lòng thành khách quen")
	var regular: Dictionary = sim.state.regulars[0]
	check(regular["favorite_room_id"] == "room_01" and regular["favorite_product_id"] == "nuoc_ngot", "Ghi nhớ phòng đã ngồi và món đã gọi")
	check(_data["regulars"]["names"]["bolero_regular"].has(regular["name"]) and regular["visits"] == 1, "Khách quen có tên riêng, tính là lần ghé đầu")
	check(not sim.regulars._free_names("bolero_regular").has(regular["name"]), "Tên đã dùng không cấp cho khách quen khác")
	step(sim, 400)

	# Đêm sau: khách quen ghé lại, mỗi đêm một lần.
	sim.next_day()
	sim.open_doors()
	sim.customers.spawning_enabled = true
	step(sim, balance["first_arrival_minute"])
	var visitor = sim.customers.waiting_groups()[0]
	check(visitor["regular_id"] == regular["id"] and visitor["type_name"].contains("khách quen"), "Khách quen quay lại, tên hiện trên nhóm")
	check(visitor["trait"].contains("Phòng 01") and visitor["trait"].contains("nước ngọt"), "Đặc điểm ghi rõ phòng quen và món quen")
	check(visitor["favorite_room_id"] == "room_01" and regular["last_visit_day"] == 2, "Nhóm mang thông tin sở thích, đã ghi nhận lượt ghé đêm nay")
	step(sim, 60)
	var repeat_visits: int = 0
	for group in sim.state.groups:
		if group["regular_id"] == regular["id"]:
			repeat_visits += 1
	check(repeat_visits <= 1, "Một khách quen chỉ ghé một lần mỗi đêm")
	sim.customers.spawning_enabled = false

	if sim.customers.get_group(visitor["id"]) == null:
		visitor = sim.customers.add_group("bolero_regular", 3, 45, sim.clock.minute)
		sim.regulars.apply_to_group(visitor, regular)
	for room in sim.state.rooms:
		if room["state"] == "DIRTY":
			sim.rooms.finish_cleaning(room)
	visitor["wait_minutes"] = 0
	var before: int = visitor["satisfaction"]
	check(sim.assign_group(visitor["id"], "room_01") == "", "Xếp khách quen vào phòng quen")
	check(visitor["satisfaction"] == before + balance["regular_favorite_room_bonus"] and visitor["tags"].has("phong_quen"), "Đúng phòng quen: +5 hài lòng")
	var room1: Dictionary = sim.rooms.get_room("room_01")
	sim.service._open_order(room1, visitor, sim.clock.minute)
	check(room1["request"]["product_id"] == "nuoc_ngot", "Khách quen gọi món quen")
	before = visitor["satisfaction"]
	sim.deliver_order("room_01")
	check(visitor["satisfaction"] == before + balance["order_bonus"] + balance["fast_service_bonus"] + balance["regular_favorite_product_bonus"], "Giao đúng món quen: thêm hài lòng")
	room1["session_end"] = sim.clock.minute + 1
	step(sim, 1)
	check(regular["visits"] == 2 and sim.state.regulars.size() == 1, "Phục vụ tốt: tăng số lần ghé, không tạo khách quen trùng")
	check(sim.check_invariants().is_empty(), "Bất biến ổn")

	# Phục vụ tệ: mất khách quen.
	sim.rooms.finish_cleaning(room1)
	var upset = sim.customers.add_group("bolero_regular", 3, 45, sim.clock.minute)
	sim.regulars.apply_to_group(upset, regular)
	sim.assign_group(upset["id"], "room_01")
	upset["satisfaction"] = 20
	room1["session_end"] = sim.clock.minute + 1
	step(sim, 1)
	check(sim.state.regulars.is_empty(), "Hài lòng dưới 40: khách quen bỏ quán")

	chances["bolero_regular"] = saved_chance
	balance["regular_return_chance"] = saved_return
	balance["regular_favorite_product_chance"] = saved_favorite
	balance["theft_chance_permille"] = saved_theft


## Bot chơi một phút bằng các hàm công khai của Simulation.
func bot_minute(sim) -> void:
	for room in sim.state.rooms:
		if room["state"] == "DIRTY":
			sim.clean_room(room["id"])
		if not room["request"].is_empty():
			match room["request"]["kind"]:
				"HOT":
					sim.answer_request(room["id"], "ac")
				"EXTEND":
					sim.answer_request(room["id"], "decline")
	for group in sim.customers.waiting_groups():
		for room in sim.state.rooms:
			if sim.assign_group(group["id"], room["id"]) == "":
				break
	sim.step_minute()


func bot_night(sim) -> void:
	sim.open_doors()
	var guard: int = 0
	while sim.state.phase == "OPEN" and guard < 1000:
		guard += 1
		bot_minute(sim)


func state_text(sim) -> String:
	var snapshot: Dictionary = SaveManager.make_snapshot(sim.state, sim.rng)
	return JSON.stringify(snapshot["state"]) + snapshot["rng_state"]


func test_save_load() -> void:
	print("Lưu và tải")
	var path: String = "user://test_save_%d.json" % Time.get_ticks_usec()
	var backup: String = SaveManager.backup_path(path)
	check(not SaveManager.has_save(path) and SaveManager.read_save(_data, path)["error"] == "Chưa có bản lưu.", "Chưa có bản lưu: báo rõ")

	var sim = new_sim(11, true)
	sim.hire_host("host_1")
	sim.hire_staff("staff_2")
	sim.buy_upgrade("spare_mics")
	sim.open_doors()
	for i in 30:
		bot_minute(sim)
	check(sim.save_game(path).contains("Chỉ lưu được") and not FileAccess.file_exists(path), "Giữa ca: từ chối lưu")
	while sim.state.phase == "OPEN":
		bot_minute(sim)
	var saved_events: Array = []
	sim.game_saved.connect(func(saved_path: String, error: String) -> void: saved_events.append([saved_path, error]))
	check(sim.save_game(path) == "" and FileAccess.file_exists(path), "Sau tổng kết: lưu thành công")
	check(saved_events == [[path, ""]], "Phát tín hiệu game_saved không lỗi")
	check(not FileAccess.file_exists(SaveManager.temp_path(path)) and not FileAccess.file_exists(backup), "Không để lại tệp tạm; lần đầu chưa có bản sao lưu")

	var loaded: Dictionary = Simulation.create_from_save(_data, path)
	check(loaded["ok"] and not loaded["used_backup"], "Tải lại thành công từ tệp chính")
	var copy = loaded["sim"]
	check(state_text(copy) == state_text(sim), "Trạng thái sau khi tải giống hệt lúc lưu (tiền, kho, phòng, nhân viên, khách quen, ngẫu nhiên)")
	check(copy.state.money == sim.state.money and copy.economy.ledger_matches_balance(), "Tiền và sổ giao dịch khớp sau khi tải")
	check(copy.state.stock == sim.state.stock and str(copy.state.stock.keys()) == str(sim.state.stock.keys()), "Tồn kho giống hệt sau khi tải, giữ cả thứ tự mặt hàng")
	check(copy.state.staff.size() == 2 and copy.state.hosts.size() == 1 and copy.service.upgrade_level("spare_mics") == 1, "Nhân viên, Lan can và nâng cấp được giữ")
	check(copy.state.phase == "SUMMARY" and copy.clock.minute == Clock.NIGHT_MINUTES and copy.last_summary()["day"] == 1, "Tải về đúng mốc tổng kết đêm 1")
	check(copy.check_invariants().is_empty(), "Bất biến ổn sau khi tải")

	# Chơi tiếp từ bản tải phải cho đúng diễn biến như chơi liền mạch.
	check(sim.next_day() == "" and copy.next_day() == "", "Cả hai sang đêm 2")
	bot_night(sim)
	bot_night(copy)
	check(JSON.stringify(sim.state.history[1]) == JSON.stringify(copy.state.history[1]), "Đêm 2 từ bản tải giống hệt đêm 2 chơi liền mạch")
	check(state_text(copy) == state_text(sim), "Sau đêm 2: tiền, kho, công việc, khách quen vẫn trùng khớp")

	# Lần lưu thứ hai tạo bản sao lưu; tệp chính hỏng thì dùng bản sao lưu, không xóa gì.
	check(sim.save_game(path) == "" and FileAccess.file_exists(backup), "Lưu lần hai: bản cũ thành bản sao lưu")
	var good_main: String = FileAccess.get_file_as_string(path)
	var garbage: String = "{ hỏng giữa chừng"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(garbage)
	file.close()
	var recovered: Dictionary = Simulation.create_from_save(_data, path)
	check(recovered["ok"] and recovered["used_backup"] and recovered["notice"] != "", "Tệp chính hỏng: tải từ bản sao lưu và có thông báo")
	check(recovered["sim"].state.day == 1 and recovered["sim"].check_invariants().is_empty(), "Bản sao lưu là mốc cuối đêm 1, nhất quán")
	check(FileAccess.get_file_as_string(path) == garbage, "Không tự xóa hay ghi đè tệp hỏng")
	file = FileAccess.open(backup, FileAccess.WRITE)
	file.store_string("")
	file.close()
	var broken: Dictionary = Simulation.create_from_save(_data, path)
	check(not broken["ok"] and broken["sim"] == null and broken["error"].contains("Không tải được"), "Cả hai tệp hỏng: báo lỗi dễ hiểu")
	check(FileAccess.file_exists(path) and FileAccess.file_exists(backup), "Hai tệp hỏng vẫn còn nguyên để người chơi tự xử lý")

	# Kiểm tra dữ liệu bản lưu.
	var snapshot: Dictionary = DataLoader.normalize(JSON.parse_string(good_main))
	check(SaveManager.validate(snapshot, _data) == "", "Bản lưu tốt qua kiểm tra")
	var newer: Dictionary = snapshot.duplicate(true)
	newer["schema_version"] = SaveManager.SCHEMA_VERSION + 1
	check(SaveManager.validate(newer, _data).contains("mới hơn"), "Chặn bản lưu của phiên bản mới hơn")
	var older: Dictionary = snapshot.duplicate(true)
	older["schema_version"] = 0
	check(SaveManager.validate(older, _data).contains("cũ"), "Chặn bản lưu phiên bản cũ không tương thích")
	var rich: Dictionary = snapshot.duplicate(true)
	rich["state"]["money"] += 1000000
	check(SaveManager.validate(rich, _data).contains("không khớp sổ"), "Sửa tiền trong tệp: bị phát hiện")
	var no_stock: Dictionary = snapshot.duplicate(true)
	no_stock["state"]["stock"]["da"] = -3
	check(SaveManager.validate(no_stock, _data).contains("Tồn kho"), "Tồn kho âm trong tệp: bị từ chối")
	var missing: Dictionary = snapshot.duplicate(true)
	missing["state"].erase("regulars")
	check(SaveManager.validate(missing, _data).contains("thiếu trường"), "Thiếu trường: bị từ chối")
	var ghost: Dictionary = snapshot.duplicate(true)
	ghost["state"]["rooms"][0]["id"] = "room_99"
	check(SaveManager.validate(ghost, _data).contains("phòng không tồn tại"), "Phòng lạ: bị từ chối")
	var midshift: Dictionary = snapshot.duplicate(true)
	midshift["state"]["phase"] = "OPEN"
	check(SaveManager.validate(midshift, _data) != "", "Bản lưu giữa ca: bị từ chối")
	var fresh = new_sim(5)
	var money: int = fresh.state.money
	check(fresh.restore(rich) != "" and fresh.state.money == money and fresh.state.day == 1, "Tải thất bại không làm bẩn ván đang chơi")

	# Tự lưu sau tổng kết và lưu tay lúc chuẩn bị.
	var auto_path: String = path + ".auto"
	var auto = new_sim(3, true)
	auto.autosave_path = auto_path
	check(auto.save_game(auto_path) == "", "Lưu tay ở giai đoạn chuẩn bị")
	var prep: Dictionary = Simulation.create_from_save(_data, auto_path)
	check(prep["ok"] and prep["sim"].state.phase == "PREP" and prep["sim"].clock.minute == 0 and prep["sim"].open_doors() == "", "Tải bản lưu lúc chuẩn bị rồi mở cửa được")
	bot_night(auto)
	var after: Dictionary = Simulation.create_from_save(_data, auto_path)
	check(after["ok"] and after["sim"].state.phase == "SUMMARY" and after["sim"].state.money == auto.state.money, "Tự lưu sau tổng kết đêm")

	for leftover in [path, backup, auto_path, SaveManager.backup_path(auto_path)]:
		if FileAccess.file_exists(leftover):
			DirAccess.remove_absolute(leftover)


## Chơi tự động nhiều đêm với seed cố định, kiểm tra bất biến ở từng phút.
func test_full_nights() -> void:
	print("Mô phỏng trọn đêm (bot tự chơi)")
	for p_seed in [7, 42, 2024]:
		var sim = new_sim(p_seed, true)
		if p_seed != 7:
			sim.unlock_room("room_03")
			sim.hire_host("host_1")
		if p_seed == 2024:
			sim.set_guard(true)
		var problems: Array = []
		for night in 3:
			sim.open_doors()
			var guard: int = 0
			while sim.state.phase == "OPEN" and guard < 1000:
				guard += 1
				for room in sim.state.rooms:
					if room["state"] == "DIRTY":
						sim.clean_room(room["id"])
				for group in sim.customers.waiting_groups():
					for room in sim.state.rooms:
						if sim.assign_group(group["id"], room["id"]) == "":
							break
				for host in sim.state.hosts:
					for room in sim.state.rooms:
						sim.assign_host(host["id"], room["id"])
				for room in sim.state.rooms:
					if room["request"].is_empty():
						continue
					match room["request"]["kind"]:
						"ORDER":
							sim.deliver_order(room["id"])
						"MIC":
							if p_seed != 42:
								sim.fix_mic(room["id"])
						"HOT":
							sim.answer_request(room["id"], "ac")
						"EXTEND":
							sim.answer_request(room["id"], "accept" if sim.customers.waiting_groups().is_empty() else "decline")
				if sim.state.phase == "PREP" or sim.clock.minute % 60 == 0:
					for product in _data["products"]:
						if sim.state.stock[product["id"]] < product["pack_size"]:
							sim.buy_stock(product["id"])
				sim.step_minute()
				problems.append_array(sim.check_invariants())
			var s: Dictionary = sim.state.history[night]
			print("    seed %d đêm %d: phục vụ %d, bỏ về %d, phòng %s, món %s, Lan can %s, mất xe %d, lợi nhuận %s, danh tiếng %d, mục tiêu %s" % [p_seed, s["day"], s["served"], s["unserved"], Money.format(s["room_revenue"]), Money.format(s["order_revenue"]), Money.format(s["lancan_revenue"]), s["thefts"], Money.format(s["profit"]), s["reputation"], "đạt" if s["goal_met"] else "trượt"])
			check(sim.state.phase == "SUMMARY" and sim.clock.minute == Clock.NIGHT_MINUTES, "Seed %d đêm %d kết thúc đúng 24:00" % [p_seed, night + 1])
			check(s["served"] > 0, "Seed %d đêm %d có khách" % [p_seed, night + 1])
			sim.next_day()
		check(problems.is_empty(), "Seed %d: không vi phạm bất biến %s" % [p_seed, str(problems.slice(0, 3))])
		check(sim.economy.ledger_matches_balance(), "Seed %d: số dư khớp sổ giao dịch" % p_seed)

	var a = new_sim(99, true)
	var b = new_sim(99, true)
	a.open_doors()
	b.open_doors()
	step(a, 200)
	step(b, 200)
	check(str(a.state.messages) == str(b.state.messages), "Cùng seed cho cùng diễn biến")
