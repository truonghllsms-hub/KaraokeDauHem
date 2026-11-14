extends RefCounted
## Viết đánh giá kiểu Google Maps cho mỗi nhóm đã thanh toán: tên người đánh giá, số bài đã viết,
## và câu nhận xét đúng với chuyện đã xảy ra (dấu vết trong group["tags"]). Tránh trùng câu và trùng tên
## với các đánh giá gần đây. Dùng bộ ngẫu nhiên riêng nên không làm lệch diễn biến của mô phỏng.

## Thứ tự ưu tiên khi chọn chuyện để kể: chuyện tệ nặng nhất trước, rồi chuyện tốt nổi bật.
const BAD_TAGS: Array = ["mat_xe", "micro", "cho_do", "cho_phong", "het_hang", "nong", "lancan_lo", "gia_cao"]
const RECENT_SENTENCES: int = 8
const GOOD_TAGS: Array = ["trom_bat", "lancan_hop_gu", "vip", "phong_quen", "giao_nhanh", "hat_them", "lancan", "gia_mem"]

var _state
var _data: Dictionary
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _seed: int = 0


func _init(state, data: Dictionary, p_seed: int) -> void:
	_state = state
	_data = data
	_seed = p_seed


func _pick(options: Array) -> Variant:
	return options[_rng.randi_range(0, options.size() - 1)]


func _recent(field: String) -> Dictionary:
	var used: Dictionary = {}
	for review in _state.reviews:
		used[review.get(field, "")] = true
	return used


func _reviewer() -> Dictionary:
	var lib: Dictionary = _data["reviews"]
	var used: Dictionary = _recent("who")
	var name: String = ""
	for attempt in 12:
		match _rng.randi_range(0, 5):
			0, 1:
				name = "%s %s" % [_pick(lib["given_names"]), _pick(lib["family_names"])]
			2:
				name = "%s %s" % [_pick(lib["family_names"]), _pick(lib["given_names"])]
			3:
				name = "%s%d" % [_pick(lib["nick_handles"]), _rng.randi_range(88, 2009)]
			4:
				name = "%s.%s" % [_pick(lib["nick_handles"]), _pick(["hn", "sg", "dn", "ct"])]
			_:
				name = String(_pick(lib["nicknames"])).capitalize()
		if not used.has(name):
			break
	var count: int = _rng.randi_range(1, 9) if _rng.randi_range(1, 100) <= 60 else _rng.randi_range(10, 240)
	var badge: String = "Local Guide · %d bài đánh giá" % count if count >= 40 else "%d bài đánh giá" % count
	return {"who": name, "badge": badge}


func _fill(text: String, context: Dictionary) -> String:
	for key in context:
		text = text.replace("{%s}" % key, str(context[key]))
	return text


## Trả về {"who", "badge", "text"} cho một nhóm.
func write(group: Dictionary, stars: int, context: Dictionary) -> Dictionary:
	# Gieo theo từng nhóm: tải lại bản lưu vẫn cho cùng đánh giá.
	_rng.seed = hash([_seed, _state.day, group["id"], "review"])
	var lib: Dictionary = _data["reviews"]
	var tags: Array = group["tags"]
	var used: Dictionary = _recent("text")
	var main_tag: String = ""
	var order: Array = BAD_TAGS + GOOD_TAGS if stars <= 3 else GOOD_TAGS + BAD_TAGS
	for tag in order:
		if tags.has(tag) and lib["by_tag"].has(tag):
			if tag in ["lancan", "lancan_hop_gu"] and str(context.get("host", "")) == "":
				continue
			if tag in ["cho_do", "het_hang", "giao_nhanh"] and str(context.get("item", "")) == "" and _template_needs(lib["by_tag"][tag], "{item}"):
				continue
			main_tag = tag
			break
	# Câu chính không trùng với RECENT_SENTENCES đánh giá gần nhất (tránh đọc thấy lặp).
	var recent_sentences: Dictionary = {}
	for i in range(maxi(0, _state.reviews.size() - RECENT_SENTENCES), _state.reviews.size()):
		recent_sentences[_state.reviews[i].get("main", "")] = true
	var text: String = ""
	var main_sentence: String = ""
	for attempt in 14:
		var parts: Array = []
		main_sentence = ""
		if main_tag != "":
			main_sentence = _fill(_pick(lib["by_tag"][main_tag]), context)
			if recent_sentences.has(main_sentence) and attempt < 12:
				continue
			parts.append(main_sentence)
		# Thêm một câu chung theo số sao (đôi khi đứng một mình).
		if parts.is_empty() or _rng.randi_range(1, 100) <= 55:
			parts.append(_pick(lib["by_stars"][str(stars)]))
		text = " ".join(parts)
		if not used.has(text) and not recent_sentences.has(text):
			break
	var reviewer: Dictionary = _reviewer()
	return {"who": reviewer["who"], "badge": reviewer["badge"], "text": text, "main": main_sentence if main_sentence != "" else text}


static func _template_needs(options: Array, token: String) -> bool:
	for option in options:
		if not String(option).contains(token):
			return false
	return true
