extends SceneTree
const Art = preload("res://scripts/ui/character_art.gd")
const Nav = preload("res://scripts/ui/lobby_navigation.gd")
const SaveManager = preload("res://scripts/core/save_manager.gd")
var failures: int = 0
var game
var sim
var venue
var out: String = "user://experience"
func _initialize() -> void:
	var args = OS.get_cmdline_user_args()
	if not args.is_empty(): out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	_run()
func check(value: bool, label: String) -> void:
	print(("ok " if value else "FAIL ") + label)
	if not value: failures += 1
func advance(seconds: float) -> void:
	for i in int(seconds * 20): venue.advance_actors(0.05)
func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name+".png"))
func button(text: String) -> Button:
	for candidate in game._overlay.find_children("*", "Button", true, false):
		if candidate.text == text: return candidate
	return null
func _run() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	sim = game.sim
	venue = game.venue
	venue.set_process(false)
	sim.customers.spawning_enabled = false
	sim.service.enabled = false
	sim.security.enabled = false
	check(sim.state.staff.is_empty() and not sim.state.guard_hired, "New game has no hired staff or guard")
	venue.advance_actors(0)
	check(venue._bikes.all(func(b): return not b.visible), "Empty venue has no parked bikes")
	for pair in [[Vector2(170,925), Vector2(260,1095)], [Vector2(250,940), Vector2(410,1000)], [Vector2(430,1060), Vector2(170,925)]]:
		var start: Vector2 = pair[0]
		var path: Array = venue._route(start, pair[1])
		var clear: bool = true
		for point in path:
			for sample in 41:
				var at: Vector2 = start.lerp(point, sample/40.0)
				clear = clear and not Rect2(140,960,220,108).has_point(at) and not Rect2(43,885,95,183).has_point(at)
			start = point
		check(clear, "Lobby route goes around counter and fridge")
	await shot("e01_empty")
	sim.economy.record("TEST", 40000000, "experience_fixture")
	sim.equip_room("room_03")
	sim.equip_room("room_04")
	sim.hire_host("host_1")
	sim.hire_host("host_2")
	sim.open_doors()
	var party = sim.customers.add_group("company", 5, 120, sim.clock.minute)
	party["wants_host"] = true
	party["host_requested_count"] = 2
	party["host_gender"] = "any"
	sim.assign_group(party["id"], "room_02")
	party["host_request"] = "PENDING"
	check(sim.assign_host("host_1", "room_02") == "" and sim.assign_host("host_2", "room_02") == "", "Pair two companions with guests")
	advance(30)
	check(venue._bikes.filter(func(b): return b.visible).size() == 3, "Five guests bring three bikes")
	var plan: Dictionary = venue._seating("room_02")
	check(plan["stools"].is_empty(), "Guests stay on the L sofa, without floor stools")
	for i in 2:
		check(plan["guests"][i].distance_to(plan["hosts"][i]) <= 43, "Companion sits close to own guest")
	venue._on_line_spoken({"host_id": "", "speaker_index": 2, "group_id": party["id"], "reply_text": "", "text": "♪ Hát vang một đêm thật vui", "kind": "SONG"})
	venue.advance_actors(0)
	var actor = venue._group_actors[party["id"]]
	for i in actor._sprites.size():
		var sprite: Sprite2D = actor._sprites[i]
		var contact: Vector2 = Art.seat_contact(actor._people[i], sprite.texture)
		if sprite.flip_h: contact.x = -contact.x
		var actual: Vector2 = actor.position + sprite.position + contact.rotated(sprite.rotation)
		check(actual.distance_to(plan["guests"][i]) < 1, "Guest hip contact stays on cushion while singing")
	for host_id in venue._host_actors:
		var host_actor = venue._host_actors[host_id]
		var sprite: Sprite2D = host_actor._sprites[0]
		var contact: Vector2 = Art.seat_contact(host_actor._people[0], sprite.texture)
		if sprite.flip_h: contact.x = -contact.x
		var actual: Vector2 = host_actor.position + sprite.position + contact.rotated(sprite.rotation)
		check(actual.distance_to(venue._host_position("room_02", host_id)) < 1, "Companion hip contact matches paired cushion")
	check(actor._bubble.get_theme_color("font_color") == Color.BLACK and actor.bubble_speaker == 2, "Song bubble has black text on white and follows actual speaker")
	await shot("e02_seated_song")
	var room: Dictionary = sim.rooms.get_room("room_02")
	sim.service._open(room, {"kind": "MIC", "text": "Micro"}, sim.clock.minute, 100)
	venue.advance_actors(0)
	check(actor._bubble.text.contains("mic hỏng") and actor._bubble.get_theme_color("font_color") == Color.WHITE and actor._bubble_background == Color("#a53741") and not venue._room_ui["room_02"]["request"].visible, "Broken mic becomes customer speech with distinct color")
	await shot("e03_mic_chat")
	sim.fix_mic("room_02")
	sim.service._open(room, {"kind": "ORDER", "product_id": "da", "quantity": 1, "price": 15000, "text": "Đá"}, sim.clock.minute, 100)
	venue.advance_actors(0)
	check(actor._bubble.text.contains("thêm đá") and actor._bubble.get_theme_color("font_color") == Color.WHITE and actor._bubble_background == Color("#24618b"), "Drinks request speaks in amber")
	await shot("e04_order_chat")
	venue._add_task({"kind": "deliver", "room_id": "room_02"})
	for i in 400:
		venue.advance_actors(0.05)
		if venue._owner.carrying: break
	check(venue._owner.carrying and venue._owner.position.y < 948 and venue._owner.position.distance_to(venue.PICKUP) < 25, "Owner collects behind counter without crossing desk")
	await shot("e04b_behind_counter")
	advance(15)
	check(room["request"].is_empty(), "Order reaches room after safe return route")
	sim.state.day = 3
	check(sim.security.spawn(sim.clock.minute), "Thief targets a real parked vehicle")
	advance(1)
	check(venue._thief_actor._people == ["thief"], "Thief has dedicated character art")
	var view: Dictionary = venue.save_view()
	var thief_position: Vector2 = venue._thief_actor.position
	venue._thief_actor.position = Vector2.ZERO
	venue.restore_view(view)
	check(venue._thief_actor.position.distance_to(thief_position) < 0.1, "Save view restores thief location during approach")
	venue._on_thief_pressed()
	check(sim.state.thief["catch_at"] == -1, "Click alone cannot catch thief before arrival")
	advance(10)
	check(sim.state.thief["state"] == "CAUGHT" and sim.state.night["thefts"] == 0, "Owner reaches thief in time and saves vehicle")
	await shot("e05_caught")
	sim.state.thief = {}
	sim.security.spawn(sim.clock.minute)
	var money: int = sim.state.money
	sim.clock.minute = sim.state.thief["escape"]
	sim.security.tick(sim.clock.minute)
	venue.advance_actors(0)
	check(sim.state.money == money - 8000000 and party["stolen_bikes"] == 1 and venue._bikes.filter(func(b): return b.visible).size() == 2, "Missed thief removes a bike and charges substantial compensation once")
	game._show_waiters()
	check(button("Thuê bảo vệ") != null, "Guard recruitment lives with other staff")
	await shot("e06_staff")
	for panel in ["stock", "upgrades", "ledger"]:
		if panel == "stock": game._show_stock()
		elif panel == "upgrades": game._show_upgrades()
		else: game._show_ledger()
		await process_frame
		var readable: bool = true
		for label in game._overlay.find_children("*", "Label", true, false):
			readable = readable and label.get_theme_font_size("font_size") >= 22
		check(readable, "Readable text size in " + panel)
		await shot("e06_" + panel)
	game._close_overlay()
	for i in 400:
		if sim.state.phase == "OPEN": sim.step_minute()
	venue.advance_actors(0)
	check(venue._bikes.all(func(b): return not b.visible), "All guests leave: yard empty")
	await process_frame
	await process_frame
	check(game._overlay_kind == "summary", "Night ends with summary")
	var next: Button = button("Sang đêm tiếp theo")
	var scroller = game._overlay.find_child("DialogScroll", true, false)
	check(next != null and not scroller.is_ancestor_of(next) and root.get_visible_rect().encloses(next.get_global_rect()), "Next-night button stays visible outside scrolling summary")
	sim.save_game("user://summary_fixture.json", venue.save_view())
	await shot("e07_summary")
	next.pressed.emit()
	check(sim.state.phase == "PREP" and sim.state.day == 4 and sim.clock.minute == 0 and sim.clock._modal_locks == 0 and venue._btn_open.visible, "Summary action reaches next day, clears modal and enables opening")
	venue._btn_open.pressed.emit()
	for i in 400:
		if sim.state.phase == "OPEN": sim.step_minute()
	game._close_overlay()
	venue.advance_actors(0)
	venue._btn_open.pressed.emit()
	check(sim.state.phase == "PREP" and sim.state.day == 5, "Closing summary still leaves a working next-day action")
	await shot("e08_next_day")
	sim.hire_staff("staff_3")
	venue.advance_actors(0)
	var original_speed: float = venue._staff_actors["staff_3"].speed
	check(sim.buy_upgrade("staff_training") == "", "Purchase training after hiring staff")
	venue.advance_actors(0)
	check(venue._staff_actors["staff_3"].speed > original_speed, "Training immediately accelerates existing staff actors")
	check(venue._lbl_tasks.get_theme_font_size("font_size") >= 22, "Pending-work label remains readable")
	print("EXPERIENCE FAILURES: ", failures)
	quit(1 if failures else 0)
