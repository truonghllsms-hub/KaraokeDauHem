extends RefCounted
## The approved illustration is the source atlas. Crop regions at runtime so the
## live UI uses the approved art rather than an independently redrawn substitute.
const ATLAS = preload("res://assets/reference/approved_ui.png")

static func texture(region: Rect2) -> AtlasTexture:
	var result: AtlasTexture = AtlasTexture.new()
	result.atlas = ATLAS
	result.region = region
	return result

static func image(region: Rect2, at: Rect2) -> TextureRect:
	var result: TextureRect = TextureRect.new()
	result.texture = texture(region)
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = TextureRect.STRETCH_SCALE
	result.position = at.position
	result.size = at.size
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

static func hit(at: Rect2, tooltip: String = "") -> Button:
	var result: Button = Button.new()
	result.position = at.position
	result.size = at.size
	result.focus_mode = Control.FOCUS_NONE
	result.tooltip_text = tooltip
	result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for key in ["normal", "hover", "pressed", "focus", "disabled"]:
		result.add_theme_stylebox_override(key, StyleBoxEmpty.new())
	return result
