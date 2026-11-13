extends RefCounted
## Sinh nhóm khách, quản lý hàng chờ và mức kiên nhẫn.
## Vòng đời: WAITING -> IN_ROOM -> CHECKOUT -> LEAVING, hoặc LEFT_UNSERVED nếu bỏ về.

const Clock = preload("res://scripts/core/simulation_clock.gd")

## Tắt để kiểm thử từng kịch bản mà không có khách ngẫu nhiên.
var spawning_enabled: bool = true
## Hệ thống khách quen (Simulation gán sau khi khởi tạo); null thì không có khách quen ghé.
var regulars = null

var _state
var _data: Dictionary
var _rng: RandomNumberGenerator
var _rooms
var _notify: Callable


func _init(state, data: Dictionary, rng: RandomNumberGenerator, rooms, notify: Callable) -> void:
	_state = state
	_data = data
	_rng = rng
	_rooms = rooms
	_notify = notify


func get_group(group_id: int) -> Variant:
	for group in _state.groups:
		if group["id"] == group_id:
			return group
	return null


func get_type(type_id: String) -> Variant:
	for t in _data["customers"]["types"]:
		if t["id"] == type_id:
			return t
	return null


func waiting_groups() -> Array:
	var result: Array = []
	for group in _state.groups:
		if group["state"] == "WAITING":
			result.append(group)
	return result


func music_name(music_id: String) -> String:
	return _data["customers"]["music_names"].get(music_id, music_id)


## Tạo một nhóm và đưa vào hàng chờ. Dùng chung cho sinh khách tự động, debug và kiểm thử.
func add_group(type_id: String, size: int, planned_minutes: int, now: int, music: String = "") -> Variant:
	var t = get_type(type_id)
	if t == null:
		return null
	if music == "":
		music = _pick_weighted(t["music"])
	var group: Dictionary = {
		"id": _state.next_group_id,
		"type": type_id,
		"type_name": t["name"],
		"size": size,
		"budget_per_hour": t["budget_per_hour"],
		"planned_minutes": planned_minutes,
		"music": music,
		"patience": _rng.randi_range(t["patience_min"], t["patience_max"]),
		"satisfaction": _data["balance"]["base_satisfaction"],
		"state": "WAITING",
		"room_id": "",
		"arrived_at": now,
		"wait_minutes": 0,
		"sprites": t["sprites"],
		# Lan can: NONE -> PENDING -> ACTIVE -> DONE, hoặc MISSED nếu không ai tới.
		"wants_host": _rng.randi_range(1, 100) <= t["lancan_chance"],
		"host_request": "NONE",
		"host_request_at": 0,
		# Các khoản ngoài tiền phòng, được thu cùng lúc thanh toán.
		"bill_items": [],
		# Nhu cầu khi đang hát.
		"trait": t["trait"],
		"requests_left": _rng.randi_range(t["orders_min"], t["orders_max"]),
		"next_request_at": 0,
		"extend_chance": t["extend_chance"],
		"extend_asked": false,
		"mic_penalty_mult": t["mic_penalty_mult"],
		"discount_percent": 0,
		# Dấu vết trải nghiệm, dùng để viết lời nhận xét cuối đêm.
		"tags": [],
		# Khách quen (rỗng nếu là khách vãng lai).
		"regular_id": "",
		"regular_name": "",
		"favorite_room_id": "",
		"favorite_product_id": "",
	}
	_state.next_group_id += 1
	_state.groups.append(group)
	return group


func remove_group(group: Dictionary) -> void:
	for i in _state.groups.size():
		if _state.groups[i]["id"] == group["id"]:
			_state.groups.remove_at(i)
			return


func tick(now: int) -> void:
	var balance: Dictionary = _data["balance"]
	for group in waiting_groups():
		group["wait_minutes"] += 1
		if now + group["planned_minutes"] > Clock.NIGHT_MINUTES:
			_leave_unserved(group, "Nhóm %s: \"Muộn quá rồi, hẹn bữa khác nha!\"" % group["type_name"], 0)
		elif group["wait_minutes"] >= group["patience"]:
			_leave_unserved(group, "Nhóm %s chờ quá lâu nên bỏ về." % group["type_name"], balance["reputation_unserved_penalty"])

	if spawning_enabled and now <= balance["last_spawn_minute"] and now >= _state.next_arrival_minute:
		_spawn_random(now)
		# Quán càng nhiều phòng thì khách tới càng dày, để lượng khách không vượt sức phục vụ.
		var interval: int = _rng.randi_range(balance["spawn_interval_min"], balance["spawn_interval_max"])
		@warning_ignore("integer_division")
		_state.next_arrival_minute = now + maxi(1, interval * 3 / (_rooms.unlocked_count() + 1))


## Giờ đóng cửa: những nhóm còn chờ ra về, không trừ danh tiếng.
func clear_waiting_at_close() -> void:
	for group in waiting_groups():
		_leave_unserved(group, "Nhóm %s ra về vì quán đóng cửa." % group["type_name"], 0)


func _leave_unserved(group: Dictionary, text: String, reputation_penalty: int) -> void:
	group["state"] = "LEFT_UNSERVED"
	remove_group(group)
	_state.night["unserved"] += 1
	if reputation_penalty > 0:
		_state.reputation = clampi(_state.reputation - reputation_penalty, 0, 100)
		text += " (-%d danh tiếng)" % reputation_penalty
	_notify.call(text, "bad")


func _spawn_random(now: int) -> void:
	var balance: Dictionary = _data["balance"]
	var capacity: int = _rooms.max_unlocked_capacity()

	# Chỉ sinh nhóm mà quán có phòng đủ chứa và còn kịp hát trước giờ đóng cửa.
	var weights: Dictionary = {}
	for t in _data["customers"]["types"]:
		if t["size_min"] <= capacity:
			weights[t["id"]] = t["weight"]
	var stay_options: Array = []
	for minutes in balance["stay_options"]:
		if now + minutes + balance["seat_grace_minutes"] <= Clock.NIGHT_MINUTES:
			stay_options.append(minutes)
	if weights.is_empty() or stay_options.is_empty():
		return

	# Khách quen ghé lại (nếu có ai tới lượt), không thì sinh nhóm ngẫu nhiên.
	var visitor: Variant = null
	if regulars != null and not _state.regulars.is_empty():
		var min_sizes: Dictionary = {}
		for t in _data["customers"]["types"]:
			min_sizes[t["id"]] = t["size_min"]
		visitor = regulars.pick_visitor(_state.day, capacity, min_sizes)
	var chosen: Dictionary = get_type(visitor["type"] if visitor != null else _pick_weighted(weights))
	var size: int = _rng.randi_range(chosen["size_min"], mini(chosen["size_max"], capacity))
	var planned: int = stay_options[_rng.randi_range(0, stay_options.size() - 1)]

	if waiting_groups().size() >= balance["queue_limit"]:
		_state.night["unserved"] += 1
		_notify.call("Sảnh chờ hết chỗ, %s thấy đông nên quay xe." % (visitor["name"] if visitor != null else "một nhóm " + chosen["name"]), "bad")
		return

	var group = add_group(chosen["id"], size, planned, now)
	if visitor != null:
		regulars.apply_to_group(group, visitor)
		_notify.call("%s (%d người) ghé lại quán: \"%s\"" % [visitor["name"], size, regulars.greeting()], "good")
		return
	var greetings: Array = chosen["greetings"]
	var line: String = greetings[_rng.randi_range(0, greetings.size() - 1)]
	_notify.call("Nhóm %s (%d người) tới quầy: \"%s\"" % [group["type_name"], size, line], "info")


func _pick_weighted(weights: Dictionary) -> String:
	var total: int = 0
	for key in weights:
		total += weights[key]
	var roll: int = _rng.randi_range(1, total)
	for key in weights:
		roll -= weights[key]
		if roll <= 0:
			return key
	return weights.keys()[0]
