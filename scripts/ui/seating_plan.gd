extends RefCounted
## Five stations anchored to the L sofa, with a close companion beside each guest.
static func build(rect: Rect2, guests: int, companions: int) -> Dictionary:
	assert(guests >= 1 and guests <= 5 and companions >= 0 and companions <= guests)
	var stations: Array = [
		[Vector2(106, 205), Vector2(148, 205)],
		[Vector2(196, 205), Vector2(238, 205)],
		[Vector2(286, 205), Vector2(328, 205)],
		[Vector2(70, 290), Vector2(108, 290)],
		[Vector2(70, 375), Vector2(108, 375)],
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

	return {"guests": guest_points, "hosts": host_points, "stools": stools, "scale": 1.0}
