extends RefCounted
## Nhân viên phục vụ: tự nhận việc dọn phòng, giao món và đổi micro, mỗi người một việc tại một thời điểm.
## Họ chờ một nhịp ngắn trước khi nhận việc để người chơi (chủ quán) vẫn được ra tay trước; nếu việc đã
## có người khác lo xong thì nhân viên bỏ việc đó và rảnh ngay, không bị kẹt ở trạng thái bận.
##
## member["task"] rỗng là đang rảnh, ngược lại:
##   {"kind": "CLEAN"|"DELIVER"|"FIX"|"REST", "room_id", "request_id", "phase": "TRAVEL"|"WORK", "start", "end"}

const Money = preload("res://scripts/core/money.gd")

## Tắt để kiểm thử từng kịch bản mà không có nhân viên tự làm việc.
var enabled: bool = true

var _state
var _data: Dictionary
var _economy
var _rooms
var _service
var _notify: Callable


func _init(state, data: Dictionary, economy, rooms, service, notify: Callable) -> void:
	_state = state
	_data = data
	_economy = economy
	_rooms = rooms
	_service = service
	_notify = notify


func setup_new_game() -> void:
	_state.staff = []
	_state.staff_priority = []
	for def in _data["staff"]:
		if def["starter"]:
			_state.staff.append(_make_member(def))


func _make_member(def: Dictionary) -> Dictionary:
	return {
		"id": def["id"], "name": def["name"], "role": def["role"], "speed": def["speed"], "wage": def["wage"],
		"about": def["about"], "energy": 100, "task": {}, "tasks_done": 0,
	}


func get_member(staff_id: String) -> Variant:
	for member in _state.staff:
		if member["id"] == staff_id:
			return member
	return null


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
	if _state.staff.size() >= balance["staff_max"]:
		return "Quán chỉ thuê tối đa %d nhân viên phục vụ." % balance["staff_max"]
	var chosen: Variant = null
	for def in _data["staff"]:
		if def["id"] == staff_id:
			chosen = def
	if chosen == null:
		return "Không tìm thấy ứng viên."
	var cost: int = balance["staff_hire_cost"]
	if not _economy.can_afford(cost):
		return "Không đủ tiền: tuyển %s cần %s." % [chosen["name"], Money.format(cost)]
	if not _economy.record("HIRE_STAFF", -cost, staff_id, "Tuyển " + chosen["name"]):
		return "Đã thanh toán phí tuyển người này rồi."
	_state.staff.append(_make_member(chosen))
	_notify.call("%s nhận việc phục vụ (lương %s/đêm)." % [chosen["name"], Money.format(chosen["wage"])], "good")
	return ""


## Người chơi đánh dấu một phòng cần lo trước: nhân viên rảnh kế tiếp sẽ nhận ngay, không chờ nhịp.
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
		_economy.record("WAGES", -member["wage"], "day:%d:%s" % [day, member["id"]], "Lương " + member["name"])
		member["task"] = {}
		member["energy"] = 100
	_state.staff_priority = []


# ---------------------------------------------------------------- Nội bộ

func _claimed_by(room_id: String) -> String:
	for member in _state.staff:
		if is_busy(member) and member["task"].get("room_id", "") == room_id:
			return member["id"]
	return ""


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
		member["task"] = {"kind": "REST", "room_id": "", "request_id": 0, "phase": "WORK", "start": now, "end": now + balance["staff_rest_minutes"]}
		_notify.call("%s mệt, xin nghỉ %d phút." % [member["name"], balance["staff_rest_minutes"]], "info")
		return

	var best: Dictionary = {}
	var best_room: Dictionary = {}
	for room in _state.rooms:
		if _claimed_by(room["id"]) != "":
			continue
		var prioritized: bool = _state.staff_priority.has(room["id"])
		var job: Dictionary = _job_for(room, now, prioritized)
		if job.is_empty():
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
		"kind": best["kind"], "room_id": best_room["id"], "request_id": best["request_id"],
		"phase": "TRAVEL", "start": now, "end": now + _duration(member, base),
	}
	match best["kind"]:
		"DELIVER":
			_notify.call("%s ra quầy lấy món cho %s." % [member["name"], best_room["name"]], "info")
		"FIX":
			_notify.call("%s mang micro mới tới %s." % [member["name"], best_room["name"]], "info")
		"CLEAN":
			_notify.call("%s đi dọn %s." % [member["name"], best_room["name"]], "info")


## Thời gian làm theo tốc độ; năng lượng thấp thì chậm hơn. Tối thiểu 1 phút.
func _duration(member: Dictionary, base_minutes: int) -> int:
	var balance: Dictionary = _data["balance"]
	var scaled: float = base_minutes * 100.0 / maxi(1, member["speed"])
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
	if now < task["end"]:
		return
	if task["kind"] == "DELIVER":
		_service.deliver_order(room, now)
		_finish(member, balance["staff_energy_deliver"])
	else:
		_service.fix_mic(room, now)
		_finish(member, balance["staff_energy_fix"])


func _finish(member: Dictionary, energy_cost: int) -> void:
	member["task"] = {}
	member["tasks_done"] += 1
	member["energy"] = maxi(0, member["energy"] - energy_cost)
