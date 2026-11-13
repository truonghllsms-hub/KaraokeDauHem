extends RefCounted
## Chỗ ngồi dọc sofa chữ L, xen kẽ khách và vị trí giao lưu đã được nhóm gọi.
## Dãy bên phải được phản chiếu để mọi người nhìn về TV ở vách đối diện.

static var _cache: Dictionary = {}

static func build(rect: Rect2, guests: int, companions: int) -> Dictionary:
	var key: String = "%s:%d:%d" % [str(rect), guests, companions]
	if _cache.has(key):
		return _cache[key]
	var count: int = guests + companions
	var guest_points: Array = []
	var host_points: Array = []
	var all_points: Array = []
	var a: Vector2 = Vector2(83, 170)
	var b: Vector2 = Vector2(83, 344)
	var c: Vector2 = Vector2(240, 344)
	if count <= 2:
		a = Vector2(190 if count == 1 else 145, 344)
		b = c
	var places: Array = []
	if count <= 2:
		for i in count:
			places.append(a.lerp(c, float(i) / maxi(1, count - 1)))
	else:
		var vertical: int = ceili(float(count) * 0.5)
		var horizontal: int = count - vertical
		for i in vertical:
			places.append(a.lerp(b, float(i) / maxi(1, vertical - 1)))
		for i in horizontal:
			places.append(b.lerp(c, float(i + 1) / horizontal))
	for i in count:
		var point: Vector2 = places[i]
		if rect.position.x > 510:
			point.x = rect.size.x - point.x
		point += rect.position
		all_points.append(point)
	# Giữ hình người tách rời kể cả trên cạnh dọc và ở góc chữ L.
	var seated_scale: float = 1.0
	for i in all_points.size():
		for j in range(i + 1, all_points.size()):
			var delta: Vector2 = (all_points[i] - all_points[j]).abs()
			seated_scale = minf(seated_scale, maxf(delta.x / 88.0, delta.y / 108.0))
	seated_scale = clampf(seated_scale, 0.15, 1.0)
	var used: Dictionary = {}
	for pair in _adjacent_pairs(all_points, companions):
		var first: Vector2 = all_points[pair[0]]
		var second: Vector2 = all_points[pair[1]]
		var gap: float = (110.0 if is_equal_approx(first.x, second.x) else 90.0) * seated_scale
		if first.distance_to(second) > gap:
			var midpoint: Vector2 = (first + second) * 0.5
			var direction: Vector2 = (second - first).normalized()
			first = midpoint - direction * gap * 0.5
			second = midpoint + direction * gap * 0.5
		guest_points.append(first)
		host_points.append(second)
		used[pair[0]] = true
		used[pair[1]] = true
	for i in count:
		if not used.has(i):
			guest_points.append(all_points[i])
	_cache[key] = {"guests": guest_points, "hosts": host_points, "scale": seated_scale}
	return _cache[key]


## Chọn các cặp ghế liền nhau, tránh ghép một người ở hai đầu xa của sofa.
static func _adjacent_pairs(points: Array, wanted: int) -> Array:
	var costs: Array = []
	var take: Array = []
	for i in points.size() + 2:
		var row: Array = []
		var choices: Array = []
		for k in wanted + 1:
			row.append(0.0 if k == 0 else INF)
			choices.append(false)
		costs.append(row)
		take.append(choices)
	for i in range(points.size() - 1, -1, -1):
		for k in range(1, wanted + 1):
			costs[i][k] = costs[i + 1][k]
			if i + 1 < points.size():
				var paired: float = points[i].distance_squared_to(points[i + 1]) + costs[i + 2][k - 1]
				if paired <= costs[i][k]:
					costs[i][k] = paired
					take[i][k] = true
	var result: Array = []
	var index: int = 0
	while wanted > 0 and index < points.size():
		if take[index][wanted]:
			result.append([index, index + 1])
			wanted -= 1
			index += 2
		else:
			index += 1
	return result
