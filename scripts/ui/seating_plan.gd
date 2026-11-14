extends RefCounted
## Fixed-size seating. The last station and companions use individual stools.
static func build(rect: Rect2, guests: int, companions: int) -> Dictionary:
	assert(guests >= 1 and guests <= 5 and companions >= 0 and companions <= guests)
	var stations: Array = [
		[Vector2(100, 170), Vector2(190, 170)],
		[Vector2(280, 170), Vector2(370, 170)],
		[Vector2(80, 280), Vector2(170, 280)],
		[Vector2(80, 390), Vector2(170, 390)],
		[Vector2(290, 390), Vector2(380, 390)],
	]
	var selected: Array = [[1], [0, 2], [0, 1, 2], [0, 1, 2, 3], [0, 1, 2, 3, 4]][guests - 1]
	var guest_points: Array = []
	var host_points: Array = []
	var stools: Array = []
	for i in guests:
		for role in 2:
			if role == 1 and i >= companions:
				continue
			var point: Vector2 = stations[selected[i]][role]
			if rect.position.x > 515:
				point.x = rect.size.x - point.x
			point += rect.position
			(guest_points if role == 0 else host_points).append(point)
			if selected[i] == 4 or (role == 1 and selected[i] >= 2):
				stools.append(point)
	return {"guests": guest_points, "hosts": host_points, "stools": stools, "scale": 1.0}
