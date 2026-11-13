extends RefCounted
## Bộ điều phối mô phỏng. Giao diện và kiểm thử headless đều gọi cùng các hàm ở đây,
## nên chỉ có một bộ quy tắc. Các hàm hành động trả về "" khi thành công,
## hoặc lý do thất bại bằng tiếng Việt để giao diện hiển thị.

signal message(text: String, kind: String)
signal night_ended(summary: Dictionary)
signal bill_paid(bill: Dictionary)
## Phát sau mỗi lần lưu (tự động hoặc thủ công). error rỗng là lưu thành công.
signal game_saved(path: String, error: String)

const GameState = preload("res://scripts/core/game_state.gd")
const Clock = preload("res://scripts/core/simulation_clock.gd")
const Money = preload("res://scripts/core/money.gd")
const EconomySystem = preload("res://scripts/systems/economy_system.gd")
const RoomSystem = preload("res://scripts/systems/room_system.gd")
const CustomerSystem = preload("res://scripts/systems/customer_system.gd")
const HospitalitySystem = preload("res://scripts/systems/hospitality_system.gd")
const ServiceSystem = preload("res://scripts/systems/service_system.gd")
const StaffSystem = preload("res://scripts/systems/staff_system.gd")
const RegularSystem = preload("res://scripts/systems/regular_system.gd")
const SaveManager = preload("res://scripts/core/save_manager.gd")

const MAX_MESSAGES: int = 60
## Các loại giao dịch tính vào lợi nhuận vận hành của một đêm.
const OPERATING_TYPES: Array = ["ROOM_FEE", "ORDER", "LANCAN_FEE", "DISCOUNT", "STOCK", "WAGES", "OPERATING", "UTILITIES", "COMPENSATION"]
## Lời nhận xét của khách theo dấu vết trải nghiệm; mục đứng trước được ưu tiên.
const COMMENTS: Array = [
	["mat_xe", "Ra về thì mất xe ngay trước quán, hết hồn luôn."],
	["micro", "Micro hú hoài mà không ai lo."],
	["cho_do", "Gọi đồ mà chờ mỏi cổ không thấy."],
	["cho_phong", "Chờ phòng lâu quá trời."],
	["het_hang", "Gọi gì quán cũng báo hết."],
	["nong", "Phòng nóng như cái lò."],
	["gia_cao", "Giá hơi chát so với túi tiền tụi mình."],
	["lancan_lo", "Gọi Lan can mà chẳng thấy ai."],
	["phong_quen", "Vẫn phòng quen, vẫn dễ thương như mọi lần."],
	["giao_nhanh", "Gọi đá có liền, ưng cái bụng!"],
	["lancan", "Bạn Lan can khuấy động vui hết nấc."],
	["hat_them", "Được hát thêm nửa tiếng, quán dễ thương ghê."],
	["gia_mem", "Giá mềm, lần sau rủ cả hội tới."],
]

var data: Dictionary
var state
var clock
var economy
var rooms
var customers
var hosts
var service
var staff
var regulars
## Đặt đường dẫn (ví dụ SaveManager.DEFAULT_PATH) để tự lưu sau mỗi lần tổng kết đêm. Rỗng là tắt.
var autosave_path: String = ""
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(p_data: Dictionary, p_seed: int) -> void:
	data = p_data
	rng.seed = p_seed
	state = GameState.new()
	state.rng_seed = p_seed
	clock = Clock.new()
	economy = EconomySystem.new(state, clock)
	rooms = RoomSystem.new(state, data)
	customers = CustomerSystem.new(state, data, rng, rooms, Callable(self, "notify"))
	hosts = HospitalitySystem.new(state, data, rng, economy, customers, rooms, Callable(self, "notify"))

	service = ServiceSystem.new(state, data, rng, economy, customers, Callable(self, "notify"), Callable(self, "_change_satisfaction"))

	var balance: Dictionary = data["balance"]
	state.reputation = balance["starting_reputation"]
	rooms.setup_new_game()
	service.setup_new_game()
	staff = StaffSystem.new(state, data, economy, rooms, service, Callable(self, "notify"))
	staff.setup_new_game()
	regulars = RegularSystem.new(state, data, rng, Callable(self, "notify"))
	customers.regulars = regulars
	economy.record("OPENING", balance["starting_money"], "new_game", "Vốn ban đầu")
	_begin_day()


func notify(text: String, kind: String = "info") -> void:
	state.messages.append({"day": state.day, "minute": clock.minute, "text": text, "kind": kind})
	if state.messages.size() > MAX_MESSAGES:
		state.messages.pop_front()
	message.emit(text, kind)


# ---------------------------------------------------------------- Vòng đời một đêm

func open_doors() -> String:
	if state.phase != "PREP":
		return "Quán đang mở cửa rồi."
	state.phase = "OPEN"
	notify("Đêm %d: bật biển hiệu, mở cửa đón khách!" % state.day, "good")
	return ""


## Gọi mỗi khung hình với thời gian thực; đồng hồ quyết định mô phỏng bao nhiêu phút.
func advance(real_seconds: float) -> void:
	if state.phase != "OPEN":
		return
	var steps: int = clock.advance(real_seconds)
	for i in steps:
		step_minute()
		if state.phase != "OPEN":
			break


## Mô phỏng đúng một phút game. Kiểm thử gọi trực tiếp hàm này.
func step_minute() -> void:
	if state.phase != "OPEN":
		return
	clock.minute += 1
	var now: int = clock.minute

	for room in rooms.tick(now):
		notify("%s đã dọn xong, sẵn sàng đón khách." % room["name"], "good")

	# Lan can chạy trước thanh toán, để phiên kết thúc cùng phút vẫn kịp vào hóa đơn.
	hosts.tick(now)
	service.tick(now)
	staff.tick(now)

	for room in state.rooms:
		if room["state"] == "OCCUPIED" and now >= room["session_end"]:
			_checkout(room, now)

	customers.tick(now)

	if now >= Clock.NIGHT_MINUTES:
		_close_night()


func next_day() -> String:
	if state.phase != "SUMMARY":
		return "Chưa tổng kết đêm nay."
	state.day += 1
	_begin_day()
	return ""


func _begin_day() -> void:
	state.phase = "PREP"
	clock.reset()
	state.next_arrival_minute = data["balance"]["first_arrival_minute"]
	hosts.begin_day()
	state.night = {
		"served": 0,
		"unserved": 0,
		"satisfaction_sum": 0,
		"reputation_start": state.reputation,
		"comments": [],
		"thefts": 0,
		"guard_on_duty": state.guard_hired,
		"goal_served": mini(data["balance"]["goal_base"] + state.day, data["balance"]["goal_max"]),
		"goal_unserved_max": data["balance"]["goal_unserved_max"],
	}


func goal_text() -> String:
	return "Phục vụ ít nhất %d nhóm, không để quá %d nhóm bỏ về" % [state.night["goal_served"], state.night["goal_unserved_max"]]


func _close_night() -> void:
	var now: int = clock.minute
	var balance: Dictionary = data["balance"]

	# Kết thúc mọi lượt còn lại, tính tiền theo thời gian sử dụng thực tế.
	for room in state.rooms:
		if room["state"] == "OCCUPIED":
			_checkout(room, now)
	customers.clear_waiting_at_close()

	# Kết ca: dọn nốt các phòng để sáng mai sẵn sàng.
	for room in state.rooms:
		if room["state"] == "DIRTY" or room["state"] == "CLEANING":
			rooms.finish_cleaning(room)

	var day_key: String = "day:%d" % state.day
	staff.end_night(state.day)
	hosts.end_night(state.day)
	if state.night["guard_on_duty"]:
		economy.record("WAGES", -balance["guard_wage"], day_key + ":guard", "Lương bảo vệ")
	economy.record("OPERATING", -balance["operating_cost_per_night"], day_key, "Điện, nước, mặt bằng")

	var served: int = state.night["served"]
	var goal_met: bool = served >= state.night["goal_served"] and state.night["unserved"] <= state.night["goal_unserved_max"]
	if goal_met:
		state.reputation = clampi(state.reputation + balance["goal_reputation_bonus"], 0, 100)

	var profit: int = 0
	for type in OPERATING_TYPES:
		profit += economy.total_for_day(state.day, type)
	var summary: Dictionary = {
		"day": state.day,
		"room_revenue": economy.total_for_day(state.day, "ROOM_FEE"),
		"order_revenue": economy.total_for_day(state.day, "ORDER"),
		"lancan_revenue": economy.total_for_day(state.day, "LANCAN_FEE"),
		"discounts": -economy.total_for_day(state.day, "DISCOUNT"),
		"stock_cost": -economy.total_for_day(state.day, "STOCK"),
		"wages": -economy.total_for_day(state.day, "WAGES"),
		"operating": -economy.total_for_day(state.day, "OPERATING") - economy.total_for_day(state.day, "UTILITIES"),
		"compensation": -economy.total_for_day(state.day, "COMPENSATION"),
		"profit": profit,
		"served": served,
		"unserved": state.night["unserved"],
		"thefts": state.night["thefts"],
		"avg_satisfaction": (state.night["satisfaction_sum"] / served) if served > 0 else 0,
		"reputation": state.reputation,
		"reputation_change": state.reputation - state.night["reputation_start"],
		"goal": goal_text(),
		"goal_met": goal_met,
		"comments": _pick_comments(),
		"balance": state.money,
	}
	state.history.append(summary)
	state.phase = "SUMMARY"
	notify("Hết giờ, quán đóng cửa. Tổng kết đêm %d." % state.day, "info")
	if autosave_path != "":
		save_game(autosave_path)
	night_ended.emit(summary)


## Chọn tối đa ba lời nhận xét: nhóm kém hài lòng nhất, nhóm hài lòng nhất, và một nhóm khác.
func _pick_comments() -> Array:
	var all: Array = state.night["comments"].duplicate()
	all.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["satisfaction"] < b["satisfaction"])
	if all.size() <= 3:
		return all
	@warning_ignore("integer_division")
	return [all[0], all[all.size() / 2], all[all.size() - 1]]


# ---------------------------------------------------------------- Hành động của người chơi

func assign_group(group_id: int, room_id: String) -> String:
	if state.phase != "OPEN":
		return "Quán chưa mở cửa."
	var group = customers.get_group(group_id)
	if group == null or group["state"] != "WAITING":
		return "Nhóm khách này không còn chờ ở quầy."
	var room = rooms.get_room(room_id)
	if room == null:
		return "Không tìm thấy phòng."
	var now: int = clock.minute
	var reason: String = rooms.check_assign(room, group, now, Clock.NIGHT_MINUTES)
	if reason != "":
		return reason

	rooms.start_session(room, group, now)
	group["state"] = "IN_ROOM"
	group["room_id"] = room["id"]
	group["next_request_at"] = now + rng.randi_range(data["balance"]["first_request_min"], data["balance"]["first_request_max"])
	notify("Nhóm %s (%d người) vào %s, hát %d phút." % [group["type_name"], group["size"], room["name"], group["planned_minutes"]], "info")
	_rate_seating(group, room)
	return ""


## Xem trước khi xếp phòng: lý do không xếp được (nếu có), tiền phòng dự kiến và có vượt ngân sách không.
func preview_assign(group_id: int, room_id: String) -> Dictionary:
	var group = customers.get_group(group_id)
	var room = rooms.get_room(room_id)
	if group == null or room == null:
		return {"reason": "Không tìm thấy nhóm hoặc phòng.", "estimate": 0, "over_budget": false}
	return {
		"reason": rooms.check_assign(room, group, clock.minute, Clock.NIGHT_MINUTES),
		"estimate": Money.room_fee(room["price_per_hour"], group["planned_minutes"]),
		"over_budget": room["price_per_hour"] > group["budget_per_hour"],
	}


func deliver_order(room_id: String) -> String:
	var room = rooms.get_room(room_id)
	return "Không tìm thấy phòng." if room == null else service.deliver_order(room, clock.minute)


func fix_mic(room_id: String) -> String:
	var room = rooms.get_room(room_id)
	return "Không tìm thấy phòng." if room == null else service.fix_mic(room, clock.minute)


func answer_request(room_id: String, choice: String) -> String:
	var room = rooms.get_room(room_id)
	return "Không tìm thấy phòng." if room == null else service.answer(room, choice)


func buy_stock(product_id: String) -> String:
	return service.buy_stock(product_id)


func buy_upgrade(upgrade_id: String) -> String:
	return service.buy_upgrade(upgrade_id)


## Thuê hoặc cho bảo vệ nghỉ. Đêm nào có bảo vệ trực (dù chỉ một lúc) thì trả lương đêm đó.
func set_guard(hired: bool) -> String:
	state.guard_hired = hired
	if hired:
		state.night["guard_on_duty"] = true
		notify("Chú bảo vệ nhận ca trông xe (lương %s/đêm)." % Money.format(data["balance"]["guard_wage"]), "good")
	else:
		notify("Cho bảo vệ nghỉ từ đêm sau. Sân xe không ai trông.", "info")
	return ""


func hire_staff(staff_id: String) -> String:
	return staff.hire(staff_id)


## Đánh dấu một phòng để nhân viên rảnh kế tiếp lo ngay (dọn, giao món hoặc đổi micro).
func prioritize_job(room_id: String) -> String:
	return staff.prioritize(room_id)


## Bảng tổng kết của đêm gần nhất ({} nếu chưa có đêm nào).
func last_summary() -> Dictionary:
	return {} if state.history.is_empty() else state.history[state.history.size() - 1]


# ---------------------------------------------------------------- Lưu và tải

## Lưu ở mốc chuẩn bị hoặc sau tổng kết. Trả về "" nếu thành công.
func save_game(path: String = SaveManager.DEFAULT_PATH) -> String:
	var error: String = ""
	if not SaveManager.SAVEABLE_PHASES.has(state.phase):
		error = "Chỉ lưu được trước khi mở cửa hoặc sau tổng kết đêm."
	else:
		error = SaveManager.write_snapshot(SaveManager.make_snapshot(state, rng), path)
	game_saved.emit(path, error)
	return error


## Nạp một bản chụp đã qua SaveManager.validate vào bộ mô phỏng này. Trả về "" nếu thành công.
func restore(snapshot: Dictionary) -> String:
	var error: String = SaveManager.validate(snapshot, data)
	if error != "":
		return error
	var saved: Dictionary = snapshot["state"]
	for field in SaveManager.STATE_FIELDS:
		var value = saved[field]
		state.set(field, value.duplicate(true) if (value is Array or value is Dictionary) else value)
	state.rng_seed = int(str(snapshot["rng_seed"]))
	rng.seed = state.rng_seed
	rng.state = int(str(snapshot["rng_state"]))
	state.messages = []
	clock.reset()
	if state.phase == "SUMMARY":
		clock.minute = Clock.NIGHT_MINUTES
	var problems: Array = check_invariants()
	if not problems.is_empty():
		return "Bản lưu không nhất quán: " + problems[0]
	return ""


## Tạo bộ mô phỏng từ bản lưu. Trả về {"ok", "sim", "error", "used_backup", "notice"}.
static func create_from_save(p_data: Dictionary, path: String = SaveManager.DEFAULT_PATH) -> Dictionary:
	var loaded: Dictionary = SaveManager.read_save(p_data, path)
	if not loaded["ok"]:
		return {"ok": false, "sim": null, "error": loaded["error"], "used_backup": false, "notice": ""}
	var sim = new(p_data, 0)
	var error: String = sim.restore(loaded["snapshot"])
	if error != "":
		return {"ok": false, "sim": null, "error": error, "used_backup": loaded["used_backup"], "notice": ""}
	return {"ok": true, "sim": sim, "error": "", "used_backup": loaded["used_backup"], "notice": loaded["notice"]}


func theft_risk_active() -> bool:
	return state.day >= data["balance"]["theft_start_day"]


func clean_room(room_id: String) -> String:
	var room = rooms.get_room(room_id)
	if room == null:
		return "Không tìm thấy phòng."
	return rooms.start_cleaning(room, clock.minute)


func unlock_room(room_id: String) -> String:
	var room = rooms.get_room(room_id)
	if room == null:
		return "Không tìm thấy phòng."
	if room["state"] != "LOCKED":
		return "%s đã mở rồi." % room["name"]
	var cost: int = room["unlock_cost"]
	if not economy.can_afford(cost):
		return "Không đủ tiền: mở %s cần %s." % [room["name"], Money.format(cost)]
	if not economy.record("UNLOCK_ROOM", -cost, room["id"], "Mở " + room["name"]):
		return "%s đã được thanh toán trước đó." % room["name"]
	room["state"] = "AVAILABLE"
	notify("Đã mở %s (sức chứa %d người)." % [room["name"], room["capacity"]], "good")
	return ""


func hire_host(host_id: String) -> String:
	return hosts.hire(host_id)


func assign_host(host_id: String, room_id: String) -> String:
	if state.phase != "OPEN":
		return "Quán chưa mở cửa."
	var host = hosts.get_host(host_id)
	var room = rooms.get_room(room_id)
	if host == null or room == null:
		return "Không tìm thấy nhân viên hoặc phòng."
	var reason: String = hosts.check_assign(host, room, clock.minute)
	if reason != "":
		return reason
	hosts.assign(host, room, clock.minute)
	return ""


## Chỉ chỉnh giá ở giai đoạn chuẩn bị, để không đổi giá giữa lượt hát.
func change_price(room_id: String, steps: int) -> String:
	if state.phase != "PREP":
		return "Chỉ chỉnh giá được trước khi mở cửa."
	var room = rooms.get_room(room_id)
	if room == null or room["state"] == "LOCKED":
		return "Phòng chưa mở."
	var balance: Dictionary = data["balance"]
	var price: int = room["price_per_hour"] + steps * balance["price_step"]
	if price < balance["price_min"] or price > balance["price_max"]:
		return "Giá phòng phải từ %s đến %s." % [Money.format(balance["price_min"]), Money.format(balance["price_max"])]
	room["price_per_hour"] = price
	return ""


# ---------------------------------------------------------------- Nội bộ

func _checkout(room: Dictionary, now: int) -> void:
	var group = customers.get_group(room["group_id"])
	if group == null:
		rooms.end_session(room)
		return
	var balance: Dictionary = data["balance"]
	var minutes: int = now - room["session_start"]
	var room_fee: int = Money.room_fee(room["session_price"], minutes)
	@warning_ignore("integer_division")
	var discount: int = Money.round_to_thousand(room_fee * group["discount_percent"] / 100)
	var key: String = "group:%d" % group["id"]

	group["state"] = "CHECKOUT"
	hosts.release_room(room, now)
	service.close_room(room)
	var total: int = 0
	if economy.record("ROOM_FEE", room_fee, key, "%s, %d phút" % [room["name"], minutes]):
		total += room_fee
	var items: Array = []
	for i in group["bill_items"].size():
		var item: Dictionary = group["bill_items"][i]
		if economy.record(item["type"], item["amount"], "%s:%d" % [key, i], item["note"]):
			total += item["amount"]
			items.append(item)
	if discount > 0 and economy.record("DISCOUNT", -discount, key, "Giảm %d%% tiền phòng xin lỗi khách" % group["discount_percent"]):
		total -= discount
	var room_name: String = room["name"]
	rooms.end_session(room)
	room["dirty_since"] = now
	group["state"] = "LEAVING"
	customers.remove_group(group)

	# Ra sân lấy xe: từ đêm có nguy cơ, không có bảo vệ thì dễ mất xe.
	if theft_risk_active():
		var chance: int = balance["theft_chance_guard_permille"] if state.guard_hired else balance["theft_chance_permille"]
		if rng.randi_range(1, 1000) <= chance:
			group["tags"].append("mat_xe")
			group["satisfaction"] = 0
			state.night["thefts"] += 1
			economy.record("COMPENSATION", -balance["theft_compensation"], key, "Đền xe cho nhóm " + group["type_name"])
			state.reputation = clampi(state.reputation - balance["theft_reputation_penalty"], 0, 100)
			notify("Nhóm %s ra về thì phát hiện MẤT XE! Quán đền %s, -%d danh tiếng.%s" % [
				group["type_name"], Money.format(balance["theft_compensation"]), balance["theft_reputation_penalty"],
				"" if state.guard_hired else " Nên thuê bảo vệ trông xe.",
			], "bad")

	var satisfaction: int = clampi(group["satisfaction"], 0, 100)
	var change: int = clampi(int(round((satisfaction - 60) / 10.0)), -3, 3)
	state.reputation = clampi(state.reputation + change, 0, 100)
	state.night["served"] += 1
	state.night["satisfaction_sum"] += satisfaction
	var ordered_product_id: String = ""
	for item in items:
		ordered_product_id = item.get("product_id", ordered_product_id)
	regulars.on_checkout(group, room["id"], satisfaction, ordered_product_id, state.day)
	var comment: String = _comment_for(group, satisfaction)
	state.night["comments"].append({"who": group["type_name"], "text": comment, "satisfaction": satisfaction})

	var bill: Dictionary = {
		"group_name": group["type_name"], "size": group["size"], "room_name": room_name, "minutes": minutes,
		"price_per_hour": room["session_price"], "room_fee": room_fee, "items": items,
		"discount": discount, "discount_percent": group["discount_percent"], "total": total,
		"satisfaction": satisfaction, "reputation_change": change, "comment": comment,
	}
	state.last_bill = bill
	var text: String = "Nhóm %s thanh toán %s (%s, %d phút). Hài lòng %d/100" % [group["type_name"], Money.format(total), room_name, minutes, satisfaction]
	if change != 0:
		text += ", danh tiếng %+d" % change
	notify(text + ".", "money")
	bill_paid.emit(bill)


func _comment_for(group: Dictionary, satisfaction: int) -> String:
	for entry in COMMENTS:
		if group["tags"].has(entry[0]):
			return entry[1]
	if satisfaction >= 75:
		return "Quán dễ thương, lần sau ghé nữa!"
	if satisfaction >= 55:
		return "Cũng được, hát vui."
	return "Chắc lần sau thử quán khác."


## Đánh giá lúc vào phòng: thời gian chờ, giá so với kỳ vọng, chất lượng âm thanh.
func _rate_seating(group: Dictionary, room: Dictionary) -> void:
	var balance: Dictionary = data["balance"]
	var over_wait: int = group["wait_minutes"] - balance["wait_grace_minutes"]
	if over_wait > 0:
		group["tags"].append("cho_phong")
		_change_satisfaction(group, -mini(over_wait, balance["wait_penalty_max"]), "Chờ %d phút" % group["wait_minutes"])

	var price: int = room["price_per_hour"]
	var budget: int = group["budget_per_hour"]
	if price > budget:
		group["tags"].append("gia_cao")
		_change_satisfaction(group, -balance["price_over_budget_penalty"], "Giá phòng cao hơn dự tính")
	elif price * 10 <= budget * 8:
		group["tags"].append("gia_mem")
		_change_satisfaction(group, balance["price_bargain_bonus"], "Giá phòng dễ chịu")

	if group.get("favorite_room_id", "") == room["id"]:
		group["tags"].append("phong_quen")
		_change_satisfaction(group, balance["regular_favorite_room_bonus"], "Được ngồi đúng phòng quen")

	var sound_bonus: int = (room["sound"] - 1) * balance["sound_bonus_per_level"]
	if sound_bonus > 0:
		_change_satisfaction(group, sound_bonus, "Âm thanh hay")


func _change_satisfaction(group: Dictionary, delta: int, reason: String) -> void:
	if delta == 0:
		return
	group["satisfaction"] = clampi(group["satisfaction"] + delta, 0, 100)
	notify("%s: %+d hài lòng" % [reason, delta], "good" if delta > 0 else "bad")


## Các bất biến của mô phỏng. Trả về danh sách vi phạm (rỗng nếu ổn).
func check_invariants() -> Array:
	var problems: Array = []
	if not economy.ledger_matches_balance():
		problems.append("Số dư không khớp sổ giao dịch.")
	var seen_groups: Dictionary = {}
	for room in state.rooms:
		if room["state"] == "OCCUPIED":
			var group = customers.get_group(room["group_id"])
			if group == null or group["state"] != "IN_ROOM" or group["room_id"] != room["id"]:
				problems.append("%s có khách không hợp lệ." % room["name"])
			elif seen_groups.has(group["id"]):
				problems.append("Nhóm %d ở hai phòng." % group["id"])
			elif group["size"] > room["capacity"]:
				problems.append("%s vượt sức chứa." % room["name"])
			seen_groups[room["group_id"]] = true
		elif room["group_id"] != 0:
			problems.append("%s không có khách nhưng còn giữ ID nhóm." % room["name"])
		if room["host_id"] != "":
			var host = hosts.get_host(room["host_id"])
			if room["state"] != "OCCUPIED" or host == null or host["state"] != "SERVING" or host["room_id"] != room["id"]:
				problems.append("%s giữ nhân viên Lan can không hợp lệ." % room["name"])
	for host in state.hosts:
		if host["state"] == "SERVING":
			var host_room = rooms.get_room(host["room_id"])
			if host_room == null or host_room["host_id"] != host["id"]:
				problems.append("%s ghi là đang phục vụ nhưng không ở phòng nào." % host["name"])
		elif host["room_id"] != "":
			problems.append("%s đã xong việc nhưng còn giữ phòng." % host["name"])
	for group in state.groups:
		if group["state"] == "IN_ROOM" and not seen_groups.has(group["id"]):
			problems.append("Nhóm %d ghi là đang hát nhưng không ở phòng nào." % group["id"])
		if group["state"] != "IN_ROOM" and group["state"] != "WAITING":
			problems.append("Nhóm %d đã rời quán nhưng chưa bị xóa." % group["id"])
	var claimed: Dictionary = {}
	for member in state.staff:
		var task: Dictionary = member["task"]
		if task.is_empty() or task["kind"] == "REST":
			continue
		if rooms.get_room(task["room_id"]) == null:
			problems.append("%s nhận việc ở phòng không tồn tại." % member["name"])
		elif claimed.has(task["room_id"]):
			problems.append("Hai nhân viên cùng nhận việc ở %s." % task["room_id"])
		claimed[task["room_id"]] = true
	for regular in state.regulars:
		if rooms.get_room(regular["favorite_room_id"]) == null or service.get_product(regular["favorite_product_id"]) == null:
			problems.append("Khách quen %s có sở thích không hợp lệ." % regular["name"])
	for product_id in state.stock:
		if state.stock[product_id] < 0:
			problems.append("Tồn kho âm: %s." % product_id)
	for room in state.rooms:
		if not room["request"].is_empty() and room["state"] != "OCCUPIED":
			problems.append("%s không có khách nhưng còn yêu cầu mở." % room["name"])
	if customers.waiting_groups().size() > data["balance"]["queue_limit"]:
		problems.append("Hàng chờ vượt giới hạn.")
	return problems
