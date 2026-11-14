extends SceneTree
## Layout regression checks complement ui_smoke and the browser mouse/touch checks.
var errors: int = 0

func _initialize() -> void:
	_run()

func check(ok: bool, message: String) -> void:
	print(("OK " if ok else "FAIL ") + message)
	if not ok:
		errors += 1

func _run() -> void:
	var game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	await process_frame
	var venue = game.venue
	check(not venue._owner.visible, "Preparation starts without characters")
	check(game.sim.rooms.unlocked_count() == 2, "Only first two rooms start open")
	var rects: Array = []
	for room in game.sim.state.rooms:
		rects.append(venue._rect_of(room["id"]))
	var clear: bool = true
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			clear = clear and not rects[i].intersects(rects[j])
	check(clear, "All ten room hit regions are disjoint")
	check(rects[0].position.y == rects[1].position.y and rects[2].position.y < rects[0].position.y, "Two facing columns grow upwards")
	check(rects[0].end.x < rects[1].position.x and rects[0].size.y >= 300, "Wide rooms and clear central corridor")
	check(game._map_scroll.scroll_vertical == 0, "Ground floor fits without scrolling")
	var nav: Control = game.find_child("Nav_staff", true, false)
	var nav_position: Vector2 = nav.global_position
	game._map_scroll.scroll_vertical = 0
	await process_frame
	check(nav.global_position.is_equal_approx(nav_position), "Navigation stays fixed while map scrolls")
	check(game._map_stage.custom_minimum_size.y == game._map_scroll.size.y, "Each floor fits the map viewport")
	game._map_scroll.scroll_vertical = 100
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.position = game._map_scroll.get_global_rect().get_center()
	touch.pressed = true
	game._input(touch)
	var drag: InputEventScreenDrag = InputEventScreenDrag.new()
	drag.position = touch.position - Vector2(0, 120)
	drag.relative = Vector2(0, -120)
	game._input(drag)
	check(game._map_scroll.scroll_vertical == 0, "Touch dragging cannot pan outside a floor")
	check(game._overlay == null and game._touch_scrolling, "Panning does not open a room inspector")
	game._finish_touch_pan()
	game._show_staff()
	check(game._overlay != null and not game.sim.clock.is_running(), "Staff management pauses simulation")
	game._close_overlay()
	game._show_guard()
	check(game._overlay != null, "Security remains available under staff management")
	game._close_overlay()
	venue.selected_room = "room_03"
	game._show_venue_panel()
	check(game._btn_unlock.visible and game._btn_unlock.text.contains("4.000.000"), "Room inspector offers correct unlock action")
	game._close_overlay()
	var route: Array = venue._route(Vector2(280, 950), venue._work_position("room_01"))
	check(route.has(Vector2(430, 950)), "Reception workspace has an unobstructed right-side exit")
	check(game.sim.check_invariants().is_empty(), "Layout and inspector preserve simulation state")
	print("ui_redesign: %d errors" % errors)
	quit(0 if errors == 0 else 1)
