extends RefCounted
## Atlas nhân vật theo mẫu đã duyệt. Vùng ảnh loại phần lề trong suốt;
## cùng một ID dùng cho ảnh tuyển dụng, đứng, ngồi và các hướng chủ quán.

const SHEETS: Dictionary = {
	"staff_tasks": preload("res://assets/characters/staff_tasks.webp"),
	"staff_idle": preload("res://assets/characters/staff_idle.webp"),
	"new_men": preload("res://assets/characters/new_men_base.webp"),
	"new_men_seated": preload("res://assets/characters/new_men_seated.webp"),
	"staff": preload("res://assets/characters/staff.webp"),
	"hosts": preload("res://assets/characters/hosts.webp"),
	"hosts_seated": preload("res://assets/characters/hosts_seated.webp"),
	"guests_a": preload("res://assets/characters/guests_a.webp"),
	"guests_b": preload("res://assets/characters/guests_b.webp"),
	"guests_a_seated": preload("res://assets/characters/guests_a_seated.webp"),
	"guests_b_seated": preload("res://assets/characters/guests_b_seated.webp"),
}

const REGIONS: Dictionary = {
	"staff_tasks": [Rect2(134, 13, 245, 424), Rect2(553, 16, 279, 421), Rect2(986, 15, 254, 422), Rect2(1423, 11, 229, 425), Rect2(132, 454, 233, 425), Rect2(545, 456, 231, 421), Rect2(967, 458, 242, 420), Rect2(1430, 458, 239, 420)],
	"staff_idle": [Rect2(171, 13, 182, 485), Rect2(627, 18, 214, 480), Rect2(1127, 15, 216, 482), Rect2(155, 520, 194, 494), Rect2(629, 525, 215, 489), Rect2(1148, 520, 199, 494)],
	"new_men": [Rect2(119, 15, 241, 424), Rect2(503, 11, 226, 429), Rect2(898, 14, 185, 423), Rect2(168, 448, 184, 377), Rect2(539, 454, 180, 371), Rect2(910, 448, 181, 376), Rect2(168, 838, 179, 401), Rect2(535, 837, 185, 403), Rect2(910, 837, 179, 403)],
	"new_men_seated": [Rect2(63, 15, 327, 429), Rect2(457, 12, 331, 431), Rect2(911, 17, 290, 427), Rect2(105, 441, 260, 391), Rect2(504, 449, 269, 387), Rect2(908, 445, 260, 391), Rect2(69, 834, 298, 408), Rect2(474, 838, 303, 406), Rect2(878, 837, 302, 405)],
	"staff": [Rect2(134, 26, 188, 406), Rect2(573, 26, 186, 404), Rect2(1020, 26, 181, 407), Rect2(1457, 26, 182, 408), Rect2(117, 463, 252, 413), Rect2(565, 460, 238, 416), Rect2(988, 470, 247, 402), Rect2(1443, 477, 221, 397)],
	"hosts": [Rect2(86, 41, 240, 467), Rect2(484, 41, 192, 466), Rect2(844, 36, 228, 470), Rect2(1206, 44, 226, 461), Rect2(115, 526, 206, 470), Rect2(439, 527, 243, 472), Rect2(865, 530, 184, 468), Rect2(1234, 527, 217, 474)],
	"hosts_seated": [Rect2(87, 23, 235, 489), Rect2(457, 21, 224, 491), Rect2(822, 19, 228, 493), Rect2(1223, 28, 236, 484), Rect2(80, 512, 251, 508), Rect2(468, 512, 235, 509), Rect2(852, 512, 203, 510), Rect2(1210, 512, 255, 510)],
	"guests_a": [Rect2(226, 31, 144, 308), Rect2(676, 31, 160, 308), Rect2(1160, 11, 144, 330), Rect2(218, 348, 161, 328), Rect2(691, 354, 147, 320), Rect2(1159, 361, 148, 314), Rect2(225, 690, 169, 325), Rect2(675, 690, 175, 324), Rect2(1164, 691, 166, 324)],
	"guests_b": [Rect2(205, 20, 157, 318), Rect2(679, 19, 164, 318), Rect2(1170, 24, 161, 314), Rect2(210, 350, 143, 326), Rect2(673, 361, 163, 314), Rect2(1181, 355, 149, 321), Rect2(195, 699, 162, 318), Rect2(690, 690, 153, 327), Rect2(1164, 701, 165, 316)],
	"guests_a_seated": [Rect2(218, 24, 198, 317), Rect2(658, 27, 213, 314), Rect2(1132, 5, 200, 336), Rect2(205, 341, 212, 341), Rect2(675, 341, 213, 341), Rect2(1129, 341, 204, 341), Rect2(220, 682, 219, 336), Rect2(652, 682, 234, 342), Rect2(1141, 682, 212, 339)],
	"guests_b_seated": [Rect2(171, 19, 226, 322), Rect2(653, 16, 218, 325), Rect2(1159, 23, 219, 318), Rect2(171, 341, 215, 341), Rect2(650, 341, 229, 341), Rect2(1161, 341, 222, 341), Rect2(160, 682, 225, 342), Rect2(648, 682, 227, 342), Rect2(1142, 682, 228, 342)],
}

const PEOPLE: Dictionary = {
	"janitor_m": ["staff_idle", 0],
	"janitor_f": ["staff_idle", 1],
	"server_f": ["staff_idle", 2],
	"server_m": ["staff_idle", 3],
	"reception_f": ["staff_idle", 4],
	"reception_m": ["staff_idle", 5],
	"janitor_m_cleaning": ["staff_tasks", 0],
	"janitor_f_cleaning": ["staff_tasks", 1],
	"server_f_carrying": ["staff_tasks", 2],
	"server_m_carrying": ["staff_tasks", 3],
	"owner_carrying_front": ["staff_tasks", 4],
	"owner_carrying_back": ["staff_tasks", 5],
	"owner_carrying_left": ["staff_tasks", 6],
	"owner_carrying_right": ["staff_tasks", 7],
	"lancan_9": ["new_men", 0],
	"lancan_10": ["new_men", 1],
	"lancan_11": ["new_men", 2],
	"middle_m_1": ["new_men", 3],
	"middle_m_2": ["new_men", 4],
	"middle_m_3": ["new_men", 5],
	"young_m_1": ["new_men", 6],
	"young_m_2": ["new_men", 7],
	"young_m_3": ["new_men", 8],
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
	if pose == "carrying":
		key = "owner_carrying_" + facing if person == "owner" else person + "_carrying"
	elif pose == "cleaning" and person.begins_with("janitor_"):
		key = person + "_cleaning"
	elif person == "owner":
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


static func staff_sprite(member: Dictionary) -> String:
	return {"staff_1": "janitor_m", "staff_2": "janitor_f", "staff_3": "server_f", "staff_4": "server_m", "staff_5": "reception_f", "staff_6": "reception_m"}.get(member.get("id", ""), member.get("sprite", "server_m"))
