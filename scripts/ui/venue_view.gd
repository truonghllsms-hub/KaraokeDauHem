extends Control
## Hai tầng: 4 phòng thường và 6 VIP, hành lang giữa và cầu thang nối tầng.
## Giữ tọa độ thế giới riêng cho mỗi tầng, camera chỉ hiển thị tầng đang chọn.

signal report(reason: String)
signal hint(text: String)
signal choice_requested(room_id: String)
signal inspect_requested(room_id: String)

const ReferenceSkin = preload("res://scripts/ui/reference_skin.gd")
const UI = preload("res://scripts/ui/ui_kit.gd")
const Actor = preload("res://scripts/ui/actor.gd")
const CharacterArt = preload("res://scripts/ui/character_art.gd")
const EMPTY_FLOOR = preload("res://assets/topdown/unequipped_floor.webp")
const MAP_STANDARD = preload("res://assets/topdown/floor1_final.webp")
const MAP_VIP = preload("res://assets/topdown/floor2_final.webp")
const SeatingPlan = preload("res://scripts/ui/seating_plan.gd")
const Money = preload("res://scripts/core/money.gd")
const Clock = preload("res://scripts/core/simulation_clock.gd")

const VIEW_SIZE: Vector2 = Vector2(1024, 1264)
const FLOOR2_OFFSET: float = 1400.0
const MAP_Y: float = 64.0
const ROOM_W: float = 446.0
const ROOM_H: float = 400.0
const ROOM_COLS: Array = [16.0, 566.0]
const ROOM_ROWS: Array = [64.0, 464.0, 864.0]
const CORRIDOR_X: float = 515.0
const LOBBY_Y: float = 864.0
const YARD_Y: float = 1084.0
const JUNCTION: Vector2 = Vector2(515, 890)
const GATE: Vector2 = Vector2(515, 1084)
const STAIR1: Vector2 = Vector2(515, 300)
const STAIR2: Vector2 = Vector2(515, 1700)
const OWNER_HOME: Vector2 = Vector2(410, 1000)
const PICKUP: Vector2 = Vector2(110, 1070)
const HOST_SLOTS: Array = [Vector2(650, 960), Vector2(735, 960), Vector2(820, 960), Vector2(905, 960), Vector2(960, 1015), Vector2(960, 1070)]
const QUEUE_SLOTS: Array = [Vector2(460, 1010), Vector2(460, 1065), Vector2(580, 1010), Vector2(580, 1065)]
const STREET: Vector2 = Vector2(515, 1280)
const BIKE_SLOTS: Array = [Vector2(140, 1210), Vector2(260, 1210), Vector2(720, 1210), Vector2(350, 1210), Vector2(800, 1210), Vector2(430, 1210)]
const GUARD_POS: Vector2 = Vector2(900, 1220)
const MAX_TASKS: int = 5
## Chỗ nhân viên phục vụ đứng chờ việc (cạnh quầy) và thời gian hiện một câu hát/thoại (giây thực).
const STAFF_SLOTS: Array = [Vector2(330, 935), Vector2(250, 935), Vector2(170, 935)]
## Chỗ đứng theo vai trò: lễ tân sau quầy, tạp vụ và phục vụ cạnh quầy.
const ROLE_SLOTS: Dictionary = {
	"receptionist": [Vector2(250, 940), Vector2(340, 940)],
	"janitor": [Vector2(190, 950), Vector2(430, 1060)],
	"waiter": [Vector2(565, 955), Vector2(565, 1060)],
}
const THIEF_FROM: Vector2 = Vector2(980, 1290)
const LINE_SECONDS: float = 4.5
const REPLY_AFTER: float = 2.2
const STAFF_BUBBLE: Dictionary = {"CLEAN": "Đi dọn phòng", "DELIVER": "Mang món tới!", "FIX": "Đổi micro mới", "SEAT": "Mời vào phòng!", "REST": "Nghỉ xíu..."}

const STATE_TEXT: Dictionary = {
	"LOCKED": "[CHƯA LẮP]", "AVAILABLE": "[TRỐNG]", "OCCUPIED": "[ĐANG HÁT]",
	"DIRTY": "[BẨN]", "CLEANING": "[ĐANG DỌN]", "BROKEN": "[HỎNG]",
}
const STATE_BLOCK: Dictionary = {
	"LOCKED": "Chưa lắp thiết bị", "OCCUPIED": "Đang có khách", "DIRTY": "Đang bẩn", "CLEANING": "Đang dọn", "BROKEN": "Đang hỏng",
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
var current_floor: int = 1
var _floor_buttons: Dictionary = {}
var _stairs_button: Button
var _stairs_label: Label
var selected_group: int = 0
var selected_room: String = ""
var selected_host: String = ""

var _actors: Node2D
var _owner: Node2D
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
var _anim_time: float = 0.0
var _fridge_active_until: float = 0.0
var _toast_until: int = 0
var _staff_actors: Dictionary = {}
var _thief_actor = null
var _thief_id: int = -1
## Câu hát/thoại đang hiện: khóa "g:<id nhóm>" hoặc "h:<id nhân viên>" -> {text, reply, reply_key, at}.
var _lines: Dictionary = {}
var _line_clock: float = 0.0

## Hàng việc của chủ quán: {"kind": "seat"|"clean"|"deliver"|"fix"|"goto", ...}
var _tasks: Array = []
var _current_task: Dictionary = {}
var _cleaning_room: String = ""


func setup(p_sim) -> void:
	sim = p_sim
	custom_minimum_size = VIEW_SIZE
	size = VIEW_SIZE
	clip_contents = true

	for i in sim.state.rooms.size():
		_build_room(sim.state.rooms[i], i)
	_lbl_yard = _add_label("", 13, UI.TEXT, Rect2(610, 1225, 350, 26), true)
	_lbl_yard.visible = false
	_actors = Node2D.new()
	_actors.y_sort_enabled = true
	add_child(_actors)
	for i in BIKE_SLOTS.size():
		var bike: Sprite2D = Sprite2D.new()
		bike.texture = ReferenceSkin.texture(Rect2(107, 1208, 70, 175))
		bike.visible = false
		bike.position = BIKE_SLOTS[i] - Vector2(0, 72)
		bike.modulate = [Color.WHITE, Color("#d4d8ab"), Color("#9fbbb6")][i % 3]
		_actors.add_child(bike)
		_bikes.append(bike)

	_guard = Node2D.new()
	_guard.position = GUARD_POS
	var seated: Sprite2D = Sprite2D.new()
	seated.texture = CharacterArt.texture("guard")
	var guard_scale: float = CharacterArt.height("guard") / seated.texture.get_height()
	seated.scale = Vector2(guard_scale, guard_scale)
	seated.offset.y = -seated.texture.get_height() * 0.5
	_guard.add_child(seated)
	_guard.visible = false
	_actors.add_child(_guard)

	_owner = Actor.new()
	_owner.setup(["owner"])
	_owner.portals = [[STAIR1, STAIR2], [STAIR2, STAIR1]]
	_owner.position = OWNER_HOME
	_owner.speed = 330.0
	_owner.set_clickable(false)
	_actors.add_child(_owner)

	_lbl_toast = _add_label("", 22, UI.TEXT, Rect2(80, 1195, 830, 48), true)
	_lbl_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_toast.size = Vector2(830, 64)
	_lbl_toast.position.y = 1182
	_lbl_toast.add_theme_font_size_override("font_size", 19)
	_lbl_toast.visible = false
	_lbl_toast.add_theme_stylebox_override("normal", UI.box(Color(UI.PANEL, 0.93), UI.BORDER, 1, 5))
	_lbl_tasks = _add_label("", 11, UI.GOLD, Rect2(350, 1050, 290, 32), true)
	_lbl_tasks.visible = false

	_btn_open = UI.button("▶  MỞ CỬA ĐÓN KHÁCH", 28, UI.PINK)
	_btn_open.position = Vector2(330, 1006)
	_btn_open.visible = false
	_btn_open.size = Vector2(360, 72)
	_btn_open.pressed.connect(func() -> void: report.emit(sim.open_doors()))
	add_child(_btn_open)
	_build_floor_controls()
	sim.line_spoken.connect(_on_line_spoken)


func set_toast(text: String, color: Color) -> void:
	_lbl_toast.text = text
	_lbl_toast.add_theme_color_override("font_color", color)
	_lbl_toast.visible = true
	_toast_until = Time.get_ticks_msec() + 4500


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




func floor_of_room(room_id: String) -> int:
	return sim.rooms.get_room(room_id)["floor"]

func _world_floor(point: Vector2) -> int:
	return 2 if point.y >= FLOOR2_OFFSET else 1

func _floor_offset() -> Vector2:
	return Vector2(0, FLOOR2_OFFSET if current_floor == 2 else 0)

func set_floor(floor_number: int) -> bool:
	if not sim.rooms.floor_unlocked(floor_number):
		report.emit(sim.rooms.floor_lock_reason())
		return false
	current_floor = floor_number
	_actors.position = -_floor_offset()
	_refresh_rooms()
	_refresh_floor_controls()
	_apply_actor_visibility()
	queue_redraw()
	return true

func _build_floor_controls() -> void:
	for floor_number in [1, 2]:
		var button: Button = UI.button("TẦNG %d" % floor_number, 25, UI.GOOD)
		button.name = "Floor%d" % floor_number
		button.position = Vector2(270 + (floor_number - 1) * 255, 7)
		button.custom_minimum_size = Vector2(220, 48)
		button.size = Vector2(220, 48)
		button.add_theme_stylebox_override("normal", UI.box(Color("#fff0cb"), UI.TEXT, 2, 8))
		button.add_theme_stylebox_override("pressed", UI.box(Color("#647c36"), UI.TEXT, 2, 8))
		button.add_theme_color_override("font_pressed_color", Color("#fff2cb"))
		button.toggle_mode = true
		button.pressed.connect(func() -> void: set_floor(floor_number))
		add_child(button)
		_floor_buttons[floor_number] = button
	_stairs_button = ReferenceSkin.hit(Rect2(465, 70, 100, 225), "Cầu thang")
	_stairs_button.name = "Stairs"
	_stairs_button.pressed.connect(func() -> void: set_floor(2 if current_floor == 1 else 1))
	add_child(_stairs_button)
	_stairs_label = _room_label(self, "", Rect2(452, 67, 126, 32), 15)
	_stairs_label.add_theme_stylebox_override("normal", UI.box(Color("#ffe6b5"), UI.TEXT, 2, 3))
	_refresh_floor_controls()

func _refresh_floor_controls() -> void:
	for floor_number in [1, 2]:
		var button: Button = _floor_buttons[floor_number]
		var ready: bool = sim.rooms.floor_unlocked(floor_number)
		var attention: int = 0
		for room in sim.state.rooms:
			if room["floor"] != floor_number:
				continue
			var group = sim.customers.get_group(room["group_id"])
			if room["state"] in ["DIRTY", "BROKEN"] or not room["request"].is_empty() or (group != null and sim.hosts.needs_staff(group)):
				attention += 1
		button.text = ("TẦNG %d" % floor_number) + (" · KHÓA" if not ready else (" · !%d" % attention if attention else ""))
		button.set_pressed_no_signal(current_floor == floor_number)
		button.tooltip_text = sim.rooms.floor_lock_reason() if not ready else "Đổi tầng · %d phòng cần chú ý" % attention
	_stairs_button.tooltip_text = "Lên tầng 2" if current_floor == 1 else "Xuống tầng 1"
	_stairs_label.text = "LÊN TẦNG 2 ↑" if current_floor == 1 else "XUỐNG TẦNG 1 ↓"

func _room_rect(index: int) -> Rect2:
	@warning_ignore("integer_division")
	var row: int = 1 - index / 2 if index < 4 else (index - 4) / 2
	var floor_offset: float = 0.0 if index < 4 else FLOOR2_OFFSET
	return Rect2(ROOM_COLS[index % 2], MAP_Y + row * ROOM_H + floor_offset, ROOM_W, ROOM_H)

func _room_label(parent: Control, text: String, at: Rect2, font_size: int = 22) -> Label:
	var label: Label = UI.label(text, font_size, UI.TEXT, true)
	label.position = at.position
	label.size = at.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _build_room(room: Dictionary, index: int) -> void:
	var rect: Rect2 = _room_rect(index)
	var root: Control = Control.new()
	root.position = rect.position
	root.size = rect.size
	root.visible = room["floor"] == current_floor
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var dimmer: TextureRect = TextureRect.new()
	dimmer.texture = EMPTY_FLOOR
	dimmer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dimmer.stretch_mode = TextureRect.STRETCH_SCALE
	dimmer.position = Vector2(8, 68)
	dimmer.size = Vector2(ROOM_W - 16, ROOM_H - 78)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dimmer)
	var furniture: Control = Control.new()
	root.add_child(furniture)
	var room_title: String = "P%02d" % (index + 1) if index < 4 else "VIP %02d" % (index - 3)
	var title: Label = _room_label(root, room_title, Rect2(12, 10, 125, 43), 25)
	title.add_theme_stylebox_override("normal", UI.box(Color("#ffe6b5"), UI.TEXT, 2, 5))
	var kind: Label = _room_label(root, "PHÒNG VIP" if room["floor"] == 2 else "PHÒNG THƯỜNG", Rect2(140, 10, 132, 43), 17)
	var status: Label = _room_label(root, "", Rect2(280, 12, 152, 39), 22)
	status.add_theme_stylebox_override("normal", UI.box(Color("#6d7d42"), Color("#fff0cb"), 2, 5))
	var info: Label = _room_label(root, "", Rect2(12, 55, 420, 25), 17)
	info.visible = false
	var center_text: Label = _room_label(root, "", Rect2(90, 315, 270, 65), 20)
	center_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center_text.visible = false
	var request: Label = _room_label(root, "", Rect2(20, 75, 406, 44), 20)
	request.clip_text = true
	var bar: ProgressBar = UI.progress(UI.PINK)
	bar.position = Vector2(18, ROOM_H - 14)
	bar.size = Vector2(ROOM_W - 36, 8)
	bar.custom_minimum_size = Vector2.ZERO
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)
	var hit: Button = ReferenceSkin.hit(Rect2(Vector2.ZERO, rect.size))
	hit.pressed.connect(func() -> void: on_room_pressed(room["id"]))
	root.add_child(hit)
	_room_ui[room["id"]] = {"root": root, "index": index, "dimmer": dimmer, "furniture": furniture, "title": title, "kind": kind, "info": info, "status": status, "center": center_text, "request": request, "bar": bar, "hit": hit, "art": furniture}


# ---------------------------------------------------------------- Vị trí và đường đi

func _rect_of(room_id: String) -> Rect2:
	return _room_rect(_room_ui[room_id]["index"])


func _seat_position(room_id: String) -> Vector2:
	var rect: Rect2 = _rect_of(room_id)
	return rect.position + Vector2(145 if rect.position.x < CORRIDOR_X else 220, ROOM_H - 38)


func _seating(room_id: String) -> Dictionary:
	var room = sim.rooms.get_room(room_id)
	var group = sim.customers.get_group(room["group_id"])
	var reserved: int = group["host_requested_count"] if sim.hosts.can_request(group) and (group["wants_host"] or group["host_request"] != "NONE") else 0
	return SeatingPlan.build(_rect_of(room_id), group["size"], mini(group["size"], reserved))


func _host_position(room_id: String, host_id: String = "") -> Vector2:
	var plan: Dictionary = _seating(room_id)
	var host = sim.hosts.get_host(host_id)
	var index: int = host.get("guest_index", 0) if host != null else 0
	return plan["hosts"][index] if index < plan["hosts"].size() else _seat_position(room_id)


func _work_position(room_id: String) -> Vector2:
	var rect: Rect2 = _rect_of(room_id)
	return rect.position + Vector2(330 if rect.position.x < CORRIDOR_X else 80, ROOM_H - 52)


func _zone(point: Vector2) -> int:
	if _world_floor(point) == 2:
		return 1 if point.x >= 462 and point.x <= 566 else 0
	if point.y >= YARD_Y:
		return 3
	if point.y >= LOBBY_Y:
		return 2
	return 1 if point.x >= 462 and point.x <= 566 else 0

func _door(point: Vector2) -> Vector2:
	var floor_offset: float = FLOOR2_OFFSET if _world_floor(point) == 2 else 0.0
	var row: int = clampi(int((point.y - floor_offset - MAP_Y) / ROOM_H), 0, 2 if floor_offset > 0 else 1)
	return Vector2(CORRIDOR_X, floor_offset + MAP_Y + row * ROOM_H + ROOM_H - 38)

func _route(from: Vector2, to: Vector2) -> Array:
	var points: Array = []
	var start: int = _zone(from)
	var finish: int = _zone(to)
	if start == 0:
		points.append(Vector2(430 if from.x < CORRIDOR_X else 600, _door(from).y))
		points.append(_door(from))
	elif start >= 2:
		if from.x < 400 and from.y < 1030:
			points.append(Vector2(430, from.y))
		points.append(Vector2(CORRIDOR_X, from.y))
	if _world_floor(from) != _world_floor(to):
		points.append(STAIR1 if _world_floor(from) == 1 else STAIR2)
		points.append(STAIR2 if _world_floor(to) == 2 else STAIR1)
	if finish == 0:
		points.append(_door(to))
		points.append(Vector2(430 if to.x < CORRIDOR_X else 600, _door(to).y))
	else:
		points.append(Vector2(CORRIDOR_X, to.y))
	if finish >= 2 and to.x < 400 and to.y < 1030:
		points.append(Vector2(430, to.y))
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
	if task["kind"] == "deliver":
		var order: Dictionary = sim.rooms.get_room(task["room_id"])["request"]
		task["request_id"] = order.get("id", -1)
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
	if _current_task.get("kind", "") == "deliver" and not _owner_order_valid(_current_task):
		_owner.walk_to([])
		_owner.carrying = false
		_owner.pose = "standing"
		_current_task = {}
	if _cleaning_room != "":
		if sim.rooms.get_room(_cleaning_room)["state"] == "CLEANING":
			return
		_cleaning_room = ""
		_owner.pose = "standing"
		_owner.singing = false

	if _owner.is_moving():
		return
	if _current_task.is_empty():
		if _tasks.is_empty():
			_owner.set_bubble("")
			return
		_current_task = _tasks.pop_front()
		_owner.carrying = false
		if _current_task["kind"] == "deliver" and not _owner_order_valid(_current_task):
			_current_task = {}
			return
		_owner.walk_to(_route(_owner.position, _task_target(_current_task)))
		var bubbles: Dictionary = {"seat": "Mời vào phòng!", "clean": "Đi dọn phòng", "deliver": "Đến tủ lạnh lấy đồ", "fix": "Đi đổi micro"}
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
				_owner.pose = "cleaning"
				_owner.singing = true
				_owner.set_bubble("Đang dọn...")
			else:
				report.emit(reason)
		"deliver":
			if not task.get("picked", false):
				if not task.has("pickup_started"):
					task["pickup_started"] = _anim_time
					_owner.set_bubble("Lấy đồ ở tủ lạnh")
					return
				if _anim_time - task["pickup_started"] < 0.5:
					return
				task["picked"] = true
				_owner.carrying = true
				_fridge_active_until = _anim_time + 0.8
				_owner.walk_to(_route(_owner.position, _work_position(task["room_id"])))
				_owner.set_bubble("Mang món tới!")
				return
			_owner.carrying = false
			report.emit(sim.deliver_order(task["room_id"]))
		"fix":
			report.emit(sim.fix_mic(task["room_id"]))
	_current_task = {}


func _owner_order_valid(task: Dictionary) -> bool:
	var room = sim.rooms.get_room(task.get("room_id", ""))
	return room != null and room["state"] == "OCCUPIED" and room["request"].get("kind", "") == "ORDER" and room["request"].get("id", -1) == task.get("request_id", room["request"].get("id", -1))


# ---------------------------------------------------------------- Đồng bộ với mô phỏng

func _process(delta: float) -> void:
	if sim == null:
		return
	var scaled: float = delta * sim.clock.speed if sim.clock.is_running() else 0.0
	# Câu hát hiện theo giây thực (đọc kịp ở mọi tốc độ) và dừng khi tạm dừng.
	if sim.clock.is_running():
		_line_clock += delta
	advance_actors(scaled)


## Tách riêng để kịch bản kiểm thử có thể tua nhanh phần hình ảnh.
func advance_actors(delta: float) -> void:
	_anim_time += delta
	_sync_groups()
	_sync_hosts()
	_sync_staff(delta)
	_sync_thief(delta)
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
	_refresh_floor_controls()
	_apply_actor_visibility()
	_btn_open.visible = sim.state.phase == "PREP" and current_floor == 1
	if _lbl_toast.visible and Time.get_ticks_msec() > _toast_until:
		_lbl_toast.visible = false
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
		_bikes[i].visible = i >= 3 and i < parked
	_guard.visible = sim.state.guard_hired and sim.state.phase != "PREP"
	var thief: Dictionary = sim.state.thief
	_guard.position = GUARD_POS
	if not thief.is_empty() and thief["chased_by"] == "guard" and _thief_actor != null and sim.clock.minute >= thief["appear"] + sim.data["balance"]["guard_react_minutes"]:
		_guard.position = GUARD_POS.lerp(_thief_actor.position + Vector2(40, 0), 0.8)
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
			for i in group["size"]:
				names.append(group["sprites"][i % group["sprites"].size()])
			actor.setup(names, "×%d" % group["size"])
			actor.portals = [[STAIR1, STAIR2], [STAIR2, STAIR1]]
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
		actor.pose = "standing" if waiting else "seated"
		actor.seated_faces_left = not waiting and _rect_of(group["room_id"]).position.x > CORRIDOR_X
		actor.seated_offsets = []
		if not waiting:
			var plan: Dictionary = _seating(group["room_id"])
			for point in plan["guests"]:
				actor.seated_offsets.append(point - target)
		actor.mood = "neutral"
		if waiting:
			var left: int = maxi(0, group["patience"] - group["wait_minutes"])
			actor.patience_ratio = float(left) / float(maxi(1, group["patience"]))
			if actor.patience_ratio <= 0.2:
				actor.mood = "angry"
			elif actor.patience_ratio <= 0.5:
				actor.mood = "impatient"
			if group_id == selected_group:
				actor.set_bubble("ĐANG CHỌN", Color(1.0, 0.96, 0.8), UI.GOLD)
			elif left <= 5:
				actor.set_bubble("Sắp bỏ về!", Color(1.0, 0.85, 0.85), UI.BAD)
			else:
				actor.set_bubble("")
		else:
			actor.patience_ratio = -1.0
			actor.mood = "angry" if group["satisfaction"] < 55 else "happy"
			var request_text: String = sim.hosts.request_label(group)
			var room_now = sim.rooms.get_room(group["room_id"])
			# Cảnh báo luôn ưu tiên hơn câu hát trang trí.
			if request_text == "" and room_now != null and room_now["request"].is_empty():
				_show_line(actor, "g:%d" % group_id)
			else:
				actor.set_bubble(request_text, Color(1.0, 0.9, 0.97), UI.PINK)

	for group_id in _group_actors.keys():
		if alive.has(group_id):
			continue
		var actor = _group_actors[group_id]
		_group_actors.erase(group_id)
		if actor.place_key.begins_with("queue"):
			actor.mood = "angry"
			actor.set_bubble("Thôi về!", Color(1.0, 0.85, 0.85), UI.BAD)
		else:
			actor.mood = "happy"
			actor.set_bubble("Cảm ơn nha!", Color(0.88, 1.0, 0.9), UI.GOOD)
		actor.patience_ratio = -1.0
		actor.set_clickable(false)
		actor.set_highlight(false)
		actor.singing = false
		actor.pose = "standing"
		var points: Array = _route(actor.position, STREET)
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
			actor.portals = [[STAIR1, STAIR2], [STAIR2, STAIR1]]
			actor.position = HOST_SLOTS[i % HOST_SLOTS.size()]
			actor.place_key = "lounge"
			actor.set_tooltip("Bấm để chọn, rồi bấm vào phòng đang gọi Lan can.")
			actor.pressed.connect(func() -> void: on_host_pressed(host_id))
			_actors.add_child(actor)
			_host_actors[host_id] = actor

		var key: String = "%s:%d" % [host["room_id"], host.get("guest_index", 0)] if host["state"] == "SERVING" else "lounge"
		if actor.place_key != key:
			actor.place_key = key
			var target: Vector2 = _host_position(host["room_id"], host_id) if key != "lounge" else HOST_SLOTS[i % HOST_SLOTS.size()]
			actor.walk_to(_route(actor.position, target))
		actor.set_clickable(host["state"] != "SERVING")
		actor.set_highlight(host_id == selected_host)
		actor.singing = host["state"] == "SERVING" and not actor.is_moving()
		actor.pose = "seated"
		actor.seated_faces_left = key == "lounge" or _rect_of(host["room_id"]).position.x > CORRIDOR_X
		actor.mood = "tired" if host["state"] == "RESTING" else ("happy" if host["state"] == "SERVING" else "neutral")
		if host_id == selected_host:
			actor.set_bubble("ĐANG CHỌN", Color(1.0, 0.96, 0.8), UI.GOLD)
		elif host["state"] == "RESTING":
			actor.set_bubble("Nghỉ xíu...", Color(0.9, 0.93, 1.0), UI.INFO)
		else:
			_show_line(actor, "h:" + host_id)


func _sync_staff(delta: float) -> void:
	for i in sim.state.staff.size():
		var member: Dictionary = sim.state.staff[i]
		var staff_id: String = member["id"]
		var actor = _staff_actors.get(staff_id)
		if actor == null:
			actor = Actor.new()
			actor.setup([CharacterArt.staff_sprite(member)])
			actor.portals = [[STAIR1, STAIR2], [STAIR2, STAIR1]]
			actor.position = _staff_slot(member, i)
			actor.speed = 300.0
			actor.set_clickable(false)
			actor.set_tooltip("%s %s" % [sim.staff.role_name(member["role"]), member["name"]])
			_actors.add_child(actor)
			_staff_actors[staff_id] = actor
		var task: Dictionary = member["task"]
		var working: bool = not task.is_empty() and task["kind"] != "REST"
		var delivery: bool = working and task["kind"] == "DELIVER"
		var phase: String = task.get("phase", "")
		var key: String = "%s:%s:%s:%d" % [task["room_id"], task["kind"], phase, task.get("request_id", 0)] if working else "idle"
		if actor.place_key != key:
			actor.place_key = key
			actor.set_meta("pickup_wait", 0.0)
			var target: Vector2 = _staff_slot(member, i)
			if working:
				target = _work_position(task["room_id"])
				if delivery and phase == "PICKUP":
					target = PICKUP
				elif task["kind"] == "SEAT":
					target = QUEUE_SLOTS[0] + Vector2(-70, 0)
			actor.walk_to(_route(actor.position, target))
		actor.carrying = delivery and phase == "CARRY" and task.get("pickup_confirmed", false)
		actor.pose = "cleaning" if working and task["kind"] == "CLEAN" and phase == "WORK" else "standing"
		actor.mood = "tired" if member["energy"] < 40 else "neutral"
		actor.set_bubble(("Đến tủ lạnh" if phase == "PICKUP" else "Mang đồ tới phòng") if delivery else STAFF_BUBBLE.get(task.get("kind", ""), ""), Color(0.9, 0.97, 1.0), UI.INFO)
		actor.visible = sim.state.phase != "PREP"
		actor.advance(delta)
		if delivery and not actor.is_moving() and delta > 0.0:
			var request_id: int = task["request_id"]
			if phase == "PICKUP" and actor.position.distance_to(PICKUP) < 2.0:
				var waited: float = actor.get_meta("pickup_wait", 0.0) + delta
				actor.set_meta("pickup_wait", waited)
				if waited >= 0.5 and sim.staff.confirm_pickup(staff_id, request_id):
					_fridge_active_until = _anim_time + 0.8
			elif phase == "CARRY":
				if sim.staff.confirm_delivery(staff_id, request_id, sim.clock.minute):
					actor.carrying = false


func _staff_slot(member: Dictionary, index: int) -> Vector2:
	var slots: Array = ROLE_SLOTS.get(member["role"], STAFF_SLOTS)
	var same_role: int = 0
	for other in sim.state.staff:
		if other["id"] == member["id"]:
			break
		same_role += 1 if other["role"] == member["role"] else 0
	return slots[same_role % slots.size()]


## Tên trộm: đi chậm từ đầu hẻm tới chiếc xe bị nhắm, phá khóa, rồi tẩu thoát. Bấm vào hắn để đuổi.
func _sync_thief(delta: float) -> void:
	var thief: Dictionary = sim.state.thief
	if thief.is_empty():
		if _thief_actor != null:
			_thief_actor.queue_free()
			_thief_actor = null
			_thief_id = -1
		return
	if _thief_actor == null or _thief_id != thief["id"]:
		if _thief_actor != null:
			_thief_actor.queue_free()
		_thief_actor = Actor.new()
		_thief_actor.setup(["young_m_3"])
		_thief_actor.modulate = Color(0.45, 0.45, 0.55)
		_thief_actor.position = THIEF_FROM
		_thief_actor.speed = 40.0
		_thief_actor.set_tooltip("Trộm xe! Bấm để chạy ra đuổi.")
		_thief_actor.pressed.connect(_on_thief_pressed)
		_actors.add_child(_thief_actor)
		_thief_id = thief["id"]
		_thief_actor.walk_to([BIKE_SLOTS[thief["id"] % 3]])
	var actor = _thief_actor
	match thief["state"]:
		"APPROACH":
			# Đi chậm rãi: tốc độ đủ để tới xe đúng lúc mô phỏng báo tới nơi.
			var minutes_left: float = maxf(0.5, thief["reach"] - sim.clock.minute)
			actor.speed = maxf(15.0, actor.position.distance_to(BIKE_SLOTS[thief["id"] % 3]) / (minutes_left * 2.0))
			actor.set_bubble("Ai đuổi theo rồi!" if thief["catch_at"] >= 0 else "Rón rén...", Color(0.92, 0.92, 0.95), UI.MUTED)
		"STEALING":
			actor.set_bubble("Ai đuổi theo rồi!" if thief["catch_at"] >= 0 else "Đang phá khóa!", Color(1.0, 0.85, 0.85), UI.BAD)
		"CAUGHT":
			actor.set_bubble("Bị tóm rồi!", Color(0.88, 1.0, 0.9), UI.GOOD)
			actor.mood = "angry"
		"ESCAPED":
			actor.set_bubble("Mất xe!", Color(1.0, 0.85, 0.85), UI.BAD)
			if not actor.is_moving():
				actor.speed = 260.0
				actor.walk_to([STREET])
	actor.set_clickable(thief["state"] in ["APPROACH", "STEALING"] and thief["catch_at"] < 0)
	actor.pose = "standing"
	actor.visible = current_floor == 1
	actor.advance(delta)


func _on_thief_pressed() -> void:
	var reason: String = sim.chase_thief()
	if reason != "":
		report.emit(reason)
		return
	hint.emit("Chủ quán chạy ra đuổi trộm!")
	# Chủ quán bỏ dở bước đi hiện tại, chạy ra bãi xe rồi quay lại làm tiếp.
	if not _current_task.is_empty() and _cleaning_room == "":
		_tasks.push_front(_current_task)
		_current_task = {}
	_owner.walk_to(_route(_owner.position, _thief_actor.position))
	_owner.set_bubble("Đứng lại!")


## Một câu hát hoặc câu thoại vừa phát trong phòng (xem AmbienceSystem).
func _on_line_spoken(event: Dictionary) -> void:
	var key: String = "h:" + event["host_id"] if event["speaker_index"] < 0 else "g:%d" % event["group_id"]
	var reply_key: String = ""
	if event["reply_text"] != "":
		reply_key = "h:" + event["reply_host_id"] if event["reply_host_id"] != "" else key
	_lines[key] = {"text": event["text"], "reply": event["reply_text"], "reply_key": reply_key, "at": _line_clock, "song": event["kind"] == "SONG"}


func _show_line(actor, key: String) -> void:
	var text: String = ""
	var song: bool = false
	for line_key in _lines:
		var line: Dictionary = _lines[line_key]
		var age: float = _line_clock - line["at"]
		if line_key == key and age < (REPLY_AFTER if line["reply_key"] == key else LINE_SECONDS):
			text = line["text"]
			song = line["song"]
		elif line["reply_key"] == key and age >= REPLY_AFTER and age < REPLY_AFTER + LINE_SECONDS:
			text = line["reply"]
			song = line["song"]
	if text == "":
		actor.set_bubble("")
		return
	if song:
		actor.set_bubble(_wrap_line(text), Color(0.97, 0.92, 1.0), UI.PURPLE)
	else:
		actor.set_bubble(_wrap_line(text), Color(1, 1, 1, 0.96), UI.BORDER)


## Ngắt câu dài thành hai dòng ở khoảng trắng gần giữa.
static func _wrap_line(text: String) -> String:
	if text.length() <= 30:
		return text
	var middle: int = text.length() / 2
	for offset in middle:
		for at in [middle + offset, middle - offset]:
			if at > 0 and at < text.length() and text[at] == " ":
				return text.substr(0, at) + "\n" + text.substr(at + 1)
	return text


func _apply_actor_visibility() -> void:
	_owner.visible = sim.state.phase != "PREP" and _world_floor(_owner.position) == current_floor
	for actor in _group_actors.values():
		actor.visible = _world_floor(actor.position) == current_floor
	for actor in _host_actors.values():
		actor.visible = sim.state.phase != "PREP" and _world_floor(actor.position) == current_floor
	for actor in _leaving:
		actor.visible = _world_floor(actor.position) == current_floor
	for actor in _staff_actors.values():
		actor.visible = sim.state.phase != "PREP" and _world_floor(actor.position) == current_floor
	_guard.visible = current_floor == 1 and sim.state.guard_hired and sim.state.phase != "PREP"
	for bike in _bikes:
		bike.visible = bike.visible and current_floor == 1
	_lbl_tasks.visible = current_floor == 1 and task_count() > 0

func _refresh_rooms() -> void:
	var now: int = sim.clock.minute
	for room in sim.state.rooms:
		var ui: Dictionary = _room_ui[room["id"]]
		var locked: bool = room["state"] == "LOCKED"
		ui["root"].position = _rect_of(room["id"]).position - _floor_offset()
		ui["root"].visible = room["floor"] == current_floor
		ui["dimmer"].visible = locked
		ui["furniture"].visible = not locked
		ui["status"].text = STATE_TEXT[room["state"]].trim_prefix("[").trim_suffix("]")
		ui["status"].add_theme_color_override("font_color", Color("#fff2cb"))
		ui["status"].get_theme_stylebox("normal").bg_color = Color("#8b704d") if locked else STATE_COLOR[room["state"]].darkened(0.25)
		var center: String = ""
		var color: Color = UI.TEXT
		var border: Color = UI.GOLD if selected_room == room["id"] else Color.TRANSPARENT
		if locked:
			var info: Dictionary = sim.room_info(room["id"])
			center = "CHƯA LẮP THIẾT BỊ\n%s\nLắp: %s" % [info["tier_name"], Money.format(info["equip_cost"])]
			if info["floor_locked"]:
				center += "\n(cần mở tầng 2)"
		elif room["state"] == "DIRTY":
			center = "Bấm để dọn"
		elif room["state"] == "CLEANING":
			center = "Đang dọn · còn %d'" % maxi(0, room["task_end"] - now)
		if selected_group != 0:
			var preview: Dictionary = sim.preview_assign(selected_group, room["id"])
			border = UI.GOOD if preview["reason"] == "" else UI.BAD
			if preview["reason"] == "":
				center = "XẾP ĐƯỢC · dự kiến %s" % Money.format(preview["estimate"])
				if preview["over_budget"]:
					center += "\nHơi đắt với nhóm: -%d hài lòng" % sim.data["balance"]["price_over_budget_penalty"]
					border = UI.GOLD
			else:
				center = preview.get("block_text", preview["reason"])
			color = border
		ui["center"].text = center
		ui["center"].visible = center != ""
		# Phòng chưa lắp thiết bị: khung chữ nằm giữa sàn trống, không đè lên phòng bên cạnh.
		ui["center"].position = Vector2(63, 155) if locked and selected_group == 0 else Vector2(90, 300)
		ui["center"].size = Vector2(320, 116) if locked and selected_group == 0 else Vector2(270, 80)
		ui["center"].add_theme_color_override("font_color", color)
		ui["center"].add_theme_stylebox_override("normal", UI.box(Color("#fff5dd", 0.95), Color("#b48b4c"), 2, 14))
		var bar: ProgressBar = ui["bar"]
		bar.visible = false
		if room["state"] == "OCCUPIED":
			_show_bar(bar, UI.PINK, now - room["session_start"], room["session_end"] - room["session_start"])
		elif room["state"] == "CLEANING":
			_show_bar(bar, UI.INFO, now - room["task_start"], room["task_end"] - room["task_start"])
		var request: Dictionary = room["request"]
		ui["request"].visible = not request.is_empty()
		if not request.is_empty():
			var kind: String = request["kind"]
			ui["request"].text = "%s · %d'" % [request["text"] if kind == "ORDER" else REQUEST_LABEL[kind], maxi(0, request["deadline"] - now)]
			ui["request"].add_theme_stylebox_override("normal", UI.box(UI.PANEL, REQUEST_COLOR[kind], 2, 5))
		ui["hit"].tooltip_text = "%s · %s · %s/giờ" % [room["name"], STATE_TEXT[room["state"]], Money.format(room["price_per_hour"])]
		ui["hit"].add_theme_stylebox_override("normal", UI.box(Color.TRANSPARENT, border, 3, 0))


func _show_bar(bar: ProgressBar, color: Color, value: int, total: int) -> void:
	bar.visible = true
	bar.get_theme_stylebox("fill").bg_color = color
	bar.max_value = maxi(1, total)
	bar.value = value


# ---------------------------------------------------------------- Vẽ nền

func _draw() -> void:
	if sim == null:
		return
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color("#ead2ab"))
	if current_floor == 1:
		var cuts: Array = [[0, 440, 64, 400], [440, 830, 464, 400], [830, 1095, 864, 220], [1095, 1337, 1084, 180]]
		for cut in cuts:
			draw_texture_rect_region(MAP_STANDARD, Rect2(0, cut[2], 1024, cut[3]), Rect2(0, cut[0], MAP_STANDARD.get_width(), cut[1] - cut[0]))
	else:
		# Approved VIP map has a taller first row for the stair landing.
		var source_rows: Array = [0, 490, 900, MAP_VIP.get_height()]
		for row in 3:
			draw_texture_rect_region(MAP_VIP, Rect2(0, MAP_Y + row * ROOM_H, 1024, ROOM_H), Rect2(0, source_rows[row], MAP_VIP.get_width(), source_rows[row + 1] - source_rows[row]))
	if current_floor == 1 and _anim_time < _fridge_active_until:
		draw_style_box(UI.box(Color(1.0, 0.92, 0.5, 0.2), UI.GOLD, 2, 0), Rect2(45, 885, 94, 180))
	for room in sim.state.rooms:
		if room["floor"] != current_floor or room["state"] != "OCCUPIED":
			continue
		for point in _seating(room["id"])["stools"]:
			var seat: Vector2 = point - _floor_offset() - Vector2(0, 10)
			draw_style_box(UI.box(Color("#8b7844"), Color("#50351f"), 2, 6), Rect2(seat - Vector2(23, 8), Vector2(46, 20)))


func save_view() -> Dictionary:
	var groups: Dictionary = {}
	for group_id in _group_actors:
		groups[str(group_id)] = _group_actors[group_id].save_view()
	var hosts: Dictionary = {}
	for host_id in _host_actors:
		hosts[host_id] = _host_actors[host_id].save_view()
	var staff: Dictionary = {}
	for staff_id in _staff_actors:
		staff[staff_id] = _staff_actors[staff_id].save_view()
	var tasks: Array = []
	for task in _tasks:
		tasks.append(_save_task(task))
	return {"owner": _owner.save_view(), "staff": staff, "groups": groups, "hosts": hosts, "tasks": tasks, "current": _save_task(_current_task), "cleaning": _cleaning_room, "time": _anim_time, "floor": current_floor}

func _save_task(task: Dictionary) -> Dictionary:
	var copy: Dictionary = task.duplicate(true)
	if copy.get("position") is Vector2:
		copy["position"] = [copy["position"].x, copy["position"].y]
	return copy

func _restore_task(task: Dictionary) -> Dictionary:
	var copy: Dictionary = task.duplicate(true)
	if copy.get("position") is Array:
		copy["position"] = Vector2(float(copy["position"][0]), float(copy["position"][1]))
	return copy

func restore_view(saved: Dictionary) -> void:
	if saved.is_empty():
		return
	advance_actors(0.0)
	_anim_time = float(saved.get("time", 0.0))
	_current_task = _restore_task(saved.get("current", {}))
	_tasks = []
	for task in saved.get("tasks", []):
		_tasks.append(_restore_task(task))
	_cleaning_room = saved.get("cleaning", "")
	if saved.has("owner"):
		_owner.restore_view(saved["owner"])
	for group_id in saved.get("groups", {}):
		if _group_actors.has(int(group_id)):
			_group_actors[int(group_id)].restore_view(saved["groups"][group_id])
	for host_id in saved.get("hosts", {}):
		if _host_actors.has(host_id):
			_host_actors[host_id].restore_view(saved["hosts"][host_id])
	for staff_id in saved.get("staff", {}):
		if _staff_actors.has(staff_id):
			_staff_actors[staff_id].restore_view(saved["staff"][staff_id])
	set_floor(int(saved.get("floor", 1)))
