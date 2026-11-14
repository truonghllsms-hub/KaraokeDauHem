extends Node2D
## Một nhân vật hoặc một nhóm nhân vật trên mặt bằng quán: đi theo các điểm mốc,
## nhún nhảy khi đi, có bóng thoại và vùng bấm.

const UI = preload("res://scripts/ui/ui_kit.gd")
const CharacterArt = preload("res://scripts/ui/character_art.gd")
const Motion = preload("res://scripts/ui/character_motion.gd")
const OFFSETS: Array = [
	[Vector2(0, 0)],
	[Vector2(-29, 0), Vector2(29, 0)],
	[Vector2(-54, -4), Vector2(54, -4), Vector2(0, 4)],
]
const WALK_OFFSETS: Array = [
	[Vector2.ZERO],
	[Vector2(-18, -6), Vector2(18, 6)],
	[Vector2(-20, -12), Vector2(20, -12), Vector2(0, 10)],
]

signal pressed

var speed: float = 190.0
var place_key: String = ""
var bubble_speaker: int = 0
var _bubble_background: Color = Color.WHITE
var _bubble_border: Color = UI.BORDER
var _bubble_text_color: Color = UI.TEXT
var carrying: bool = false
var singing: bool = false
var pose: String = "standing"
var seated_faces_left: bool = false
var seated_offsets: Array = []
var portals: Array = []
var mood: String = "neutral"
var _facing: String = "front"
var _look_left: bool = false
var _walk_distance: float = 0.0

## Tỉ lệ kiên nhẫn còn lại (0..1); âm thì không vẽ thanh.
var patience_ratio: float = -1.0

var _highlight: bool = false
var _path: Array = []
var _sprites: Array = []
var _people: Array = []
var _appearance_keys: Array = []
var _time: float = 0.0
var _bubble: Label
var _badge: Label
var _button: Button


func setup(texture_names: Array, badge_text: String = "") -> void:
	y_sort_enabled = true
	var count: int = clampi(texture_names.size(), 1, 5)
	var offsets: Array = _walking_offsets(count)
	for i in count:
		var sprite: Sprite2D = Sprite2D.new()
		_people.append(str(texture_names[i]))
		_appearance_keys.append("")
		sprite.position = offsets[i]
		add_child(sprite)
		_sprites.append(sprite)
	_update_appearance()

	_button = Button.new()
	_button.flat = true
	_button.focus_mode = Control.FOCUS_NONE
	_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for style_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		_button.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	var hit_width: float = 90.0 if count == 1 else 190.0
	_button.position = Vector2(-hit_width * 0.5, -126)
	_button.size = Vector2(hit_width, 132)
	_button.pressed.connect(func() -> void: pressed.emit())
	add_child(_button)

	_badge = UI.label(badge_text, 18, UI.TEXT, true)
	_badge.add_theme_stylebox_override("normal", UI.box(UI.PANEL, UI.GOLD, 1, 3))
	_badge.position = Vector2(24, -20)
	_badge.visible = badge_text != ""
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_badge)

	_bubble = UI.label("", 20, Color(0.2, 0.14, 0.22), true)
	_bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.visible = false
	add_child(_bubble)
	_bubble.z_index = 5
	_badge.z_index = 5


func _walking_offsets(count: int) -> Array:
	if count <= 3:
		return WALK_OFFSETS[count - 1]
	var points: Array = []
	var rows: int = ceili(float(count) / 3.0)
	for i in count:
		points.append(Vector2((i % 3 - 1) * 18, floori(float(i) / 3.0) * 22 - (rows - 1) * 11))
	return points


func set_clickable(clickable: bool) -> void:
	_button.visible = clickable


func set_tooltip(text: String) -> void:
	_button.tooltip_text = text


## Bóng thoại phía trên đầu. Chuỗi rỗng để ẩn.
func set_bubble(text: String, background: Color = Color(1, 1, 1, 0.95), border: Color = UI.PINK, text_color: Color = UI.TEXT) -> void:
	if text == "":
		_bubble.visible = false
		return
	if _bubble.text != text or _bubble_background != background or _bubble_border != border or _bubble_text_color != text_color:
		_bubble.text = text
		_bubble_background = background
		_bubble_border = border
		_bubble_text_color = text_color
		_bubble.add_theme_color_override("font_color", text_color)
		_bubble.add_theme_stylebox_override("normal", UI.box(background, border, 2, 6))
		_bubble.reset_size()
	_bubble.visible = true
	_place_bubble()

func _place_bubble() -> void:
	if _bubble == null or not _bubble.visible or _sprites.is_empty():
		return
	var index: int = clampi(bubble_speaker, 0, _sprites.size() - 1)
	var at: Vector2 = _sprites[index].position
	var art_height: float = CharacterArt.height(_people[index], "standing" if is_moving() else pose)
	_bubble.position = at + Vector2(-_bubble.size.x * 0.5, -art_height - 10 - _bubble.size.y)
	var canvas_width: float = get_viewport_rect().size.x
	var x: float = _bubble.global_position.x
	_bubble.position.x += clampf(x, 8, maxf(8, canvas_width-8-_bubble.size.x))-x


func set_highlight(on: bool) -> void:
	_highlight = on
	scale = Vector2.ONE


## Viền sáng dưới chân khi được chọn và thanh kiên nhẫn trên đầu (xanh -> vàng -> đỏ).
func _draw() -> void:
	if _bubble != null and _bubble.visible:
		var tail: Vector2 = _bubble.position + Vector2(_bubble.size.x * 0.5, _bubble.size.y)
		if not _sprites.is_empty(): tail.x = clampf(_sprites[clampi(bubble_speaker,0,_sprites.size()-1)].position.x, _bubble.position.x+8, _bubble.position.x+_bubble.size.x-8)
		draw_colored_polygon(PackedVector2Array([tail + Vector2(-6, 0), tail + Vector2(6, 0), tail + Vector2(0, 8)]), _bubble_background)
	# Bóng tiếp đất giữ bước chân và vị trí sofa rõ khi thân người chuyển động.
	for sprite in _sprites:
		draw_set_transform(sprite.position + Vector2(0, 1), 0, Vector2(1, 0.22))
		draw_circle(Vector2.ZERO, 18, Color(0.16, 0.10, 0.06, 0.16))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if _highlight:
		var pulse: float = 0.75 + 0.25 * sin(_time * 6.0)
		draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.0, 0.38))
		draw_circle(Vector2.ZERO, 46.0, Color(UI.GOLD, 0.35 * pulse))
		draw_arc(Vector2.ZERO, 46.0, 0.0, TAU, 40, Color(UI.GOLD, pulse), 5.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if patience_ratio >= 0.0:
		var width: float = 64.0
		var origin: Vector2 = Vector2(-width * 0.5, -124)
		var color: Color = UI.GOOD
		if patience_ratio <= 0.25:
			color = UI.BAD
		elif patience_ratio <= 0.5:
			color = UI.GOLD
		draw_rect(Rect2(origin - Vector2(2, 2), Vector2(width + 4, 11)), UI.PANEL_DARK)
		draw_rect(Rect2(origin, Vector2(width * clampf(patience_ratio, 0.0, 1.0), 7)), color)
	if singing and mood != "angry":
		for i in 2:
			var phase: float = fmod(_time * 0.7 + i * 0.5, 1.0)
			var at: Vector2 = Vector2(-24 + i * 48, -117 - phase * 26)
			var color: Color = Color(UI.GOLD, 1.0 - phase)
			draw_circle(at, 3.0, color)
			draw_line(at + Vector2(2, 0), at + Vector2(2, -13), color, 2.0, true)
			draw_line(at + Vector2(2, -13), at + Vector2(9, -10), color, 2.0, true)
	elif mood == "angry" or mood == "impatient":
		var at: Vector2 = Vector2(30, -118 + sin(_time * 5) * 2)
		var color: Color = UI.BAD if mood == "angry" else UI.GOLD
		for i in 3:
			var angle: float = -1.4 + i * 0.7
			var ray: Vector2 = Vector2.from_angle(angle)
			draw_line(at + ray * 5, at + ray * 12, color, 2.5, true)
	elif mood == "tired":
		var at: Vector2 = Vector2(24, -115 + sin(_time * 2) * 2)
		draw_colored_polygon(PackedVector2Array([at + Vector2(0, -6), at + Vector2(-4, 2), at + Vector2(0, 5), at + Vector2(4, 2)]), Color("#7cbbc7"))


func walk_to(points: Array) -> void:
	_path = points.duplicate()


func is_moving() -> bool:
	return not _path.is_empty()


func _update_appearance() -> void:
	var active_pose: String = "carrying" if carrying else ("standing" if is_moving() else pose)
	for i in _sprites.size():
		var person: String = _people[i]
		var texture: Texture2D
		if carrying:
			texture = CharacterArt.texture(person, active_pose, _facing)
		elif is_moving():
			texture = Motion.walk_texture(person, int(_walk_distance / 26.0) + i * 2, _facing)
		else:
			var expression: String = ""
			var phase: float = _time + i * 0.71
			if person.begins_with("lancan_") and active_pose == "seated":
				if mood == "tired":
					expression = "tired"
				elif singing and fmod(phase, 1.4) < 0.65:
					expression = "cheer"
				elif not singing and fmod(phase, 4.6) < 0.16:
					expression = "blink"
			elif active_pose == "standing":
				if mood == "impatient" or mood == "angry":
					expression = "impatient"
				elif fmod(phase, 4.1) < 0.15:
					expression = "blink"
			elif active_pose == "seated" and mood == "angry":
				expression = "angry_seated"
			texture = Motion.expression_texture(person, expression)
		if texture == null:
			texture = CharacterArt.texture(person, active_pose, _facing)
		var key: String = str(texture.get_instance_id())
		if _appearance_keys[i] == key:
			continue
		_appearance_keys[i] = key
		var sprite: Sprite2D = _sprites[i]
		sprite.texture = texture
		var art_height: float = sprite.texture.get_height()
		var ratio: float = CharacterArt.height(person, active_pose) / art_height
		sprite.scale = Vector2(ratio, ratio)
		sprite.offset = Vector2(0, -art_height * 0.5)
		sprite.set_meta("base_scale", ratio)


func advance(delta: float) -> void:
	_time += delta
	queue_redraw()
	var travelled: float = 0.0
	var remaining: float = speed * delta
	while remaining > 0.0 and not _path.is_empty():
		var target: Vector2 = _path[0]
		var used_portal: bool = false
		for portal in portals:
			if position.distance_to(portal[0]) < 1.0 and target.distance_to(portal[1]) < 1.0:
				position = target
				_path.pop_front()
				used_portal = true
				break
		if used_portal:
			continue
		var distance: float = position.distance_to(target)
		travelled += minf(distance, remaining)
		if distance > 0.01:
			var direction: Vector2 = (target - position) / distance
			if absf(direction.x) > 0.2:
				_look_left = direction.x < 0.0
			if absf(direction.y) >= absf(direction.x):
				_facing = "back" if direction.y < 0.0 else "front"
			else:
				_facing = "left" if direction.x < 0.0 else "right"
		if distance <= remaining:
			position = target
			remaining -= distance
			_path.pop_front()
		else:
			var direction: Vector2 = (target - position) / distance
			position += direction * remaining
			remaining = 0.0

	_walk_distance += travelled
	_update_appearance()
	var offsets: Array = _walking_offsets(_sprites.size())
	if pose == "seated" and not is_moving():
		if seated_offsets.size() == _sprites.size():
			offsets = seated_offsets
		elif _sprites.size() <= 3:
			offsets = OFFSETS[_sprites.size() - 1]
	if _badge != null:
		_badge.visible = _badge.text != "" and (pose != "seated" or is_moving())
	var compact: bool = pose != "seated" or is_moving()
	var spread: float = 1.0
	if compact and _sprites.size() > 1:
		var widest: float = 0.0
		for sprite in _sprites:
			widest = maxf(widest, sprite.texture.get_width() * float(sprite.get_meta("base_scale")))
		spread = clampf((99.0 - widest) / 40.0, 0.0, 1.0)
	for i in _sprites.size():
		var base: Vector2 = offsets[i]
		base.x *= spread
		var bob: float = 0.0
		var tilt: float = 0.0
		if is_moving():
			bob = -absf(sin(_walk_distance / 16.5 + i)) * 0.8
			tilt = sin(_walk_distance / 16.5 + i) * 0.015
		elif singing:
			bob = -absf(sin(_time * 5.0 + i * 0.9)) * 1.2
			tilt = sin(_time * 3.0 + i) * 0.025
		elif mood == "impatient" or mood == "angry":
			tilt = sin(_time * 7.0 + i) * 0.018
		elif pose == "cleaning":
			tilt = sin(_time * 7.0) * 0.07
		var ratio: float = _sprites[i].get_meta("base_scale")
		_sprites[i].scale = Vector2(ratio, ratio)
		if is_moving():
			_sprites[i].flip_h = _look_left and _people[i] != "owner"
		else:
			_sprites[i].flip_h = pose == "seated" and seated_faces_left
		if pose == "seated" and not is_moving():
			var contact: Vector2 = CharacterArt.seat_contact(_people[i], _sprites[i].texture)
			if seated_faces_left: contact.x = -contact.x
			_sprites[i].position = base - contact.rotated(tilt)
		else:
			_sprites[i].position = base + Vector2(0, bob)
		_sprites[i].rotation = tilt

	_place_bubble()


func save_view() -> Dictionary:
	var points: Array = []
	for point in _path:
		points.append([point.x, point.y])
	return {"position": [position.x, position.y], "path": points, "facing": _facing, "left": _look_left, "pose": pose, "carrying": carrying, "place": place_key}

func restore_view(saved: Dictionary) -> void:
	var at: Array = saved.get("position", [position.x, position.y])
	position = Vector2(float(at[0]), float(at[1]))
	_path = []
	for point in saved.get("path", []):
		_path.append(Vector2(float(point[0]), float(point[1])))
	_facing = saved.get("facing", "front")
	_look_left = saved.get("left", false)
	pose = saved.get("pose", "standing")
	carrying = saved.get("carrying", false)
	place_key = saved.get("place", "")
	_update_appearance()
