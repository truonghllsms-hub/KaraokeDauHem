extends Control
## Mặt bằng quán nhìn từ trên xuống: sáu phòng hát (hai dãy, hành lang ở giữa), sảnh lễ tân và góc Lan can
## bên phải, sân xe và chỗ chờ phía dưới. Chỉ hiển thị trạng thái của Simulation và biến cú bấm
## thành việc cho chủ quán đi làm.

signal report(reason: String)
signal hint(text: String)
signal choice_requested(room_id: String)
signal inspect_requested(room_id: String)

const UI = preload("res://scripts/ui/ui_kit.gd")
const Actor = preload("res://scripts/ui/actor.gd")
const Money = preload("res://scripts/core/money.gd")
const Clock = preload("res://scripts/core/simulation_clock.gd")

const VIEW_SIZE: Vector2 = Vector2(980, 1820)
const ROOM_W: float = 410.0
const ROOM_H: float = 340.0
const ROOM_COLS: Array = [16.0, 554.0]
const ROOM_ROWS: Array = [44.0, 404.0, 764.0]
const CORRIDOR_X: float = 490.0
const LOBBY_Y: float = 1120.0
const YARD_Y: float = 1530.0
const JUNCTION: Vector2 = Vector2(490, 1170)
const GATE: Vector2 = Vector2(490, 1530)
const OWNER_HOME: Vector2 = Vector2(200, 1270)
const PICKUP: Vector2 = Vector2(345, 1330)
const HOST_SLOTS: Array = [Vector2(692, 1236), Vector2(772, 1236), Vector2(852, 1236)]
const QUEUE_SLOTS: Array = [Vector2(345, 1400), Vector2(300, 1470), Vector2(650, 1430), Vector2(690, 1490)]
const STREET: Vector2 = Vector2(490, 1855)
const BIKE_SLOTS: Array = [Vector2(80, 1740), Vector2(160, 1740), Vector2(240, 1740), Vector2(320, 1740), Vector2(655, 1740), Vector2(735, 1740), Vector2(815, 1740)]
const GUARD_POS: Vector2 = Vector2(906, 1702)
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
 "LOCKED": Color("#b9ae98"), "AVAILABLE": Color("#eccca0"), "OCCUPIED": Color("#e5c199"),
 "DIRTY": Color("#c4ae88"), "CLEANING": Color("#d9d1a8"), "BROKEN": Color("#c69a81"),
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
var _lobby_texture: Texture2D
var _yard_texture: Texture2D
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

	_lobby_texture = load("res://assets/topdown/lobby_painted.webp")
	_yard_texture = load("res://assets/topdown/yard.svg")
	for i in sim.state.rooms.size():
		_build_room(sim.state.rooms[i], i)
	_lbl_yard = _add_label("", 13, UI.TEXT, Rect2(610, 1778, 350, 26), true)
	_actors = Node2D.new()
	_actors.y_sort_enabled = true
	add_child(_actors)
	for i in BIKE_SLOTS.size():
		var bike: Sprite2D = Sprite2D.new()
		bike.texture = load("res://assets/topdown/scooter.svg")
		bike.position = BIKE_SLOTS[i] - Vector2(0, 72)
		bike.modulate = [Color.WHITE, Color("#d4d8ab"), Color("#9fbbb6")][i % 3]
		_actors.add_child(bike)
		_bikes.append(bike)

	_guard = Node2D.new()
	_guard.position = GUARD_POS
	var seated: Sprite2D = Sprite2D.new()
	seated.texture = load("res://assets/topdown/guard_seated.svg")
	seated.position.y = -35
	_guard.add_child(seated)
	_guard.visible = false
	_actors.add_child(_guard)

	_owner = Actor.new()
	_owner.setup(["owner"])
	_owner.position = OWNER_HOME
	_owner.speed = 330.0
	_owner.set_clickable(false)
	_actors.add_child(_owner)
	_owner_broom = Sprite2D.new()
	_owner_broom.texture = load("res://assets/sprites/broom.svg")
	_owner_broom.scale = Vector2(0.5, 0.5)
	_owner_broom.position = Vector2(24, -18)
	_owner_broom.visible = false
	_owner.add_child(_owner_broom)

	_lbl_toast = _add_label("", 13, UI.TEXT, Rect2(45, 1490, 890, 30), true)
	_lbl_toast.clip_text = true
	_lbl_toast.visible = false
	_lbl_toast.add_theme_stylebox_override("normal", UI.box(Color(UI.PANEL, 0.93), UI.BORDER, 1, 5))
	_lbl_tasks = _add_label("", 11, UI.GOLD, Rect2(350, 1450, 290, 32), true)

	_btn_open = UI.button("MỞ CỬA ĐÓN KHÁCH", 18, UI.PINK)
	_btn_open.position = Vector2(345, 1380)
	_btn_open.size = Vector2(290, 56)
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




func _room_rect(index: int) -> Rect2:
	@warning_ignore("integer_division")
	return Rect2(ROOM_COLS[index % 2], ROOM_ROWS[2 - index / 2], ROOM_W, ROOM_H)


func _build_room(room: Dictionary, index: int) -> void:
	var room_id: String = room["id"]
	var rect: Rect2 = _room_rect(index)
	var origin: Vector2 = rect.position
	var center_x: float = origin.x + ROOM_W * 0.5

	var furniture: Node2D = Node2D.new()
	add_child(furniture)
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = load("res://assets/topdown/room_painted.webp")
	sprite.centered = false
	var sx: float = ROOM_W / sprite.texture.get_width()
	var sy: float = ROOM_H / sprite.texture.get_height()
	sprite.scale = Vector2(sx if index % 2 == 0 else -sx, sy)
	sprite.position = origin + (Vector2(ROOM_W, 0) if index % 2 == 1 else Vector2.ZERO)
	furniture.add_child(sprite)

	var title: Label = _add_label("", 19, UI.TEXT, Rect2(origin + Vector2(18, 16), Vector2(180, 26)), false)
	var status: Label = _add_label("", 15, UI.GOOD, Rect2(origin + Vector2(210, 16), Vector2(180, 26)), false)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_stylebox_override("normal", UI.box(Color(UI.PANEL, 0.96), UI.BORDER, 1, 4))
	status.add_theme_stylebox_override("normal", UI.box(Color(UI.PANEL, 0.96), UI.PURPLE, 1, 4))
	var info: Label = _add_label("", 15, UI.TEXT, Rect2(origin + Vector2(18, 47), Vector2(ROOM_W - 36, 23)), false)
	info.clip_text = true
	info.add_theme_stylebox_override("normal", UI.box(Color(UI.PANEL, 0.94), Color.TRANSPARENT, 0, 4))
	var center_text: Label = _add_label("", 19, UI.TEXT, Rect2(origin + Vector2(40, 83), Vector2(ROOM_W - 80, 76)), true)
	center_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_text.z_index = 2
	var request: Label = _add_label("", 15, UI.TEXT, Rect2(origin + Vector2(18, 72), Vector2(ROOM_W - 36, 35)), false)
	request.clip_text = true
	request.z_index = 2
	request.visible = false
	var bar: ProgressBar = UI.progress(UI.PINK)
	bar.position = origin + Vector2(18, ROOM_H - 24)
	bar.size = Vector2(ROOM_W - 36, 10)
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
	return rect.position + Vector2(130 if rect.position.x < CORRIDOR_X else 280, 254)


func _host_position(room_id: String) -> Vector2:
	return _rect_of(room_id).position + Vector2(218, 275)


func _work_position(room_id: String) -> Vector2:
	var rect: Rect2 = _rect_of(room_id)
	return rect.position + Vector2(330 if rect.position.x < CORRIDOR_X else 80, 284)


func _zone(point: Vector2) -> int:
	if point.y >= YARD_Y:
		return 3
	if point.y >= LOBBY_Y:
		return 2
	if point.x >= 426 and point.x <= 554:
		return 1
	return 0


func _door(point: Vector2) -> Vector2:
	var row: int = clampi(int((point.y - 44) / 360.0), 0, 2)
	return Vector2(CORRIDOR_X, ROOM_ROWS[row] + 285)


## Every trip passes through the corridor; staff never cut across other rooms.
func _route(from: Vector2, to: Vector2) -> Array:
	var points: Array = []
	var start: int = _zone(from)
	var finish: int = _zone(to)
	if start == 0:
		points.append(Vector2(from.x, _door(from).y + 25))
		points.append(_door(from))
	elif start >= 2:
		# Counter workspace exits on the right, clear of its front edge.
		if from.x < 340 and from.y < 1350:
			points.append(Vector2(360, from.y))
		points.append(Vector2(CORRIDOR_X, from.y))
	if finish == 0:
		points.append(_door(to))
		points.append(Vector2(to.x, _door(to).y + 25))
	else:
		points.append(Vector2(CORRIDOR_X, to.y))
	if finish >= 2 and to.x < 340 and to.y < 1350:
		points.append(Vector2(360, to.y))
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
	if room["state"] in ["LOCKED", "AVAILABLE"]:
		inspect_requested.emit(room_id)


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
	var scaled: float = delta * sim.clock.speed if sim.clock.is_running() else 0.0
	advance_actors(scaled)


## Tách riêng để kịch bản kiểm thử có thể tua nhanh phần hình ảnh.
func advance_actors(delta: float) -> void:
	_anim_time += delta
	_sync_groups()
	_sync_hosts()
	_update_owner()
	_owner.visible = sim.state.phase != "PREP"
	_owner.advance(delta)
	for actor in _group_actors.values():
		actor.advance(delta)
	for actor in _host_actors.values():
		actor.visible = sim.state.phase != "PREP"
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
		_bikes[i].visible = i < maxi(3, parked)
	_guard.visible = sim.state.guard_hired and sim.state.phase != "PREP"
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
		ui["title"].text = room["name"]
		ui["status"].text = STATE_TEXT[room_state]
		ui["status"].add_theme_color_override("font_color", STATE_COLOR[room_state])
		var info: String = "%d người · %s/giờ" % [room["capacity"], Money.format(room["price_per_hour"])]
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
			badge.add_theme_stylebox_override("normal", UI.box(UI.PANEL.lightened(0.12), Color(REQUEST_COLOR[kind], blink), 2, 6))
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
		ui["center"].add_theme_stylebox_override("normal", UI.box(Color(UI.PANEL, 0.94), UI.BORDER, 1, 6) if center != "" else StyleBoxEmpty.new())
		ui["center"].add_theme_color_override("font_color", center_color)
		ui["furniture"].modulate = Color(0.63, 0.60, 0.53) if dim else Color.WHITE
		ui["border"] = border
		ui["dim"] = dim
		ui["hit"].tooltip_text = tip
		var highlight_color: Color = UI.GOLD if room["id"] == selected_room else (border if choosing != null else Color.TRANSPARENT)
		if ui.get("highlight_color", Color(-1, -1, -1)) != highlight_color:
			var outline: StyleBoxFlat = UI.box(Color.TRANSPARENT, highlight_color, 4, 0)
			outline.shadow_size = 0
			outline.set_corner_radius_all(4)
			ui["hit"].add_theme_stylebox_override("normal", outline)
			ui["highlight_color"] = highlight_color


func _show_bar(bar: ProgressBar, color: Color, value: int, total: int) -> void:
	bar.visible = true
	bar.get_theme_stylebox("fill").bg_color = color
	bar.max_value = maxi(1, total)
	bar.value = value


# ---------------------------------------------------------------- Vẽ nền

func _draw() -> void:
	if sim == null:
		return
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color("#cbb78e"))
	# Continuous cream tiles throughout the corridor and reception.
	draw_rect(Rect2(426, 0, 128, LOBBY_Y), Color("#f3e3bf"))
	for y in range(0, int(LOBBY_Y), 42):
		draw_line(Vector2(426, y), Vector2(554, y), Color("#d4c29d"), 1)
	draw_line(Vector2(CORRIDOR_X, 0), Vector2(CORRIDOR_X, LOBBY_Y), Color("#decdaa"), 1)
	draw_texture_rect(_lobby_texture, Rect2(0, LOBBY_Y, 980, 410), false)
	draw_texture_rect(_yard_texture, Rect2(0, YARD_Y, 980, 290), false)
	for room in sim.state.rooms:
		var ui: Dictionary = _room_ui[room["id"]]
		var rect: Rect2 = _room_rect(ui["index"])
		if room["state"] == "OCCUPIED":
			for i in 2:
				var phase: float = fmod(_anim_time * 1.3 + i, 3.0)
				var at: Vector2 = rect.position + Vector2(170 + i * 80, 200 - phase * 12)
				draw_texture_rect(_note_texture, Rect2(at, Vector2(20, 25)), false, Color(UI.PINK, 1.0 - phase / 3.0))
		elif room["state"] in ["DIRTY", "CLEANING"]:
			for i in (5 if room["state"] == "DIRTY" else 2):
				var at: Vector2 = rect.position + Vector2(120 + i * 37, 275 + (i % 2) * 15)
				draw_circle(at, 5, UI.PANEL)
		# Subtle timber outline, stronger when the player selects a room.
		var selected: bool = room["id"] == selected_room
		if selected or selected_group != 0:
			draw_rect(rect.grow(-2), UI.GOLD if selected else ui["border"], false, 5)
