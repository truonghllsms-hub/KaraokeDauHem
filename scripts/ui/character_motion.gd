extends RefCounted
## Khung bước đi và nét mặt dùng cùng trang phục đã duyệt.
## Mỗi hàng dùng chung vùng cắt để đầu/chân không đổi kích thước giữa khung.
const Art = preload("res://scripts/ui/character_art.gd")

const SHEETS: Dictionary = {
	"new_men_walk": preload("res://assets/characters/motion/new_men_walk.webp"),
	"new_hosts_emotions": preload("res://assets/characters/motion/new_hosts_emotions.webp"),
	"middle_men_emotions": preload("res://assets/characters/motion/middle_men_emotions.webp"),
	"young_men_emotions": preload("res://assets/characters/motion/young_men_emotions.webp"),
	"owner_walk": preload("res://assets/characters/motion/owner_walk.webp"),
	"hosts_walk": preload("res://assets/characters/motion/hosts_walk.webp"),
	"guests_a_walk": preload("res://assets/characters/motion/guests_a_walk.webp"),
	"guests_b_walk": preload("res://assets/characters/motion/guests_b_walk.webp"),
	"guests_a_emotions": preload("res://assets/characters/motion/guests_a_emotions.webp"),
	"guests_b_emotions": preload("res://assets/characters/motion/guests_b_emotions.webp"),
	"hosts_a_emotions": preload("res://assets/characters/motion/hosts_a_emotions.webp"),
	"hosts_b_emotions": preload("res://assets/characters/motion/hosts_b_emotions.webp"),
}

const REGIONS: Dictionary = {
	"owner_walk": [Rect2(112, 23, 125, 267), Rect2(407, 23, 135, 263), Rect2(710, 23, 132, 264), Rect2(1018, 24, 131, 263), Rect2(103, 336, 128, 266), Rect2(409, 336, 131, 260), Rect2(715, 337, 126, 265), Rect2(1021, 339, 133, 257), Rect2(94, 650, 142, 263), Rect2(417, 651, 114, 262), Rect2(708, 650, 142, 262), Rect2(1028, 651, 112, 261), Rect2(109, 964, 144, 263), Rect2(417, 965, 112, 261), Rect2(712, 964, 147, 262), Rect2(1026, 965, 117, 261)],
	"hosts_walk": [Rect2(112, 8, 105, 180), Rect2(360, 8, 92, 182), Rect2(586, 8, 101, 180), Rect2(827, 8, 92, 182), Rect2(120, 199, 96, 181), Rect2(356, 198, 98, 184), Rect2(580, 199, 106, 181), Rect2(826, 198, 96, 184), Rect2(112, 389, 110, 183), Rect2(352, 387, 103, 187), Rect2(580, 388, 111, 185), Rect2(818, 388, 105, 186), Rect2(108, 584, 110, 181), Rect2(356, 583, 96, 183), Rect2(587, 584, 101, 181), Rect2(825, 582, 97, 184), Rect2(108, 775, 111, 182), Rect2(355, 773, 99, 185), Rect2(583, 774, 107, 183), Rect2(825, 773, 99, 185), Rect2(108, 967, 110, 181), Rect2(361, 965, 93, 184), Rect2(575, 967, 114, 181), Rect2(832, 964, 93, 185), Rect2(111, 1158, 107, 183), Rect2(360, 1158, 93, 184), Rect2(581, 1158, 107, 183), Rect2(830, 1157, 91, 185), Rect2(109, 1351, 109, 181), Rect2(357, 1348, 97, 185), Rect2(586, 1351, 104, 181), Rect2(831, 1348, 96, 185)],
	"guests_a_walk": [Rect2(87, 12, 91, 160), Rect2(347, 11, 76, 159), Rect2(602, 12, 79, 159), Rect2(862, 12, 74, 158), Rect2(83, 189, 90, 161), Rect2(341, 189, 90, 161), Rect2(597, 189, 88, 162), Rect2(854, 189, 90, 161), Rect2(89, 358, 87, 176), Rect2(345, 358, 80, 176), Rect2(600, 358, 86, 176), Rect2(859, 359, 82, 175), Rect2(79, 542, 98, 172), Rect2(337, 542, 95, 172), Rect2(593, 542, 96, 172), Rect2(850, 542, 97, 171), Rect2(89, 729, 87, 157), Rect2(346, 728, 77, 158), Rect2(602, 729, 84, 157), Rect2(859, 729, 79, 157), Rect2(83, 902, 94, 159), Rect2(339, 902, 85, 158), Rect2(596, 902, 88, 159), Rect2(851, 902, 87, 158), Rect2(86, 1071, 92, 150), Rect2(347, 1071, 78, 149), Rect2(600, 1071, 84, 150), Rect2(860, 1071, 78, 149), Rect2(82, 1232, 93, 149), Rect2(339, 1229, 91, 152), Rect2(595, 1230, 91, 151), Rect2(854, 1231, 90, 149), Rect2(87, 1390, 86, 144), Rect2(346, 1390, 79, 142), Rect2(602, 1391, 82, 142), Rect2(858, 1390, 80, 142)],
	"guests_b_walk": [Rect2(83, 12, 106, 160), Rect2(348, 12, 88, 156), Rect2(600, 12, 89, 155), Rect2(853, 12, 98, 155), Rect2(82, 191, 102, 157), Rect2(341, 188, 90, 159), Rect2(596, 191, 93, 154), Rect2(854, 189, 90, 157), Rect2(84, 366, 98, 155), Rect2(340, 366, 88, 153), Rect2(597, 367, 93, 152), Rect2(853, 366, 90, 154), Rect2(85, 534, 105, 162), Rect2(349, 533, 81, 162), Rect2(602, 534, 90, 159), Rect2(856, 534, 90, 161), Rect2(80, 712, 100, 161), Rect2(339, 712, 91, 160), Rect2(592, 715, 103, 157), Rect2(852, 713, 92, 158), Rect2(84, 886, 102, 162), Rect2(342, 885, 89, 162), Rect2(597, 888, 95, 159), Rect2(855, 885, 91, 161), Rect2(82, 1064, 103, 155), Rect2(342, 1063, 88, 154), Rect2(596, 1063, 98, 153), Rect2(852, 1063, 91, 154), Rect2(87, 1231, 100, 153), Rect2(348, 1231, 83, 150), Rect2(602, 1232, 91, 148), Rect2(858, 1232, 92, 149), Rect2(83, 1396, 93, 138), Rect2(341, 1397, 87, 136), Rect2(595, 1398, 97, 135), Rect2(855, 1398, 86, 135)],
	"guests_a_emotions": [Rect2(182, 20, 91, 177), Rect2(463, 19, 98, 177), Rect2(748, 26, 103, 173), Rect2(175, 212, 105, 179), Rect2(449, 210, 118, 180), Rect2(734, 216, 116, 175), Rect2(182, 388, 92, 189), Rect2(463, 386, 100, 190), Rect2(749, 391, 105, 188), Rect2(176, 581, 102, 188), Rect2(457, 580, 108, 188), Rect2(734, 588, 122, 183), Rect2(184, 774, 92, 165), Rect2(463, 773, 98, 165), Rect2(750, 781, 103, 160), Rect2(183, 944, 94, 172), Rect2(455, 941, 106, 175), Rect2(739, 948, 115, 173), Rect2(183, 1123, 97, 153), Rect2(457, 1120, 104, 155), Rect2(744, 1128, 112, 149), Rect2(177, 1280, 97, 132), Rect2(454, 1279, 105, 135), Rect2(735, 1280, 114, 138), Rect2(184, 1416, 90, 120), Rect2(465, 1417, 91, 118), Rect2(752, 1422, 99, 114)],
	"guests_b_emotions": [Rect2(158, 9, 100, 189), Rect2(461, 8, 100, 190), Rect2(754, 10, 111, 188), Rect2(152, 206, 103, 191), Rect2(449, 207, 112, 190), Rect2(745, 211, 112, 184), Rect2(155, 405, 101, 189), Rect2(452, 405, 110, 189), Rect2(744, 408, 112, 185), Rect2(158, 598, 98, 184), Rect2(460, 598, 106, 184), Rect2(753, 601, 110, 180), Rect2(148, 788, 107, 181), Rect2(451, 788, 111, 181), Rect2(743, 792, 116, 177), Rect2(159, 971, 97, 165), Rect2(457, 971, 108, 165), Rect2(753, 975, 117, 162), Rect2(156, 1139, 98, 157), Rect2(455, 1140, 102, 156), Rect2(754, 1147, 108, 151), Rect2(165, 1296, 87, 143), Rect2(457, 1296, 97, 143), Rect2(756, 1302, 103, 137), Rect2(161, 1440, 86, 94), Rect2(459, 1440, 87, 94), Rect2(750, 1441, 101, 94)],
	"hosts_a_emotions": [Rect2(94, 8, 189, 361), Rect2(425, 8, 245, 361), Rect2(776, 13, 182, 356), Rect2(98, 372, 188, 353), Rect2(415, 369, 259, 356), Rect2(779, 382, 183, 343), Rect2(104, 724, 189, 370), Rect2(424, 725, 260, 369), Rect2(783, 728, 178, 365), Rect2(112, 1093, 188, 351), Rect2(429, 1095, 237, 351), Rect2(777, 1099, 192, 348)],
	"hosts_b_emotions": [Rect2(100, 11, 186, 353), Rect2(432, 13, 239, 351), Rect2(781, 11, 173, 353), Rect2(117, 370, 183, 354), Rect2(443, 366, 231, 357), Rect2(807, 377, 164, 347), Rect2(128, 733, 162, 352), Rect2(442, 731, 239, 355), Rect2(808, 738, 154, 349), Rect2(112, 1090, 192, 358), Rect2(428, 1087, 253, 361), Rect2(781, 1109, 192, 339)],
	"new_men_walk": [Rect2(85, 6, 126, 188), Rect2(338, 5, 108, 190), Rect2(570, 6, 129, 189), Rect2(834, 6, 93, 189), Rect2(85, 197, 126, 189), Rect2(338, 197, 108, 189), Rect2(570, 197, 129, 189), Rect2(833, 197, 94, 190), Rect2(112, 388, 113, 190), Rect2(354, 389, 90, 189), Rect2(596, 389, 109, 189), Rect2(839, 389, 87, 189), Rect2(116, 579, 98, 169), Rect2(357, 578, 84, 170), Rect2(599, 579, 95, 169), Rect2(836, 579, 86, 169), Rect2(112, 749, 105, 161), Rect2(350, 749, 89, 161), Rect2(595, 749, 104, 161), Rect2(836, 749, 85, 161), Rect2(110, 908, 106, 167), Rect2(350, 907, 87, 168), Rect2(595, 908, 105, 167), Rect2(833, 908, 87, 167), Rect2(114, 1075, 104, 160), Rect2(355, 1075, 75, 160), Rect2(598, 1075, 102, 161), Rect2(841, 1077, 76, 159), Rect2(111, 1237, 108, 161), Rect2(353, 1237, 81, 161), Rect2(595, 1237, 106, 161), Rect2(837, 1237, 80, 161), Rect2(115, 1398, 98, 138), Rect2(355, 1399, 76, 137), Rect2(595, 1399, 99, 137), Rect2(837, 1399, 79, 137)],
	"new_hosts_emotions": [Rect2(112, 10, 230, 403), Rect2(457, 9, 303, 404), Rect2(933, 35, 232, 378), Rect2(131, 426, 224, 406), Rect2(452, 420, 325, 412), Rect2(935, 453, 245, 379), Rect2(129, 846, 238, 396), Rect2(452, 842, 323, 400), Rect2(933, 860, 245, 382)],
	"middle_men_emotions": [Rect2(150, 20, 178, 396), Rect2(537, 21, 167, 394), Rect2(904, 59, 211, 355), Rect2(148, 435, 184, 396), Rect2(536, 434, 167, 397), Rect2(899, 461, 216, 367), Rect2(155, 842, 174, 399), Rect2(541, 841, 163, 399), Rect2(895, 877, 221, 361)],
	"young_men_emotions": [Rect2(179, 15, 153, 406), Rect2(557, 16, 151, 404), Rect2(916, 51, 188, 370), Rect2(179, 433, 159, 402), Rect2(563, 432, 146, 403), Rect2(913, 466, 194, 370), Rect2(179, 842, 160, 394), Rect2(558, 842, 150, 396), Rect2(906, 881, 210, 357)],
}

const CANVAS_SIZES: Dictionary = {
	"owner_walk": [Vector2(135, 267), Vector2(133, 266), Vector2(142, 263), Vector2(147, 263)],
	"hosts_walk": [Vector2(105, 182), Vector2(106, 184), Vector2(111, 187), Vector2(110, 184), Vector2(111, 185), Vector2(114, 185), Vector2(107, 185), Vector2(109, 185)],
	"guests_a_walk": [Vector2(91, 160), Vector2(90, 162), Vector2(87, 176), Vector2(98, 172), Vector2(87, 158), Vector2(94, 159), Vector2(92, 150), Vector2(93, 152), Vector2(86, 144)],
	"guests_b_walk": [Vector2(106, 160), Vector2(102, 159), Vector2(98, 155), Vector2(105, 162), Vector2(103, 161), Vector2(102, 162), Vector2(103, 155), Vector2(100, 153), Vector2(97, 138)],
	"guests_a_emotions": [Vector2(103, 177), Vector2(118, 180), Vector2(105, 190), Vector2(122, 188), Vector2(103, 165), Vector2(115, 175), Vector2(112, 155), Vector2(114, 138), Vector2(99, 120)],
	"guests_b_emotions": [Vector2(111, 190), Vector2(112, 191), Vector2(112, 189), Vector2(110, 184), Vector2(116, 181), Vector2(117, 165), Vector2(108, 157), Vector2(103, 143), Vector2(101, 94)],
	"hosts_a_emotions": [Vector2(245, 361), Vector2(259, 356), Vector2(260, 370), Vector2(237, 351)],
	"hosts_b_emotions": [Vector2(239, 353), Vector2(231, 357), Vector2(239, 355), Vector2(253, 361)],
	"new_men_walk": [Vector2(129, 190), Vector2(129, 190), Vector2(113, 190), Vector2(98, 170), Vector2(105, 161), Vector2(106, 168), Vector2(104, 161), Vector2(108, 161), Vector2(99, 138)],
	"new_hosts_emotions": [Vector2(303, 404), Vector2(325, 412), Vector2(323, 400)],
	"middle_men_emotions": [Vector2(211, 396), Vector2(216, 397), Vector2(221, 399)],
	"young_men_emotions": [Vector2(188, 406), Vector2(194, 403), Vector2(210, 396)],
}

static var _cache: Dictionary = {}

static func walk_texture(person: String, step: int, facing: String = "front") -> Texture2D:
	if person == "owner":
		var directions: Array = ["front", "back", "left", "right"]
		return _frame("owner_walk", maxi(0, directions.find(facing)), posmod(step, 4), 4)
	if not Art.PEOPLE.has(person):
		return null
	var entry: Array = Art.PEOPLE[person]
	var sheet: String = str(entry[0]) + "_walk"
	return _frame(sheet, entry[1], posmod(step, 4), 4) if SHEETS.has(sheet) else null


static func expression_texture(person: String, expression: String) -> Texture2D:
	if expression == "" or not Art.PEOPLE.has(person):
		return null
	var entry: Array = Art.PEOPLE[person]
	var sheet: String = entry[0]
	var row: int = entry[1]
	var col: int = 0
	if sheet == "new_men":
		if row < 3:
			sheet = "new_hosts_emotions"
			col = {"blink": 0, "cheer": 1, "tired": 2}.get(expression, -1)
		else:
			sheet = "middle_men_emotions" if row < 6 else "young_men_emotions"
			row = row - 3 if row < 6 else row - 6
			col = {"blink": 0, "impatient": 1, "angry_seated": 2}.get(expression, -1)
	elif sheet == "hosts":
		sheet = "hosts_a_emotions" if row < 4 else "hosts_b_emotions"
		row = row % 4
		col = {"blink": 0, "cheer": 1, "tired": 2}.get(expression, -1)
	elif sheet.begins_with("guests_"):
		sheet += "_emotions"
		col = {"blink": 0, "impatient": 1, "angry_seated": 2}.get(expression, -1)
	else:
		return null
	return _frame(sheet, row, col, 3) if col >= 0 else null


static func _frame(sheet: String, row: int, col: int, columns: int) -> Texture2D:
	var key: String = "%s:%d:%d" % [sheet, row, col]
	if not _cache.has(key):
		var texture: AtlasTexture = AtlasTexture.new()
		texture.atlas = SHEETS[sheet]
		texture.region = REGIONS[sheet][row * columns + col]
		var canvas: Vector2 = CANVAS_SIZES[sheet][row]
		var gap: Vector2 = canvas - texture.region.size
		texture.margin = Rect2(Vector2(gap.x * 0.5, gap.y), gap)
		texture.filter_clip = true
		texture.set_meta("animation", "walk" if sheet.ends_with("_walk") else "expression")
		texture.set_meta("frame", col)
		_cache[key] = texture
	return _cache[key]
