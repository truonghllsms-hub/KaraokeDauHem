extends SceneTree
## Chơi thử tự động theo kiểu người chơi để soi cân bằng (không phải kiểm thử đạt/trượt).
## Chủ quán của bot cũng mất thời gian làm từng việc như người thật.
## Chạy: godot --headless --path . --script res://tests/playtest.gd -- <kiểu> <seed> <số_đêm>
## Kiểu: novice (người mới: chậm, hay quên) | careful (cẩn thận) | loan (vay để mở rộng) | reckless (vay liều) | gambler (vay liều, làm ăn kém) | lazy (lười)

const DataLoader = preload("res://scripts/core/data_loader.gd")
const Simulation = preload("res://scripts/core/simulation.gd")
const Money = preload("res://scripts/core/money.gd")

var style: String = "careful"
var sim
var busy_until: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	style = args[0] if args.size() > 0 else "careful"
	var game_seed: int = int(args[1]) if args.size() > 1 else 1
	var nights: int = int(args[2]) if args.size() > 2 else 10
	rng.seed = game_seed * 31 + 7
	var data: Dictionary = DataLoader.load_all()
	sim = Simulation.new(data, game_seed)
	var line: String = ""
	for night in nights:
		prepare(night)
		play_night()
		var s: Dictionary = sim.last_summary()
		print("%-8s seed %d đêm %2d | phòng %2d | khách %2d/%2d bỏ | thu %s | lãi đêm %s | tiền %s | nợ %s | sao %s | khách đến %d%% | danh tiếng %d | trộm %d/%d bắt | NV %d%s" % [
			style, game_seed, s["day"], sim.rooms.unlocked_count(), s["served"], s["unserved"],
			Money.format(s["room_revenue"] + s["order_revenue"] + s["lancan_revenue"] + s.get("tip_share", 0)),
			Money.format(s["profit"]), Money.format(sim.state.money), Money.format(sim.state.loan_principal),
			sim.rating_text().replace(" đánh giá", ""), sim.customers.demand_percent(), sim.state.reputation, s["thefts"], s.get("thieves_caught", 0),
			sim.state.staff.size() + sim.state.hosts.size(), " | PHÁ SẢN" if s["bankrupt"] else (" | ÂM TIỀN" if sim.state.money < 0 else "")])
		if s["bankrupt"]:
			break
		sim.next_day()
	quit()


func cheapest_locked() -> Dictionary:
	var best: Dictionary = {}
	for room in sim.state.rooms:
		if room["state"] == "LOCKED" and (best.is_empty() or room["unlock_cost"] < best["unlock_cost"]):
			best = room
	return best


func prepare(night: int) -> void:
	var balance: Dictionary = sim.data["balance"]
	# Nhập hàng còn thiếu.
	for product in sim.data["products"]:
		if sim.state.stock[product["id"]] < product["pack_size"] / 2 and style != "lazy":
			sim.buy_stock(product["id"])
	match style:
		"careful", "novice":
			var room: Dictionary = cheapest_locked()
			if not room.is_empty() and sim.state.money >= room["unlock_cost"] + 6000000:
				sim.equip_room(room["id"])
		"loan":
			var room: Dictionary = cheapest_locked()
			if not room.is_empty() and sim.rooms.unlocked_count() < 6:
				var need: int = room["unlock_cost"] + 4000000 - sim.state.money
				if need > 0 and sim.loan_info()["available"] >= need:
					sim.take_loan(mini(sim.loan_info()["available"], ((need + 4999999) / 5000000) * 5000000))
				if sim.state.money >= room["unlock_cost"] + 4000000:
					sim.equip_room(room["id"])
			# Dư dả thì trả bớt nợ.
			if sim.state.loan_principal > 0 and sim.state.money > 14000000:
				sim.repay_loan(mini(sim.state.loan_principal, sim.state.money - 10000000))
		"reckless", "gambler":
			if sim.loan_info()["available"] > 0:
				sim.take_loan(sim.loan_info()["available"])
			var room: Dictionary = cheapest_locked()
			while not room.is_empty() and sim.state.money >= room["unlock_cost"]:
				sim.equip_room(room["id"])
				room = cheapest_locked()
				if sim.loan_info()["available"] > 0:
					sim.take_loan(sim.loan_info()["available"])
		"lazy":
			pass
	# Nhân sự: bảo vệ từ đêm 2, phục vụ và lễ tân khi quán lớn dần, Lan can khi đủ phòng tầng 1.
	if style != "lazy" and style != "gambler":
		if sim.theft_risk_active() and style != "reckless" and (style != "novice" or sim.state.day >= 4):
			sim.set_guard(true)
		if sim.rooms.unlocked_count() >= 3:
			sim.hire_staff("staff_3")
		if sim.rooms.unlocked_count() >= 4:
			sim.hire_staff("staff_5")
		if sim.rooms.unlocked_count() >= 6:
			sim.hire_staff("staff_2")
		if sim.lancan_lock_reason() == "" and sim.state.hosts.size() < 2:
			for host in ["host_1", "host_4"]:
				sim.hire_host(host)
	if style == "reckless":
		for id in ["staff_3", "staff_5", "staff_2", "staff_4", "staff_6"]:
			sim.hire_staff(id)
		for host in ["host_1", "host_3", "host_4", "host_8"]:
			sim.hire_host(host)
	busy_until = 0


func owner_act(now: int) -> void:
	if now < busy_until:
		return
	var lax: bool = style == "lazy" or style == "gambler"
	var reaction_ok: bool = rng.randi_range(1, 100) <= (60 if lax else (45 if style == "novice" else 85))
	var slow: int = 2 if style == "novice" else 0
	# Trộm: chạy ra đuổi nếu để ý thấy.
	if sim.security.is_active() and sim.state.thief["catch_at"] < 0 and reaction_ok and not lax:
		if sim.chase_thief() == "":
			busy_until = now + 3 + slow
			return
	for room in sim.state.rooms:
		if room["request"].is_empty():
			continue
		match room["request"]["kind"]:
			"HOT":
				sim.answer_request(room["id"], "ac")
			"EXTEND":
				sim.answer_request(room["id"], "accept" if sim.customers.waiting_groups().is_empty() else "decline")
	# Việc ưu tiên: xếp khách (2'), micro (2'), giao món (3'), dọn phòng (8').
	for group in sim.customers.waiting_groups():
		var best: String = ""
		var best_price: int = -1
		for room in sim.state.rooms:
			var preview: Dictionary = sim.preview_assign(group["id"], room["id"])
			if preview["reason"] == "" and not preview["over_budget"] and room["price_per_hour"] > best_price:
				best = room["id"]
				best_price = room["price_per_hour"]
		if best == "":
			for room in sim.state.rooms:
				if sim.preview_assign(group["id"], room["id"])["reason"] == "":
					best = room["id"]
					break
		if best != "" and sim.assign_group(group["id"], best) == "":
			busy_until = now + 2 + slow
			return
	if not lax:
		for room in sim.state.rooms:
			if not room["request"].is_empty() and room["request"]["kind"] == "MIC" and sim.fix_mic(room["id"]) == "":
				busy_until = now + 2
				return
		for room in sim.state.rooms:
			if style == "novice" and rng.randi_range(1, 100) > 60:
				continue
			if not room["request"].is_empty() and room["request"]["kind"] == "ORDER" and sim.deliver_order(room["id"]) == "":
				busy_until = now + 3 + slow
				return
		for host in sim.state.hosts:
			for room in sim.state.rooms:
				if sim.assign_host(host["id"], room["id"]) == "":
					return
	for room in sim.state.rooms:
		if room["state"] == "DIRTY" and sim.clean_room(room["id"]) == "":
			busy_until = now + sim.data["balance"]["clean_minutes"]
			return


func play_night() -> void:
	sim.open_doors()
	var guard: int = 0
	while sim.state.phase == "OPEN" and guard < 1000:
		guard += 1
		owner_act(sim.clock.minute)
		sim.step_minute()
