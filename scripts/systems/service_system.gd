extends RefCounted
## Nhu cầu phát sinh khi khách đang hát: gọi món, micro trục trặc, phòng nóng, xin hát thêm.
## Mỗi phòng có tối đa một yêu cầu đang mở (room["request"]), có hạn chót; quá hạn thì có hậu quả.
## Hàng được giữ chỗ ngay khi khách gọi và trả lại kho nếu đơn bị hủy.

const Money = preload("res://scripts/core/money.gd")
const Clock = preload("res://scripts/core/simulation_clock.gd")

## Tắt để kiểm thử từng kịch bản mà không có yêu cầu ngẫu nhiên.
var enabled: bool = true
## Hàm (room, key, now) để phát thoại phản ứng; Simulation gán sau khi khởi tạo.
var react: Callable = Callable()

var _state
var _data: Dictionary
var _rng: RandomNumberGenerator
var _economy
var _customers
var _notify: Callable
var _change_satisfaction: Callable


func _init(state, data: Dictionary, rng: RandomNumberGenerator, economy, customers, notify: Callable, change_satisfaction: Callable) -> void:
	_state = state
	_data = data
	_rng = rng
	_economy = economy
	_customers = customers
	_notify = notify
	_change_satisfaction = change_satisfaction


func setup_new_game() -> void:
	_state.stock = {}
	for product in _data["products"]:
		_state.stock[product["id"]] = product["start_stock"]
	_state.upgrades = {}


func get_product(product_id: String) -> Variant:
	for product in _data["products"]:
		if product["id"] == product_id:
			return product
	return null


func get_upgrade(upgrade_id: String) -> Variant:
	for upgrade in _data["upgrades"]:
		if upgrade["id"] == upgrade_id:
			return upgrade
	return null


func upgrade_level(upgrade_id: String) -> int:
	return _state.upgrades.get(upgrade_id, 0)


## Nhập một lô hàng. Tiền trừ ngay lúc nhập kho.
func buy_stock(product_id: String) -> String:
	var product = get_product(product_id)
	if product == null:
		return "Không có mặt hàng này."
	var cost: int = product["cost"] * product["pack_size"]
	if not _economy.can_afford(cost):
		return "Không đủ tiền: nhập %d %s %s cần %s." % [product["pack_size"], product["unit"], product["name"], Money.format(cost)]
	_state.purchase_counter += 1
	_economy.record("STOCK", -cost, "buy:%d" % _state.purchase_counter, "Nhập %d %s %s" % [product["pack_size"], product["unit"], product["name"]])
	_state.stock[product_id] += product["pack_size"]
	return ""


func buy_upgrade(upgrade_id: String) -> String:
	var upgrade = get_upgrade(upgrade_id)
	if upgrade == null:
		return "Không có nâng cấp này."
	var level: int = upgrade_level(upgrade_id)
	if level >= upgrade["max_level"]:
		return "%s đã ở cấp cao nhất." % upgrade["name"]
	var cost: int = upgrade_cost(upgrade_id)
	if not _economy.can_afford(cost):
		return "Không đủ tiền: %s cần %s." % [upgrade["name"], Money.format(cost)]
	if not _economy.record("UPGRADE", -cost, "%s:%d" % [upgrade_id, level + 1], upgrade["name"]):
		return "Nâng cấp này đã được thanh toán."
	_state.upgrades[upgrade_id] = level + 1
	if upgrade_id in ["sound", "soundproof"]:
		for room in _state.rooms:
			room[upgrade_id] += 1
	_notify.call("Đã lắp %s (cấp %d)." % [upgrade["name"], level + 1], "good")
	return ""


func tick(now: int) -> void:
	var balance: Dictionary = _data["balance"]
	for room in _state.rooms:
		if room["state"] != "OCCUPIED":
			continue
		var group = _customers.get_group(room["group_id"])
		if group == null:
			continue
		if not room["request"].is_empty():
			if now >= room["request"]["deadline"]:
				_expire(room, group)
			continue
		if not enabled:
			continue

		var remaining: int = room["session_end"] - now
		if not group["extend_asked"] and remaining <= balance["extend_ask_before"] and remaining >= 4:
			group["extend_asked"] = true
			var fits_night: bool = room["session_end"] + balance["extend_minutes"] <= Clock.NIGHT_MINUTES
			if fits_night and _rng.randi_range(1, 100) <= group["extend_chance"]:
				_open(room, {"kind": "EXTEND", "text": "Xin hát thêm %d'" % balance["extend_minutes"]}, now, mini(balance["extend_timeout"], remaining - 1))
				_notify.call("%s: \"Đang hay mà, cho tụi anh hát thêm %d phút nha em?\"" % [room["name"], balance["extend_minutes"]], "info")
				continue
		if group["requests_left"] > 0 and now >= group["next_request_at"] and remaining >= balance["request_min_remaining"]:
			group["requests_left"] -= 1
			group["next_request_at"] = now + _rng.randi_range(balance["request_gap_min"], balance["request_gap_max"])
			_open_random(room, group, now)


func _open(room: Dictionary, request: Dictionary, now: int, timeout: int) -> void:
	request["id"] = _state.next_request_id
	request["opened"] = now
	request["deadline"] = now + timeout
	_state.next_request_id += 1
	room["request"] = request


func _open_random(room: Dictionary, group: Dictionary, now: int) -> void:
	if _state.day == 1 and _state.night.get("training_spawned", 0) > 0:
		_open_order(room, group, now)
		return
	var balance: Dictionary = _data["balance"]
	var mic_weight: int = mic_request_weight()
	var hot_weight: int = hot_request_weight()
	@warning_ignore("integer_division")
	mic_weight = mic_weight * room.get("mic_weight_percent", 100) / 100
	var roll: int = _rng.randi_range(1, balance["request_weight_order"] + mic_weight + hot_weight)
	if roll <= balance["request_weight_order"]:
		_open_order(room, group, now)
	elif roll <= balance["request_weight_order"] + mic_weight:
		_open(room, {"kind": "MIC", "text": "Micro trục trặc!"}, now, balance["mic_timeout"])
		_notify.call("%s: micro hú rồi tắt tiếng, khách đang gọi." % room["name"], "bad")
		_react(room, "mic_broken", now)
	else:
		_open(room, {"kind": "HOT", "text": "Phòng nóng quá!"}, now, balance["hot_timeout"])
		_notify.call("%s: \"Phòng nóng quá em ơi!\"" % room["name"], "info")
		_react(room, "hot", now)


func _open_order(room: Dictionary, group: Dictionary, now: int) -> void:
	var balance: Dictionary = _data["balance"]
	var products: Array = _data["products"]
	var product: Dictionary = products[_rng.randi_range(0, products.size() - 1)]
	# Khách quen thường gọi món quen.
	var favorite_id: String = group.get("favorite_product_id", "")
	if favorite_id != "" and _rng.randi_range(1, 100) <= balance["regular_favorite_product_chance"]:
		product = get_product(favorite_id)
	var quantity: int = group["size"] if product["per_person"] else _rng.randi_range(1, 2)
	var in_stock: int = _state.stock[product["id"]]
	if in_stock <= 0:
		group["tags"].append("het_hang")
		_change_satisfaction.call(group, -balance["out_of_stock_penalty"], "%s gọi %s nhưng kho đã hết" % [room["name"], product["name"]])
		return
	quantity = mini(quantity, in_stock)
	# Giữ chỗ hàng để không bán trùng tồn kho.
	_state.stock[product["id"]] -= quantity
	var timeout: int = balance["order_timeout"] + balance["cart_bonus_minutes"] * upgrade_level("cart")
	var price: int = product["price"] * quantity
	_open(room, {
		"kind": "ORDER", "product_id": product["id"], "quantity": quantity, "price": price,
		"text": "%d %s %s · %s" % [quantity, product["unit"], product["name"], Money.format(price)],
	}, now, timeout)
	_notify.call("%s: \"%s\" (%d %s, %s)" % [room["name"], product["call"], quantity, product["unit"], Money.format(price)], "info")


func _react(room: Dictionary, key: String, now: int) -> void:
	if react.is_valid():
		react.call(room, key, now)


func _expire(room: Dictionary, group: Dictionary) -> void:
	var balance: Dictionary = _data["balance"]
	var request: Dictionary = room["request"]
	room["request"] = {}
	match request["kind"]:
		"ORDER":
			_state.stock[request["product_id"]] += request["quantity"]
			group["tags"].append("cho_do")
			_react(room, "order_late", request["deadline"])
			_change_satisfaction.call(group, -balance["order_late_penalty"], "%s chờ đồ quá lâu, hủy món" % room["name"])
		"MIC":
			group["tags"].append("micro")
			group["discount_percent"] = balance["mic_discount_percent"]
			_change_satisfaction.call(group, -balance["mic_penalty"] * group["mic_penalty_mult"], "%s: micro hỏng không ai xử lý (giảm %d%% tiền phòng xin lỗi khách)" % [room["name"], balance["mic_discount_percent"]])
		"HOT":
			group["tags"].append("nong")
			_change_satisfaction.call(group, -balance["hot_penalty"], "%s nóng mà không ai chỉnh" % room["name"])
		"EXTEND":
			_notify.call("%s: khách thôi không xin hát thêm nữa." % room["name"], "info")


## Khách rời phòng: hủy yêu cầu còn mở, trả hàng giữ chỗ về kho.
func close_room(room: Dictionary) -> void:
	var request: Dictionary = room["request"]
	if not request.is_empty() and request["kind"] == "ORDER":
		_state.stock[request["product_id"]] += request["quantity"]
	room["request"] = {}


func _open_request(room: Dictionary, kind: String) -> Variant:
	if room["state"] != "OCCUPIED" or room["request"].is_empty() or room["request"]["kind"] != kind:
		return null
	return room["request"]


func deliver_order(room: Dictionary, now: int) -> String:
	var request = _open_request(room, "ORDER")
	if request == null:
		return "%s không có món nào đang chờ." % room["name"]
	var balance: Dictionary = _data["balance"]
	var group = _customers.get_group(room["group_id"])
	var product = get_product(request["product_id"])
	room["request"] = {}
	group["bill_items"].append({"type": "ORDER", "amount": request["price"], "note": "%d %s %s" % [request["quantity"], product["unit"], product["name"]], "product_id": product["id"]})
	var bonus: int = balance["order_bonus"]
	var reason: String = "%s nhận món" % room["name"]
	if group.get("favorite_product_id", "") == product["id"]:
		bonus += balance["regular_favorite_product_bonus"]
	if now - request["opened"] <= balance["fast_service_minutes"]:
		bonus += balance["fast_service_bonus"]
		reason = "%s nhận món rất nhanh" % room["name"]
		group["tags"].append("giao_nhanh")
	_change_satisfaction.call(group, bonus, reason)
	return ""


func fix_mic(room: Dictionary, now: int) -> String:
	var request = _open_request(room, "MIC")
	if request == null:
		return "Micro ở %s vẫn ổn." % room["name"]
	var group = _customers.get_group(room["group_id"])
	room["request"] = {}
	if now - request["opened"] <= _data["balance"]["fast_service_minutes"]:
		_change_satisfaction.call(group, 1, "%s được đổi micro ngay" % room["name"])
		_react(room, "mic_fixed_fast", now)
	else:
		_notify.call("Đã đổi micro mới cho %s." % room["name"], "info")
	return ""


## choice: HOT -> "ac" | "ignore"; EXTEND -> "accept" | "decline".
func answer(room: Dictionary, choice: String) -> String:
	var balance: Dictionary = _data["balance"]
	if room["state"] != "OCCUPIED" or room["request"].is_empty():
		return "%s không có yêu cầu nào." % room["name"]
	var request: Dictionary = room["request"]
	var group = _customers.get_group(room["group_id"])
	if request["kind"] == "HOT":
		room["request"] = {}
		if choice == "ac":
			_economy.record("UTILITIES", -cooling_cost(), "request:%d" % request["id"], "Tăng điều hòa " + room["name"])
			_change_satisfaction.call(group, balance["ac_bonus"], "%s mát rượi (tốn %s tiền điện)" % [room["name"], Money.format(cooling_cost())])
		else:
			group["tags"].append("nong")
			_change_satisfaction.call(group, -balance["hot_penalty"], "%s vẫn nóng" % room["name"])
		return ""
	if request["kind"] == "EXTEND":
		if choice == "accept":
			if room["session_end"] + balance["extend_minutes"] > Clock.NIGHT_MINUTES:
				return "Không gia hạn được: quá giờ đóng cửa."
			room["request"] = {}
			room["session_end"] += balance["extend_minutes"]
			group["tags"].append("hat_them")
			_change_satisfaction.call(group, balance["extend_bonus"], "%s được hát thêm %d phút" % [room["name"], balance["extend_minutes"]])
		else:
			room["request"] = {}
			_change_satisfaction.call(group, -balance["extend_decline_penalty"], "%s bị từ chối hát thêm" % room["name"])
			_react(room, "extend_declined", request["opened"])
		return ""
	return "Yêu cầu này cần chủ quán tới tận phòng."


func upgrade_cost(upgrade_id: String) -> int:
	var definition = get_upgrade(upgrade_id)
	if definition == null: return 0
	return Money.round_to_thousand(int(round(definition["cost"] * pow(definition.get("cost_growth_percent", 100)/100.0, upgrade_level(upgrade_id)))))

func mic_request_weight() -> int:
	var level: int = upgrade_level("spare_mics")
	return _data["balance"]["request_weight_mic"] if level == 0 else maxi(1, int(round(_data["balance"]["request_weight_mic_spare"] * pow(0.65, level-1))))

func hot_request_weight() -> int:
	return maxi(1, int(round(_data["balance"]["request_weight_hot"] * maxf(0.25, 1.0-0.12*upgrade_level("aircon")))))

func cooling_cost() -> int:
	return Money.round_to_thousand(int(round(_data["balance"]["ac_cost"] * (1.0-0.05*upgrade_level("aircon")))))
