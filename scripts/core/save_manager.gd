extends RefCounted
## Lưu tiến trình trước, giữa và sau ca. Giữ tương thích bản tự lưu cũ.
## - Ghi ra tệp tạm, kiểm tra đọc lại được, rồi mới thay tệp chính; bản chính cũ thành bản sao lưu (.bak).
## - Tải: kiểm tra phiên bản và dữ liệu; tệp chính hỏng thì thử bản sao lưu. Không bao giờ tự xóa tệp hỏng.

const DataLoader = preload("res://scripts/core/data_loader.gd")

const SCHEMA_VERSION: int = 1
const GAME_ID: String = "karaoke-dau-hem"
const DEFAULT_PATH: String = "user://karaoke_save.json"
## Các trường của GameState được lưu. Nhật ký thông báo (messages) không lưu.
const STATE_FIELDS: Array = [
	"phase", "day", "money", "reputation", "rooms", "groups", "next_group_id", "next_arrival_minute",
	"ledger", "ledger_keys", "night", "history", "hosts", "stock", "upgrades", "guard_hired",
	"next_request_id", "purchase_counter", "last_bill", "staff", "staff_priority", "regulars", "next_regular_id",
	"rating_sum", "rating_count", "reviews",
]
## Trường thêm sau; bản lưu cũ thiếu thì dùng giá trị mặc định.
const OPTIONAL_DEFAULTS: Dictionary = {
	"loan_principal": 0, "loan_counter": 0, "negative_nights": 0, "bankrupt": false, "thief": {}, "floor2_unlocked": true,
}
const SAVEABLE_PHASES: Array = ["PREP", "OPEN", "SUMMARY"]
const MANUAL_PATHS: Array = ["user://karaoke_slot_1.json", "user://karaoke_slot_2.json", "user://karaoke_slot_3.json"]


static func backup_path(path: String) -> String:
	return path + ".bak"


static func temp_path(path: String) -> String:
	return path + ".tmp"


static func has_save(path: String = DEFAULT_PATH) -> bool:
	return _exists(path) or _exists(backup_path(path))


## Chụp trạng thái thành Dictionary thuần. Số ngẫu nhiên 64-bit lưu dạng chuỗi để JSON không làm tròn.
static func make_snapshot(state, rng: RandomNumberGenerator) -> Dictionary:
	var fields: Dictionary = {}
	for field in STATE_FIELDS + OPTIONAL_DEFAULTS.keys():
		var value = state.get(field)
		fields[field] = value.duplicate(true) if (value is Array or value is Dictionary) else value
	return {
		"game": GAME_ID,
		"schema_version": SCHEMA_VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"saved_at_unix": Time.get_unix_time_from_system(),
		"day": state.day,
		"money": state.money,
		"rng_seed": str(state.rng_seed),
		"rng_state": str(rng.state),
		"state": fields,
	}


## Trả về "" nếu ghi thành công, ngược lại là lý do.
static func write_snapshot(snapshot: Dictionary, path: String = DEFAULT_PATH) -> String:
	var temp: String = temp_path(path)
	var file: FileAccess = FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return "Không ghi được tệp lưu (lỗi %d)." % FileAccess.get_open_error()
	# Giữ nguyên thứ tự khóa để trạng thái tải lại giống hệt lúc lưu.
	file.store_string(JSON.stringify(snapshot, "", false))
	file.close()
	# Đọc lại tệp tạm trước khi thay tệp chính.
	var check: Dictionary = _read_file(temp)
	if check["error"] != "":
		return "Tệp lưu vừa ghi không đọc lại được: " + check["error"]
	var previous: String = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else _web_read(path)
	if FileAccess.file_exists(path):
		var copy_error: int = DirAccess.copy_absolute(path, backup_path(path))
		if copy_error != OK:
			return "Không tạo được bản sao lưu (lỗi %d)." % copy_error
	var rename_error: int = DirAccess.rename_absolute(temp, path)
	if rename_error != OK:
		return "Không thay được tệp lưu chính (lỗi %d)." % rename_error
	if OS.has_feature("web"):
		if previous != "":
			_web_write(backup_path(path), previous)
		_web_write(path, JSON.stringify(snapshot, "", false))
	return ""


## Đọc bản lưu, kiểm tra với dữ liệu game hiện tại.
## Trả về {"ok": bool, "snapshot": Dictionary, "error": String, "used_backup": bool, "notice": String}.
static func read_save(data: Dictionary, path: String = DEFAULT_PATH) -> Dictionary:
	var problems: Array = []
	for candidate in [path, backup_path(path)]:
		if not _exists(candidate):
			continue
		var loaded: Dictionary = _read_file(candidate)
		var error: String = loaded["error"]
		if error == "":
			error = validate(loaded["snapshot"], data)
		if error == "":
			var from_backup: bool = candidate != path
			return {
				"ok": true, "snapshot": loaded["snapshot"], "error": "", "used_backup": from_backup,
				"notice": "Bản lưu chính bị lỗi (%s). Đã dùng bản sao lưu gần nhất." % " ".join(problems) if from_backup and not problems.is_empty() else "",
			}
		problems.append(error)
	if problems.is_empty():
		return {"ok": false, "snapshot": {}, "error": "Chưa có bản lưu.", "used_backup": false, "notice": ""}
	return {"ok": false, "snapshot": {}, "error": "Không tải được bản lưu: " + " | ".join(problems), "used_backup": false, "notice": ""}


static func _read_file(path: String) -> Dictionary:
	var text: String = _web_read(path)
	if text == "" and FileAccess.file_exists(path):
		text = FileAccess.get_file_as_string(path)
	if text == "":
		return {"snapshot": {}, "error": "Tệp lưu trống hoặc không đọc được."}
	var parser: JSON = JSON.new()
	var parsed = parser.data if parser.parse(text) == OK else null
	if not (parsed is Dictionary):
		return {"snapshot": {}, "error": "Tệp lưu hỏng, không phải JSON hợp lệ."}
	return {"snapshot": DataLoader.normalize(parsed), "error": ""}


## Kiểm tra một bản chụp có tải được với dữ liệu game hiện tại không. "" là hợp lệ.
static func validate(snapshot: Dictionary, data: Dictionary) -> String:
	if snapshot.get("game", "") != GAME_ID:
		return "Đây không phải bản lưu của Karaoke Đầu Hẻm."
	var version = snapshot.get("schema_version", null)
	if typeof(version) != TYPE_INT:
		return "Bản lưu thiếu số phiên bản."
	if version > SCHEMA_VERSION:
		return "Bản lưu được tạo bởi phiên bản game mới hơn (v%d, game đang là v%d). Hãy cập nhật game." % [version, SCHEMA_VERSION]
	if version < SCHEMA_VERSION:
		return "Bản lưu thuộc phiên bản cũ (v%d) không còn tương thích." % version
	if not (snapshot.get("state", null) is Dictionary):
		return "Bản lưu thiếu phần trạng thái."
	if not str(snapshot.get("rng_state", "")).is_valid_int() or not str(snapshot.get("rng_seed", "")).is_valid_int():
		return "Bản lưu thiếu trạng thái ngẫu nhiên."
	var state: Dictionary = snapshot["state"]
	for field in STATE_FIELDS:
		if not state.has(field):
			return "Bản lưu thiếu trường \"%s\"." % field
	for field in ["day", "money", "reputation", "next_group_id", "next_request_id", "purchase_counter", "next_regular_id"]:
		if typeof(state[field]) != TYPE_INT:
			return "Trường \"%s\" trong bản lưu không phải số nguyên." % field
	for field in ["rooms", "groups", "ledger", "history", "hosts", "staff", "regulars", "staff_priority"]:
		if not (state[field] is Array):
			return "Trường \"%s\" trong bản lưu không phải danh sách." % field
	for field in ["ledger_keys", "night", "stock", "upgrades", "last_bill"]:
		if not (state[field] is Dictionary):
			return "Trường \"%s\" trong bản lưu sai kiểu." % field
	if not SAVEABLE_PHASES.has(state["phase"]):
		return "Bản lưu có giai đoạn chơi không hợp lệ."
	if state["day"] < 1 or state["reputation"] < 0 or state["reputation"] > 100:
		return "Bản lưu có số ngày hoặc danh tiếng không hợp lệ."
	if state["phase"] != "OPEN" and not state["groups"].is_empty():
		return "Bản lưu còn khách trong quán, không phải mốc cuối đêm."

	if state["phase"] == "OPEN":
		var time = snapshot.get("clock", {})
		if not time is Dictionary or typeof(time.get("minute", null)) != TYPE_INT or time["minute"] < 0 or time["minute"] >= 360:
			return "Bản lưu giữa ca thiếu đồng hồ hợp lệ."
		if not time.get("speed", 1) in [1, 2, 4]:
			return "Tốc độ trong bản lưu không hợp lệ."

	# Sổ giao dịch phải khớp số dư.
	var total: int = 0
	for entry in state["ledger"]:
		if not (entry is Dictionary) or typeof(entry.get("amount", null)) != TYPE_INT:
			return "Sổ giao dịch trong bản lưu bị hỏng."
		total += entry["amount"]
	if total != state["money"]:
		return "Số dư trong bản lưu không khớp sổ giao dịch."

	# Mọi ID phải còn tồn tại trong dữ liệu game.
	var room_ids: Dictionary = {}
	for def in data["rooms"]:
		room_ids[def["id"]] = true
	if state["rooms"].size() != data["rooms"].size():
		return "Số phòng trong bản lưu khác với game hiện tại."
	for room in state["rooms"]:
		if not (room is Dictionary) or not room_ids.has(room.get("id", "")):
			return "Bản lưu có phòng không tồn tại trong game hiện tại."
	for product in data["products"]:
		if typeof(state["stock"].get(product["id"], null)) != TYPE_INT or state["stock"][product["id"]] < 0:
			return "Tồn kho \"%s\" trong bản lưu không hợp lệ." % product["name"]
	for pair in [["hosts", "hosts", "nhân viên Lan can"], ["staff", "staff", "nhân viên phục vụ"]]:
		var known: Dictionary = {}
		for def in data[pair[1]]:
			known[def["id"]] = true
		for entry in state[pair[0]]:
			if not (entry is Dictionary) or not known.has(entry.get("id", "")):
				return "Bản lưu có %s không tồn tại trong game hiện tại." % pair[2]
	return ""


static func _exists(path: String) -> bool:
	return FileAccess.file_exists(path) or _web_read(path) != ""

static func _web_read(path: String) -> String:
	if not OS.has_feature("web"):
		return ""
	var value = JavaScriptBridge.eval("(function(){try{return localStorage.getItem(" + JSON.stringify("karaoke_save:" + path) + ");}catch(e){return null;}})()", true)
	return value if value is String else ""

static func _web_write(path: String, contents: String) -> void:
	JavaScriptBridge.eval("try{localStorage.setItem(" + JSON.stringify("karaoke_save:" + path) + "," + JSON.stringify(contents) + ");}catch(e){}", true)

static func latest_path(data: Dictionary) -> String:
	var latest: String = ""
	var latest_time: float = -1.0
	for path in [DEFAULT_PATH] + MANUAL_PATHS:
		var saved: Dictionary = read_save(data, path)
		if saved["ok"]:
			var snapshot: Dictionary = saved["snapshot"]
			var stamp: float = float(snapshot.get("saved_at_unix", Time.get_unix_time_from_datetime_string(str(snapshot.get("saved_at", "")))))
			if latest == "" or stamp > latest_time:
				latest = path
				latest_time = stamp
	return latest
