extends RefCounted
## Không khí trong phòng hát: câu hát (có ♪), thoại đối đáp, phản ứng theo tình huống và câu riêng của
## nhân viên Lan can. Đây là hiệu ứng trang trí: KHÔNG đổi hài lòng, tiền hay trạng thái lưu, và dùng
## bộ sinh ngẫu nhiên riêng nên không làm lệch diễn biến của mô phỏng.
##
## Mỗi lần có câu mới, hệ thống gọi _emit(event) (Simulation phát tín hiệu line_spoken). Một event:
##   {"id", "minute", "room_id", "group_id", "kind": "SONG"|"BANTER"|"REACTION"|"LANCAN", "key",
##    "text", "speaker_index", "speaker_sprite", "speaker_age", "host_id",
##    "reply_text", "reply_speaker_index", "reply_host_id", "song_id", "song_title", "mood"}
## speaker_index là vị trí thành viên trong nhóm (0..2, trùng thứ tự hình của nhóm); -1 nếu người nói
## là nhân viên Lan can (xem host_id). reply_text rỗng nếu không có câu đáp.

var enabled: bool = true

var _state
var _data: Dictionary
var _customers
var _emit: Callable
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _seed: int = 0
var _next_at: Dictionary = {}
var _last: Dictionary = {}
var _turn: Dictionary = {}
var _used_by_group: Dictionary = {}
var _used_tonight: Dictionary = {}
var _next_id: int = 1


func _init(state, data: Dictionary, customers, p_seed: int, emit: Callable) -> void:
	_state = state
	_data = data
	_customers = customers
	_seed = p_seed
	_emit = emit
	reset()


## Gọi đầu mỗi đêm (và sau khi tải bản lưu): xóa lịch và danh sách câu đã dùng.
func reset() -> void:
	_rng.seed = hash([_seed, _state.day, "ambience"])
	_next_at = {}
	_last = {}
	_turn = {}
	_used_by_group = {}
	_used_tonight = {}


## Câu gần nhất của một phòng nếu vừa phát trong max_age phút game, ngược lại {}.
func current_line(room_id: String, now: int, max_age: int = 2) -> Dictionary:
	var event: Dictionary = _last.get(room_id, {})
	if event.is_empty() or now - event["minute"] > max_age:
		return {}
	return event


func tick(now: int) -> void:
	if not enabled:
		return
	var balance: Dictionary = _data["balance"]
	for room in _state.rooms:
		var room_id: String = room["id"]
		if room["state"] != "OCCUPIED":
			_next_at.erase(room_id)
			continue
		if not _next_at.has(room_id):
			_next_at[room_id] = now + _rng.randi_range(balance["line_first_min"], balance["line_first_max"])
			continue
		if now < _next_at[room_id]:
			continue
		# Đang báo micro hỏng thì không hát; thử lại sau ít phút.
		if not room["request"].is_empty() and room["request"]["kind"] == "MIC":
			_next_at[room_id] = now + 3
			continue
		var group = _customers.get_group(room["group_id"])
		if group == null:
			continue
		_next_at[room_id] = now + _rng.randi_range(balance["line_gap_min"], balance["line_gap_max"])
		if room["host_id"] == "" and _rng.randi_range(1, 100) <= balance["line_banter_chance"] and _banter(room, group, now):
			continue
		_song(room, group, now)


## Phản ứng của khách với một tình huống vừa xảy ra (micro hỏng, chờ món lâu, thanh toán…).
func react(room: Dictionary, key: String, now: int) -> void:
	if not enabled:
		return
	var options: Array = _data["banter"]["reactions"].get(key, [])
	var group = _customers.get_group(room["group_id"])
	if options.is_empty() or group == null:
		return
	var option: Dictionary = _pick_unused(options, group)
	var event: Dictionary = _event(room, group, "REACTION", key, option["text"], now)
	event["reply_text"] = option.get("reply", "")
	if event["reply_text"] != "":
		event["reply_speaker_index"] = _other_member(group, event["speaker_index"])
	# Đang có nhân viên Lan can trong phòng mà micro hỏng: người đó đỡ lời.
	if key == "mic_broken" and room["host_id"] != "":
		var lines: Dictionary = _data["banter"]["host_lines"].get(room["host_id"], {})
		if lines.has("rescue"):
			event["reply_text"] = lines["rescue"]
			event["reply_speaker_index"] = -1
			event["reply_host_id"] = room["host_id"]
	_publish(event)
	if _next_at.has(room["id"]):
		_next_at[room["id"]] = maxi(_next_at[room["id"]], now + 4)


## Câu riêng của một nhân viên Lan can. key: enter | match | rescue | finish | rest.
func host_line(host: Dictionary, key: String, room_id: String, now: int) -> void:
	if not enabled:
		return
	var lines: Dictionary = _data["banter"]["host_lines"].get(host["id"], {})
	if not lines.has(key):
		return
	var event: Dictionary = {
		"id": _next_id, "minute": now, "room_id": room_id, "group_id": 0, "kind": "LANCAN", "key": key,
		"text": lines[key], "speaker_index": -1, "speaker_sprite": host["sprite"], "speaker_age": "", "host_id": host["id"],
		"reply_text": "", "reply_speaker_index": -1, "reply_host_id": "", "song_id": "", "song_title": "", "mood": "",
	}
	_publish(event)


# ---------------------------------------------------------------- Nội bộ

func _members(group: Dictionary) -> Array:
	var sprites: Array = []
	for i in mini(group["size"], 3):
		sprites.append(group["sprites"][i % group["sprites"].size()])
	return sprites


func _other_member(group: Dictionary, index: int) -> int:
	var count: int = _members(group).size()
	return (index + 1) % count if count > 1 else -1


func _event(room: Dictionary, group: Dictionary, kind: String, key: String, text: String, now: int) -> Dictionary:
	var members: Array = _members(group)
	var index: int = _turn.get(group["id"], 0) % members.size()
	_turn[group["id"]] = index + 1
	return {
		"id": _next_id, "minute": now, "room_id": room["id"], "group_id": group["id"], "kind": kind, "key": key,
		"text": text, "speaker_index": index, "speaker_sprite": members[index],
		"speaker_age": _data["lyrics"]["sprite_age"].get(members[index], "middle"), "host_id": "",
		"reply_text": "", "reply_speaker_index": -1, "reply_host_id": "", "song_id": "", "song_title": "", "mood": "",
	}


func _publish(event: Dictionary) -> void:
	_next_id += 1
	if event["room_id"] != "":
		_last[event["room_id"]] = event
	_used_tonight[event["text"]] = true
	if event["group_id"] != 0:
		if not _used_by_group.has(event["group_id"]):
			_used_by_group[event["group_id"]] = {}
		_used_by_group[event["group_id"]][event["text"]] = true
	_emit.call(event)


## Ưu tiên câu nhóm chưa dùng, rồi câu chưa dùng trong đêm.
func _pick_unused(options: Array, group: Dictionary) -> Dictionary:
	var used: Dictionary = _used_by_group.get(group["id"], {})
	var fresh: Array = options.filter(func(o: Dictionary) -> bool: return not used.has(o["text"]) and not _used_tonight.has(o["text"]))
	if fresh.is_empty():
		fresh = options.filter(func(o: Dictionary) -> bool: return not used.has(o["text"]))
	if fresh.is_empty():
		fresh = options
	return fresh[_rng.randi_range(0, fresh.size() - 1)]


func _banter(room: Dictionary, group: Dictionary, now: int) -> bool:
	if _members(group).size() < 2:
		return false
	var used: Dictionary = _used_by_group.get(group["id"], {})
	var options: Array = []
	for pair in _data["banter"]["pairs"]:
		var fits: bool = pair["types"].is_empty() or pair["types"].has(group["type"])
		if fits and not used.has(pair["text"]) and not _used_tonight.has(pair["text"]):
			options.append(pair)
	if options.is_empty():
		return false
	var pair: Dictionary = options[_rng.randi_range(0, options.size() - 1)]
	var event: Dictionary = _event(room, group, "BANTER", pair["situation"], pair["text"], now)
	event["reply_text"] = pair["reply"]
	event["reply_speaker_index"] = _other_member(group, event["speaker_index"])
	_publish(event)
	return true


## Chọn câu hát theo tuổi người đang cầm micro và gu nhạc của nhóm (chỉ là xác suất, không cấm cứng).
func _song(room: Dictionary, group: Dictionary, now: int) -> void:
	var balance: Dictionary = _data["balance"]
	var event: Dictionary = _event(room, group, "SONG", "", "", now)
	var used: Dictionary = _used_by_group.get(group["id"], {})
	var lines: Array = _data["lyrics"]["lines"]
	var pool: Array = lines.filter(func(l: Dictionary) -> bool: return not used.has(_sung(l["text"])) and not _used_tonight.has(_sung(l["text"])))
	if pool.is_empty():
		pool = lines.filter(func(l: Dictionary) -> bool: return not used.has(_sung(l["text"])))
	if pool.is_empty():
		return
	var total: int = 0
	var weights: Array = []
	for line in pool:
		var weight: int = 1
		if line["age"] == event["speaker_age"]:
			weight *= 4
		if line["family"] == group["music"]:
			weight *= 2
		weights.append(weight)
		total += weight
	var roll: int = _rng.randi_range(1, total)
	var chosen: Dictionary = pool[0]
	for i in pool.size():
		roll -= weights[i]
		if roll <= 0:
			chosen = pool[i]
			break
	event["text"] = _sung(chosen["text"])
	event["song_id"] = chosen["song_id"]
	event["song_title"] = _data["lyrics"]["songs"].get(chosen["song_id"], "")
	event["mood"] = chosen["mood"]

	# Hát nối câu: người bên cạnh, hoặc nhân viên Lan can đang ở trong phòng.
	var with_host: bool = room["host_id"] != ""
	var duet_chance: int = balance["line_duet_chance_with_host"] if with_host else balance["line_duet_chance"]
	if _rng.randi_range(1, 100) <= duet_chance:
		for line in lines:
			if line["song_id"] == chosen["song_id"] and line["id"] != chosen["id"]:
				if with_host:
					event["reply_text"] = _sung(line["text"])
					event["reply_host_id"] = room["host_id"]
				elif _other_member(group, event["speaker_index"]) >= 0:
					event["reply_text"] = _sung(line["text"])
					event["reply_speaker_index"] = _other_member(group, event["speaker_index"])
				break
	_publish(event)
	if event["reply_text"] != "":
		_used_by_group[group["id"]][event["reply_text"]] = true
		_used_tonight[event["reply_text"]] = true


static func _sung(text: String) -> String:
	return "♪ %s ♪" % text
