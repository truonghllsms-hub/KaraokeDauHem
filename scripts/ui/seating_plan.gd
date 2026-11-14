extends RefCounted
## Five stations anchored to the L sofa, with a close companion beside each guest.
static func build(rect: Rect2, guests: int, companions: int) -> Dictionary:
	assert(guests >= 1 and guests <= 5 and companions >= 0 and companions <= guests)
	var floor_two: bool = rect.position.y >= 1400
	var row: int = int((rect.position.y - (1464 if floor_two else 64)) / 400)
	var cushion_y: float = ([192.0, 169.0, 163.0][clampi(row, 0, 2)] if floor_two else [179.0, 165.0][clampi(row, 0, 1)])
	var stations: Array = [
		[Vector2(96, cushion_y), Vector2(138, cushion_y)],
		[Vector2(186, cushion_y), Vector2(228, cushion_y)],
		[Vector2(276, cushion_y), Vector2(318, cushion_y)],
		[Vector2(54, 260), Vector2(86, 260)],
		[Vector2(54, 342), Vector2(86, 342)],
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
