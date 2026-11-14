extends RefCounted
## Quản lý phòng và chuyển trạng thái. Cả sáu phòng đã được xây sẵn; trạng thái "LOCKED" nghĩa là
## phòng CHƯA LẮP THIẾT BỊ (giữ tên cũ để tương thích), lắp xong thì thành AVAILABLE.
## LOCKED -> AVAILABLE -> OCCUPIED -> DIRTY -> CLEANING -> AVAILABLE. (BROKEN dành cho giai đoạn sau.)

const Money = preload("res://scripts/core/money.gd")

var _state
var _data: Dictionary


func _init(state, data: Dictionary) -> void:
	_state = state
	_data = data


func setup_new_game() -> void:
	_state.rooms = []
	for def in _data["rooms"]:
		_state.rooms.append({
			"id": def["id"],
			"name": def["name"],
			"capacity": def["capacity"],
			"price_per_hour": def["price_per_hour"],
			"unlock_cost": def["unlock_cost"],
			"state": "AVAILABLE" if def["unlocked"] else "LOCKED",
			"sound": def["sound"],
			"soundproof": def["soundproof"],
			"cleanliness": 100,
			"durability": 100,
			"group_id": 0,
			"host_id": "",
			"request": {},
			"dirty_since": 0,
			# Loại phòng và lợi ích (VIP khác phòng thường ở các số này).
			"tier": def["tier"],
			"tier_name": def["tier_name"],
			"equipment": def["equipment"].duplicate(),
			"perks": def["perks"].duplicate(),
			"upkeep_per_night": def["upkeep_per_night"],
			"comfort_bonus": def["comfort_bonus"],
			"budget_bonus_percent": def["budget_bonus_percent"],
			"mic_weight_percent": def["mic_weight_percent"],
			"session_start": 0,
			"session_end": 0,
			"session_price": 0,
			"task_start": 0,
			"task_end": 0,
		})


func get_room(room_id: String) -> Variant:
	for room in _state.rooms:
		if room["id"] == room_id:
			return room
	return null


func unlocked_count() -> int:
	var count: int = 0
	for room in _state.rooms:
		if room["state"] != "LOCKED":
			count += 1
	return count


func max_unlocked_capacity() -> int:
	var best: int = 0
	for room in _state.rooms:
		if room["state"] != "LOCKED":
			best = maxi(best, room["capacity"])
	return best


## Trả về "" nếu xếp được, ngược lại là lý do bằng tiếng Việt.
func check_assign(room: Dictionary, group: Dictionary, now: int, night_minutes: int) -> String:
	match room["state"]:
		"LOCKED":
			return "%s chưa lắp thiết bị." % room["name"]
		"OCCUPIED":
			return "%s đang có khách." % room["name"]
		"DIRTY":
			return "%s chưa dọn, không thể nhận khách." % room["name"]
		"CLEANING":
			return "%s đang dọn, chờ một chút." % room["name"]
		"BROKEN":
			return "%s đang hỏng thiết bị." % room["name"]
	if group["size"] > room["capacity"]:
		return "%s chỉ chứa %d người, nhóm có %d người." % [room["name"], room["capacity"], group["size"]]
	if now + group["planned_minutes"] > night_minutes:
		return "Không kịp hát %d phút trước giờ đóng cửa." % group["planned_minutes"]
	# Khách thấy giá trước khi nhận phòng: đắt hơn ngân sách quá nhiều thì họ từ chối.
	var budget: int = effective_budget(room, group)
	if room["price_per_hour"] * 100 > budget * (100 + _data["balance"]["price_refuse_over_percent"]):
		return "Nhóm %s chê giá: %s tính %s/giờ, họ chỉ định chi khoảng %s/giờ." % [group["type_name"], room["name"], Money.format(room["price_per_hour"]), Money.format(budget)]
	return ""


## Ngân sách mỗi giờ nhóm chấp nhận cho phòng này (phòng VIP được nới thêm).
func effective_budget(room: Dictionary, group: Dictionary) -> int:
	@warning_ignore("integer_division")
	return group["budget_per_hour"] * (100 + room.get("budget_bonus_percent", 0)) / 100


func start_session(room: Dictionary, group: Dictionary, now: int) -> void:
	room["state"] = "OCCUPIED"
	room["group_id"] = group["id"]
	room["session_start"] = now
	room["session_end"] = now + group["planned_minutes"]
	room["session_price"] = room["price_per_hour"]


func end_session(room: Dictionary) -> void:
	room["state"] = "DIRTY"
	room["group_id"] = 0
	room["host_id"] = ""
	room["request"] = {}
	room["cleanliness"] = 40


func start_cleaning(room: Dictionary, now: int) -> String:
	if room["state"] == "CLEANING":
		return "%s đang được dọn rồi." % room["name"]
	if room["state"] != "DIRTY":
		return "%s không cần dọn." % room["name"]
	room["state"] = "CLEANING"
	room["task_start"] = now
	room["task_end"] = now + _data["balance"]["clean_minutes"]
	return ""


func finish_cleaning(room: Dictionary) -> void:
	room["state"] = "AVAILABLE"
	room["cleanliness"] = 100


## Trả về danh sách phòng vừa dọn xong trong phút này.
func tick(now: int) -> Array:
	var finished: Array = []
	for room in _state.rooms:
		if room["state"] == "CLEANING" and now >= room["task_end"]:
			finish_cleaning(room)
			finished.append(room)
	return finished
