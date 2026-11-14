extends RefCounted
const SHEET = preload("res://assets/topdown/bikes.webp")
const REGIONS: Array = [Rect2(71, 19, 435, 973), Rect2(552, 20, 433, 971), Rect2(1032, 20, 434, 971)]
static func texture(index: int) -> Texture2D:
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = SHEET
	atlas.region = REGIONS[posmod(index, 3)]
	atlas.filter_clip = true
	return atlas
