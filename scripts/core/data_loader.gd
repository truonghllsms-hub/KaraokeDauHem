extends RefCounted
## Đọc dữ liệu định nghĩa từ res://data một lần và kiểm tra hợp lệ khi khởi động.

const ROOM_KEYS: Array = ["id", "name", "capacity", "price_per_hour", "unlock_cost", "unlocked", "sound", "soundproof"]
const TYPE_KEYS: Array = ["id", "name", "weight", "size_min", "size_max", "budget_per_hour", "patience_min", "patience_max", "music", "greetings", "lancan_chance", "sprites", "trait", "orders_min", "orders_max", "extend_chance", "mic_penalty_mult"]
const BALANCE_KEYS: Array = [
	"starting_money",
	"starting_reputation",
	"queue_limit",
	"first_arrival_minute",
	"spawn_interval_min",
	"spawn_interval_max",
	"last_spawn_minute",
	"stay_options",
	"seat_grace_minutes",
	"clean_minutes",
	"wait_grace_minutes",
	"wait_penalty_max",
	"base_satisfaction",
	"price_over_budget_penalty",
	"price_bargain_bonus",
	"sound_bonus_per_level",
	"reputation_unserved_penalty",
	"staff_wage_per_night",
	"operating_cost_per_night",
	"price_step",
	"price_min",
	"price_max",
	"lancan_hire_cost",
	"lancan_max_staff",
	"lancan_fee",
	"lancan_minutes",
	"lancan_request_delay",
	"lancan_request_timeout",
	"lancan_ignored_penalty",
	"lancan_music_match_bonus",
	"lancan_energy_cost",
	"lancan_rest_minutes",
	"lancan_tip_max",
	"first_request_min",
	"first_request_max",
	"request_gap_min",
	"request_gap_max",
	"request_min_remaining",
	"request_weight_order",
	"request_weight_mic",
	"request_weight_mic_spare",
	"request_weight_hot",
	"order_timeout",
	"mic_timeout",
	"hot_timeout",
	"extend_timeout",
	"extend_ask_before",
	"extend_minutes",
	"order_late_penalty",
	"order_bonus",
	"fast_service_minutes",
	"fast_service_bonus",
	"out_of_stock_penalty",
	"mic_penalty",
	"mic_discount_percent",
	"hot_penalty",
	"ac_cost",
	"ac_bonus",
	"extend_bonus",
	"extend_decline_penalty",
	"cart_bonus_minutes",
	"theft_start_day",
	"theft_chance_permille",
	"theft_chance_guard_permille",
	"theft_compensation",
	"theft_reputation_penalty",
	"guard_wage",
	"goal_base",
	"goal_max",
	"goal_unserved_max",
	"goal_reputation_bonus",
]
const PRODUCT_KEYS: Array = ["id", "name", "unit", "cost", "price", "per_person", "pack_size", "start_stock", "call"]
const UPGRADE_KEYS: Array = ["id", "name", "cost", "max_level", "effect"]
const HOST_KEYS: Array = ["id", "name", "sprite", "personality", "talk", "duet", "music", "wage"]


## Trả về {"errors": Array[String], "rooms": Array, "customers": Dictionary, "balance": Dictionary, "hosts": Array}.
static func load_all() -> Dictionary:
	var errors: Array = []
	var rooms = _read("res://data/rooms.json", errors)
	var customers = _read("res://data/customers.json", errors)
	var balance = _read("res://data/balance.json", errors)
	var hosts = _read("res://data/hosts.json", errors)
	var products = _read("res://data/products.json", errors)
	var upgrades = _read("res://data/upgrades.json", errors)
	if products is Array:
		for product in products:
			_require(product, PRODUCT_KEYS, "products.json", errors)
	elif products != null:
		errors.append("products.json: phải là một danh sách.")
	if upgrades is Array:
		for upgrade in upgrades:
			_require(upgrade, UPGRADE_KEYS, "upgrades.json", errors)
	elif upgrades != null:
		errors.append("upgrades.json: phải là một danh sách.")
	if hosts is Array:
		for host in hosts:
			_require(host, HOST_KEYS, "hosts.json", errors)
	elif hosts != null:
		errors.append("hosts.json: phải là một danh sách.")

	if rooms is Array:
		if rooms.is_empty():
			errors.append("rooms.json: cần ít nhất một phòng.")
		for room in rooms:
			_require(room, ROOM_KEYS, "rooms.json", errors)
	elif rooms != null:
		errors.append("rooms.json: phải là một danh sách.")

	if customers is Dictionary:
		_require(customers, ["music_names", "types"], "customers.json", errors)
		var types = customers.get("types", [])
		if types is Array:
			if types.is_empty():
				errors.append("customers.json: cần ít nhất một nhóm khách.")
			for t in types:
				_require(t, TYPE_KEYS, "customers.json", errors)
	elif customers != null:
		errors.append("customers.json: phải là một đối tượng.")

	if balance is Dictionary:
		_require(balance, BALANCE_KEYS, "balance.json", errors)
	elif balance != null:
		errors.append("balance.json: phải là một đối tượng.")

	return {"errors": errors, "rooms": rooms, "customers": customers, "balance": balance, "hosts": hosts, "products": products, "upgrades": upgrades}


static func _read(path: String, errors: Array):
	if not FileAccess.file_exists(path):
		errors.append("Thiếu tệp dữ liệu: " + path)
		return null
	var text: String = FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if parsed == null:
		errors.append("Tệp dữ liệu sai định dạng JSON: " + path)
		return null
	return _normalize(parsed)


## JSON của Godot đọc mọi số thành float; đổi các số nguyên về int.
static func _normalize(value):
	if typeof(value) == TYPE_FLOAT:
		if value == floor(value):
			return int(value)
		return value
	if value is Array:
		var list: Array = []
		for item in value:
			list.append(_normalize(item))
		return list
	if value is Dictionary:
		var dict: Dictionary = {}
		for key in value:
			dict[key] = _normalize(value[key])
		return dict
	return value


static func _require(entry, keys: Array, file_name: String, errors: Array) -> void:
	if not (entry is Dictionary):
		errors.append(file_name + ": mục dữ liệu phải là một đối tượng.")
		return
	for key in keys:
		if not entry.has(key):
			errors.append("%s: thiếu trường \"%s\"." % [file_name, key])
