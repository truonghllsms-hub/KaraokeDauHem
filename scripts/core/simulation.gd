extends RefCounted
## Bộ điều phối mô phỏng. Giao diện và kiểm thử headless đều gọi cùng các hàm ở đây,
## nên chỉ có một bộ quy tắc. Các hàm hành động trả về "" khi thành công,
## hoặc lý do thất bại bằng tiếng Việt để giao diện hiển thị.

signal message(text: String, kind: String)
signal night_ended(summary: Dictionary)
signal bill_paid(bill: Dictionary)
## Phát sau mỗi lần lưu (tự động hoặc thủ công). error rỗng là lưu thành công.
signal game_saved(path: String, error: String)
## Câu hát hoặc câu thoại trang trí vừa phát trong một phòng (xem AmbienceSystem để biết các trường).
signal line_spoken(event: Dictionary)

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
const AmbienceSystem = preload("res://scripts/systems/ambience_system.gd")
const SecuritySystem = preload("res://scripts/systems/security_system.gd")
const FinanceSystem = preload("res://scripts/systems/finance_system.gd")
const ReviewSystem = preload("res://scripts/systems/review_system.gd")
const SaveManager = preload("res://scripts/core/save_manager.gd")

const MAX_MESSAGES: int = 60
## Các loại giao dịch tính vào lợi nhuận vận hành của một đêm.
const OPERATING_TYPES: Array = ["ROOM_FEE", "ORDER", "LANCAN_FEE", "TIP_SHARE", "DISCOUNT", "STOCK", "WAGES", "OPERATING", "UTILITIES", "COMPENSATION", "LOAN_INTEREST"]
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
	["lancan_hop_gu", "Bạn Lan can hát đúng gu, cả phòng phiêu theo."],
	["vip", "Phòng VIP xịn thật, loa nghe đã tai."],
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
var ambience
var security
var finance
var review_writer
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
	staff = StaffSystem.new(state, data, economy, rooms, service, Callable(self, "notify"), customers)
	staff.setup_new_game()
	staff.seat_preview = Callable(self, "preview_assign")
	staff.seat_assign = Callable(self, "assign_group")
	security = SecuritySystem.new(state, data, rng, economy, customers, Callable(self, "notify"))
	finance = FinanceSystem.new(state, data, economy, Callable(self, "notify"))
	review_writer = ReviewSystem.new(state, data, p_seed)
	regulars = RegularSystem.new(state, data, rng, Callable(self, "notify"))
	customers.regulars = regulars
	ambience = AmbienceSystem.new(state, data, customers, p_seed, Callable(self, "_emit_line"))
	service.react = Callable(ambience, "react")
	hosts.speak = Callable(ambience, "host_line")
	economy.record("OPENING", balance["starting_money"], "new_game", "Vốn ban đầu")
	_begin_day()


func _emit_line(event: Dictionary) -> void:
	line_spoken.emit(event)


func notify(text: String, kind: String = "info") -> void:
	state.messages.append({"day": state.day, "minute": clock.minute, "text": text, "kind": kind})
	if state.messages.size() > MAX_MESSAGES:
		state.messages.pop_front()
	message.emit(text, kind)


# ---------------------------------------------------------------- Vòng đời một đêm

func open_doors() -> String:
	if state.bankrupt:
		return "Quán đã phá sản."
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
	security.tick(now)

	for room in state.rooms:
		if room["state"] == "OCCUPIED" and now >= room["session_end"]:
			_checkout(room, now)

	customers.tick(now)
	ambience.tick(now)

	var training_done: bool = state.day == 1 and customers.spawning_enabled and customers.training_count() >= 2 and state.groups.is_empty() and not state.rooms.any(func(room: Dictionary) -> bool: return room["state"] in ["DIRTY", "CLEANING"])
	if now >= Clock.NIGHT_MINUTES or training_done:
		_close_night()


func next_day() -> String:
	if state.phase != "SUMMARY":
		return "Chưa tổng kết đêm nay."
	if state.bankrupt:
		return "Quán đã phá sản. Hãy bắt đầu ván mới."
	state.day += 1
	_begin_day()
	return ""


func _begin_day() -> void:
	state.phase = "PREP"
	clock.reset()
	state.next_arrival_minute = data["balance"]["first_arrival_minute"]
	hosts.begin_day()
	if ambience != null:
		ambience.reset()
	state.night = {
		"served": 0,
		"unserved": 0,
		"satisfaction_sum": 0,
		"reputation_start": state.reputation,
		"comments": [],
		"rating_sum": 0,
		"rating_count": 0,
		"rating_before_x10": rating_x10(),
		"thefts": 0,
		"guard_on_duty": state.guard_hired,
		"goal_served": 2 if state.day == 1 else mini(data["balance"]["goal_base"] + state.day, data["balance"]["goal_max"]),
		"training_spawned": 0,
		"goal_unserved_max": data["balance"]["goal_unserved_max"] + data["balance"]["goal_unserved_per_room"] * rooms.unlocked_count(),
	}


func goal_text() -> String:
	if state.day == 1: return "Ca hướng dẫn: phục vụ 2 nhóm khách và dọn phòng"
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
	for room in state.rooms:
		if room["state"] != "LOCKED" and room["upkeep_per_night"] > 0:
			economy.record("OPERATING", -room["upkeep_per_night"], "%s:%s" % [day_key, room["id"]], "Vận hành " + room["name"])

	security.end_night()
	var loan_paid: Dictionary = finance.settle_night(state.day)
	var went_bankrupt: bool = finance.check_solvency()

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
		"tip_share": economy.total_for_day(state.day, "TIP_SHARE"),
		"loan_interest": loan_paid["interest"],
		"loan_principal_paid": loan_paid["principal"],
		"loan_balance": state.loan_principal,
		"next_loan_payment": finance.next_payment()["total"],
		"negative_nights": state.negative_nights,
		"bankrupt": went_bankrupt or state.bankrupt,
		"thieves_caught": state.night.get("thieves_caught", 0),
		"arrival_percent": customers.arrival_percent(),
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
		# Đánh giá sao: riêng đêm nay và toàn quán (x10 để tránh số thực; 43 nghĩa là 4,3 sao).
		"night_reviews": state.night["rating_count"],
		"night_rating_x10": _average_x10(state.night["rating_sum"], state.night["rating_count"]),
		"night_rating_text": format_rating(_average_x10(state.night["rating_sum"], state.night["rating_count"]), state.night["rating_count"]),
		"rating_before_x10": state.night["rating_before_x10"],
		"rating_after_x10": rating_x10(),
		"rating_text": rating_text(),
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
	var reason: String = rooms.check_assign(room, group, clock.minute, Clock.NIGHT_MINUTES)
	return {
		"reason": reason,
		# Mã lý do ngắn để giao diện chọn nhãn: "" | STATE | CAPACITY | TIME | PRICE.
		"block": _block_code(room, group, reason),
		"block_text": _block_text(room, group, reason),
		"estimate": Money.room_fee(room["price_per_hour"], group["planned_minutes"]),
		"over_budget": room["price_per_hour"] > rooms.effective_budget(room, group),
		"budget_per_hour": rooms.effective_budget(room, group),
	}


func _block_code(room: Dictionary, group: Dictionary, reason: String) -> String:
	if reason == "":
		return ""
	if room["state"] != "AVAILABLE":
		return "STATE"
	if group["size"] > room["capacity"]:
		return "CAPACITY"
	if clock.minute + group["planned_minutes"] > Clock.NIGHT_MINUTES:
		return "TIME"
	return "PRICE"


func _block_text(room: Dictionary, group: Dictionary, reason: String) -> String:
	match _block_code(room, group, reason):
		"STATE":
			return {"LOCKED": "Chưa lắp thiết bị", "OCCUPIED": "Đang có khách", "DIRTY": "Đang bẩn", "CLEANING": "Đang dọn", "BROKEN": "Đang hỏng"}.get(room["state"], "Không dùng được")
		"CAPACITY":
			return "Thiếu chỗ: chỉ chứa %d người" % room["capacity"]
		"TIME":
			return "Không kịp trước 24:00"
		"PRICE":
			return "Khách chê đắt: %s/giờ" % Money.format(room["price_per_hour"])
	return ""


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

## Lưu đầy đủ ca hiện tại và trạng thái hình ảnh tùy chọn. Trả về "" nếu thành công.
func save_game(path: String = SaveManager.DEFAULT_PATH, view_state: Dictionary = {}) -> String:
	var error: String = ""
	if not SaveManager.SAVEABLE_PHASES.has(state.phase):
		error = "Không thể lưu ở trạng thái hiện tại."
	else:
		var snapshot: Dictionary = SaveManager.make_snapshot(state, rng)
		snapshot["clock"] = {"minute": clock.minute, "speed": clock.speed, "paused": clock.paused, "accum": clock._accum}
		snapshot["view"] = view_state.duplicate(true)
		error = SaveManager.write_snapshot(snapshot, path)
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
	for field in SaveManager.OPTIONAL_DEFAULTS:
		var value = saved.get(field, SaveManager.OPTIONAL_DEFAULTS[field])
		state.set(field, value.duplicate(true) if (value is Array or value is Dictionary) else value)
	for room in state.rooms:
		if room.get("floor", 1) == 1 and not room.get("price_customized", false):
			var legacy: Dictionary = {"room_01": 250000, "room_02": 350000, "room_03": 260000, "room_04": 420000}
			if room["price_per_hour"] == legacy.get(room["id"], -1): room["price_per_hour"] = 250000
	state.rng_seed = int(str(snapshot["rng_seed"]))
	rng.seed = state.rng_seed
	rng.state = int(str(snapshot["rng_state"]))
	state.messages = []
	# Các bộ ngẫu nhiên riêng (đánh giá, câu hát) phải dùng đúng hạt giống của ván đã lưu.
	review_writer._seed = state.rng_seed
	ambience._seed = state.rng_seed
	ambience.reset()
	clock.reset()
	if state.phase == "SUMMARY":
		clock.minute = Clock.NIGHT_MINUTES
	elif state.phase == "OPEN":
		clock.minute = int(snapshot["clock"]["minute"])
	clock.set_speed(int(snapshot.get("clock", {}).get("speed", 1)))
	clock.paused = bool(snapshot.get("clock", {}).get("paused", false))
	clock._accum = clampf(float(snapshot.get("clock", {}).get("accum", 0.0)), 0.0, 2.0)
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
	return {"ok": true, "sim": sim, "error": "", "used_backup": loaded["used_backup"], "notice": loaded["notice"], "view": loaded["snapshot"].get("view", {})}


func theft_risk_active() -> bool:
	return security.risk_active()


## Chủ quán chạy ra đuổi tên trộm đang ở bãi xe. "" nếu đã bắt đầu đuổi.
func chase_thief() -> String:
	if state.phase != "OPEN":
		return "Quán chưa mở cửa."
	return security.chase(clock.minute)


func take_loan(amount: int) -> String:
	return finance.take_loan(amount)


func repay_loan(amount: int) -> String:
	return finance.repay(amount)


## Thông tin vay để hiển thị: hạn mức, dư nợ, khoản phải trả cuối đêm, số đêm âm tiền.
func loan_info() -> Dictionary:
	var balance: Dictionary = data["balance"]
	return {
		"principal": state.loan_principal, "limit": finance.credit_limit(), "available": finance.available_credit(),
		"rate_permille": balance["loan_rate_permille_per_day"], "min_principal_percent": balance["loan_min_principal_percent"],
		"next_payment": finance.next_payment(), "step": balance["loan_step"], "negative_nights": state.negative_nights,
		"bankrupt": state.bankrupt, "can_change": state.phase != "OPEN" and not state.bankrupt,
	}


## Lan can mở khi đã lắp đủ phòng tầng 1. Trả về "" nếu đã mở, ngược lại là lý do.
func lancan_lock_reason() -> String:
	var need: int = data["balance"]["lancan_unlock_floor1_rooms"]
	var have: int = rooms.equipped_on_floor(1)
	return "" if have >= need else "Mở khi đã lắp đủ %d phòng tầng 1 (hiện có %d)." % [need, have]


func clean_room(room_id: String) -> String:
	var room = rooms.get_room(room_id)
	if room == null:
		return "Không tìm thấy phòng."
	return rooms.start_cleaning(room, clock.minute)


## Lắp thiết bị cho một phòng đã xây sẵn để đưa vào kinh doanh. Chỉ làm được ở giai đoạn chuẩn bị.
func equip_room(room_id: String) -> String:
	var room = rooms.get_room(room_id)
	if room == null:
		return "Không tìm thấy phòng."
	if room["state"] != "LOCKED":
		return "%s đã lắp thiết bị rồi." % room["name"]
	if not rooms.floor_unlocked(room["floor"]):
		return rooms.floor_lock_reason()
	if state.phase != "PREP":
		return "Chỉ lắp thiết bị được ở giai đoạn chuẩn bị, trước khi mở cửa."
	var cost: int = room["unlock_cost"]
	if not economy.can_afford(cost):
		return "Không đủ tiền: lắp thiết bị %s cần %s, còn thiếu %s." % [room["name"], Money.format(cost), Money.format(cost - state.money)]
	if not economy.record("EQUIP_ROOM", -cost, room["id"], "Lắp thiết bị phòng: " + room["name"]):
		return "%s đã được thanh toán trước đó." % room["name"]
	room["state"] = "AVAILABLE"
	notify("Đã lắp thiết bị cho %s (%s, %d người). Phòng sẵn sàng đón khách." % [room["name"], room["tier_name"], room["capacity"]], "good")
	return ""


## Tên cũ của equip_room, giữ lại để giao diện hiện tại vẫn chạy.
func unlock_room(room_id: String) -> String:
	return equip_room(room_id)


## Thông tin một phòng để hiển thị: loại, thiết bị, lợi ích, chi phí lắp và số tiền còn thiếu.
func room_info(room_id: String) -> Dictionary:
	var room = rooms.get_room(room_id)
	if room == null:
		return {}
	var equipped: bool = room["state"] != "LOCKED"
	var cost: int = room["unlock_cost"]
	return {
		"id": room["id"], "name": room["name"], "tier": room["tier"], "tier_name": room["tier_name"],
		"capacity": room["capacity"], "price_per_hour": room["price_per_hour"],
		"equipped": equipped, "status_text": "Sẵn sàng" if equipped else "Chưa lắp thiết bị",
		"equipment": room["equipment"], "perks": room["perks"],
		"equip_cost": cost, "missing_money": 0 if equipped else maxi(0, cost - state.money),
		"floor": room["floor"],
		"floor_locked": not rooms.floor_unlocked(room["floor"]),
		"locked_reason": "" if rooms.floor_unlocked(room["floor"]) else rooms.floor_lock_reason(),
		"can_equip_now": not equipped and state.phase == "PREP" and economy.can_afford(cost) and rooms.floor_unlocked(room["floor"]),
		"equip_button_text": "Lắp thiết bị — %s" % Money.format(cost),
		"upkeep_per_night": room["upkeep_per_night"], "sound": room["sound"], "soundproof": room["soundproof"],
	}


# ---------------------------------------------------------------- Đánh giá sao

## Danh tiếng (mức độ được biết đến) thay đổi theo số sao nhóm để lại: 5★ và 4★ +1, 3★ 0, 2★ −1, 1★ −3.
## Từ mốc reputation_four_star_cap trở lên, chỉ khách 5★ mới làm quán nổi tiếng thêm.
func reputation_change_for(satisfaction: int) -> int:
	var balance: Dictionary = data["balance"]
	var stars: int = stars_for(satisfaction)
	if stars == 4 and state.reputation >= balance["reputation_four_star_cap"]:
		return 0
	return balance["reputation_by_stars"][str(stars)]


## Số sao (1-5) ứng với mức hài lòng cuối lượt.
func stars_for(satisfaction: int) -> int:
	var thresholds: Array = data["balance"]["star_thresholds"]
	for i in thresholds.size():
		if satisfaction >= thresholds[i]:
			return 5 - i
	return 1


static func _average_x10(total: int, count: int) -> int:
	if count <= 0:
		return 0
	@warning_ignore("integer_division")
	return (total * 10 + count / 2) / count


## Điểm trung bình toàn quán nhân 10 (43 nghĩa là 4,3 sao); 0 khi chưa có đánh giá.
func rating_x10() -> int:
	return _average_x10(state.rating_sum, state.rating_count)


static func format_rating(x10: int, count: int) -> String:
	if count <= 0:
		return "Chưa có đánh giá"
	@warning_ignore("integer_division")
	return "★ %d,%d/5 · %d đánh giá" % [x10 / 10, x10 % 10, count]


## Dòng hiển thị trên giao diện chính, ví dụ "★ 4,3/5 · 28 đánh giá" hoặc "Chưa có đánh giá".
func rating_text() -> String:
	return format_rating(rating_x10(), state.rating_count)


## Các nhận xét gần nhất, mới nhất đứng đầu: {"day", "who", "room_name", "stars", "satisfaction", "text"}.
func recent_reviews(limit: int = 10) -> Array:
	var result: Array = []
	for i in range(state.reviews.size() - 1, maxi(-1, state.reviews.size() - 1 - limit), -1):
		result.append(state.reviews[i])
	return result


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
	var bounds: Vector2i = rooms.price_bounds(room)
	if price < bounds.x or price > bounds.y:
		return "%s: giá từ %s đến %s/giờ." % [room["tier_name"], Money.format(bounds.x), Money.format(bounds.y)]
	room["price_per_hour"] = price
	room["price_customized"] = true
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
	ambience.react(room, "checkout", now)
	hosts.release_room(room, now)
	service.close_room(room)
	var total: int = 0
	var first_payment: bool = economy.record("ROOM_FEE", room_fee, key, "%s, %d phút" % [room["name"], minutes])
	if first_payment:
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

	var satisfaction: int = clampi(group["satisfaction"], 0, 100)
	var change: int = reputation_change_for(satisfaction)
	state.reputation = clampi(state.reputation + change, 0, 100)
	state.night["served"] += 1
	state.night["satisfaction_sum"] += satisfaction
	var ordered_product_id: String = ""
	for item in items:
		ordered_product_id = item.get("product_id", ordered_product_id)
	regulars.on_checkout(group, room["id"], satisfaction, ordered_product_id, state.day)
	var stars: int = stars_for(satisfaction)
	var host_name: String = ""
	var item_name: String = ""
	for item in group["bill_items"]:
		if item["type"] == "LANCAN_FEE":
			host_name = item["note"].trim_prefix("Lan can: ")
		elif item.has("product_id"):
			item_name = service.get_product(item["product_id"])["name"]
	if item_name == "":
		var favorite = service.get_product(group.get("favorite_product_id", ""))
		item_name = favorite["name"] if favorite != null else "nước"
	var review: Dictionary = review_writer.write(group, stars, {
		"room": room_name, "wait": group["wait_minutes"], "item": item_name, "host": host_name,
		"price": Money.format(room["session_price"]),
	})
	var comment: String = review["text"]
	state.night["comments"].append({"who": review["who"], "group_name": group["type_name"], "text": comment, "satisfaction": satisfaction, "stars": stars})
	# Mỗi nhóm đã thanh toán để lại đúng một đánh giá.
	if first_payment:
		state.rating_sum += stars
		state.rating_count += 1
		state.night["rating_sum"] += stars
		state.night["rating_count"] += 1
		state.reviews.append({"day": state.day, "who": review["who"], "badge": review["badge"], "group_name": group["type_name"], "room_name": room_name, "stars": stars, "satisfaction": satisfaction, "text": comment, "main": review["main"]})
		while state.reviews.size() > balance["reviews_kept"]:
			state.reviews.pop_front()

	var bill: Dictionary = {
		"group_name": group["type_name"], "size": group["size"], "room_name": room_name, "minutes": minutes,
		"price_per_hour": room["session_price"], "room_fee": room_fee, "items": items,
		"discount": discount, "discount_percent": group["discount_percent"], "total": total,
		"satisfaction": satisfaction, "reputation_change": change, "comment": comment, "stars": stars,
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
	var budget: int = rooms.effective_budget(room, group)
	if price > budget:
		group["tags"].append("gia_cao")
		_change_satisfaction(group, -balance["price_over_budget_penalty"], "Giá phòng cao hơn dự tính")
	elif price * 10 <= budget * 8:
		group["tags"].append("gia_mem")
		_change_satisfaction(group, balance["price_bargain_bonus"], "Giá phòng dễ chịu")

	if room["comfort_bonus"] > 0:
		group["tags"].append("vip")
		_change_satisfaction(group, room["comfort_bonus"], "%s sang trọng" % room["tier_name"])
	if group.get("favorite_room_id", "") == room["id"]:
		group["tags"].append("phong_quen")
		_change_satisfaction(group, balance["regular_favorite_room_bonus"], "Được ngồi đúng phòng quen")

	var sound_bonus: int = (room["sound"] - 1) * balance["sound_bonus_per_level"]
	if sound_bonus > 0:
		_change_satisfaction(group, sound_bonus, "Âm thanh hay")

	var comfort: int = service.upgrade_level("soundproof")*2 + service.upgrade_level("lighting")*2
	if comfort > 0:
		_change_satisfaction(group, comfort, "Cách âm và không gian dễ chịu")


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
		if room["host_id"] != ("" if room["host_ids"].is_empty() else room["host_ids"][0]):
			problems.append("%s có danh sách nhân viên không nhất quán." % room["name"])
		var paired: Dictionary = {}
		for host_id in room["host_ids"]:
			var host = hosts.get_host(host_id)
			if room["state"] != "OCCUPIED" or host == null or host["state"] != "SERVING" or host["room_id"] != room["id"]:
				problems.append("%s giữ nhân viên Lan can không hợp lệ." % room["name"])
			elif paired.has(host["guest_index"]):
				problems.append("Hai nhân viên cùng ghép một khách.")
			else:
				paired[host["guest_index"]] = true
	for host in state.hosts:
		if host["state"] == "SERVING":
			var host_room = rooms.get_room(host["room_id"])
			if host_room == null or not host_room["host_ids"].has(host["id"]):
				problems.append("%s ghi là đang phục vụ nhưng không ở phòng nào." % host["name"])
		elif host["room_id"] != "":
			problems.append("%s đã xong việc nhưng còn giữ phòng." % host["name"])
	for group in state.groups:
		if group["size"] < 1 or group["size"] > 5:
			problems.append("Nhóm khách phải có từ 1 đến 5 người.")
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
