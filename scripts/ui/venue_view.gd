extends Control
## Mặt bằng quán nhìn từ trên xuống: sáu phòng hát (hai dãy, hành lang ở giữa), sảnh lễ tân và góc Lan can
## bên phải, sân xe và chỗ chờ phía dưới. Chỉ hiển thị trạng thái của Simulation và biến cú bấm
## thành việc cho chủ quán đi làm.

signal report(reason: String)
signal hint(text: String)
signal choice_requested(room_id: String)

const UI = preload("res://scripts/ui/ui_kit.gd")
const Actor = preload("res://scripts/ui/actor.gd")
const Money = preload("res://scripts/core/money.gd")
const Clock = preload("res://scripts/core/simulation_clock.gd")

const VIEW_SIZE: Vector2 = Vector2(980, 570)
const ROOM_W: float = 226.0
const ROOM_H: float = 166.0
const ROOM_COLS: Array = [6.0, 238.0, 470.0]
const ROOM_ROWS: Array = [34.0, 238.0]
const CORRIDOR_Y: float = 219.0
const HALL_X: float = 704.0
const YARD_Y: float = 408.0
const JUNCTION: Vector2 = Vector2(722, 219)
const GATE: Vector2 = Vector2(840, 414)
const DESK_POS: Vector2 = Vector2(790, 142)
const OWNER_HOME: Vector2 = Vector2(892, 140)
const PICKUP: Vector2 = Vector2(800, 168)
const LOUNGE: Rect2 = Rect2(712, 252, 258, 150)
const HOST_SLOTS: Array = [Vector2(762, 386), Vector2(841, 386), Vector2(920, 386)]
const QUEUE_SLOTS: Array = [Vector2(770, 512), Vector2(660, 512), Vector2(550, 512), Vector2(440, 512)]
const STREET: Vector2 = Vector2(330, 620)
const BIKE_SLOTS: Array = [Vector2(48, 478), Vector2(122, 478), Vector2(196, 478), Vector2(270, 478), Vector2(48, 556), Vector2(122, 556), Vector2(196, 556), Vector2(270, 556)]
const GUARD_POS: Vector2 = Vector2(920, 528)
const MAX_TASKS: int = 5

const STATE_TEXT: Dictionary = {
	"LOCKED": "[KHÓA]", "AVAILABLE": "[TRỐNG]", "OCCUPIED": "[ĐANG HÁT]",
	"DIRTY": "[BẨN]", "CLEANING": "[ĐANG DỌN]", "BROKEN": "[HỎNG]",
}
const STATE_BLOCK: Dictionary = {
	"LOCKED": "Chưa mở", "OCCUPIED": "Đang có khách", "DIRTY": "Đang bẩn", "CLEANING": "Đang dọn", "BROKEN": "Đang hỏng",
}
const STATE_COLOR: Dictionary = {
	"LOCKED": UI.MUTED, "AVAILABLE": UI.GOOD, "OCCUPIED": UI.PINK,
	"DIRTY": UI.GOLD, "CLEANING": UI.INFO, "BROKEN": UI.BAD,
}
const FLOOR_COLOR: Dictionary = {
	"LOCKED": Color(0.12, 0.11, 0.16), "AVAILABLE": Color(0.27, 0.22, 0.36), "OCCUPIED": Color(0.36, 0.20, 0.42),
	"DIRTY": Color(0.30, 0.26, 0.26), "CLEANING": Color(0.24, 0.27, 0.38), "BROKEN": Color(0.3, 0.18, 0.18),
}
const REQUEST_LABEL: Dictionary = {"ORDER": "GỌI MÓN", "MIC": "MICRO HỎNG", "HOT": "PHÒNG NÓNG", "EXTEND": "HÁT THÊM?"}
const REQUEST_COLOR: Dictionary = {"ORDER": UI.GOLD, "MIC": UI.BAD, "HOT": Color(1.0, 0.62, 0.3), "EXTEND": UI.INFO}

var sim
var selected_group: int = 0
var selected_room: String = ""
var selected_host: String = ""

var _actors: Node2D
var _owner: Node2D
var _owner_broom: Sprite2D
var _guard: Node2D
var _group_actors: Dictionary = {}
var _host_actors: Dictionary = {}
var _leaving: Array = []
var _bikes: Array = []
var _room_ui: Dictionary = {}
var _btn_open: Button
var _lbl_toast: Label
var _lbl_tasks: Label
var _lbl_yard: Label
var _note_texture: Texture2D
var _anim_time: float = 0.0

## Hàng việc của chủ quán: {"kind": "seat"|"clean"|"deliver"|"fix"|"goto", ...}
var _tasks: Array = []
var _current_task: Dictionary = {}
var _cleaning_room: String = ""


func setup(p_sim) -> void:
	sim = p_sim
	custom_minimum_size = VIEW_SIZE
	size = VIEW_SIZE
	clip_contents = true
	_note_texture = load("res://assets/sprites/note.svg")

	_add_label("♪  KARAOKE ĐẦU HẺM  ♪", 18, UI.PINK, Rect2(0, 3, 700, 26), true)
	_add_label("LỄ TÂN", 14, UI.GOLD, Rect2(HALL_X, 38, 270, 20), true)
	for i in sim.state.rooms.size():
		_build_room(sim.state.rooms[i], i)

	_add_label("LAN CAN", 17, UI.PINK, Rect2(LOUNGE.position.x, LOUNGE.position.y + 3, LOUNGE.size.x, 22), true)
	_add_label("Song ca · MC · khuấy động", 10, UI.GOLD, Rect2(LOUNGE.position.x, LOUNGE.position.y + 25, LOUNGE.size.x, 14), true)
	_add_label("BÃI XE", 13, UI.MUTED, Rect2(14, YARD_Y + 8, 120, 18), false)
	_add_label("CHỖ CHỜ", 13, UI.MUTED, Rect2(400, YARD_Y + 8, 420, 18), true)
	_lbl_yard = _add_label("", 11, UI.MUTED, Rect2(826, YARD_Y + 136, 150, 28), true)
	_lbl_yard.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_actors = Node2D.new()
	_actors.y_sort_enabled = true
	add_child(_actors)
	_add_prop("desk", DESK_POS, 0.5)
	_add_prop("plant", Vector2(724, 116), 0.42)
	_add_prop("plant", Vector2(792, 432), 0.42)
	_add_prop("plant", Vector2(888, 432), 0.42)
	for i in BIKE_SLOTS.size():
		var bike: Sprite2D = _add_prop("motorbike_%d" % (i % 4), BIKE_SLOTS[i], 0.42)
		bike.visible = false
		_bikes.append(bike)
	_add_railing()

	_guard = Actor.new()
	_guard.setup(["guard"])
	_guard.position = GUARD_POS
	_guard.set_clickable(false)
	_guard.visible = false
	_actors.add_child(_guard)

	_owner = Actor.new()
	_owner.setup(["owner"])
	_owner.position = OWNER_HOME
	_owner.speed = 250.0
	_owner.set_clickable(false)
	_actors.add_child(_owner)
	_owner_broom = Sprite2D.new()
	_owner_broom.texture = load("res://assets/sprites/broom.svg")
	_owner_broom.scale = Vector2(0.5, 0.5)
	_owner_broom.position = Vector2(24, -18)
	_owner_broom.visible = false
	_owner.add_child(_owner_broom)

	_lbl_toast = _add_label("", 13, UI.TEXT, Rect2(8, 209, 688, 20), true)
	_lbl_toast.clip_text = true
	_lbl_tasks = _add_label("", 11, UI.GOLD, Rect2(HALL_X + 6, 60, 262, 16), true)

	_btn_open = UI.button("MỞ CỬA ĐÓN KHÁCH", 18, UI.PINK)
	_btn_open.position = Vector2(440, 462)
	_btn_open.size = Vector2(300, 50)
	_btn_open.pressed.connect(func() -> void: report.emit(sim.open_doors()))
	add_child(_btn_open)


func set_toast(text: String, color: Color) -> void:
	_lbl_toast.text = text
	_lbl_toast.add_theme_color_override("font_color", color)


func task_count() -> int:
	return _tasks.size() + (0 if _current_task.is_empty() else 1)


# ---------------------------------------------------------------- Dựng cảnh

func _add_label(text: String, font_size: int, color: Color, rect: Rect2, centered: bool) -> Label:
	var label: Label = UI.label(text, font_size, color, true)
	label.position = rect.position
	label.size = rect.size
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _add_prop(texture_name: String, at: Vector2, prop_scale: float) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = load("res://assets/sprites/%s.svg" % texture_name)
	sprite.scale = Vector2(prop_scale, prop_scale)
	sprite.offset = Vector2(0, -sprite.texture.get_height() * 0.5)
	sprite.position = at
	_actors.add_child(sprite)
	return sprite


## Cái lan can thật ở góc Lan can: nhân viên đứng tựa phía sau.
func _add_railing() -> void:
	var railing: Node2D = Node2D.new()
	railing.position = Vector2(LOUNGE.position.x + 14, LOUNGE.end.y - 2)
	_actors.add_child(railing)
	var width: float = LOUNGE.size.x - 28
	for bar_y in [-32.0, -17.0]:
		var bar: ColorRect = ColorRect.new()
		bar.color = UI.GOLD
		bar.position = Vector2(0, bar_y)
		bar.size = Vector2(width, 5)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		railing.add_child(bar)
	for i in 6:
		var post: ColorRect = ColorRect.new()
		post.color = Color(0.85, 0.62, 0.25)
		post.position = Vector2(i * (width - 6) / 5.0, -36)
		post.size = Vector2(6, 36)
		post.mouse_filter = Control.MOUSE_FILTER_IGNORE
		railing.add_child(post)


func _room_rect(index: int) -> Rect2:
	@warning_ignore("integer_division")
	return Rect2(ROOM_COLS[index % 3], ROOM_ROWS[index / 3], ROOM_W, ROOM_H)


func _build_room(room: Dictionary, index: int) -> void:
	var room_id: String = room["id"]
	var rect: Rect2 = _room_rect(index)
	var origin: Vector2 = rect.position
	var center_x: float = origin.x + ROOM_W * 0.5

	var furniture: Node2D = Node2D.new()
	add_child(furniture)
	for entry in [["tv", Vector2(center_x, origin.y + 62), 0.36], ["sofa", Vector2(center_x, origin.y + 132), 0.62]]:
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = load("res://assets/sprites/%s.svg" % entry[0])
		sprite.scale = Vector2(entry[2], entry[2])
		sprite.offset = Vector2(0, -sprite.texture.get_height() * 0.5)
		sprite.position = entry[1]
		furniture.add_child(sprite)

	var title: Label = _add_label("", 12, UI.TEXT, Rect2(origin + Vector2(7, 3), Vector2(150, 16)), false)
	var status: Label = _add_label("", 11, UI.GOOD, Rect2(origin + Vector2(ROOM_W - 96, 4), Vector2(90, 16)), false)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var info: Label = _add_label("", 10, UI.MUTED, Rect2(origin + Vector2(7, 19), Vector2(ROOM_W - 14, 14)), false)
	info.clip_text = true
	var center_text: Label = _add_label("", 12, UI.TEXT, Rect2(origin + Vector2(4, 62), Vector2(ROOM_W - 8, 50)), true)
	center_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_text.z_index = 2
	var request: Label = _add_label("", 10, Color(0.14, 0.1, 0.16), Rect2(origin + Vector2(6, 34), Vector2(ROOM_W - 12, 18)), false)
	request.clip_text = true
	request.z_index = 2
	request.visible = false
	var bar: ProgressBar = UI.progress(UI.PINK)
	bar.position = origin + Vector2(8, ROOM_H - 11)
	bar.size = Vector2(ROOM_W - 16, 6)
	bar.custom_minimum_size = Vector2(0, 6)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)

	var hit: Button = Button.new()
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for style_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		hit.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	hit.position = origin
	hit.size = rect.size
	hit.pressed.connect(func() -> void: on_room_pressed(room_id))
	add_child(hit)

	_room_ui[room_id] = {"index": index, "furniture": furniture, "title": title, "info": info, "status": status,
		"center": center_text, "request": request, "bar": bar, "hit": hit, "border": STATE_COLOR[room["state"]], "dim": false}


# ---------------------------------------------------------------- Vị trí và đường đi

func _rect_of(room_id: String) -> Rect2:
	return _room_rect(_room_ui[room_id]["index"])


func _seat_position(room_id: String) -> Vector2:
	var rect: Rect2 = _rect_of(room_id)
	return Vector2(rect.position.x + ROOM_W * 0.5 - 16, rect.position.y + 148)


func _host_position(room_id: String) -> Vector2:
	var rect: Rect2 = _rect_of(room_id)
	return Vector2(rect.position.x + ROOM_W - 34, rect.position.y + 152)


func _work_position(room_id: String) -> Vector2:
	var rect: Rect2 = _rect_of(room_id)
	return Vector2(rect.position.x + 36, rect.position.y + 154)


## Khu vực của một điểm: 0 = trong phòng, 1 = hành lang, 2 = sảnh, 3 = sân.
func _zone(point: Vector2) -> int:
	if point.y >= YARD_Y:
		return 3
	if point.x >= HALL_X:
		return 2
	if point.y > ROOM_ROWS[0] + ROOM_H and point.y < ROOM_ROWS[1]:
		return 1
	return 0


func _door(point: Vector2) -> Vector2:
	var column: int = clampi(int((point.x - ROOM_COLS[0]) / 232.0), 0, 2)
	return Vector2(ROOM_COLS[column] + ROOM_W * 0.5, CORRIDOR_Y)


func _exit_point(zone: int, reference: Vector2) -> Vector2:
	match zone:
		0:
			return _door(reference)
		1:
			return JUNCTION
	return GATE


## Đường đi qua các cửa: phòng <-> hành lang <-> sảnh <-> sân.
func _route(from: Vector2, to: Vector2) -> Array:
	var start: int = _zone(from)
	var finish: int = _zone(to)
	var points: Array = []
	if start == 0 and finish == 0:
		var same_room: bool = _door(from).is_equal_approx(_door(to)) and (from.y < CORRIDOR_Y) == (to.y < CORRIDOR_Y)
		if not same_room:
			points.append(_door(from))
			points.append(_door(to))
	elif start < finish:
		for zone in range(start, finish):
			points.append(_exit_point(zone, from))
	elif start > finish:
		for zone in range(start - 1, finish - 1, -1):
			points.append(_exit_point(zone, to))
	points.append(to)
	return points


# ---------------------------------------------------------------- Thao tác của người chơi

func on_group_pressed(group_id: int) -> void:
	selected_host = ""
	selected_room = ""
	if selected_group == group_id:
		selected_group = 0
		hint.emit("Đã bỏ chọn nhóm khách.")
		return
	selected_group = group_id
	var group = sim.customers.get_group(group_id)
	if group != null:
		hint.emit("Chọn phòng cho nhóm %s: %d người, hát %d phút. Phòng viền xanh là xếp được." % [group["type_name"], group["size"], group["planned_minutes"]])


func on_host_pressed(host_id: String) -> void:
	selected_group = 0
	selected_room = ""
	if selected_host == host_id:
		selected_host = ""
		return
	selected_host = host_id
	hint.emit("Chọn phòng đang gọi Lan can cho %s." % sim.hosts.get_host(host_id)["name"])


func on_room_pressed(room_id: String) -> void:
	var room = sim.rooms.get_room(room_id)

	# Đang chọn nhóm khách: bấm phòng là xếp phòng, báo ngay lý do nếu không được.
	if selected_group != 0:
		var preview: Dictionary = sim.preview_assign(selected_group, room_id)
		if preview["reason"] != "":
			report.emit(preview["reason"])
			return
		_add_task({"kind": "seat", "room_id": room_id, "group_id": selected_group})
		selected_group = 0
		return
	if selected_host != "":
		if room["state"] == "OCCUPIED":
			report.emit(sim.assign_host(selected_host, room_id))
			selected_host = ""
			return
		report.emit("%s không có khách gọi Lan can." % room["name"])
		return

	if room["state"] == "DIRTY":
		_add_task({"kind": "clean", "room_id": room_id})
	elif room["state"] == "OCCUPIED" and not room["request"].is_empty():
		match room["request"]["kind"]:
			"ORDER":
				_add_task({"kind": "deliver", "room_id": room_id})
			"MIC":
				_add_task({"kind": "fix", "room_id": room_id})
			_:
				choice_requested.emit(room_id)
	selected_room = room_id


## Bấm xuống sàn (ngoài các phòng): chủ quán đi tới đó.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _zone(event.position) != 0 and event.position.y > 34:
			_add_task({"kind": "goto", "position": event.position})


func _add_task(task: Dictionary) -> void:
	if sim.state.phase != "OPEN" and task["kind"] != "goto":
		report.emit("Quán chưa mở cửa.")
		return
	if task["kind"] == "goto":
		# Lệnh đi bộ mới thay cho lệnh đi bộ cũ, không chen ngang việc đang làm.
		_tasks = _tasks.filter(func(t: Dictionary) -> bool: return t["kind"] != "goto")
	else:
		for existing in _tasks + [_current_task]:
			if existing.get("kind", "") == task["kind"] and existing.get("room_id", "") == task["room_id"]:
				return
	if _tasks.size() >= MAX_TASKS:
		report.emit("Chủ quán đang ôm quá nhiều việc, chờ xíu!")
		return
	_tasks.append(task)


func _task_target(task: Dictionary) -> Vector2:
	match task["kind"]:
		"seat":
			var actor = _group_actors.get(task["group_id"])
			return actor.position + Vector2(56, 6) if actor != null else GATE
		"deliver":
			return PICKUP
		"clean", "fix":
			return _work_position(task["room_id"])
	return task["position"]


func _update_owner() -> void:
	if _cleaning_room != "":
		if sim.rooms.get_room(_cleaning_room)["state"] == "CLEANING":
			return
		_cleaning_room = ""
		_owner_broom.visible = false
		_owner.singing = false

	if _owner.is_moving():
		return
	if _current_task.is_empty():
		if _tasks.is_empty():
			_owner.set_bubble("")
			return
		_current_task = _tasks.pop_front()
		_owner.walk_to(_route(_owner.position, _task_target(_current_task)))
		var bubbles: Dictionary = {"seat": "Mời vào phòng!", "clean": "Đi dọn phòng", "deliver": "Lấy món ở quầy", "fix": "Đi đổi micro"}
		_owner.set_bubble(bubbles.get(_current_task["kind"], ""))
		return

	# Đã tới nơi: thực hiện việc qua Simulation.
	var task: Dictionary = _current_task
	match task["kind"]:
		"seat":
			report.emit(sim.assign_group(task["group_id"], task["room_id"]))
		"clean":
			var reason: String = sim.clean_room(task["room_id"])
			if reason == "":
				_cleaning_room = task["room_id"]
				_owner_broom.visible = true
				_owner.singing = true
				_owner.set_bubble("Đang dọn...")
			else:
				report.emit(reason)
		"deliver":
			if not task.get("picked", false):
				# Chặng hai: bưng món từ quầy tới phòng.
				task["picked"] = true
				_owner.walk_to(_route(_owner.position, _work_position(task["room_id"])))
				_owner.set_bubble("Mang món tới!")
				return
			report.emit(sim.deliver_order(task["room_id"]))
		"fix":
			report.emit(sim.fix_mic(task["room_id"]))
	_current_task = {}


# ---------------------------------------------------------------- Đồng bộ với mô phỏng

func _process(delta: float) -> void:
	if sim == null:
		return
	var scaled: float = delta * sim.clock.speed if (sim.clock.is_running() or sim.state.phase != "OPEN") else 0.0
	advance_actors(scaled)


## Tách riêng để kịch bản kiểm thử có thể tua nhanh phần hình ảnh.
func advance_actors(delta: float) -> void:
	_anim_time += delta
	_sync_groups()
	_sync_hosts()
	_update_owner()
	_owner.advance(delta)
	for actor in _group_actors.values():
		actor.advance(delta)
	for actor in _host_actors.values():
		actor.advance(delta)
	for actor in _leaving.duplicate():
		actor.advance(delta)
		if not actor.is_moving():
			_leaving.erase(actor)
			actor.queue_free()
	_refresh_rooms()
	_refresh_yard()
	_btn_open.visible = sim.state.phase == "PREP"
	var count: int = task_count()
	_lbl_tasks.text = "Việc đang chờ chủ quán: %d" % count if count > 0 else ""
	queue_redraw()


func _refresh_yard() -> void:
	var parked: int = 0
	for group in sim.state.groups:
		@warning_ignore("integer_division")
		parked += (group["size"] + 1) / 2
	parked = mini(parked + _leaving.size(), _bikes.size())
	for i in _bikes.size():
		_bikes[i].visible = i < parked
	_guard.visible = sim.state.guard_hired
	_guard.advance(0.0)
	if sim.state.guard_hired:
		_lbl_yard.text = "Bảo vệ đang trông xe"
		_lbl_yard.add_theme_color_override("font_color", UI.GOOD)
	elif sim.theft_risk_active():
		_lbl_yard.text = "KHÔNG AI TRÔNG XE\nDễ mất xe!"
		_lbl_yard.add_theme_color_override("font_color", UI.BAD)
	else:
		_lbl_yard.text = "Chưa thuê bảo vệ"
		_lbl_yard.add_theme_color_override("font_color", UI.MUTED)


func _sync_groups() -> void:
	var alive: Dictionary = {}
	var waiting_index: int = 0
	for group in sim.state.groups:
		var group_id: int = group["id"]
		alive[group_id] = true
		var actor = _group_actors.get(group_id)
		if actor == null:
			actor = Actor.new()
			var names: Array = []
			for i in mini(group["size"], 3):
				names.append(group["sprites"][i % group["sprites"].size()])
			actor.setup(names, "×%d" % group["size"])
			actor.position = STREET
			actor.set_tooltip("Bấm để chọn nhóm, rồi bấm vào phòng viền xanh.")
			actor.pressed.connect(func() -> void: on_group_pressed(group_id))
			_actors.add_child(actor)
			_group_actors[group_id] = actor

		var key: String
		var target: Vector2
		if group["state"] == "WAITING":
			key = "queue_%d" % waiting_index
			target = QUEUE_SLOTS[mini(waiting_index, QUEUE_SLOTS.size() - 1)]
			waiting_index += 1
		else:
			key = group["room_id"]
			target = _seat_position(group["room_id"])
		if actor.place_key != key:
			actor.place_key = key
			actor.walk_to(_route(actor.position, target))

		var waiting: bool = group["state"] == "WAITING"
		actor.set_clickable(waiting)
		actor.set_highlight(group_id == selected_group)
		actor.singing = not waiting and not actor.is_moving()
		if waiting:
			var left: int = maxi(0, group["patience"] - group["wait_minutes"])
			actor.patience_ratio = float(left) / float(maxi(1, group["patience"]))
			if group_id == selected_group:
				actor.set_bubble("ĐANG CHỌN", Color(1.0, 0.96, 0.8), UI.GOLD)
			elif left <= 5:
				actor.set_bubble("Sắp bỏ về!", Color(1.0, 0.85, 0.85), UI.BAD)
			else:
				actor.set_bubble("")
		else:
			actor.patience_ratio = -1.0
			actor.set_bubble("Gọi Lan can!" if group["host_request"] == "PENDING" else "", Color(1.0, 0.9, 0.97), UI.PINK)

	for group_id in _group_actors.keys():
		if alive.has(group_id):
			continue
		var actor = _group_actors[group_id]
		_group_actors.erase(group_id)
		if actor.place_key.begins_with("queue"):
			actor.set_bubble("Thôi về!", Color(1.0, 0.85, 0.85), UI.BAD)
		else:
			actor.set_bubble("Cảm ơn nha!", Color(0.88, 1.0, 0.9), UI.GOOD)
		actor.patience_ratio = -1.0
		actor.set_clickable(false)
		actor.set_highlight(false)
		actor.singing = false
		var points: Array = _route(actor.position, Vector2(STREET.x, 540))
		points.append(STREET)
		actor.walk_to(points)
		_leaving.append(actor)
		if selected_group == group_id:
			selected_group = 0


func _sync_hosts() -> void:
	for i in sim.state.hosts.size():
		var host: Dictionary = sim.state.hosts[i]
		var host_id: String = host["id"]
		var actor = _host_actors.get(host_id)
		if actor == null:
			actor = Actor.new()
			actor.setup([host["sprite"]])
			actor.position = HOST_SLOTS[i % HOST_SLOTS.size()]
			actor.place_key = "lounge"
			actor.set_tooltip("Bấm để chọn, rồi bấm vào phòng đang gọi Lan can.")
			actor.pressed.connect(func() -> void: on_host_pressed(host_id))
			_actors.add_child(actor)
			_host_actors[host_id] = actor

		var key: String = host["room_id"] if host["state"] == "SERVING" else "lounge"
		if actor.place_key != key:
			actor.place_key = key
			var target: Vector2 = _host_position(host["room_id"]) if key != "lounge" else HOST_SLOTS[i % HOST_SLOTS.size()]
			actor.walk_to(_route(actor.position, target))
		actor.set_clickable(host["state"] != "SERVING")
		actor.set_highlight(host_id == selected_host)
		actor.singing = host["state"] == "SERVING" and not actor.is_moving()
		if host_id == selected_host:
			actor.set_bubble("ĐANG CHỌN", Color(1.0, 0.96, 0.8), UI.GOLD)
		elif host["state"] == "RESTING":
			actor.set_bubble("Nghỉ xíu...", Color(0.9, 0.93, 1.0), UI.INFO)
		else:
			actor.set_bubble("")


func _refresh_rooms() -> void:
	var now: int = sim.clock.minute
	var choosing = sim.customers.get_group(selected_group) if selected_group != 0 else null
	for room in sim.state.rooms:
		var ui: Dictionary = _room_ui[room["id"]]
		var room_state: String = room["state"]
		var locked: bool = room_state == "LOCKED"
		ui["title"].text = "%s · %d người" % [room["name"], room["capacity"]]
		ui["status"].text = STATE_TEXT[room_state]
		ui["status"].add_theme_color_override("font_color", STATE_COLOR[room_state])
		var info: String = "%s/giờ" % Money.format(room["price_per_hour"])
		var center: String = ""
		var center_color: Color = UI.TEXT
		var border: Color = Color(STATE_COLOR[room_state], 0.85)
		var dim: bool = locked
		var tip: String = "Bấm để xem chi tiết."
		var bar: ProgressBar = ui["bar"]
		bar.visible = false

		match room_state:
			"LOCKED":
				center = "CHƯA MỞ\n%s" % Money.format(room["unlock_cost"])
				tip = "Bấm để chọn, rồi mở phòng ở bảng Chi tiết."
			"OCCUPIED":
				info = "Còn %d' · tạm tính %s" % [maxi(0, room["session_end"] - now), Money.format(Money.room_fee(room["session_price"], now - room["session_start"]))]
				_show_bar(bar, UI.PINK, now - room["session_start"], room["session_end"] - room["session_start"])
			"DIRTY":
				center = "Bấm để dọn"
				center_color = UI.GOLD
				tip = "Bấm để chủ quán tới dọn phòng."
			"CLEANING":
				info = "Còn %d' nữa là dọn xong" % maxi(0, room["task_end"] - now)
				_show_bar(bar, UI.INFO, now - room["task_start"], room["task_end"] - room["task_start"])

		# Đang chọn nhóm khách: tô rõ phòng nào xếp được và vì sao phòng kia thì không.
		if choosing != null:
			var preview: Dictionary = sim.preview_assign(selected_group, room["id"])
			if preview["reason"] == "":
				border = UI.GOOD.lerp(Color.WHITE, 0.35 + 0.35 * sin(_anim_time * 6.0))
				center = "XẾP ĐƯỢC · dự kiến %s" % Money.format(preview["estimate"])
				center_color = UI.GOOD
				if preview["over_budget"]:
					center += "\nĐắt hơn nhóm này dự tính: -%d hài lòng" % sim.data["balance"]["price_over_budget_penalty"]
					center_color = UI.GOLD
				tip = "Bấm để chủ quán dẫn nhóm vào phòng này."
			else:
				dim = true
				center_color = UI.BAD
				if STATE_BLOCK.has(room_state):
					center = STATE_BLOCK[room_state]
				elif choosing["size"] > room["capacity"]:
					center = "Thiếu chỗ: chỉ chứa %d người" % room["capacity"]
				else:
					center = "Không kịp trước 24:00"
				tip = preview["reason"]

		# Yêu cầu của khách đang hát.
		var request: Dictionary = room["request"]
		var badge: Label = ui["request"]
		badge.visible = not request.is_empty()
		if badge.visible:
			var kind: String = request["kind"]
			var left: int = maxi(0, request["deadline"] - now)
			badge.text = " %s · còn %d'" % [request["text"] if kind == "ORDER" else REQUEST_LABEL[kind], left]
			var blink: float = 0.8 + 0.2 * sin(_anim_time * 8.0) if left <= 4 else 1.0
			badge.add_theme_stylebox_override("normal", UI.box(Color(REQUEST_COLOR[kind], blink), Color(0.14, 0.1, 0.16), 1, 2))
			if choosing == null and selected_host == "":
				match kind:
					"ORDER":
						tip = "Bấm để chủ quán lấy món ở quầy rồi mang tới."
					"MIC":
						tip = "Bấm để chủ quán tới đổi micro."
					_:
						tip = "Bấm để trả lời khách."
		if selected_host != "" and room_state == "OCCUPIED":
			tip = "Bấm để cử nhân viên Lan can đang chọn vào phòng này."

		ui["info"].text = info
		ui["center"].text = center
		ui["center"].add_theme_color_override("font_color", center_color)
		ui["furniture"].modulate = Color(0.35, 0.35, 0.4) if dim else Color.WHITE
		ui["border"] = border
		ui["dim"] = dim
		ui["hit"].tooltip_text = tip


func _show_bar(bar: ProgressBar, color: Color, value: int, total: int) -> void:
	bar.visible = true
	bar.get_theme_stylebox("fill").bg_color = color
	bar.max_value = maxi(1, total)
	bar.value = value


# ---------------------------------------------------------------- Vẽ nền

func _draw() -> void:
	if sim == null:
		return
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(0.10, 0.08, 0.15))
	draw_rect(Rect2(170, 2, 360, 28), Color(UI.PINK, 0.9), false, 2.0)

	# Hành lang giữa hai dãy phòng và sảnh lễ tân
	draw_rect(Rect2(0, ROOM_ROWS[0] + ROOM_H, HALL_X, ROOM_ROWS[1] - ROOM_ROWS[0] - ROOM_H), Color(0.20, 0.17, 0.27))
	draw_rect(Rect2(HALL_X, 34, VIEW_SIZE.x - HALL_X, YARD_Y - 38), Color(0.24, 0.21, 0.32))
	for ix in 7:
		for iy in 10:
			if (ix + iy) % 2 == 0:
				draw_rect(Rect2(HALL_X + ix * 40.0, 34 + iy * 38.0, 40, 38).intersection(Rect2(HALL_X, 34, 276, YARD_Y - 38)), Color(1, 1, 1, 0.025))
	draw_rect(LOUNGE, Color(0.36, 0.14, 0.34))
	draw_rect(LOUNGE, Color(UI.PINK, 0.9), false, 2.0)

	# Sân: bãi xe bên trái, chỗ chờ có mái hiên, chốt bảo vệ bên phải
	draw_rect(Rect2(0, YARD_Y, VIEW_SIZE.x, VIEW_SIZE.y - YARD_Y), Color(0.30, 0.34, 0.40))
	draw_rect(Rect2(0, YARD_Y - 4, GATE.x - 34, 7), Color(0.07, 0.05, 0.11))
	draw_rect(Rect2(GATE.x + 34, YARD_Y - 4, VIEW_SIZE.x, 7), Color(0.07, 0.05, 0.11))
	draw_rect(Rect2(GATE.x - 34, YARD_Y - 4, 68, 7), Color(UI.GOLD, 0.6))
	draw_rect(Rect2(6, YARD_Y + 28, 310, 130), Color(0.26, 0.29, 0.35))
	for i in 5:
		draw_line(Vector2(12 + i * 74.0, YARD_Y + 30), Vector2(12 + i * 74.0, YARD_Y + 156), Color(1, 1, 1, 0.18), 2.0)
	draw_line(Vector2(8, YARD_Y + 93), Vector2(314, YARD_Y + 93), Color(1, 1, 1, 0.12), 2.0)
	draw_rect(Rect2(392, YARD_Y + 28, 424, 112), Color(0.36, 0.33, 0.40))
	for i in 11:
		draw_rect(Rect2(392 + i * 40.0, YARD_Y + 28, 20, 8), Color(UI.PINK, 0.55))
	draw_rect(Rect2(866, YARD_Y + 44, 108, 90), Color(0.20, 0.24, 0.34))
	draw_rect(Rect2(866, YARD_Y + 44, 108, 90), UI.GOOD if sim.state.guard_hired else Color(UI.MUTED, 0.6), false, 2.0)
	draw_rect(Rect2(866, YARD_Y + 44, 108, 14), Color(0.29, 0.47, 0.78) if sim.state.guard_hired else Color(0.3, 0.3, 0.36))
	draw_rect(Rect2(STREET.x - 46, VIEW_SIZE.y - 5, 92, 5), Color(UI.GOLD, 0.6))

	# Phòng hát
	for room in sim.state.rooms:
		var ui: Dictionary = _room_ui[room["id"]]
		var rect: Rect2 = _room_rect(ui["index"])
		var room_state: String = room["state"]
		var floor_color: Color = FLOOR_COLOR[room_state]
		draw_rect(rect, floor_color.darkened(0.35) if ui["dim"] else floor_color)
		var center_x: float = rect.position.x + ROOM_W * 0.5
		if room_state == "OCCUPIED":
			var hue: float = fmod(_anim_time * 0.25 + ui["index"] * 0.3, 1.0)
			draw_rect(rect, Color(Color.from_hsv(hue, 0.6, 1.0), 0.10))
			for i in 2:
				var phase: float = _anim_time * 1.6 + i * 2.1 + ui["index"]
				var note_pos: Vector2 = Vector2(center_x - 96 + i * 170, rect.position.y + 96 - fmod(phase, 3.0) * 12)
				draw_texture_rect(_note_texture, Rect2(note_pos, Vector2(15, 18)), false, Color(1, 1, 1, 1.0 - fmod(phase, 3.0) / 3.0))
		elif room_state == "DIRTY" or room_state == "CLEANING":
			var mess: Array = [Vector2(-80, 120), Vector2(60, 96), Vector2(86, 142), Vector2(-30, 84), Vector2(20, 150)]
			for i in (mess.size() if room_state == "DIRTY" else 2):
				var p: Vector2 = Vector2(center_x, rect.position.y) + mess[i]
				draw_circle(p, 4.0, Color(0.85, 0.82, 0.7))
				draw_rect(Rect2(p + Vector2(7, -3), Vector2(8, 4)), Color(0.5, 0.8, 0.95))
		var selected: bool = room["id"] == selected_room
		draw_rect(rect.grow(-1.5), UI.GOLD if selected else ui["border"], false, 4.0 if selected else 3.0)
		# Cửa phòng mở ra hành lang
		var door_y: float = rect.end.y - 3 if ui["index"] < 3 else rect.position.y - 3
		draw_rect(Rect2(center_x - 24, door_y, 48, 6), floor_color.lightened(0.3))
