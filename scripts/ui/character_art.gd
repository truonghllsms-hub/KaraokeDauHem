extends RefCounted
## Atlas nhân vật theo mẫu đã duyệt. Vùng ảnh loại phần lề trong suốt;
## cùng một ID dùng cho ảnh tuyển dụng, đứng, ngồi và các hướng chủ quán.

const SHEETS: Dictionary = {
	"staff": preload("res://assets/characters/staff.webp"),
	"hosts": preload("res://assets/characters/hosts.webp"),
	"hosts_seated": preload("res://assets/characters/hosts_seated.webp"),
	"guests_a": preload("res://assets/characters/guests_a.webp"),
	"guests_b": preload("res://assets/characters/guests_b.webp"),
	"guests_a_seated": preload("res://assets/characters/guests_a_seated.webp"),
	"guests_b_seated": preload("res://assets/characters/guests_b_seated.webp"),
}

const REGIONS: Dictionary = {
	"staff": [Rect2(134, 26, 188, 406), Rect2(573, 26, 186, 404), Rect2(1020, 26, 181, 407), Rect2(1457, 26, 182, 408), Rect2(117, 463, 252, 413), Rect2(565, 460, 238, 416), Rect2(988, 470, 247, 402), Rect2(1443, 477, 221, 397)],
	"hosts": [Rect2(86, 41, 240, 467), Rect2(484, 41, 192, 466), Rect2(844, 36, 228, 470), Rect2(1206, 44, 226, 461), Rect2(115, 526, 206, 470), Rect2(439, 527, 243, 472), Rect2(865, 530, 184, 468), Rect2(1234, 527, 217, 474)],
	"hosts_seated": [Rect2(87, 23, 235, 489), Rect2(457, 21, 224, 491), Rect2(822, 19, 228, 493), Rect2(1223, 28, 236, 484), Rect2(80, 512, 251, 508), Rect2(468, 512, 235, 509), Rect2(852, 512, 203, 510), Rect2(1210, 512, 255, 510)],
	"guests_a": [Rect2(226, 31, 144, 308), Rect2(676, 31, 160, 308), Rect2(1160, 11, 144, 330), Rect2(218, 348, 161, 328), Rect2(691, 354, 147, 320), Rect2(1159, 361, 148, 314), Rect2(225, 690, 169, 325), Rect2(675, 690, 175, 324), Rect2(1164, 691, 166, 324)],
	"guests_b": [Rect2(205, 20, 157, 318), Rect2(679, 19, 164, 318), Rect2(1170, 24, 161, 314), Rect2(210, 350, 143, 326), Rect2(673, 361, 163, 314), Rect2(1181, 355, 149, 321), Rect2(195, 699, 162, 318), Rect2(690, 690, 153, 327), Rect2(1164, 701, 165, 316)],
	"guests_a_seated": [Rect2(218, 24, 198, 317), Rect2(658, 27, 213, 314), Rect2(1132, 5, 200, 336), Rect2(205, 341, 212, 341), Rect2(675, 341, 213, 341), Rect2(1129, 341, 204, 341), Rect2(220, 682, 219, 336), Rect2(652, 682, 234, 342), Rect2(1141, 682, 212, 339)],
	"guests_b_seated": [Rect2(171, 19, 226, 322), Rect2(653, 16, 218, 325), Rect2(1159, 23, 219, 318), Rect2(171, 341, 215, 341), Rect2(650, 341, 229, 341), Rect2(1161, 341, 222, 341), Rect2(160, 682, 225, 342), Rect2(648, 682, 227, 342), Rect2(1142, 682, 228, 342)],
}

const PEOPLE: Dictionary = {
	"owner": ["staff", 0],
	"owner_back": ["staff", 1],
	"owner_left": ["staff", 2],
	"owner_right": ["staff", 3],
	"waiter_f": ["staff", 4],
	"waiter_m": ["staff", 5],
	"owner_cleaning": ["staff", 6],
	"guard": ["staff", 7],
	"lancan_1": ["hosts", 0],
	"lancan_2": ["hosts", 1],
	"lancan_3": ["hosts", 2],
	"lancan_4": ["hosts", 3],
	"lancan_5": ["hosts", 4],
	"lancan_6": ["hosts", 5],
	"lancan_7": ["hosts", 6],
	"lancan_8": ["hosts", 7],
	"friend_m": ["guests_a", 0],
	"friend_f": ["guests_a", 1],
	"birthday_m": ["guests_a", 2],
	"birthday_f": ["guests_a", 3],
	"office_m": ["guests_a", 4],
	"office_f": ["guests_a", 5],
	"uncle": ["guests_a", 6],
	"auntie": ["guests_a", 7],
	"drunk_uncle": ["guests_a", 8],
	"beer_uncle": ["guests_b", 0],
	"auntie_2": ["guests_b", 1],
	"auntie_3": ["guests_b", 2],
	"couple_m": ["guests_b", 3],
	"couple_f": ["guests_b", 4],
	"grandpa": ["guests_b", 5],
	"grandma": ["guests_b", 6],
	"genz_m": ["guests_b", 7],
	"genz_f": ["guests_b", 8],
}

static var _cache: Dictionary = {}

static func texture(person: String, pose: String = "standing", facing: String = "front") -> Texture2D:
	var key: String = person
	if person == "owner":
		if pose == "cleaning":
			key = "owner_cleaning"
		elif facing != "front":
			key = "owner_" + facing
	if not PEOPLE.has(key):
		return load("res://assets/sprites/%s.svg" % person)
	var entry: Array = PEOPLE[key]
	var sheet: String = entry[0]
	if pose == "seated" and SHEETS.has(sheet + "_seated"):
		sheet += "_seated"
	var cache_key: String = sheet + ":" + str(entry[1])
	if not _cache.has(cache_key):
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = SHEETS[sheet]
		atlas.region = REGIONS[sheet][entry[1]]
		atlas.filter_clip = true
		_cache[cache_key] = atlas
	return _cache[cache_key]


static func height(person: String, pose: String = "standing") -> float:
	if person == "guard":
		return 96.0
	if person.begins_with("lancan_"):
		return 104.0 if pose == "seated" else 120.0
	return 94.0 if pose == "seated" else 112.0
