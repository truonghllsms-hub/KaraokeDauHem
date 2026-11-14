extends RefCounted
## Bảng màu và các hàm dựng widget dùng chung cho giao diện.

const BG: Color = Color("#d6d4b9")
const PANEL: Color = Color("#fff0ce")
const PANEL_DARK: Color = Color("#f5e2b9")
const BORDER: Color = Color("#85643f")
const PINK: Color = Color("#a26d60")
const PURPLE: Color = Color("#687a40")
const GOLD: Color = Color("#a77b27")
const TEXT: Color = Color("#513c2a")
const MUTED: Color = Color("#8b8067")
const GOOD: Color = Color("#58743e")
const BAD: Color = Color("#b4553c")
const INFO: Color = Color("#427d7a")

const BOLD_FONT = preload("res://assets/fonts/Baloo2-Bold.tres")


static func box(bg: Color, border: Color, border_width: int = 2, margin: int = 12) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0.24, 0.17, 0.08, 0.12)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 3)
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
	node.add_theme_font_override("font", BOLD_FONT)
	node.add_theme_color_override("font_color", TEXT)
	node.add_theme_color_override("font_hover_color", TEXT)
	node.add_theme_color_override("font_pressed_color", GOLD)
	node.add_theme_color_override("font_disabled_color", Color(MUTED, 0.6))
	node.add_theme_stylebox_override("normal", box(PANEL, accent, 2, 12))
	node.add_theme_stylebox_override("hover", box(PANEL.lightened(0.18), accent, 2, 12))
	node.add_theme_stylebox_override("pressed", box(Color("#d3dda5"), accent, 2, 12))
	node.add_theme_stylebox_override("disabled", box(Color("#e3dcc7"), MUTED, 1, 12))
	return node


static func progress(color: Color) -> ProgressBar:
	var node: ProgressBar = ProgressBar.new()
	node.show_percentage = false
	node.custom_minimum_size = Vector2(0, 12)
	var back: StyleBoxFlat = box(Color("#dfd2ad"), Color(0, 0, 0, 0), 0, 0)
	var fill: StyleBoxFlat = box(color, Color(0, 0, 0, 0), 0, 0)
	back.set_corner_radius_all(4)
	fill.set_corner_radius_all(4)
	node.add_theme_stylebox_override("background", back)
	node.add_theme_stylebox_override("fill", fill)
	return node


static func section(title: String, subtitle: String = "") -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.add_child(label(title, 26, TEXT, true))
	if subtitle != "":
		var note: Label = label(subtitle, 19, MUTED)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(note)
	return column

static func metric(title: String, value: String, accent: Color = GOOD) -> PanelContainer:
	var card: PanelContainer = panel(Color("#fff8e8"), Color("#d6be94"))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.add_child(label(title, 19, MUTED))
	column.add_child(label(value, 25, accent, true))
	card.add_child(column)
	return card
