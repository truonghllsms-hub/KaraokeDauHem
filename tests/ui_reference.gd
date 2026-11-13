extends SceneTree
## Acceptance test: the initial live screen must reproduce the approved design.
## Run at the design resolution with a rendering display: --resolution 1024x1536.
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
	await RenderingServer.frame_post_draw
	var actual: Image = root.get_texture().get_image()
	var expected: Image = load("res://assets/reference/approved_ui.png").get_image()
	actual.convert(Image.FORMAT_RGBA8)
	expected.convert(Image.FORMAT_RGBA8)
	check(actual.get_size() == expected.get_size(), "Capture uses approved 1024x1536 design size")
	check(actual.get_data() == expected.get_data(), "Initial live screen matches every approved pixel")
	check(game._map_scroll.scroll_vertical == 564, "Initial camera shows partial locked pair, two open rooms, lobby and sidewalk")
	var fixed_nav: Control = game.find_child("Nav_staff", true, false)
	check(fixed_nav.get_global_rect() == Rect2(218, 1414, 192, 114), "Staff button hit target follows the artwork")
	var before: int = game.sim.state.money
	game.sim.buy_stock("da")
	game._refresh()
	check(game.sim.state.money < before and game._hud_money.visible, "Purchases change actual money and reveal live HUD text")
	game.sim.unlock_room("room_03")
	game.venue.advance_actors(0.0)
	check(game.venue._room_ui["room_03"]["furniture"].visible, "Unlocking removes the room's closed artwork")
	game.sim.open_doors()
	game.sim.step_minute()
	game._refresh()
	check(game._hud_clock.visible and game._hud_clock.text.contains("18:01"), "Time label updates from the simulation")
	game._speed_buttons[2].pressed.emit()
	game._refresh()
	check(game.sim.clock.speed == 2 and game._speed_buttons[2].text == "2x", "Speed buttons remain interactive with live selection")
	game.find_child("Nav_staff", true, false).pressed.emit()
	check(game._overlay != null and not game.sim.clock.is_running(), "Illustrated staff button opens real management UI")
	game._close_overlay()
	check(game.sim.check_invariants().is_empty(), "Reference skin preserves simulation invariants")
	print("ui_reference: %d errors" % errors)
	quit(0 if errors == 0 else 1)
