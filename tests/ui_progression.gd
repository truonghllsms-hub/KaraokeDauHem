extends SceneTree
## Chơi ba ván mới, mỗi ván ba đêm, qua các thao tác giao diện và đường đi thực tế.
const Simulation = preload("res://scripts/core/simulation.gd")
const SaveManager = preload("res://scripts/core/save_manager.gd")
var game
var sim
var venue
var failures: int = 0
var out: String = "/workspace/work/progression-play-shots"
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	_run()
func check(ok: bool, label: String) -> void:
	print(("ok " if ok else "FAIL ") + label)
	if not ok: failures += 1
func press(text: String) -> bool:
	if game._overlay == null: return false
	for node in game._overlay.find_children("*", "Button", true, false):
		if node.text == text and not node.disabled:
			node.pressed.emit()
			return true
	return false
func shot(name: String) -> void:
	game._refresh()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name+".png"))
func equip(id: String) -> void:
	venue.selected_room = id
	game._show_venue_panel()
	var label: String = sim.room_info(id)["equip_button_text"]
	check(press(label), "Purchase room through panel: " + id)
	game._close_overlay()
func prepare(night: int) -> void:
	if night == 2 and sim.state.money > 7000000:
		equip("room_03")
		game._show_waiters()
		check(press("Tuyển · Mận"), "Hire waiter via staff panel")
		game._close_overlay()
	if night == 3 and sim.state.money > 6000000:
		equip("room_04")
		game._show_upgrades()
		check(press("Lên cấp 1 · 1.500.000đ"), "Buy microphone upgrade through panel")
		game._close_overlay()
		if sim.rooms.unlocked_count() >= 4:
			game._show_lancan()
			for node in game._overlay.find_children("*", "Button", true, false):
				if node.text == "Tuyển" and not node.disabled:
					node.pressed.emit()
					break
			game._close_overlay()
	# Exercise price controls without changing the intended default.
	venue.selected_room = "room_02"
	game._show_venue_panel()
	check(press("Tăng giá giờ") and press("Giảm giá giờ") and sim.rooms.get_room("room_02")["price_per_hour"] == 250000, "Room price buttons +10K and -10K")
	game._close_overlay()
	venue.selected_group = 0
	venue.selected_room = ""
func act() -> void:
	if sim.security.is_active() and is_instance_valid(venue._thief_actor) and sim.state.thief.get("chased_by", "") == "": venue._on_thief_pressed()
	var tasks: Array = venue._tasks + [venue._current_task]
	var pending_groups: Array = []
	var pending_rooms: Array = []
	for task in tasks:
		if task.get("kind", "") == "seat":
			pending_groups.append(task["group_id"])
			pending_rooms.append(task["room_id"])
	for group in sim.customers.waiting_groups():
		if group["id"] in pending_groups: continue
		for room in sim.state.rooms:
			if room["id"] in pending_rooms: continue
			if sim.preview_assign(group["id"], room["id"])["reason"] == "":
				venue.on_group_pressed(group["id"])
				venue.on_room_pressed(room["id"])
				pending_rooms.append(room["id"])
				break
	for room in sim.state.rooms:
		if room["state"] == "DIRTY" or not room["request"].is_empty():
			venue.on_room_pressed(room["id"])
			if game._overlay_kind == "choice":
				press("Tăng điều hòa" if room["request"]["kind"] == "HOT" else "Từ chối khéo")
		if room["state"] == "OCCUPIED":
			for host in sim.state.hosts:
				if sim.hosts.check_assign(host, room, sim.clock.minute) == "":
					venue.on_host_pressed(host["id"])
					venue.on_room_pressed(room["id"])
func _run() -> void:
	for seed_value in [7,42,2024]:
		game = load("res://scenes/game.tscn").instantiate()
		root.add_child(game)
		await process_frame
		game.set_process(false)
		sim = game.sim
		venue = game.venue
		venue.set_process(false)
		sim.rng.seed = seed_value
		sim.state.rng_seed = seed_value
		check(sim.state.money == 15000000 and sim.state.staff.is_empty() and sim.state.hosts.is_empty(), "Fresh game, real starting money and no staff")
		for night in [1,2,3]:
			prepare(night)
			venue._btn_open.pressed.emit()
			check(sim.state.phase == "OPEN" and sim.clock._modal_locks == 0, "Open night " + str(night))
			var arrived: Dictionary = {}
			var largest_queue: int = 0
			var minute_guard: int = 0
			var problems: Array = []
			while sim.state.phase == "OPEN" and minute_guard < 370:
				minute_guard += 1
				act()
				for group in sim.state.groups: arrived[group["id"]] = true
				largest_queue = maxi(largest_queue, sim.customers.waiting_groups().size())
				for frame in 10:
					venue._line_clock += 0.2
					venue.advance_actors(0.2)
				sim.step_minute()
				problems.append_array(sim.check_invariants())
				if minute_guard % 12 == 0:
					game._refresh()
					await process_frame
				if seed_value == 7 and night == 1 and minute_guard == 35: await shot("tutorial_order")
				if seed_value == 42 and night == 3 and minute_guard == 100: await shot("day3_live")
				if night == 2 and minute_guard == 90:
					var path: String = "user://play_mid.json"
					check(sim.save_game(path, venue.save_view()) == "", "Save during real room/order movement")
					var saved: Dictionary = Simulation.create_from_save(sim.data, path)
					check(saved["ok"] and saved["sim"].state.money == sim.state.money and saved["sim"].clock.minute == sim.clock.minute, "Saved shift loads with correct money and time")
			var summary: Dictionary = sim.last_summary()
			print("PLAY seed=%d night=%d minutes=%d served=%d unserved=%d peak_waiting=%d money=%d profit=%d rating=%s" % [seed_value,night,sim.clock.minute,summary.get("served",0),summary.get("unserved",0),largest_queue,sim.state.money,summary.get("profit",0),sim.rating_text()])
			check(sim.state.phase == "SUMMARY" and sim.economy.ledger_matches_balance() and problems.is_empty(), "Night finished, accounting and invariants correct")
			if night == 1: check(arrived.size() == 2 and summary["served"] == 2 and summary["unserved"] == 0 and largest_queue <= 1, "Tutorial: two served, no extra queued group")
			await process_frame
			game._refresh()
			await process_frame
			if seed_value == 7 and night == 1: await shot("tutorial_summary")
			check(press("Sang đêm tiếp theo") and sim.state.day == night+1 and sim.state.phase == "PREP" and sim.clock._modal_locks == 0, "Next day works through visible summary action")
		game.queue_free()
		await process_frame
	print("UI PROGRESSION FAILURES: ", failures)
	quit(1 if failures else 0)
