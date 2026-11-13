extends RefCounted
## Khách quen: nhóm rất hài lòng có thể thành khách quen có tên, quay lại các đêm sau,
## có phòng quen và món quen. Phục vụ tệ thì họ bỏ quán.
##
## Một khách quen: {"id", "name", "type", "favorite_room_id", "favorite_product_id",
##                  "visits", "last_visit_day", "since_day"}

var _state
var _data: Dictionary
var _rng: RandomNumberGenerator
var _notify: Callable


func _init(state, data: Dictionary, rng: RandomNumberGenerator, notify: Callable) -> void:
	_state = state
	_data = data
	_rng = rng
	_notify = notify


func get_regular(regular_id: String) -> Variant:
	for regular in _state.regulars:
		if regular["id"] == regular_id:
			return regular
	return null


func _room_name(room_id: String) -> String:
	for room in _state.rooms:
		if room["id"] == room_id:
			return room["name"]
	return room_id


func _product_name(product_id: String) -> String:
	for product in _data["products"]:
		if product["id"] == product_id:
			return product["name"]
	return product_id


## Mô tả ngắn để hiển thị: "thích Phòng 02, hay gọi nước ngọt".
func describe(regular: Dictionary) -> String:
	return "thích %s, hay gọi %s" % [_room_name(regular["favorite_room_id"]), _product_name(regular["favorite_product_id"])]


## Chọn một khách quen ghé quán đêm nay (mỗi người tối đa một lần mỗi đêm), hoặc null.
## max_capacity: sức chứa phòng lớn nhất đã mở; type_min_sizes: {type_id: số người tối thiểu}.
func pick_visitor(day: int, max_capacity: int, type_min_sizes: Dictionary) -> Variant:
	var due: Array = []
	for regular in _state.regulars:
		if regular["last_visit_day"] < day and type_min_sizes.get(regular["type"], 999) <= max_capacity:
			due.append(regular)
	if due.is_empty():
		return null
	if _rng.randi_range(1, 100) > _data["balance"]["regular_return_chance"]:
		return null
	var chosen: Dictionary = due[_rng.randi_range(0, due.size() - 1)]
	chosen["last_visit_day"] = day
	return chosen


## Gắn thông tin khách quen vào nhóm vừa tạo: tên, phòng quen, món quen, kiên nhẫn hơn.
func apply_to_group(group: Dictionary, regular: Dictionary) -> void:
	var balance: Dictionary = _data["balance"]
	group["regular_id"] = regular["id"]
	group["regular_name"] = regular["name"]
	group["favorite_room_id"] = regular["favorite_room_id"]
	group["favorite_product_id"] = regular["favorite_product_id"]
	group["type_name"] = "%s (khách quen)" % regular["name"]
	group["trait"] = "Khách quen lần thứ %d: %s. %s" % [regular["visits"] + 1, describe(regular), group["trait"]]
	@warning_ignore("integer_division")
	group["patience"] = group["patience"] * (100 + balance["regular_patience_bonus_percent"]) / 100


func greeting() -> String:
	var lines: Array = _data["regulars"]["greetings"]
	return lines[_rng.randi_range(0, lines.size() - 1)]


## Gọi khi một nhóm thanh toán. ordered_product_id: món cuối cùng nhóm đã nhận ("" nếu không gọi).
func on_checkout(group: Dictionary, room_id: String, satisfaction: int, ordered_product_id: String, day: int) -> void:
	var balance: Dictionary = _data["balance"]
	var regular_id: String = group.get("regular_id", "")
	if regular_id != "":
		var regular = get_regular(regular_id)
		if regular == null:
			return
		if satisfaction < balance["regular_lost_below"]:
			_state.regulars.erase(regular)
			_notify.call("%s thất vọng và nói sẽ không quay lại nữa." % regular["name"], "bad")
		elif satisfaction >= balance["regular_keep_satisfaction"]:
			regular["visits"] += 1
		return

	if satisfaction < balance["regular_min_satisfaction"] or _state.regulars.size() >= balance["regular_max"]:
		return
	var chance: int = _data["regulars"]["become_chance"].get(group["type"], 0)
	var free_names: Array = _free_names(group["type"])
	if chance <= 0 or free_names.is_empty():
		return
	if _rng.randi_range(1, 100) > chance:
		return
	var product_id: String = ordered_product_id
	if product_id == "":
		var products: Array = _data["products"]
		product_id = products[_rng.randi_range(0, products.size() - 1)]["id"]
	var regular: Dictionary = {
		"id": "regular_%d" % _state.next_regular_id,
		"name": free_names[_rng.randi_range(0, free_names.size() - 1)],
		"type": group["type"],
		"favorite_room_id": room_id,
		"favorite_product_id": product_id,
		"visits": 1,
		"last_visit_day": day,
		"since_day": day,
	}
	_state.next_regular_id += 1
	_state.regulars.append(regular)
	_notify.call("%s thành khách quen của quán! Họ %s." % [regular["name"], describe(regular)], "good")


func _free_names(type_id: String) -> Array:
	var used: Dictionary = {}
	for regular in _state.regulars:
		used[regular["name"]] = true
	var result: Array = []
	for candidate in _data["regulars"]["names"].get(type_id, []):
		if not used.has(candidate):
			result.append(candidate)
	return result
