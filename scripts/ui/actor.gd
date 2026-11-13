extends Node2D
## Một nhân vật hoặc một nhóm nhân vật trên mặt bằng quán: đi theo các điểm mốc,
## nhún nhảy khi đi, có bóng thoại và vùng bấm.

const UI = preload("res://scripts/ui/ui_kit.gd")
const SPRITE_SCALE: float = 0.44
const OFFSETS: Array = [
	[Vector2(0, 0)],
	[Vector2(-17, 0), Vector2(17, 0)],
	[Vector2(-27, -8), Vector2(27, -8), Vector2(0, 4)],
]

signal pressed

var speed: float = 190.0
var place_key: String = ""
var singing: bool = false

## Tỉ lệ kiên nhẫn còn lại (0..1); âm thì không vẽ thanh.
var patience_ratio: float = -1.0

var _highlight: bool = false
var _path: Array = []
var _sprites: Array = []
var _time: float = 0.0
var _bubble: Label
var _badge: Label
var _button: Button


func setup(texture_names: Array, badge_text: String = "") -> void:
	var count: int = clampi(texture_names.size(), 1, 3)
	var offsets: Array = OFFSETS[count - 1]
	for i in count:
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = load("res://assets/sprites/%s.svg" % texture_names[i])
		sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
		sprite.offset = Vector2(0, -sprite.texture.get_height() * 0.5 + 8)
		sprite.position = offsets[i]
		add_child(sprite)
		_sprites.append(sprite)

	_button = Button.new()
	_button.flat = true
	_button.focus_mode = Control.FOCUS_NONE
	_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for style_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		_button.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	_button.position = Vector2(-52, -94)
	_button.size = Vector2(104, 100)
	_button.pressed.connect(func() -> void: pressed.emit())
	add_child(_button)

	_badge = UI.label(badge_text, 12, UI.TEXT, true)
	_badge.add_theme_stylebox_override("normal", UI.box(Color(0.1, 0.08, 0.16, 0.9), UI.GOLD, 1, 3))
	_badge.position = Vector2(24, -20)
	_badge.visible = badge_text != ""
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_badge)

	_bubble = UI.label("", 12, Color(0.2, 0.14, 0.22), true)
	_bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.visible = false
	add_child(_bubble)


func set_clickable(clickable: bool) -> void:
	_button.visible = clickable


func set_tooltip(text: String) -> void:
	_button.tooltip_text = text


## Bóng thoại phía trên đầu. Chuỗi rỗng để ẩn.
func set_bubble(text: String, background: Color = Color(1, 1, 1, 0.95), border: Color = UI.PINK) -> void:
	if text == "":
		_bubble.visible = false
		return
	if _bubble.text != text or not _bubble.visible:
		_bubble.text = text
		_bubble.add_theme_stylebox_override("normal", UI.box(background, border, 2, 4))
		_bubble.reset_size()
	_bubble.visible = true
	_bubble.position = Vector2(-_bubble.size.x * 0.5, -98 - _bubble.size.y)


func set_highlight(on: bool) -> void:
	_highlight = on
	var target: float = 1.1 if on else 1.0
	scale = Vector2(target, target)


## Viền sáng dưới chân khi được chọn và thanh kiên nhẫn trên đầu (xanh -> vàng -> đỏ).
func _draw() -> void:
	if _highlight:
		var pulse: float = 0.75 + 0.25 * sin(_time * 6.0)
		draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.0, 0.38))
		draw_circle(Vector2.ZERO, 46.0, Color(UI.GOLD, 0.35 * pulse))
		draw_arc(Vector2.ZERO, 46.0, 0.0, TAU, 40, Color(UI.GOLD, pulse), 5.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if patience_ratio >= 0.0:
		var width: float = 64.0
		var origin: Vector2 = Vector2(-width * 0.5, -92)
		var color: Color = UI.GOOD
		if patience_ratio <= 0.25:
			color = UI.BAD
		elif patience_ratio <= 0.5:
			color = UI.GOLD
		draw_rect(Rect2(origin - Vector2(2, 2), Vector2(width + 4, 11)), Color(0.1, 0.08, 0.16, 0.95))
		draw_rect(Rect2(origin, Vector2(width * clampf(patience_ratio, 0.0, 1.0), 7)), color)


func walk_to(points: Array) -> void:
	_path = points.duplicate()


func is_moving() -> bool:
	return not _path.is_empty()


func advance(delta: float) -> void:
	_time += delta
	queue_redraw()
	var remaining: float = speed * delta
	while remaining > 0.0 and not _path.is_empty():
		var target: Vector2 = _path[0]
		var distance: float = position.distance_to(target)
		if distance <= remaining:
			position = target
			remaining -= distance
			_path.pop_front()
		else:
			var direction: Vector2 = (target - position) / distance
			position += direction * remaining
			if absf(direction.x) > 0.2:
				for sprite in _sprites:
					sprite.flip_h = direction.x < 0
			remaining = 0.0

	for i in _sprites.size():
		var base: Vector2 = OFFSETS[_sprites.size() - 1][i]
		var bob: float = 0.0
		var tilt: float = 0.0
		if is_moving():
			bob = -absf(sin(_time * 11.0 + i * 1.3)) * 4.0
		elif singing:
			bob = -absf(sin(_time * 5.0 + i * 0.9)) * 2.5
			tilt = sin(_time * 4.0 + i) * 0.07
		_sprites[i].position = base + Vector2(0, bob)
		_sprites[i].rotation = tilt
