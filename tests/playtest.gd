extends SceneTree
## Chơi thử tự động nhiều đêm để soi cân bằng (không phải kiểm thử đạt/trượt).
## Chạy: godot --headless --path . --script res://tests/playtest.gd -- [seed] [số_đêm]

const DataLoader = preload("res://scripts/core/data_loader.gd")
const Simulation = preload("res://scripts/core/simulation.gd")
const Money = preload("res://scripts/core/money.gd")


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var game_seed: int = int(args[0]) if args.size() > 0 else 1
	var nights: int = int(args[1]) if args.size() > 1 else 7
	var data: Dictionary = DataLoader.load_all()
	var sim = Simulation.new(data, game_seed)
	var stats: Dictionary = {"refused_price": 0, "lines": 0, "songs": 0}
	sim.line_spoken.connect(func(event: Dictionary) -> void:
		stats["lines"] += 1
		stats["songs"] += 1 if event["kind"] == "SONG" else 0)
	for night in nights:
		# Chuẩn bị: lắp phòng rẻ nhất còn thiếu nếu còn dư 3 triệu, nhập hàng, bảo vệ từ đêm 2, tuyển thêm phục vụ.
		for room in sim.state.rooms:
			var info: Dictionary = sim.room_info(room["id"])
			if not info["equipped"] and sim.state.money - info["equip_cost"] >= 3000000:
				sim.equip_room(room["id"])
				break
		for product in data["products"]:
			if sim.state.stock[product["id"]] < product["pack_size"]:
				sim.buy_stock(product["id"])
		if sim.theft_risk_active() and not sim.state.guard_hired:
			sim.set_guard(true)
		if night == 2:
			sim.hire_staff("staff_2")
			sim.hire_host("host_1")
		sim.open_doors()
		while sim.state.phase == "OPEN":
			for room in sim.state.rooms:
				if not room["request"].is_empty():
					match room["request"]["kind"]:
						"HOT":
							sim.answer_request(room["id"], "ac")
						"EXTEND":
							sim.answer_request(room["id"], "accept" if sim.customers.waiting_groups().is_empty() else "decline")
						"MIC":
							if sim.clock.minute % 3 == 0:
								sim.fix_mic(room["id"])
						"ORDER":
							if sim.clock.minute % 4 == 0:
								sim.deliver_order(room["id"])
			for host in sim.state.hosts:
				for room in sim.state.rooms:
					sim.assign_host(host["id"], room["id"])
			for group in sim.customers.waiting_groups():
				var placed: bool = false
				var tried_refused: bool = false
				for room in sim.state.rooms:
					var reason: String = sim.assign_group(group["id"], room["id"])
					if reason == "":
						placed = true
						break
					tried_refused = tried_refused or reason.contains("chê giá")
				if not placed and tried_refused and group["wait_minutes"] == 0:
					stats["refused_price"] += 1
			sim.step_minute()
		var s: Dictionary = sim.last_summary()
		print("Đêm %d: phục vụ %2d, bỏ về %2d | phòng %s, món %s, LC %s | chi lương %s vận hành %s | lãi %s | số dư %s | danh tiếng %d | sao đêm %s | quán %s | khách quen %d | mục tiêu %s" % [
			s["day"], s["served"], s["unserved"], Money.format(s["room_revenue"]), Money.format(s["order_revenue"]), Money.format(s["lancan_revenue"]),
			Money.format(s["wages"]), Money.format(s["operating"]), Money.format(s["profit"]), Money.format(s["balance"]), s["reputation"],
			s["night_rating_text"], sim.rating_text(), sim.state.regulars.size(), "đạt" if s["goal_met"] else "trượt"])
		var problems: Array = sim.check_invariants()
		if not problems.is_empty():
			print("  BẤT BIẾN: ", problems)
		sim.next_day()
	var equipped: int = sim.rooms.unlocked_count()
	print("Phòng đã lắp: %d/6 · nhóm chê giá ngay lần đầu (ước lượng): %d · câu thoại: %d (câu hát %d) · nhân viên đã làm: %s" % [equipped, stats["refused_price"], stats["lines"], stats["songs"], str(sim.state.staff.map(func(m): return [m["name"], m["tasks_done"]]))])
	var stars: Dictionary = {}
	for review in sim.state.reviews:
		stars[review["stars"]] = stars.get(review["stars"], 0) + 1
	print("Phân bố sao 40 nhận xét gần nhất: ", stars)
	quit()
