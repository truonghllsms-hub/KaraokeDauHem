extends RefCounted
## Bảng màu và các hàm dựng widget dùng chung cho giao diện.

const BG: Color = Color(0.078, 0.063, 0.122)
const PANEL: Color = Color(0.13, 0.10, 0.20)
const PANEL_DARK: Color = Color(0.10, 0.08, 0.16)
const BORDER: Color = Color(0.36, 0.27, 0.55)
const PINK: Color = Color(1.0, 0.36, 0.72)
const PURPLE: Color = Color(0.72, 0.50, 1.0)
const GOLD: Color = Color(1.0, 0.80, 0.36)
const TEXT: Color = Color(0.93, 0.90, 0.98)
const MUTED: Color = Color(0.66, 0.62, 0.76)
const GOOD: Color = Color(0.49, 0.89, 0.60)
const BAD: Color = Color(1.0, 0.50, 0.48)
const INFO: Color = Color(0.55, 0.78, 1.0)

const BOLD_FONT = preload("res://assets/fonts/DejaVuSans-Bold.ttf")


static func box(bg: Color, border: Color, border_width: int = 2, margin: int = 12) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(margin)
	return style


static func panel(bg: Color = PANEL, border: Color = BORDER) -> PanelContainer:
	var node: PanelContainer = PanelContainer.new()
	node.add_theme_stylebox_override("panel", box(bg, border))
	return node


static func label(text: String, size: int = 16, color: Color = TEXT, bold: bool = false) -> Label:
	var node: Label = Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	if bold:
		node.add_theme_font_override("font", BOLD_FONT)
	return node


## Nút không nhận focus bàn phím, để Space/1/2/3 luôn là phím tắt của game.
static func button(text: String, size: int = 16, accent: Color = PURPLE) -> Button:
	var node: Button = Button.new()
	node.text = text
	node.focus_mode = Control.FOCUS_NONE
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", TEXT)
	node.add_theme_color_override("font_hover_color", Color.WHITE)
	node.add_theme_color_override("font_pressed_color", GOLD)
	node.add_theme_color_override("font_disabled_color", Color(MUTED, 0.6))
	node.add_theme_stylebox_override("normal", box(Color(accent, 0.16), Color(accent, 0.7), 1, 8))
	node.add_theme_stylebox_override("hover", box(Color(accent, 0.30), accent, 1, 8))
	node.add_theme_stylebox_override("pressed", box(Color(accent, 0.42), GOLD, 2, 8))
	node.add_theme_stylebox_override("disabled", box(Color(0.5, 0.5, 0.5, 0.08), Color(0.5, 0.5, 0.5, 0.3), 1, 8))
	return node


static func progress(color: Color) -> ProgressBar:
	var node: ProgressBar = ProgressBar.new()
	node.show_percentage = false
	node.custom_minimum_size = Vector2(0, 12)
	var back: StyleBoxFlat = box(Color(0, 0, 0, 0.4), Color(0, 0, 0, 0), 0, 0)
	var fill: StyleBoxFlat = box(color, Color(0, 0, 0, 0), 0, 0)
	back.set_corner_radius_all(4)
	fill.set_corner_radius_all(4)
	node.add_theme_stylebox_override("background", back)
	node.add_theme_stylebox_override("fill", fill)
	return node
