extends RefCounted
## Trộm xe: thỉnh thoảng một tên trộm rón rén đi từ đầu hẻm vào bãi xe, mất vài phút phá khóa rồi tẩu thoát.
## Chủ quán bấm đuổi kịp trước lúc hắn tẩu thoát thì xe an toàn; bảo vệ (nếu có) tự đuổi nhưng không bắt
## được 100%. Mất xe thì quán đền tiền cho khách, khách mất hứng và danh tiếng giảm.
##
## state.thief: {} khi không có trộm, ngược lại {"id", "group_id", "appear", "reach", "escape",
##   "state": "APPROACH"|"STEALING"|"CAUGHT"|"ESCAPED", "catch_at", "chased_by", "resolved_at"}

const Money = preload("res://scripts/core/money.gd")

var enabled: bool = true
var visual_chase: bool = false

var _state
var _data: Dictionary
var _rng: RandomNumberGenerator
var _economy
var _customers
var _notify: Callable


func _init(state, data: Dictionary, rng: RandomNumberGenerator, economy, customers, notify: Callable) -> void:
	_state = state
	_data = data
	_rng = rng
	_economy = economy
	_customers = customers
	_notify = notify


func risk_active() -> bool:
	return _state.day >= _data["balance"]["theft_start_day"]


func is_active() -> bool:
	return not _state.thief.is_empty() and _state.thief["state"] in ["APPROACH", "STEALING"]


func _parked_groups() -> Array:
	return _state.groups.filter(func(g: Dictionary) -> bool: return g["state"] in ["IN_ROOM", "WAITING"] and ceili(g["size"] / 2.0) > g.get("stolen_bikes", 0))


## Đưa một tên trộm vào bãi xe ngay (dùng cho kiểm thử và công cụ debug).
func spawn(now: int) -> bool:
	if is_active():
		return false
	var parked: Array = _parked_groups()
	if parked.is_empty():
		return false
	var balance: Dictionary = _data["balance"]
	var target: Dictionary = parked[_rng.randi_range(0, parked.size() - 1)]
	var reach: int = now + balance["thief_approach_minutes"]
	_state.thief = {
		"id": _state.day * 1000 + now, "group_id": target["id"], "appear": now, "reach": reach,
		"escape": reach + balance["thief_steal_minutes"], "state": "APPROACH", "catch_at": -1, "chased_by": "", "resolved_at": -1,
	}
	if _state.guard_hired:
		# Bảo vệ để ý sau vài phút; phần lớn trường hợp bắt kịp.
		if _rng.randi_range(1, 100) <= balance["guard_catch_percent"]:
			_state.thief["catch_at"] = now + balance["guard_react_minutes"] + balance["chase_minutes"]
			_state.thief["chased_by"] = "guard"
	_notify.call("Có người lạ lảng vảng ngoài bãi xe…", "bad")
	return true


## Chủ quán chạy ra đuổi. Bắt kịp nếu chạy tới nơi trước lúc trộm tẩu thoát.
func chase(now: int) -> String:
	if not is_active():
		return "Không có trộm nào trong bãi xe."
	var thief: Dictionary = _state.thief
	var arrive: int = now + _data["balance"]["chase_minutes"]
	if thief["chased_by"] == "owner" or (thief["catch_at"] >= 0 and thief["catch_at"] <= arrive):
		return "Đã có người đuổi theo rồi."
	thief["catch_at"] = -1 if visual_chase else arrive
	thief["chased_by"] = "owner"
	return ""


func confirm_chase(now: int) -> bool:
	if not is_active() or _state.thief.get("chased_by", "") != "owner" or now >= _state.thief["escape"]:
		return false
	_state.thief["catch_at"] = now
	tick(now)
	return _state.thief["state"] == "CAUGHT"


func tick(now: int) -> void:
	if _state.thief.is_empty():
		if enabled and risk_active() and not _parked_groups().is_empty():
			# Xác suất mỗi phút sao cho trung bình khoảng thief_chance_per_hour_percent% mỗi giờ.
			if _rng.randi_range(1, 6000) <= _data["balance"]["thief_chance_per_hour_percent"]:
				spawn(now)
		return
	var thief: Dictionary = _state.thief
	if thief["state"] in ["CAUGHT", "ESCAPED"]:
		# Giữ lại vài phút cho giao diện vẽ cảnh kết thúc rồi xóa.
		if now - thief["resolved_at"] >= 4:
			_state.thief = {}
		return
	if thief["catch_at"] >= 0 and now >= thief["catch_at"] and thief["catch_at"] <= thief["escape"]:
		thief["state"] = "CAUGHT"
		thief["resolved_at"] = now
		_state.night["thieves_caught"] = _state.night.get("thieves_caught", 0) + 1
		var group = _customers.get_group(thief["group_id"])
		if group != null:
			group["tags"].append("trom_bat")
		_notify.call("%s tóm được tên trộm! Xe của khách an toàn." % ("Bảo vệ" if thief["chased_by"] == "guard" else "Chủ quán"), "good")
		return
	if now >= thief["escape"]:
		_steal(thief, now)
	elif now >= thief["reach"]:
		thief["state"] = "STEALING"


func _steal(thief: Dictionary, now: int) -> void:
	var balance: Dictionary = _data["balance"]
	thief["state"] = "ESCAPED"
	thief["resolved_at"] = now
	var group = _customers.get_group(thief["group_id"])
	if group == null or ceili(group["size"] / 2.0) <= group.get("stolen_bikes", 0):
		var parked: Array = _parked_groups()
		if parked.is_empty():
			_notify.call("Tên trộm lảng vảng rồi bỏ đi tay không.", "info")
			return
		group = parked[0]
		thief["group_id"] = group["id"]
	group["stolen_bikes"] = group.get("stolen_bikes", 0) + 1
	group["tags"].append("mat_xe")
	group["satisfaction"] = clampi(group["satisfaction"] - balance["thief_satisfaction_penalty"], 0, 100)
	_state.night["thefts"] += 1
	_economy.record("COMPENSATION", -balance["theft_compensation"], "thief:%d" % thief["id"], "Đền xe cho nhóm " + group["type_name"])
	_state.reputation = clampi(_state.reputation - balance["theft_reputation_penalty"], 0, 100)
	_notify.call("MẤT XE! Trộm đã lấy xe của nhóm %s. Quán đền %s, -%d danh tiếng." % [group["type_name"], Money.format(balance["theft_compensation"]), balance["theft_reputation_penalty"]], "bad")


func end_night() -> void:
	_state.thief = {}
