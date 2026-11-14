extends SceneTree
## Kiểm thử headless, dùng chính bộ mô phỏng của game.
## Chạy: godot --headless --path . --script res://tests/run_tests.gd

const Art = preload("res://scripts/ui/character_art.gd")
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
		test_rooms_and_vip()
		test_ratings()
		test_ambience()
		test_finance()
		test_reviews_and_arrivals()
		test_tips()
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
	sim.ambience.enabled = spawning
	sim.security.enabled = spawning
	return sim


## Chi phí vận hành một đêm: mặt bằng cơ bản cộng phí của từng phòng đã lắp thiết bị.
func operating_cost(sim) -> int:
	var total: int = _data["balance"]["operating_cost_per_night"]
	for room in sim.state.rooms:
		if room["state"] != "LOCKED":
			total += room["upkeep_per_night"]
	return total


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
	check(sim.customers.add_group("company", 6, 60, 0) == null, "Từ chối nhóm trên 5 khách")
	var big = sim.customers.add_group("company", 5, 60, 0)
	check(sim.assign_group(big["id"], "room_04").contains("chưa lắp thiết bị"), "Phòng chưa lắp thiết bị: từ chối kèm lý do")
	var preview: Dictionary = sim.preview_assign(big["id"], "room_02")
	check(preview["reason"] == "" and preview["estimate"] == 350000 and not preview["over_budget"], "Xem trước: phòng 02 vừa nhóm 5 người, dự kiến 350.000đ")
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
	var money: int = sim.state.money
	check(sim.equip_room("room_03") == "" and sim.state.money == money - 4000000, "Lắp thiết bị phòng 03 trừ 4.000.000đ")
	check(sim.equip_room("room_03").contains("đã lắp") and sim.state.money == money - 4000000, "Không lắp trùng, không trừ tiền lần hai")
	check(sim.unlock_room("room_04") == "", "Tên hàm cũ unlock_room vẫn dùng được (phòng 04)")
	var note: String = sim.state.ledger[sim.state.ledger.size() - 1]["note"]
	check(note == "Lắp thiết bị phòng: Phòng 04", "Sổ thu chi ghi \"Lắp thiết bị phòng\"")
	check(sim.state.rooms.size() == 10 and sim.rooms.unlocked_count() == 4, "Quán có 10 phòng, 2 sẵn sàng và vừa lắp thêm 2")
	check(sim.rooms.floor_unlocked(2), "Tầng 2 không cần danh tiếng: đủ tiền là lắp được")
	var reason: String = sim.equip_room("room_10")
	check(reason.contains("còn thiếu " + Money.format(16000000 - sim.state.money)), "Thiếu tiền: báo rõ số còn thiếu (%s)" % reason)
	sim.open_doors()
	check(sim.change_price("room_01", 1) != "", "Đang mở cửa: không chỉnh giá")
	sim.economy.record("TEST", 20000000, "gift")
	check(sim.equip_room("room_10").contains("giai đoạn chuẩn bị") and sim.rooms.get_room("room_10")["state"] == "LOCKED", "Đang mở cửa: không lắp thiết bị")

	var rep: int = sim.state.reputation
	var group = sim.customers.add_group("friends", 2, 45, 0)
	step(sim, group["patience"])
	check(sim.customers.get_group(group["id"]) == null, "Hết kiên nhẫn: nhóm bỏ về")
	check(sim.state.night["unserved"] == 1 and sim.state.reputation == rep - 1, "Bỏ về: -1 danh tiếng")



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
	check(sim.state.money == money + 250000 - _data["staff"][0]["wage"] - operating_cost(sim), "Trừ lương và chi phí vận hành đúng một lần")
	check(summary["profit"] == 250000 - _data["staff"][0]["wage"] - operating_cost(sim), "Lợi nhuận = thu - chi")
	check(sim.rooms.get_room("room_01")["state"] == "AVAILABLE", "Kết ca: phòng được dọn")
	check(sim.state.groups.is_empty(), "Kết ca: không còn nhóm khách nào")
	var minute: int = sim.clock.minute
	sim.step_minute()
	check(sim.clock.minute == minute, "Sau tổng kết đồng hồ không chạy tiếp")
	check(sim.next_day() == "" and sim.state.day == 2 and sim.state.phase == "PREP" and sim.clock.minute == 0, "Sang đêm 2")
	check(sim.check_invariants().is_empty(), "Bất biến ổn")


func test_lancan() -> void:
	print("Lan can")
	check(_data["hosts"].size() == 11 and _data["customers"]["types"].size() == 11, "Có 11 ứng viên giao lưu và 11 nhóm khách")
	var has_students: bool = false
	for t in _data["customers"]["types"]:
		has_students = has_students or t["id"] == "students"
	check(not has_students, "Đã bỏ nhóm sinh viên")
	for def in _data["hosts"]:
		check(Art.PEOPLE.has(def["sprite"]), "Có hình cho " + def["name"])
	for t in _data["customers"]["types"]:
		var all_found: bool = true
		for sprite_name in t["sprites"]:
			all_found = all_found and Art.PEOPLE.has(sprite_name)
		check(all_found and t["greetings"].size() >= 2, "Có hình và câu thoại cho nhóm " + t["name"])
	var sim = new_sim()
	check(sim.hire_host("host_1").contains("4 phòng tầng 1") and sim.lancan_lock_reason() != "", "Chưa lắp đủ 4 phòng tầng 1: chưa tuyển được Lan can")
	sim.equip_room("room_03")
	sim.equip_room("room_04")
	check(sim.lancan_lock_reason() == "", "Lắp đủ 4 phòng tầng 1: mở dịch vụ Lan can")
	sim.economy.record("TEST", 10000000, "gift_lancan")
	var fee: int = _data["balance"]["lancan_fee"]
	var money: int = sim.state.money
	check(sim.hire_host("host_1") == "" and sim.state.money == money - 1500000, "Tuyển trừ 1.500.000đ")
	check(sim.hire_host("host_1") != "" and sim.state.money == money - 1500000, "Không tuyển trùng")
	check(sim.hire_host("host_2") == "", "Tuyển người thứ hai")
	check(sim.hire_host("host_3") == "", "Tuyển người thứ ba")
	check(_data["balance"]["lancan_max_staff"] == 6, "Có sáu vị trí nhân viên")
	check(sim.hosts.candidates().size() == 8, "Còn 8 ứng viên chưa tuyển")
	sim.open_doors()
	var g1 = sim.customers.add_group("birthday", 4, 90, 0)
	var g2 = sim.customers.add_group("friends", 4, 90, 0)
	g1["wants_host"] = true
	g1["host_requested_count"] = 1
	g2["wants_host"] = false
	sim.assign_group(g1["id"], "room_01")
	sim.assign_group(g2["id"], "room_02")
	check(sim.assign_host("host_1", "room_01").contains("không gọi"), "Khách chưa gọi: không phân công")
	step(sim, 5)
	check(g1["host_request"] == "PENDING" and g2["host_request"] == "NONE", "Sau 5 phút nhóm muốn Lan can sẽ gọi")
	check(sim.assign_host("host_1", "room_02") != "", "Phòng không gọi: từ chối")
	check(sim.assign_host("host_1", "room_01") == "", "Phân công vào phòng đang gọi")
	check(sim.assign_host("host_2", "room_01") != "", "Không phân công vượt số người nhóm đã gọi")
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
	g3["host_request_closed"] = false
	g3["host_request_at"] = sim.clock.minute
	g3["host_requested_count"] = 1
	sim.hosts.get_host("host_2")["state"] = "READY"
	check(sim.assign_host("host_2", "room_01") == "", "Phân công lại")
	sim.rooms.get_room("room_01")["session_end"] = sim.clock.minute + 3
	step(sim, 3)
	check(g3["bill_items"].is_empty() and sim.hosts.get_host("host_2")["room_id"] == "", "Khách về sớm: không thu phí, nhân viên không bị kẹt")
	check(sim.check_invariants().is_empty(), "Bất biến ổn")
	step(sim, 400)
	var summary: Dictionary = sim.state.history[0]
	check(summary["lancan_revenue"] == fee and summary["wages"] == _data["staff"][0]["wage"] + 250000 + 250000 + 300000, "Báo cáo có doanh thu Lan can và lương")
	check(sim.economy.ledger_matches_balance(), "Số dư khớp sổ")


func test_service() -> void:
	print("Phục vụ khi khách đang hát")
	var sim = new_sim()
	var balance: Dictionary = _data["balance"]
	sim.open_doors()
	var group = sim.customers.add_group("company", 5, 90, 0)
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
	check(bill["comment"].to_lower().contains("mic"), "Lời nhận xét phản ánh đúng trải nghiệm")
	check(sim.check_invariants().is_empty(), "Bất biến ổn")

	# Kho và nâng cấp.
	money = sim.state.money
	stock = sim.state.stock["nuoc_ngot"]
	check(sim.buy_stock("nuoc_ngot") == "" and sim.state.stock["nuoc_ngot"] == stock + 24 and sim.state.money == money - 24 * 8000, "Nhập một thùng nước ngọt: +24 lon, trừ 192.000đ")
	money = sim.state.money
	check(sim.buy_upgrade("spare_mics") == "" and sim.state.money == money - 1500000 and sim.service.upgrade_level("spare_mics") == 1, "Mua micro dự phòng")
	check(sim.buy_upgrade("spare_mics").contains("cao nhất"), "Không mua quá cấp tối đa")
	check(sim.buy_upgrade("sound") == "" and sim.rooms.get_room("room_04")["sound"] == 2 and sim.rooms.get_room("room_05")["sound"] == 3, "Dàn loa mới: phòng thường lên cấp 2, VIP lên cấp 3")
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
	print("Trộm xe, bảo vệ và mục tiêu đêm")
	var balance: Dictionary = _data["balance"]
	var wage_ti: int = _data["staff"][0]["wage"]
	var sim = new_sim()
	check(not sim.theft_risk_active(), "Đêm 1 chưa có trộm")
	check(sim.goal_text().contains("4 nhóm") and sim.goal_text().contains("quá 5 nhóm"), "Mục tiêu đêm 1: phục vụ 4 nhóm, không quá 3 + 2 phòng = 5 nhóm bỏ về")
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
	check(first["wages"] == wage_ti, "Chưa thuê bảo vệ: chỉ trả lương tạp vụ")

	# Đêm 3 (hết đêm tập): trộm rón rén vào bãi, không ai đuổi thì mất xe.
	sim.next_day()
	check(not sim.theft_risk_active(), "Đêm 2 vẫn là đêm tập, chưa có trộm")
	sim.open_doors()
	step(sim, 400)
	sim.next_day()
	check(sim.theft_risk_active(), "Từ đêm 3 có trộm")
	sim.open_doors()
	check(sim.chase_thief().contains("Không có trộm"), "Không có trộm thì không đuổi")
	var victim = sim.customers.add_group("friends", 3, 90, 0)
	sim.assign_group(victim["id"], "room_01")
	step(sim, 5)
	check(sim.security.spawn(sim.clock.minute) and sim.state.thief["state"] == "APPROACH" and sim.state.thief["group_id"] == victim["id"], "Trộm xuất hiện, nhắm xe của nhóm đang hát")
	check(not sim.security.spawn(sim.clock.minute), "Mỗi lúc chỉ một tên trộm")
	var money: int = sim.state.money
	rep = sim.state.reputation
	var sat: int = victim["satisfaction"]
	step(sim, balance["thief_approach_minutes"])
	check(sim.state.thief["state"] == "STEALING", "Tới bãi xe thì bắt đầu phá khóa")
	step(sim, balance["thief_steal_minutes"])
	check(sim.state.thief["state"] == "ESCAPED" and sim.state.night["thefts"] == 1, "Không ai đuổi: trộm lấy được xe")
	check(sim.state.money == money - balance["theft_compensation"], "Mất xe: quán đền tiền cho khách ngay")
	check(sim.state.reputation == rep - balance["theft_reputation_penalty"] and victim["satisfaction"] == sat - balance["thief_satisfaction_penalty"], "Mất xe: giảm danh tiếng và hài lòng của nhóm bị mất")
	step(sim, 5)
	check(sim.state.thief.is_empty(), "Vài phút sau tên trộm biến mất khỏi bản đồ")

	# Chạy ra đuổi kịp: không mất xe.
	sim.security.spawn(sim.clock.minute)
	step(sim, 3)
	check(sim.chase_thief() == "", "Chủ quán chạy ra đuổi")
	check(sim.chase_thief().contains("đuổi theo"), "Không đuổi trùng")
	money = sim.state.money
	step(sim, balance["chase_minutes"])
	check(sim.state.thief["state"] == "CAUGHT" and sim.state.night["thefts"] == 1 and sim.state.money == money, "Đuổi kịp: bắt được trộm, không mất tiền")
	check(victim["tags"].has("trom_bat"), "Khách ghi nhận chuyện bắt trộm")
	step(sim, 5)

	# Đuổi quá muộn: vẫn mất xe.
	sim.security.spawn(sim.clock.minute)
	step(sim, balance["thief_approach_minutes"] + balance["thief_steal_minutes"] - 1)
	check(sim.chase_thief() == "", "Chạy ra lúc trộm sắp tẩu thoát")
	step(sim, balance["chase_minutes"])
	check(sim.state.night["thefts"] == 2, "Đuổi không kịp: vẫn mất xe")
	step(sim, 5)

	# Có bảo vệ: tự đuổi, phần lớn trường hợp bắt được.
	check(sim.set_guard(true) == "" and sim.state.night["guard_on_duty"], "Thuê bảo vệ")
	var saved: int = balance["guard_catch_percent"]
	balance["guard_catch_percent"] = 100
	sim.security.spawn(sim.clock.minute)
	check(sim.state.thief["chased_by"] == "guard", "Bảo vệ tự đuổi")
	step(sim, balance["guard_react_minutes"] + balance["chase_minutes"])
	check(sim.state.thief["state"] == "CAUGHT" and sim.state.night["thefts"] == 2, "Bảo vệ bắt được trộm")
	balance["guard_catch_percent"] = saved
	step(sim, 400)
	var second: Dictionary = sim.state.history[2]
	check(second["wages"] == wage_ti + balance["guard_wage"] and second["compensation"] == 2 * balance["theft_compensation"] and second["thieves_caught"] == 2, "Tổng kết đêm 3: lương bảo vệ, tiền đền hai xe, hai lần bắt trộm")
	check(second["profit"] == second["room_revenue"] - second["wages"] - second["operating"] - second["compensation"], "Lợi nhuận = thu - lương - vận hành - đền xe")
	check(sim.state.thief.is_empty() and sim.economy.ledger_matches_balance(), "Kết ca không còn trộm, số dư khớp sổ")

func open_request(sim, room_id: String, request: Dictionary, timeout: int) -> void:
	if request["kind"] == "ORDER":
		sim.state.stock[request["product_id"]] -= request["quantity"]
	request["text"] = ""
	sim.service._open(sim.rooms.get_room(room_id), request, sim.clock.minute, timeout)


func test_staff() -> void:
	print("Nhân viên: tạp vụ, phục vụ, lễ tân")
	var balance: Dictionary = _data["balance"]
	var sim = new_sim()
	sim.staff.enabled = true
	check(sim.state.staff.size() == 1 and sim.state.staff[0]["role"] == "janitor", "Quán có sẵn một tạp vụ (Tí)")
	var ti: Dictionary = sim.state.staff[0]
	sim.open_doors()

	# Tạp vụ dọn phòng: chờ 2 phút, đi 2 phút, dọn 8 phút.
	var first = sim.customers.add_group("couple", 2, 45, 0)
	sim.assign_group(first["id"], "room_01")
	step(sim, 45)
	var room1: Dictionary = sim.rooms.get_room("room_01")
	check(room1["state"] == "DIRTY" and ti["task"].is_empty(), "Khách vừa về: tạp vụ chưa nhận việc (nhường chủ quán)")
	step(sim, balance["staff_delay_clean"])
	check(ti["task"].get("kind", "") == "CLEAN", "Sau 2 phút: tạp vụ nhận việc dọn")
	step(sim, balance["staff_travel_minutes"])
	check(room1["state"] == "CLEANING" and sim.clean_room("room_01") != "", "Tới nơi: đang dọn; chủ quán không dọn trùng")
	step(sim, balance["clean_minutes"])
	check(room1["state"] == "AVAILABLE" and ti["task"].is_empty() and ti["tasks_done"] == 1, "Dọn xong: phòng sẵn sàng, tạp vụ rảnh")

	# Tạp vụ không giao món.
	var party = sim.customers.add_group("company", 5, 120, sim.clock.minute)
	sim.assign_group(party["id"], "room_02")
	var room2: Dictionary = sim.rooms.get_room("room_02")
	open_request(sim, "room_02", {"kind": "ORDER", "product_id": "nuoc_ngot", "quantity": 5, "price": 125000}, 30)
	step(sim, 6)
	check(ti["task"].is_empty() and not room2["request"].is_empty(), "Tạp vụ không đi giao món")
	room2["request"] = {}
	sim.state.stock["nuoc_ngot"] += 5

	# Tuyển phục vụ và lễ tân.
	var money: int = sim.state.money
	check(sim.hire_staff("staff_3") == "" and sim.state.money == money - balance["staff_hire_cost"], "Tuyển phục vụ Mận")
	check(sim.hire_staff("staff_3") != "" and sim.state.money == money - balance["staff_hire_cost"], "Không tuyển trùng")
	check(sim.hire_staff("staff_5") == "", "Tuyển lễ tân Bảo Ngọc")
	var man: Dictionary = sim.staff.get_member("staff_3")
	var ngoc: Dictionary = sim.staff.get_member("staff_5")

	# Phục vụ giao món đúng một lần, tồn kho đúng.
	var stock: int = sim.state.stock["nuoc_ngot"]
	open_request(sim, "room_02", {"kind": "ORDER", "product_id": "nuoc_ngot", "quantity": 5, "price": 125000}, 30)
	step(sim, balance["staff_delay_order"])
	check(man["task"].get("kind", "") == "DELIVER", "Sau 3 phút: phục vụ nhận đơn gọi món")
	step(sim, 4)
	check(room2["request"].is_empty() and party["bill_items"].size() == 1 and sim.state.stock["nuoc_ngot"] == stock - 5, "Món vào hóa đơn một lần, tồn kho giảm đúng 5")

	# Chủ quán giao trước: phục vụ bỏ việc, không giao trùng.
	open_request(sim, "room_02", {"kind": "ORDER", "product_id": "da", "quantity": 1, "price": 15000}, 30)
	step(sim, balance["staff_delay_order"] + 1)
	check(man["task"].get("kind", "") == "DELIVER" and sim.deliver_order("room_02") == "", "Chủ quán giao trước khi phục vụ tới")
	step(sim, 6)
	check(man["task"].is_empty() and party["bill_items"].size() == 2, "Việc đã có người lo: phục vụ rảnh ngay, không ghi trùng")

	# Phục vụ đổi micro.
	open_request(sim, "room_02", {"kind": "MIC"}, 30)
	step(sim, balance["staff_delay_mic"] + 4)
	check(room2["request"].is_empty() and man["tasks_done"] >= 2, "Phục vụ đổi micro")

	# Lễ tân xếp khách vào phòng hợp túi tiền.
	var guests = sim.customers.add_group("friends", 3, 60, sim.clock.minute)
	step(sim, 1)
	check(ngoc["task"].is_empty() and guests["state"] == "WAITING", "Khách vừa tới: lễ tân chưa xếp ngay (nhường chủ quán)")
	step(sim, balance["staff_delay_seat"] + 2)
	check(guests["state"] == "IN_ROOM" and guests["room_id"] == "room_01", "Lễ tân xếp nhóm bạn bè vào phòng 01 vừa túi tiền")
	check(not guests["tags"].has("gia_cao"), "Lễ tân không xếp phòng vượt ngân sách khi còn phòng vừa túi tiền")
	var nobody = sim.customers.add_group("couple", 2, 60, sim.clock.minute)
	step(sim, 6)
	check(nobody["state"] == "WAITING", "Không còn phòng phù hợp: lễ tân để khách chờ")
	check(sim.check_invariants().is_empty(), "Bất biến ổn với ba loại nhân viên")

	# Giới hạn theo vai trò, lương cuối đêm.
	check(sim.hire_staff("staff_2") == "", "Tuyển thêm tạp vụ thứ hai")
	var other_janitor: Dictionary = {"id": "staff_x", "name": "X", "role": "janitor", "speed": 100, "wage": 1, "starter": false, "about": ""}
	_data["staff"].append(other_janitor)
	check(sim.hire_staff("staff_x").contains("tối đa 2 tạp vụ"), "Mỗi vai trò tối đa 2 người")
	_data["staff"].erase(other_janitor)
	var expected_wages: int = 0
	for member in sim.state.staff:
		expected_wages += member["wage"]
	step(sim, 400)
	check(sim.state.history[0]["wages"] == expected_wages, "Cuối đêm trả lương đủ từng người")
	var all_idle: bool = true
	for member in sim.state.staff:
		all_idle = all_idle and member["task"].is_empty() and member["energy"] == 100
	check(all_idle and sim.economy.ledger_matches_balance(), "Kết ca: không ai còn việc dở, sổ khớp")

func test_regulars() -> void:
	print("Khách quen")
	var balance: Dictionary = _data["balance"]
	var chances: Dictionary = _data["regulars"]["become_chance"]
	var saved_chance: int = chances["bolero_regular"]
	var saved_return: int = balance["regular_return_chance"]
	var saved_favorite: int = balance["regular_favorite_product_chance"]
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
	sim.equip_room("room_03")
	sim.equip_room("room_04")
	sim.economy.record("TEST", 10000000, "gift_save")
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


func test_rooms_and_vip() -> void:
	print("Phòng chưa lắp thiết bị và phòng VIP")
	var balance: Dictionary = _data["balance"]
	var sim = new_sim()
	var ready: int = 0
	var vip: int = 0
	for room in sim.state.rooms:
		ready += 1 if room["state"] == "AVAILABLE" else 0
		vip += 1 if room["tier"] == "vip" else 0
	check(ready == 2 and sim.rooms.unlocked_count() == 2, "Ban đầu: hai phòng hoạt động, tám phòng chưa lắp thiết bị")
	check(vip == 6 and sim.rooms.get_room("room_05")["floor"] == 2 and sim.rooms.get_room("room_04")["tier"] == "standard", "Tầng 1: 4 phòng thường; tầng 2: 6 phòng VIP")
	var info: Dictionary = sim.room_info("room_05")
	check(not info["equipped"] and info["status_text"] == "Chưa lắp thiết bị" and info["equip_button_text"] == "Lắp thiết bị — 6.000.000đ", "Thông tin phòng: nhãn và nút lắp thiết bị")
	check(info["equipment"].size() >= 5 and info["perks"].size() >= 3 and info["upkeep_per_night"] == 600000, "Thông tin phòng VIP: thiết bị, lợi ích, chi phí vận hành")
	check(info["can_equip_now"] and not info["floor_locked"] and info["locked_reason"] == "", "Phòng VIP lắp được ngay khi đủ tiền, không cần danh tiếng")
	var vip_group = sim.customers.add_group("company", 5, 60, 0)
	check(sim.preview_assign(vip_group["id"], "room_05")["reason"].contains("chưa lắp thiết bị"), "Phòng chưa lắp thiết bị không nhận khách")
	sim.economy.record("TEST", 10000000, "gift_vip")
	var money: int = sim.state.money
	check(sim.equip_room("room_05") == "" and sim.state.money == money - 6000000, "Lắp VIP 01: trừ 6.000.000đ đúng một lần")
	check(sim.equip_room("room_05").contains("đã lắp") and sim.state.money == money - 6000000, "Không lắp trùng")
	check(sim.room_info("room_05")["equipped"] and sim.rooms.unlocked_count() == 3, "Lắp xong: phòng sẵn sàng, được tính khi sinh khách")
	sim.equip_room("room_04")
	check(sim.room_info("room_06")["missing_money"] == maxi(0, 8000000 - sim.state.money) and sim.room_info("room_10")["missing_money"] == maxi(0, 16000000 - sim.state.money), "VIP: báo đúng số tiền còn thiếu")
	check(sim.room_info("room_06")["locked_reason"] == "", "Tầng 2 đã mở: không còn lý do khóa")
	sim.open_doors()

	# Cùng một loại nhóm: VIP cho trải nghiệm tốt hơn phòng thường.
	var normal_group = sim.customers.add_group("company", 5, 60, 0)
	check(sim.assign_group(normal_group["id"], "room_04") == "" and sim.assign_group(vip_group["id"], "room_05") == "", "Xếp một nhóm vào phòng thường, một nhóm vào VIP")
	check(vip_group["tags"].has("vip") and not vip_group["tags"].has("gia_cao"), "VIP 500.000đ/giờ vẫn trong ngân sách nới 30% của nhóm 550.000đ")
	check(vip_group["satisfaction"] == normal_group["satisfaction"] + 4 + balance["sound_bonus_per_level"], "VIP: hơn phòng thường +4 sang trọng và +5 âm thanh")
	check(sim.rooms.get_room("room_05")["mic_weight_percent"] == 50 and sim.rooms.get_room("room_05")["soundproof"] == 2, "VIP: micro ít trục trặc hơn, cách âm cấp 2")
	step(sim, 60)
	check(sim.state.last_bill["room_fee"] == 500000 or sim.economy.total_for_day(1, "ROOM_FEE") == 500000 + 420000, "Một giờ VIP 01 thu 500.000đ")

	var couple = sim.customers.add_group("couple", 2, 45, sim.clock.minute)
	var refuse: String = sim.assign_group(couple["id"], "room_02")
	check(refuse.contains("chê giá") and sim.customers.get_group(couple["id"])["state"] == "WAITING", "Cặp đôi 240.000đ từ chối phòng 350.000đ (%s)" % refuse)
	var why: Dictionary = sim.preview_assign(couple["id"], "room_02")
	check(why["block"] == "PRICE" and why["block_text"] == "Khách chê đắt: 350.000đ/giờ", "Xem trước: mã lý do PRICE và nhãn ngắn cho giao diện")
	check(sim.preview_assign(couple["id"], "room_10")["block"] == "STATE" and sim.preview_assign(couple["id"], "room_10")["block_text"] == "Chưa lắp thiết bị", "Xem trước: phòng chưa lắp thiết bị có mã STATE")
	check(sim.assign_group(couple["id"], "room_01") == "", "Chuyển sang phòng vừa túi tiền thì nhận")
	step(sim, 400)
	var summary: Dictionary = sim.state.history[0]
	check(summary["operating"] == operating_cost(sim) and operating_cost(sim) == balance["operating_cost_per_night"] + 3 * 300000 + 600000, "Cuối đêm: mặt bằng + 300.000đ mỗi phòng thường (3 phòng) + 600.000đ phòng VIP đã lắp")
	check(sim.economy.ledger_matches_balance() and sim.check_invariants().is_empty(), "Sổ khớp, bất biến ổn")


func test_ratings() -> void:
	print("Đánh giá sao")
	var sim = new_sim()
	check(sim.rating_text() == "Chưa có đánh giá" and sim.rating_x10() == 0 and sim.recent_reviews().is_empty(), "Chưa có khách: không tự cho sao")
	check(sim.reputation_change_for(95) == 1 and sim.reputation_change_for(80) == 1 and sim.reputation_change_for(65) == 0 and sim.reputation_change_for(50) == -1 and sim.reputation_change_for(10) == -3, "Danh tiếng theo sao: +1, +1, 0, -1, -3")
	sim.state.reputation = 70
	check(sim.reputation_change_for(80) == 0 and sim.reputation_change_for(95) == 1, "Danh tiếng từ 60: chỉ khách 5 sao mới làm quán nổi thêm")
	sim.state.reputation = 40
	check(sim.stars_for(100) == 5 and sim.stars_for(90) == 5 and sim.stars_for(89) == 4 and sim.stars_for(75) == 4 and sim.stars_for(74) == 3 and sim.stars_for(60) == 3 and sim.stars_for(59) == 2 and sim.stars_for(40) == 2 and sim.stars_for(39) == 1 and sim.stars_for(0) == 1, "Mốc quy đổi hài lòng sang sao")
	sim.open_doors()
	var rep: int = sim.state.reputation
	var impatient = sim.customers.add_group("couple", 2, 45, 0)
	step(sim, impatient["patience"])
	check(sim.state.rating_count == 0 and sim.state.reputation < rep, "Khách bỏ về: không tính sao, vẫn trừ danh tiếng")

	var scores: Array = [95, 80, 50]
	for i in scores.size():
		var group = sim.customers.add_group("couple", 2, 45, sim.clock.minute)
		sim.assign_group(group["id"], "room_01")
		if i == 2:
			open_request(sim, "room_01", {"kind": "MIC"}, 5)
			step(sim, 5)
		group["satisfaction"] = scores[i]
		step(sim, 45 - (5 if i == 2 else 0))
		sim.clean_room("room_01")
		step(sim, 8)
	check(sim.state.rating_count == 3 and sim.state.rating_sum == 5 + 4 + 2, "Ba nhóm thanh toán: ba đánh giá 5, 4 và 2 sao")
	check(sim.rating_x10() == 37 and sim.rating_text() == "★ 3,7/5 · 3 đánh giá", "Trung bình 3,7 sao, một chữ số thập phân (%s)" % sim.rating_text())
	var reviews: Array = sim.recent_reviews(2)
	check(reviews.size() == 2 and reviews[0]["stars"] == 2 and reviews[1]["stars"] == 4, "Nhận xét gần đây: mới nhất đứng đầu")
	check(reviews[0]["text"].to_lower().contains("mic") and reviews[0]["who"] != "Cặp đôi", "Nhận xét phản ánh đúng sự việc (micro hỏng)")
	check(sim.state.last_bill["stars"] == 2, "Hóa đơn có số sao của nhóm")
	check(not sim.economy.record("ROOM_FEE", 1, "group:%d" % (sim.state.next_group_id - 1)) and sim.state.rating_count == 3, "Không ghi trùng đánh giá cho cùng một nhóm")
	step(sim, 400)
	var summary: Dictionary = sim.state.history[0]
	check(summary["night_reviews"] == 3 and summary["night_rating_x10"] == 37 and summary["rating_before_x10"] == 0 and summary["rating_after_x10"] == 37, "Tổng kết: điểm riêng của đêm và thay đổi điểm toàn quán")
	check(summary["night_rating_text"] == "★ 3,7/5 · 3 đánh giá" and summary["rating_text"] == sim.rating_text(), "Tổng kết có sẵn dòng hiển thị")
	var again: Dictionary = sim.last_summary()
	check(again["night_reviews"] == 3 and sim.state.rating_count == 3, "Mở lại tổng kết không nhân đôi đánh giá")

	sim.next_day()
	sim.open_doors()
	var star = sim.customers.add_group("couple", 2, 45, 0)
	sim.assign_group(star["id"], "room_01")
	star["satisfaction"] = 100
	step(sim, 400)
	var second: Dictionary = sim.state.history[1]
	check(second["night_rating_x10"] == 50 and second["rating_before_x10"] == 37 and second["rating_after_x10"] == 40 and sim.rating_text() == "★ 4,0/5 · 4 đánh giá", "Đêm 2: đêm 5,0 sao, toàn quán từ 3,7 lên 4,0")
	for i in 60:
		sim.state.reviews.append({"day": 2, "who": "x", "room_name": "y", "stars": 3, "satisfaction": 60, "text": "z"})
	check(sim.recent_reviews(5).size() == 5, "Lấy đúng số nhận xét yêu cầu")


func test_ambience() -> void:
	print("Câu hát và thoại trong phòng")
	var lyrics: Dictionary = _data["lyrics"]
	var per_age: Dictionary = {"young": 0, "middle": 0, "senior": 0}
	var texts: Dictionary = {}
	for line in lyrics["lines"]:
		per_age[line["age"]] += 1
		texts[line["text"]] = true
	check(per_age["young"] >= 15 and per_age["middle"] >= 15 and per_age["senior"] >= 15, "Mỗi nhóm tuổi có ít nhất 15 câu hát (%s)" % str(per_age))
	check(texts.size() == lyrics["lines"].size(), "Không có câu hát trùng nhau")
	for def in _data["hosts"]:
		var lines: Dictionary = _data["banter"]["host_lines"].get(def["id"], {})
		check(lines.has("enter") and lines.has("match") and lines.has("rescue") and lines.has("finish") and lines.has("rest"), "%s có đủ năm loại câu riêng" % def["name"])

	var sim = new_sim(21)
	sim.ambience.enabled = true
	var events: Array = []
	sim.line_spoken.connect(func(event: Dictionary) -> void: events.append(event))
	sim.equip_room("room_03")
	sim.equip_room("room_04")
	sim.hire_host("host_3")
	sim.open_doors()
	var elders = sim.customers.add_group("family", 5, 90, 0, "bolero")
	var kids = sim.customers.add_group("genz", 4, 90, 0, "remix")
	sim.assign_group(elders["id"], "room_02")
	sim.assign_group(kids["id"], "room_01")
	elders["wants_host"] = false
	kids["wants_host"] = false
	var money: int = sim.state.money
	var sat: Array = [elders["satisfaction"], kids["satisfaction"]]
	step(sim, 85)
	var songs: Array = events.filter(func(e: Dictionary) -> bool: return e["kind"] == "SONG")
	check(songs.size() >= 2 and events.size() >= 6 and events.size() <= 14, "Mỗi phòng thỉnh thoảng có câu hát hoặc thoại, không dồn dập (%d câu trong 85 phút, 2 phòng)" % events.size())
	var all_marked: bool = true
	var per_room: Dictionary = {}
	var seen: Dictionary = {}
	var repeated: bool = false
	for event in events:
		if event["kind"] == "SONG":
			all_marked = all_marked and event["text"].begins_with("♪") and event["song_title"] != ""
		else:
			all_marked = all_marked and not event["text"].begins_with("♪")
		repeated = repeated or seen.has(event["text"])
		seen[event["text"]] = true
		per_room[event["room_id"]] = per_room.get(event["room_id"], [])
		per_room[event["room_id"]].append(event["minute"])
	check(all_marked, "Câu hát có ký hiệu ♪ và tên bài; câu trò chuyện thì không")
	check(not repeated, "Không lặp câu trong cùng đêm")
	var spaced: bool = true
	for room_id in per_room:
		for i in range(1, per_room[room_id].size()):
			spaced = spaced and per_room[room_id][i] - per_room[room_id][i - 1] >= 15
	check(spaced and per_room.size() == 2, "Cùng một phòng: các câu cách nhau ít nhất 15 phút game")
	check(elders["satisfaction"] == sat[0] and kids["satisfaction"] == sat[1] and sim.state.money == money, "Thoại trang trí không đổi hài lòng hay tiền")
	var family_ages: Dictionary = {}
	for event in events:
		if event["group_id"] == elders["id"]:
			family_ages[event["speaker_age"]] = true
			check(event["speaker_sprite"] == elders["sprites"][event["speaker_index"] % elders["sprites"].size()], "Người hát là một thành viên cụ thể của nhóm gia đình")
	check(family_ages.size() >= 2, "Nhóm gia đình: người cầm micro thuộc nhiều lứa tuổi khác nhau (%s)" % str(family_ages.keys()))

	# Tuổi và gu nhạc chỉ làm lệch xác suất: thống kê 400 lượt chọn.
	var match_age: int = 0
	var total: int = 0
	var probe = new_sim(77)
	probe.ambience.enabled = true
	var picked: Array = []
	probe.line_spoken.connect(func(event: Dictionary) -> void: picked.append(event))
	probe.open_doors()
	var seniors = probe.customers.add_group("bolero_regular", 2, 90, 0, "bolero")
	seniors["sprites"] = ["uncle"]
	probe.assign_group(seniors["id"], "room_01")
	var age_of: Dictionary = {}
	for line in lyrics["lines"]:
		age_of["♪ %s ♪" % line["text"]] = line["age"]
	for i in 400:
		probe.ambience.reset()
		probe.ambience._rng.seed = i
		probe.ambience._song(probe.rooms.get_room("room_01"), seniors, 10)
	for event in picked:
		total += 1
		match_age += 1 if age_of[event["text"]] == "senior" else 0
	check(total == 400 and match_age > 240 and match_age < 400, "Khách lớn tuổi thích bolero: đa số hát nhạc xưa nhưng vẫn có lúc hát bài khác (%d/400)" % match_age)

	# Micro hỏng: không hát, chỉ có câu phản ứng; có Lan can thì người đó đỡ lời.
	events.clear()
	var room1: Dictionary = sim.rooms.get_room("room_01")
	kids["host_request"] = "PENDING"
	kids["host_gender"] = "any"
	kids["host_requested_count"] = 1
	room1["session_end"] = sim.clock.minute + 60
	check(sim.assign_host("host_3", "room_01") == "", "Cử Bảo Trâm vào phòng Gen Z")
	check(events.size() == 1 and events[0]["kind"] == "LANCAN" and events[0]["host_id"] == "host_3" and events[0]["key"] == "match" and events[0]["speaker_index"] == -1, "Lan can vào phòng hợp gu: nói câu riêng của mình")
	events.clear()
	sim.ambience._next_at["room_01"] = sim.clock.minute + 1
	open_request(sim, "room_01", {"kind": "MIC"}, 30)
	sim.ambience.react(room1, "mic_broken", sim.clock.minute)
	check(events.size() == 1 and events[0]["kind"] == "REACTION" and events[0]["reply_host_id"] == "host_3" and events[0]["reply_text"] == _data["banter"]["host_lines"]["host_3"]["rescue"], "Micro hỏng khi có Lan can: khách than, nhân viên đỡ lời")
	events.clear()
	step(sim, 3)
	var sang_while_broken: bool = false
	for event in events:
		sang_while_broken = sang_while_broken or (event["room_id"] == "room_01" and event["kind"] == "SONG")
	check(not sang_while_broken, "Đang báo micro hỏng thì phòng đó không hiện câu hát")
	check(not sim.ambience.current_line("room_01", sim.clock.minute, 5).is_empty() and sim.ambience.current_line("room_03", sim.clock.minute).is_empty(), "Giao diện hỏi được câu vừa phát của từng phòng")

	# Không làm lệch mô phỏng: bật hay tắt thoại thì diễn biến như nhau.
	var with_lines = new_sim(8, true)
	var without_lines = new_sim(8, true)
	without_lines.ambience.enabled = false
	bot_night(with_lines)
	bot_night(without_lines)
	check(JSON.stringify(with_lines.state.history[0]) == JSON.stringify(without_lines.state.history[0]), "Bật hay tắt thoại trang trí, kết quả đêm giống hệt nhau")


func test_finance() -> void:
	print("Vay ngân hàng và phá sản")
	var balance: Dictionary = _data["balance"]
	var sim = new_sim()
	var info: Dictionary = sim.loan_info()
	check(info["principal"] == 0 and info["limit"] == balance["credit_base"] and info["available"] == balance["credit_base"], "Ban đầu: chưa nợ, hạn mức 10.000.000đ")
	var money: int = sim.state.money
	check(sim.take_loan(info["limit"] + 1).contains("Vượt hạn mức"), "Không vay quá hạn mức")
	check(sim.take_loan(5000000) == "" and sim.state.money == money + 5000000 and sim.state.loan_principal == 5000000, "Vay 5.000.000đ: tiền vào ngay, ghi dư nợ")
	var due: Dictionary = sim.finance.next_payment()
	check(due["interest"] == 125000 and due["principal"] == 500000, "Cuối đêm phải trả lãi 2,5% (125.000đ) và 10% gốc (500.000đ)")
	sim.equip_room("room_05")
	check(sim.loan_info()["limit"] == balance["credit_base"] + 3000000, "Lắp thiết bị nâng hạn mức vay (50% giá trị thiết bị)")
	sim.open_doors()
	check(sim.take_loan(1000000).contains("trước giờ mở cửa") and sim.repay_loan(1000000).contains("trước giờ mở cửa"), "Đang mở cửa: không vay, không trả")
	money = sim.state.money
	step(sim, 360)
	var summary: Dictionary = sim.state.history[0]
	check(summary["loan_interest"] == 125000 and summary["loan_principal_paid"] == 500000 and summary["loan_balance"] == 4500000, "Cuối đêm tự trả lãi và một phần gốc")
	check(summary["profit"] == -_data["staff"][0]["wage"] - operating_cost(sim) - 125000, "Lãi vay tính vào chi phí; trả gốc thì không")
	check(sim.economy.ledger_matches_balance(), "Sổ khớp sau khi trả nợ")
	check(sim.repay_loan(1000000) == "" and sim.state.loan_principal == 3500000, "Trả bớt nợ gốc sau tổng kết")
	check(sim.repay_loan(99000000) == "" and sim.state.loan_principal == 0, "Trả hết nợ (không trả quá dư nợ)")
	check(sim.repay_loan(1).contains("không còn nợ"), "Hết nợ thì không trả thêm")

	# Vay quá nhiều mà làm ăn thua lỗ: âm tiền hai đêm liền thì phá sản.
	var broke = new_sim()
	broke.take_loan(10000000)
	broke.economy.record("TEST", -broke.state.money + 100000, "burn")
	broke.open_doors()
	step(broke, 360)
	check(broke.state.money < 0 and broke.state.negative_nights == 1 and not broke.state.bankrupt and not broke.state.history[0]["bankrupt"], "Đêm 1 âm tiền: cảnh báo, chưa phá sản")
	check(broke.next_day() == "", "Vẫn được sang đêm sau để gỡ")
	broke.open_doors()
	step(broke, 360)
	check(broke.state.bankrupt and broke.state.history[1]["bankrupt"], "Âm tiền hai đêm liền: phá sản")
	check(broke.next_day().contains("phá sản") and broke.open_doors().contains("phá sản") and broke.take_loan(1000000).contains("phá sản"), "Phá sản: không chơi tiếp, không vay thêm")

	# Âm tiền một đêm rồi gỡ lại được thì xóa cảnh báo.
	var saved = new_sim()
	saved.economy.record("TEST", -saved.state.money + 100000, "burn")
	saved.open_doors()
	step(saved, 360)
	check(saved.state.negative_nights == 1, "Âm tiền: bắt đầu đếm")
	saved.next_day()
	check(saved.take_loan(10000000) == "", "Vay để gỡ")
	saved.open_doors()
	step(saved, 360)
	check(saved.state.money >= 0 and saved.state.negative_nights == 0 and not saved.state.bankrupt, "Số dư dương lại: hết cảnh báo")


func test_reviews_and_arrivals() -> void:
	print("Đánh giá kiểu Google Maps và lượng khách theo sao")
	var sim = new_sim(55)
	check(sim.customers.is_tutorial_night() and sim.customers.tutorial_percent() == 55, "Đêm 1 là đêm tập: khách tới bằng 55%")
	sim.state.day = 2
	check(sim.customers.tutorial_percent() == 75, "Đêm 2: khách tới bằng 75%")
	sim.state.day = 3
	check(not sim.customers.is_tutorial_night() and sim.customers.tutorial_percent() == 100 and sim.theft_risk_active(), "Từ đêm 3: khách bình thường và bắt đầu có trộm")
	sim.state.day = 2
	check(not sim.theft_risk_active(), "Hai đêm tập không có trộm")
	sim.state.day = 1
	check(sim.customers.arrival_percent() == 100, "Chưa có đánh giá: lượng khách bình thường")
	sim.state.rating_sum = 45
	sim.state.rating_count = 10
	check(sim.customers.arrival_percent() == 145, "4,5 sao: khách tới nhiều hơn (giới hạn trên 145%)")
	sim.state.rating_sum = 40
	check(sim.customers.arrival_percent() == 130, "4,0 sao: +30% khách")
	sim.state.rating_sum = 30
	check(sim.customers.arrival_percent() == 100, "3,0 sao: bình thường")
	sim.state.rating_sum = 20
	check(sim.customers.arrival_percent() == 70, "2,0 sao: -30% khách")
	sim.state.rating_sum = 10
	check(sim.customers.arrival_percent() == 65, "1,0 sao: giới hạn dưới 65%")
	sim.state.rating_sum = 0
	sim.state.rating_count = 0

	# Cùng số nhóm, quán 4,5 sao có nhiều khách hơn quán 2 sao.
	var counts: Array = []
	for stars_x10 in [20, 45]:
		var probe = new_sim(77, true)
		probe.service.enabled = false
		probe.state.rating_sum = stars_x10
		probe.state.rating_count = 10
		var arrived: Dictionary = {}
		probe.open_doors()
		for i in 300:
			probe.step_minute()
			for group in probe.state.groups:
				arrived[group["id"]] = true
		counts.append(arrived.size() + probe.state.night["unserved"])
	check(counts[1] > counts[0] * 1.4, "Quán nhiều sao đón nhiều khách hơn rõ rệt (%d so với %d nhóm)" % [counts[1], counts[0]])

	# Đánh giá: tên kiểu Google Maps, không trùng tên và không lặp câu trong các đánh giá gần đây.
	var play = new_sim(91, true)
	for night in 3:
		bot_night(play)
		play.next_day()
	var names: Dictionary = {}
	var texts: Dictionary = {}
	var group_names_used: bool = false
	for review in play.state.reviews:
		names[review["who"]] = true
		texts[review["text"]] = true
		group_names_used = group_names_used or review["who"] == review["group_name"]
	var total: int = play.state.reviews.size()
	check(total >= 20, "Có đủ đánh giá để thống kê (%d)" % total)
	check(not group_names_used and play.state.reviews[0].has("badge"), "Người đánh giá có tên riêng và số bài đánh giá, không dùng tên nhóm khách")
	check(names.size() >= total * 9 / 10, "Gần như không trùng tên người đánh giá (%d tên/%d)" % [names.size(), total])
	check(texts.size() == total, "Không có hai đánh giá giống hệt nhau (%d câu/%d)" % [texts.size(), total])
	var close_repeat: int = 0
	for i in play.state.reviews.size():
		for j in range(maxi(0, i - 8), i):
			if play.state.reviews[i]["main"] == play.state.reviews[j]["main"]:
				close_repeat += 1
	check(close_repeat <= total / 20, "Câu chính gần như không lặp trong 8 đánh giá liền nhau (%d lần lặp)" % close_repeat)
	var consistent: bool = true
	for review in play.state.reviews:
		if review["text"].contains("mất xe") or review["text"].contains("xe mất"):
			consistent = consistent and review["stars"] <= 3
	check(consistent, "Đánh giá kể chuyện mất xe đi kèm số sao thấp")


func test_tips() -> void:
	print("Tip của Lan can")
	var balance: Dictionary = _data["balance"]
	var shares: Dictionary = {"match": 0, "mismatch": 0}
	var counts: Dictionary = {"match": 0, "mismatch": 0}
	for trial in 120:
		var sim = new_sim(500 + trial)
		sim.equip_room("room_03")
		sim.equip_room("room_04")
		sim.economy.record("TEST", 10000000, "fund")
		sim.hire_host("host_3")
		sim.open_doors()
		var music: String = "remix" if trial % 2 == 0 else "bolero"
		var group = sim.customers.add_group("genz", 3, 90, 0, music)
		sim.assign_group(group["id"], "room_01")
		group["host_request"] = "PENDING"
		group["host_gender"] = "any"
		group["host_requested_count"] = 1
		sim.assign_host("host_3", "room_01")
		step(sim, balance["lancan_minutes"])
		var key: String = "match" if music == "remix" else "mismatch"
		var house: int = 0
		for item in group["bill_items"]:
			if item["type"] == "TIP_SHARE":
				house += item["amount"]
		counts[key] += 1 if house > 0 else 0
		var host: Dictionary = sim.hosts.get_host("host_3")
		if house > 0:
			shares[key] += 1 if abs(host["tips_total"] - house) <= 1000 else 0
		step(sim, 70)
		if trial == 0:
			check(sim.economy.total_for_day(1, "TIP_SHARE") == house and sim.state.history.is_empty(), "Phần tip của quán vào sổ khi khách thanh toán")
	check(counts["match"] > counts["mismatch"] + 15, "Hợp gu khách thì được tip thường xuyên hơn (%d so với %d/60 lượt)" % [counts["match"], counts["mismatch"]])
	check(shares["match"] == counts["match"] and shares["mismatch"] == counts["mismatch"], "Quán và nhân viên chia đôi tiền tip")


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
