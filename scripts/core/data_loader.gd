extends RefCounted
## Đọc dữ liệu định nghĩa từ res://data một lần và kiểm tra hợp lệ khi khởi động.

const ROOM_KEYS: Array = [
	"id", "name", "capacity", "price_per_hour", "unlock_cost", "unlocked", "sound", "soundproof", "floor",
	"tier", "tier_name", "equipment", "perks", "upkeep_per_night", "comfort_bonus", "budget_bonus_percent", "mic_weight_percent",
]
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
	"theft_compensation",
	"theft_reputation_penalty",
	"guard_wage",
	"goal_base",
	"goal_max",
	"goal_unserved_max",
	"goal_reputation_bonus",
	"lancan_men_request_male_percent",
	"staff_hire_cost",
	"staff_delay_clean",
	"staff_delay_order",
	"staff_delay_mic",
	"staff_travel_minutes",
	"staff_deliver_minutes",
	"staff_fix_minutes",
	"staff_energy_clean",
	"staff_energy_deliver",
	"staff_energy_fix",
	"staff_tired_below",
	"staff_tired_slowdown_percent",
	"staff_rest_below",
	"staff_rest_minutes",
	"staff_rest_recovery",
	"regular_min_satisfaction",
	"regular_max",
	"regular_return_chance",
	"regular_patience_bonus_percent",
	"regular_favorite_room_bonus",
	"regular_favorite_product_chance",
	"regular_favorite_product_bonus",
	"regular_keep_satisfaction",
	"regular_lost_below",
	"price_refuse_over_percent",
	"star_thresholds",
	"reviews_kept",
	"line_first_min",
	"line_first_max",
	"line_gap_min",
	"line_gap_max",
	"line_banter_chance",
	"line_duet_chance",
	"line_duet_chance_with_host",
	"reputation_by_stars",
	"reputation_four_star_cap",
	"goal_unserved_per_room",
	"staff_max_per_role",
	"staff_delay_seat",
	"staff_seat_minutes",
	"arrival_per_half_star_percent",
	"arrival_min_percent",
	"arrival_max_percent",
	"loan_rate_permille_per_day",
	"loan_min_principal_percent",
	"credit_base",
	"credit_equipment_percent",
	"loan_step",
	"bankrupt_after_negative_nights",
	"thief_chance_per_hour_percent",
	"thief_approach_minutes",
	"thief_steal_minutes",
	"chase_minutes",
	"guard_react_minutes",
	"guard_catch_percent",
	"thief_satisfaction_penalty",
	"lancan_unlock_floor1_rooms",
	"lancan_tip_chance_percent",
	"lancan_tip_match_bonus_percent",
	"lancan_tip_house_percent",
	"reputation_arrival_per_point_percent",
	"reputation_arrival_min_percent",
	"reputation_arrival_max_percent",
	"tutorial_arrival_percent",
]
const STAFF_KEYS: Array = ["id", "name", "role", "speed", "wage", "starter", "about"]
const STAFF_ROLES: Array = ["janitor", "waiter", "receptionist"]
const PRODUCT_KEYS: Array = ["id", "name", "unit", "cost", "price", "per_person", "pack_size", "start_stock", "call"]
const UPGRADE_KEYS: Array = ["id", "name", "cost", "max_level", "effect"]
const HOST_KEYS: Array = ["id", "name", "sprite", "personality", "talk", "duet", "music", "wage", "gender"]


## Trả về {"errors": Array[String], "rooms": Array, "customers": Dictionary, "balance": Dictionary, "hosts": Array}.
static func load_all() -> Dictionary:
	var errors: Array = []
	var rooms = _read("res://data/rooms.json", errors)
	var customers = _read("res://data/customers.json", errors)
	var balance = _read("res://data/balance.json", errors)
	var hosts = _read("res://data/hosts.json", errors)
	var products = _read("res://data/products.json", errors)
	var staff = _read("res://data/staff.json", errors)
	var lyrics = _read("res://data/lyrics.json", errors)
	var reviews = _read("res://data/reviews.json", errors)
	if reviews is Dictionary:
		_require(reviews, ["family_names", "given_names", "nicknames", "nick_handles", "by_tag", "by_stars"], "reviews.json", errors)
	elif reviews != null:
		errors.append("reviews.json: phải là một đối tượng.")
	if staff is Array:
		for member in staff:
			if member is Dictionary and not STAFF_ROLES.has(member.get("role", "")):
				errors.append("staff.json: vai trò nhân viên không hợp lệ (janitor, waiter, receptionist).")
	var banter = _read("res://data/banter.json", errors)
	if lyrics is Dictionary:
		_require(lyrics, ["sprite_age", "songs", "lines"], "lyrics.json", errors)
		for line in lyrics.get("lines", []):
			_require(line, ["id", "age", "genre", "family", "mood", "song_id", "text"], "lyrics.json", errors)
	elif lyrics != null:
		errors.append("lyrics.json: phải là một đối tượng.")
	if banter is Dictionary:
		_require(banter, ["pairs", "reactions", "host_lines"], "banter.json", errors)
	elif banter != null:
		errors.append("banter.json: phải là một đối tượng.")
	var regulars = _read("res://data/regulars.json", errors)
	if staff is Array:
		for member in staff:
			_require(member, STAFF_KEYS, "staff.json", errors)
	elif staff != null:
		errors.append("staff.json: phải là một danh sách.")
	if regulars is Dictionary:
		_require(regulars, ["become_chance", "names", "greetings"], "regulars.json", errors)
	elif regulars != null:
		errors.append("regulars.json: phải là một đối tượng.")
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
			if host.get("gender", "") not in ["male", "female"]:
				errors.append("hosts.json: giới tính nhân viên không hợp lệ.")
	elif hosts != null:
		errors.append("hosts.json: phải là một danh sách.")

	if rooms is Array:
		if rooms.is_empty():
			errors.append("rooms.json: cần ít nhất một phòng.")
		for room in rooms:
			_require(room, ROOM_KEYS, "rooms.json", errors)
			if room.get("floor", 0) not in [1, 2] or room.get("tier", "") != ("vip" if room.get("floor", 0) == 2 else "standard"):
				errors.append("rooms.json: tầng hoặc hạng phòng không hợp lệ.")
	elif rooms != null:
		errors.append("rooms.json: phải là một danh sách.")

	if customers is Dictionary:
		_require(customers, ["music_names", "types", "sprite_genders"], "customers.json", errors)
		var types = customers.get("types", [])
		if types is Array:
			if types.is_empty():
				errors.append("customers.json: cần ít nhất một nhóm khách.")
			for t in types:
				_require(t, TYPE_KEYS, "customers.json", errors)
				if t.get("size_min", 0) < 1 or t.get("size_max", 6) > 5 or t.get("size_min", 0) > t.get("size_max", 0):
					errors.append("customers.json: mỗi nhóm phải có từ 1 đến 5 khách.")
				if t.get("composition", "") not in ["men", "women", "mixed", "couple", "family"]:
					errors.append("customers.json: thành phần nhóm khách không hợp lệ.")
	elif customers != null:
		errors.append("customers.json: phải là một đối tượng.")

	if balance is Dictionary:
		_require(balance, BALANCE_KEYS, "balance.json", errors)
		if balance.get("lancan_men_request_male_percent", -1) < 0 or balance.get("lancan_men_request_male_percent", 101) > 100:
			errors.append("balance.json: tỷ lệ gọi nhân viên nam phải từ 0 đến 100.")
	elif balance != null:
		errors.append("balance.json: phải là một đối tượng.")

	return {"errors": errors, "rooms": rooms, "customers": customers, "balance": balance, "hosts": hosts, "products": products, "upgrades": upgrades, "staff": staff, "regulars": regulars, "lyrics": lyrics, "banter": banter, "reviews": reviews}


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
static func normalize(value):
	return _normalize(value)


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
