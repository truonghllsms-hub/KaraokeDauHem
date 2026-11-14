extends RefCounted
## Mục "Lan can": nhân viên tiếp khách (trò chuyện, song ca, khuấy động không khí).
## Trạng thái nhân viên: READY (sẵn sàng), SERVING (đang ở phòng), RESTING (đang nghỉ).
## Phí dịch vụ chỉ được ghi vào hóa đơn khi phiên phục vụ hoàn tất; phiên bị cắt ngang thì không thu.

const Money = preload("res://scripts/core/money.gd")

var _state
var _data: Dictionary
var _rng: RandomNumberGenerator
var _economy
var _customers
var _rooms
var _notify: Callable
## Hàm (host, key, room_id, now) để phát câu riêng của nhân viên; Simulation gán sau khi khởi tạo.
var speak: Callable = Callable()


func _init(state, data: Dictionary, rng: RandomNumberGenerator, economy, customers, rooms, notify: Callable) -> void:
	_state = state
	_data = data
	_rng = rng
	_economy = economy
	_customers = customers
	_rooms = rooms
	_notify = notify


func get_host(host_id: String) -> Variant:
	for host in _state.hosts:
		if host["id"] == host_id:
			return host
	return null


## Những ứng viên chưa được tuyển.
func candidates() -> Array:
	var result: Array = []
	for def in _data["hosts"]:
		if get_host(def["id"]) == null:
			result.append(def)
	return result


func can_request(group: Dictionary) -> bool:
	return group.get("composition", "mixed") not in ["couple", "family"] and group["type"] not in ["couple", "family"]


func needs_staff(group: Dictionary) -> bool:
	return can_request(group) and group["host_request"] in ["PENDING", "ACTIVE"] and not group.get("host_request_closed", false) and group.get("host_assigned_count", 0) < group.get("host_requested_count", 1)


func request_label(group: Dictionary) -> String:
	if not needs_staff(group):
		return ""
	var gender: String = {"male": "nam", "female": "nữ", "any": "giao lưu"}.get(group.get("host_gender", "any"), "giao lưu")
	return "Gọi %d %s · còn thiếu %d" % [group.get("host_requested_count", 1), gender, group.get("host_requested_count", 1) - group.get("host_assigned_count", 0)]


func hire(host_id: String) -> String:
	var balance: Dictionary = _data["balance"]
	if get_host(host_id) != null:
		return "Người này đã làm ở quán rồi."
	if _state.hosts.size() >= balance["lancan_max_staff"]:
		return "Lan can chỉ có %d vị trí." % balance["lancan_max_staff"]
	var chosen: Variant = null
	for def in _data["hosts"]:
		if def["id"] == host_id:
			chosen = def
	if chosen == null:
		return "Không tìm thấy ứng viên."
	var cost: int = balance["lancan_hire_cost"]
	if not _economy.can_afford(cost):
		return "Không đủ tiền: tuyển %s cần %s." % [chosen["name"], Money.format(cost)]
	if not _economy.record("HIRE_LANCAN", -cost, host_id, "Tuyển " + chosen["name"]):
		return "Đã thanh toán phí tuyển người này rồi."
	var host: Dictionary = chosen.duplicate()
	host["state"] = "READY"
	host["room_id"] = ""
	host["group_id"] = 0
	host["service_end"] = 0
	host["rest_end"] = 0
	host["energy"] = 100
	host["tips_tonight"] = 0
	host["tips_total"] = 0
	_state.hosts.append(host)
	_notify.call("%s nhận việc ở Lan can: \"%s\"." % [host["name"], host["personality"]], "good")
	return ""


## Trả về "" nếu phân công được, ngược lại là lý do.
func check_assign(host: Dictionary, room: Dictionary, now: int) -> String:
	if host["state"] == "SERVING":
		return "%s đang phục vụ ở phòng khác." % host["name"]
	if host["state"] == "RESTING":
		return "%s đang nghỉ lấy sức." % host["name"]
	if room["state"] != "OCCUPIED":
		return "%s không có khách." % room["name"]
	var group = _customers.get_group(room["group_id"])
	if group == null or not needs_staff(group):
		return "Khách ở %s không gọi Lan can." % room["name"]
	if group.get("host_assigned_count", 0) >= group["size"]:
		return "Mỗi khách chỉ ghép với một nhân viên trong lượt này."
	var preference: String = group.get("host_gender", "any")
	if preference != "any" and host["gender"] != preference:
		return "Nhóm này đang gọi nhân viên %s." % ("nam" if preference == "male" else "nữ")
	if now + _data["balance"]["lancan_minutes"] > room["session_end"]:
		return "Khách ở %s sắp về, không đủ %d phút." % [room["name"], _data["balance"]["lancan_minutes"]]
	return ""


func assign(host: Dictionary, room: Dictionary, now: int) -> void:
	var group = _customers.get_group(room["group_id"])
	host["state"] = "SERVING"
	host["room_id"] = room["id"]
	host["group_id"] = group["id"]
	host["service_end"] = now + _data["balance"]["lancan_minutes"]
	host["guest_index"] = group.get("host_assigned_count", 0)
	group["host_assigned_count"] = host["guest_index"] + 1
	room["host_ids"].append(host["id"])
	room["host_id"] = room["host_ids"][0]
	group["host_request"] = "ACTIVE"
	_notify.call("%s vào %s góp vui %d phút." % [host["name"], room["name"], _data["balance"]["lancan_minutes"]], "info")
	if speak.is_valid():
		speak.call(host, "match" if host["music"] == group["music"] else "enter", room["id"], now)


func tick(now: int) -> void:
	var balance: Dictionary = _data["balance"]
	for host in _state.hosts:
		if host["state"] == "SERVING" and now >= host["service_end"]:
			_complete(host, now)
		elif host["state"] == "RESTING" and now >= host["rest_end"]:
			host["state"] = "READY"
			host["energy"] = 100
			_notify.call("%s nghỉ xong, sẵn sàng trở lại." % host["name"], "info")

	if _state.hosts.is_empty():
		return
	for group in _state.groups:
		if group["state"] != "IN_ROOM" or not group["wants_host"] or not can_request(group):
			continue
		var room = _rooms.get_room(group["room_id"])
		if group["host_request"] == "NONE":
			var early_enough: bool = now + balance["lancan_minutes"] + 5 <= room["session_end"]
			if now - room["session_start"] >= balance["lancan_request_delay"] and early_enough:
				group["host_request"] = "PENDING"
				group["host_request_at"] = now
				_notify.call("%s: %s." % [room["name"], request_label(group)], "info")
		elif needs_staff(group):
			var too_late: bool = now + balance["lancan_minutes"] > room["session_end"]
			if too_late or now - group["host_request_at"] >= balance["lancan_request_timeout"]:
				group["host_request_closed"] = true
				group["host_request"] = "ACTIVE" if group.get("host_assigned_count", 0) > group.get("host_completed_count", 0) else ("DONE" if group.get("host_assigned_count", 0) > 0 else "MISSED")
				group["tags"].append("lancan_lo")
				var missing: int = group.get("host_requested_count", 1) - group.get("host_assigned_count", 0)
				var penalty: int = ceili(float(balance["lancan_ignored_penalty"] * missing) / group.get("host_requested_count", 1))
				group["satisfaction"] = clampi(group["satisfaction"] - penalty, 0, 100)
				_notify.call("Thiếu %d nhân viên giao lưu: -%d hài lòng" % [missing, penalty], "bad")


## Phiên phục vụ hoàn tất: ghi phí vào hóa đơn phòng, cộng hài lòng, tính tip cho nhân viên.
func _complete(host: Dictionary, now: int) -> void:
	if host["state"] != "SERVING":
		return
	var balance: Dictionary = _data["balance"]
	var group = _customers.get_group(host["group_id"])
	var room = _rooms.get_room(host["room_id"])
	if group != null and room != null:
		var bonus: int = host["talk"] + host["duet"]
		if host["music"] == group["music"]:
			bonus += balance["lancan_music_match_bonus"]
			group["tags"].append("lancan_hop_gu")
		group["satisfaction"] = clampi(group["satisfaction"] + bonus, 0, 100)
		group["bill_items"].append({"type": "LANCAN_FEE", "amount": balance["lancan_fee"], "note": "Lan can: " + host["name"]})
		group["host_completed_count"] = group.get("host_completed_count", 0) + 1
		if group["host_completed_count"] >= group.get("host_assigned_count", 0):
			group["host_request"] = "DONE" if group.get("host_request_closed", false) or group.get("host_assigned_count", 0) >= group.get("host_requested_count", 1) else "PENDING"
		group["tags"].append("lancan")
		@warning_ignore("integer_division")
		var tip: int = Money.round_to_thousand(_rng.randi_range(0, balance["lancan_tip_max"]) * group["satisfaction"] / 100)
		host["tips_tonight"] += tip
		host["tips_total"] += tip
		var text: String = "%s khuấy động %s: +%d hài lòng" % [host["name"], room["name"], bonus]
		if tip > 0:
			text += ", được khách tip riêng %s" % Money.format(tip)
		_notify.call(text + ".", "good")
		if speak.is_valid():
			speak.call(host, "finish", room["id"], now)
	if room != null:
		_unlink(room, host["id"])
	_release(host, now)


## Khách rời phòng khi phiên chưa xong: không thu phí dịch vụ.
func release_room(room: Dictionary, now: int) -> void:
	for host_id in room["host_ids"].duplicate():
		var host = get_host(host_id)
		_unlink(room, host_id)
		if host != null:
			_notify.call("Khách về sớm, phiên của %s không tính phí." % host["name"], "info")
			_release(host, now)


func _unlink(room: Dictionary, host_id: String) -> void:
	room["host_ids"].erase(host_id)
	room["host_id"] = "" if room["host_ids"].is_empty() else room["host_ids"][0]


func _release(host: Dictionary, now: int) -> void:
	var balance: Dictionary = _data["balance"]
	host["room_id"] = ""
	host["group_id"] = 0
	host["energy"] = maxi(0, host["energy"] - balance["lancan_energy_cost"])
	if host["energy"] < balance["lancan_energy_cost"]:
		host["state"] = "RESTING"
		host["rest_end"] = now + balance["lancan_rest_minutes"]
		_notify.call("%s xin nghỉ %d phút lấy lại giọng." % [host["name"], balance["lancan_rest_minutes"]], "info")
		if speak.is_valid():
			speak.call(host, "rest", "", now)
	else:
		host["state"] = "READY"


## Kết ca: trả lương, hồi năng lượng.
func end_night(day: int) -> void:
	for host in _state.hosts:
		_economy.record("WAGES", -host["wage"], "day:%d:%s" % [day, host["id"]], "Lương " + host["name"])
		host["state"] = "READY"
		host["room_id"] = ""
		host["group_id"] = 0
		host["energy"] = 100


func begin_day() -> void:
	for host in _state.hosts:
		host["tips_tonight"] = 0
