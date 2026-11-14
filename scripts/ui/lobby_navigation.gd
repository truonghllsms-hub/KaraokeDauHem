extends RefCounted
## Visibility graph around the reception counter and refrigerator, in world coordinates.
const SOLIDS: Array = [Rect2(128, 948, 244, 132), Rect2(33, 875, 115, 203)]
static func clear_segment(a: Vector2, b: Vector2) -> bool:
	for rect in SOLIDS:
		if rect.has_point(a) or rect.has_point(b): return false
		var corners: Array = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
		for i in 4:
			if Geometry2D.segment_intersects_segment(a, b, corners[i], corners[(i+1)%4]) != null: return false
	return true
static func free_point(point: Vector2) -> Vector2:
	if SOLIDS.all(func(rect): return not rect.has_point(point)): return point
	var options: Array = []
	for rect in SOLIDS:
		options.append(Vector2(rect.position.x-1, point.y))
		options.append(Vector2(rect.end.x+1, point.y))
		options.append(Vector2(point.x, rect.position.y-1))
		options.append(Vector2(point.x, rect.end.y+1))
	var best: Vector2 = Vector2(430, 925)
	for candidate in options:
		if SOLIDS.all(func(rect): return not rect.has_point(candidate)) and candidate.distance_squared_to(point) < best.distance_squared_to(point): best = candidate
	return best
static func between(start: Vector2, finish: Vector2) -> Array:
	var a: Vector2 = free_point(start)
	var b: Vector2 = free_point(finish)
	if clear_segment(a,b): return [b]
	var nodes: Array = [a,b]
	for solid in SOLIDS:
		var r: Rect2 = solid.grow(1)
		for corner in [r.position, Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)]:
			if SOLIDS.all(func(rect): return not rect.has_point(corner)): nodes.append(corner)
	var distance: Array = []
	var parent: Array = []
	var visited: Array = []
	for i in nodes.size():
		distance.append(INF)
		parent.append(-1)
		visited.append(false)
	distance[0] = 0.0
	for iteration in nodes.size():
		var current: int = -1
		for i in nodes.size():
			if not visited[i] and (current == -1 or distance[i] < distance[current]): current = i
		if current == -1 or is_inf(distance[current]): break
		if current == 1: break
		visited[current] = true
		for i in nodes.size():
			if visited[i] or not clear_segment(nodes[current],nodes[i]): continue
			var cost: float = distance[current] + nodes[current].distance_to(nodes[i])
			if cost < distance[i]:
				distance[i] = cost
				parent[i] = current
	var path: Array = []
	var cursor: int = 1
	if parent[cursor] == -1: return [a] # Never walk through a solid when no route exists.
	while cursor != 0:
		path.push_front(nodes[cursor])
		cursor = parent[cursor]
	return path
static func avoid(start: Vector2, points: Array) -> Array:
	var result: Array = []
	var previous: Vector2 = start
	for point in points:
		var safe: Array = between(previous, point)
		result.append_array(safe)
		previous = safe.back()
	return result
