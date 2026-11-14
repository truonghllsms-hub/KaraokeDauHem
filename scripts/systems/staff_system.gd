extends RefCounted
## Nhân viên theo vai trò, mỗi người một việc tại một thời điểm:
## - Tạp vụ (janitor): dọn phòng bẩn.
## - Phục vụ (waiter): giao món, đổi micro.
## - Lễ tân (receptionist): đón khách đang chờ và xếp vào phòng hợp túi tiền.
## Họ chờ một nhịp ngắn trước khi nhận việc để chủ quán vẫn được ra tay trước; nếu việc đã có người lo
## thì bỏ việc đó và rảnh ngay, không bị kẹt ở trạng thái bận.
##
## member["task"] rỗng là đang rảnh, ngược lại:
##   {"kind": "CLEAN"|"DELIVER"|"FIX"|"SEAT"|"REST", "room_id", "request_id", "group_id", "phase": "TRAVEL"|"WORK", "start", "end"}

const Money = preload("res://scripts/core/money.gd")

const ROLE_NAMES: Dictionary = {"janitor": "Tạp vụ", "waiter": "Phục vụ", "receptionist": "Lễ tân"}
const ROLE_JOBS: Dictionary = {"janitor": ["CLEAN"], "waiter": ["FIX", "DELIVER"], "receptionist": ["SEAT"]}

## Tắt để kiểm thử từng kịch bản mà không có nhân viên tự làm việc.
var enabled: bool = true
## The live venue acknowledges arrivals; headless simulation retains timed travel.
var visual_delivery: bool = false
## Simulation gán: (group_id, room_id) -> Dictionary như preview_assign; (group_id, room_id) -> String như assign_group.
var seat_preview: Callable = Callable()
var seat_assign: Callable = Callable()

var _state
var _data: Dictionary
var _economy
var _rooms
var _service
var _customers
var _notify: Callable


func _init(state, data: Dictionary, economy, rooms, service, notify: Callable, customers = null) -> void:
	_state = state
	_data = data
	_economy = economy
	_rooms = rooms
	_service = service
	_notify = notify
	_customers = customers


func setup_new_game() -> void:
	_state.staff = []
	_state.staff_priority = []
	for def in _data["staff"]:
		if def["starter"]:
			_state.staff.append(_make_member(def))


func _make_member(def: Dictionary) -> Dictionary:
	return {
		"id": def["id"], "name": def["name"], "role": def["role"], "speed": def["speed"], "wage": def["wage"],
		"about": def["about"], "sprite": def.get("sprite", "waiter_m"), "energy": 100, "task": {}, "tasks_done": 0,
	}


func get_member(staff_id: String) -> Variant:
	for member in _state.staff:
		if member["id"] == staff_id:
			return member
	return null


static func role_name(role: String) -> String:
	return ROLE_NAMES.get(role, role)


func count_role(role: String) -> int:
	var count: int = 0
	for member in _state.staff:
		count += 1 if member["role"] == role else 0
	return count


## Những ứng viên chưa làm ở quán.
func candidates() -> Array:
	var result: Array = []
	for def in _data["staff"]:
		if get_member(def["id"]) == null:
			result.append(def)
	return result


func hire(staff_id: String) -> String:
	var balance: Dictionary = _data["balance"]
	if get_member(staff_id) != null:
		return "Người này đã làm ở quán rồi."
	var chosen: Variant = null
	for def in _data["staff"]:
		if def["id"] == staff_id:
			chosen = def
	if chosen == null:
		return "Không tìm thấy ứng viên."
	if count_role(chosen["role"]) >= balance["staff_max_per_role"]:
		return "Quán chỉ thuê tối đa %d %s." % [balance["staff_max_per_role"], role_name(chosen["role"]).to_lower()]
	var cost: int = balance["staff_hire_cost"]
	if not _economy.can_afford(cost):
		return "Không đủ tiền: tuyển %s cần %s." % [chosen["name"], Money.format(cost)]
	if not _economy.record("HIRE_STAFF", -cost, staff_id, "Tuyển %s %s" % [role_name(chosen["role"]).to_lower(), chosen["name"]]):
		return "Đã thanh toán phí tuyển người này rồi."
	_state.staff.append(_make_member(chosen))
	_notify.call("%s nhận việc %s (lương %s/đêm)." % [chosen["name"], role_name(chosen["role"]).to_lower(), Money.format(chosen["wage"])], "good")
	return ""


## Người chơi đánh dấu một phòng cần lo trước: nhân viên đúng việc rảnh kế tiếp sẽ nhận ngay.
func prioritize(room_id: String) -> String:
	var room = _rooms.get_room(room_id)
	if room == null:
		return "Không tìm thấy phòng."
	if _job_for(room, 0, true).is_empty():
		return "%s không có việc gì cho nhân viên." % room["name"]
	if _claimed_by(room_id) != "":
		return "%s đã có nhân viên lo." % room["name"]
	if not _state.staff_priority.has(room_id):
		_state.staff_priority.append(room_id)
	return ""


func is_busy(member: Dictionary) -> bool:
	return not member["task"].is_empty()


func tick(now: int) -> void:
	for member in _state.staff:
		if is_busy(member):
			_advance(member, now)
		if enabled and not is_busy(member):
			_take_job(member, now)


## Kết ca: trả lương từng người, bỏ việc dở, hồi năng lượng.
func end_night(day: int) -> void:
	for member in _state.staff:
		_economy.record("WAGES", -member["wage"], "day:%d:%s" % [day, member["id"]], "Lương %s %s" % [role_name(member["role"]).to_lower(), member["name"]])
		member["task"] = {}
		member["energy"] = 100
	_state.staff_priority = []


# ---------------------------------------------------------------- Nội bộ

func _claimed_by(room_id: String) -> String:
	for member in _state.staff:
		if is_busy(member) and member["task"].get("room_id", "") == room_id:
			return member["id"]
	return ""


func _group_claimed(group_id: int) -> bool:
	for member in _state.staff:
		if is_busy(member) and member["task"].get("group_id", 0) == group_id:
			return true
	return false


## Việc đang mở ở một phòng: {} nếu không có, hoặc {"kind", "order", "since", "request_id"}.
func _job_for(room: Dictionary, now: int, ignore_delay: bool) -> Dictionary:
	var balance: Dictionary = _data["balance"]
	if room["state"] == "OCCUPIED" and not room["request"].is_empty():
		var request: Dictionary = room["request"]
		if request["kind"] == "MIC" and (ignore_delay or now - request["opened"] >= balance["staff_delay_mic"]):
			return {"kind": "FIX", "order": 0, "since": request["deadline"], "request_id": request["id"]}
		if request["kind"] == "ORDER" and (ignore_delay or now - request["opened"] >= balance["staff_delay_order"]):
			return {"kind": "DELIVER", "order": 1, "since": request["deadline"], "request_id": request["id"]}
	elif room["state"] == "DIRTY" and (ignore_delay or now - room.get("dirty_since", 0) >= balance["staff_delay_clean"]):
		return {"kind": "CLEAN", "order": 2, "since": room.get("dirty_since", 0), "request_id": 0}
	return {}


func _take_job(member: Dictionary, now: int) -> void:
	var balance: Dictionary = _data["balance"]
	if member["energy"] < balance["staff_rest_below"]:
		member["task"] = {"kind": "REST", "room_id": "", "request_id": 0, "group_id": 0, "phase": "WORK", "start": now, "end": now + balance["staff_rest_minutes"]}
		_notify.call("%s mệt, xin nghỉ %d phút." % [member["name"], balance["staff_rest_minutes"]], "info")
		return
	if member["role"] == "receptionist":
		_take_seat_job(member, now)
		return

	var allowed: Array = ROLE_JOBS.get(member["role"], [])
	var best: Dictionary = {}
	var best_room: Dictionary = {}
	for room in _state.rooms:
		if _claimed_by(room["id"]) != "":
			continue
		var prioritized: bool = _state.staff_priority.has(room["id"])
		var job: Dictionary = _job_for(room, now, prioritized)
		if job.is_empty() or not allowed.has(job["kind"]):
			continue
		if prioritized:
			job["order"] = -1
		if best.is_empty() or job["order"] < best["order"] or (job["order"] == best["order"] and job["since"] < best["since"]):
			best = job
			best_room = room
	if best.is_empty():
		return

	_state.staff_priority.erase(best_room["id"])
	var base: int = balance["staff_travel_minutes"]
	if best["kind"] == "DELIVER":
		base = balance["staff_deliver_minutes"]
	elif best["kind"] == "FIX":
		base = balance["staff_fix_minutes"]
	member["task"] = {
		"kind": best["kind"], "room_id": best_room["id"], "request_id": best["request_id"], "group_id": 0,
		"phase": "PICKUP" if best["kind"] == "DELIVER" else "TRAVEL", "start": now, "end": now + maxi(2, _duration(member, base)),
		"pickup_at": now + 1, "pickup_confirmed": false,
	}
	match best["kind"]:
		"DELIVER":
			_notify.call("%s ra tủ lạnh lấy món cho %s." % [member["name"], best_room["name"]], "info")
		"FIX":
			_notify.call("%s mang micro mới tới %s." % [member["name"], best_room["name"]], "info")
		"CLEAN":
			_notify.call("%s đi dọn %s." % [member["name"], best_room["name"]], "info")


## Lễ tân: chọn nhóm chờ lâu nhất và phòng hợp túi tiền nhất (đắt nhất mà không vượt ngân sách).
func _take_seat_job(member: Dictionary, now: int) -> void:
	if _customers == null or not seat_preview.is_valid():
		return
	var balance: Dictionary = _data["balance"]
	var waiting: Array = _customers.waiting_groups().filter(func(g: Dictionary) -> bool:
		return g["wait_minutes"] >= balance["staff_delay_seat"] and not _group_claimed(g["id"]))
	waiting.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["wait_minutes"] > b["wait_minutes"])
	for group in waiting:
		var best_room: Dictionary = {}
		var best_score: int = -1
		for room in _state.rooms:
			if _claimed_by(room["id"]) != "":
				continue
			var preview: Dictionary = seat_preview.call(group["id"], room["id"])
			if preview["reason"] != "":
				continue
			# Trong ngân sách thì ưu tiên phòng giá cao; vượt ngân sách thì xếp sau mọi phòng vừa túi tiền.
			var score: int = room["price_per_hour"] + (0 if preview["over_budget"] else 10000000)
			if score > best_score:
				best_score = score
				best_room = room
		if best_room.is_empty():
			continue
		member["task"] = {
			"kind": "SEAT", "room_id": best_room["id"], "request_id": 0, "group_id": group["id"],
			"phase": "TRAVEL", "start": now, "end": now + _duration(member, balance["staff_seat_minutes"]),
		}
		return


## Thời gian làm theo tốc độ; năng lượng thấp thì chậm hơn. Tối thiểu 1 phút.
func _duration(member: Dictionary, base_minutes: int) -> int:
	var balance: Dictionary = _data["balance"]
	var scaled: float = base_minutes * 100.0 / maxi(1, member["speed"]) / (1.0 + 0.08*int(_state.upgrades.get("staff_training", 0)))
	if member["energy"] < balance["staff_tired_below"]:
		scaled = scaled * balance["staff_tired_slowdown_percent"] / 100.0
	return maxi(1, int(ceil(scaled)))


func _advance(member: Dictionary, now: int) -> void:
	var balance: Dictionary = _data["balance"]
	var task: Dictionary = member["task"]
	if task["kind"] == "REST":
		if now >= task["end"]:
			member["energy"] = mini(100, member["energy"] + balance["staff_rest_recovery"])
			member["task"] = {}
		return

	var room = _rooms.get_room(task["room_id"])
	if task["kind"] == "SEAT":
		var group = _customers.get_group(task["group_id"]) if _customers != null else null
		if group == null or group["state"] != "WAITING" or room == null or room["state"] != "AVAILABLE":
			member["task"] = {}  # khách đã được xếp hoặc đã về, hoặc phòng không còn trống
			return
		if now < task["end"]:
			return
		if seat_assign.call(group["id"], room["id"]) == "":
			_notify.call("Lễ tân %s mời nhóm %s vào %s." % [member["name"], group["type_name"], room["name"]], "info")
			_finish(member, balance["staff_energy_deliver"])
		else:
			member["task"] = {}
		return

	if task["kind"] == "CLEAN":
		if task["phase"] == "TRAVEL":
			if room == null or room["state"] != "DIRTY":
				member["task"] = {}  # đã có người dọn trước
			elif now >= task["end"]:
				_rooms.start_cleaning(room, now)
				task["phase"] = "WORK"
		elif room == null or room["state"] != "CLEANING":
			_finish(member, balance["staff_energy_clean"])
		return

	# DELIVER / FIX: yêu cầu phải còn nguyên; khách về hoặc đã có người lo thì bỏ.
	if room == null or room["request"].is_empty() or room["request"]["id"] != task["request_id"]:
		member["task"] = {}
		return
	if task["kind"] == "DELIVER":
		if visual_delivery:
			return # Arrival commands below are authoritative in the live venue.
		if task["phase"] in ["PICKUP", "TRAVEL"]:
			if now >= task.get("pickup_at", task["start"] + 1):
				task["phase"] = "CARRY"
				task["pickup_confirmed"] = true
			return
		if now >= task["end"]:
			_service.deliver_order(room, now)
			_finish(member, balance["staff_energy_deliver"])
	else:
		if now >= task["end"]:
			_service.fix_mic(room, now)
			_finish(member, balance["staff_energy_fix"])

func confirm_pickup(staff_id: String, request_id: int) -> bool:
	var member = get_member(staff_id)
	if member == null:
		return false
	var task: Dictionary = member["task"]
	if not _current_delivery(task, request_id) or task["phase"] != "PICKUP":
		return false
	task["pickup_confirmed"] = true
	task["phase"] = "CARRY"
	return true

func confirm_delivery(staff_id: String, request_id: int, now: int) -> bool:
	var member = get_member(staff_id)
	if member == null:
		return false
	var task: Dictionary = member["task"]
	if not _current_delivery(task, request_id) or task["phase"] != "CARRY" or not task.get("pickup_confirmed", false):
		return false
	var room = _rooms.get_room(task["room_id"])
	if _service.deliver_order(room, now) != "":
		return false
	_finish(member, _data["balance"]["staff_energy_deliver"])
	return true

func _current_delivery(task: Dictionary, request_id: int) -> bool:
	if task.is_empty() or task.get("kind", "") != "DELIVER" or task.get("request_id", -1) != request_id:
		return false
	var room = _rooms.get_room(task["room_id"])
	return room != null and room["state"] == "OCCUPIED" and room["request"].get("id", -1) == request_id and room["request"].get("kind", "") == "ORDER"


func _finish(member: Dictionary, energy_cost: int) -> void:
	member["task"] = {}
	member["tasks_done"] += 1
	member["energy"] = maxi(0, member["energy"] - energy_cost)
