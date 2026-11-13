extends RefCounted
## Five fixed customer stations, each with a reserved adjacent companion seat.
## Positions never depend on how many companions have arrived. Character scale is always one.
static func build(rect: Rect2, guests: int, companions: int) -> Dictionary:
	assert(guests >= 1 and guests <= 5 and companions >= 0 and companions <= guests)
	var stations: Array = [
		[Vector2(225, 235), Vector2(330, 235)],
		[Vector2(90, 235), Vector2(90, 345)],
		[Vector2(90, 455), Vector2(90, 565)],
		[Vector2(70, 675), Vector2(158, 675)],
		[Vector2(246, 675), Vector2(334, 675)],
	]
	var selected: Array = [[4], [1, 4], [0, 2, 4], [0, 1, 2, 4], [0, 1, 2, 3, 4]][guests - 1]
	var guest_points: Array = []
	var host_points: Array = []
	for i in guests:
		for role in 2:
			if role == 1 and i >= companions:
				continue
			var point: Vector2 = stations[selected[i]][role]
			if rect.position.x > 510:
				point.x = rect.size.x - point.x
			(guest_points if role == 0 else host_points).append(rect.position + point)
	return {"guests": guest_points, "hosts": host_points, "scale": 1.0}
