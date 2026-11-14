extends SceneTree
const Loader = preload("res://scripts/core/data_loader.gd")
const Sim = preload("res://scripts/core/simulation.gd")
var errors: int = 0
func _initialize() -> void:
	_run()
func check(ok: bool, label: String) -> void:
	print(("OK " if ok else "FAIL ") + label)
	if not ok:
		errors += 1
func _run() -> void:
	var sim = Sim.new(Loader.load_all(), 78)
	check(sim.state.rooms.size() == 10 and sim.state.rooms.filter(func(r): return r["floor"] == 1).size() == 4 and sim.state.rooms.filter(func(r): return r["floor"] == 2).size() == 6, "Exactly four standard rooms and six VIP rooms")
	var money: int = sim.state.money
	check(sim.rooms.floor_unlocked(2) and sim.room_info("room_05")["can_equip_now"], "VIP floor needs only money, no reputation")
	check(sim.unlock_room("room_05") == "" and sim.state.money == money - 6000000, "Equipping a VIP room charges its price once")
	sim.economy.record("TEST", 30000000, "fund")
	check(sim.unlock_room("room_06") == "" and sim.rooms.get_room("room_06")["price_per_hour"] > sim.rooms.get_room("room_01")["price_per_hour"], "VIP rooms unlock individually at premium rates")
	var game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var venue = game.venue
	game.set_process(false)
	venue.set_process(false)
	game.sim.customers.spawning_enabled = false
	game.sim.service.enabled = false
	check(venue.current_floor == 1, "Game starts on the ground floor")
	check(venue._room_ui["room_01"]["root"].visible and not venue._room_ui["room_05"]["root"].visible, "Only ground-floor hit targets visible initially")
	game.sim.unlock_room("room_03")
	game.sim.unlock_room("room_04")
	game.sim.state.reputation = 60
	game.sim.economy.record("TEST", 50000000, "fund")
	game.sim.unlock_room("room_05")
	check(venue.set_floor(2) and venue.current_floor == 2 and venue._room_ui["room_05"]["root"].visible and not venue._room_ui["room_01"]["root"].visible, "Floor switch swaps art and interaction targets")
	var route: Array = venue._route(venue.OWNER_HOME, venue._work_position("room_05"))
	check(route.has(venue.STAIR1) and route.has(venue.STAIR2), "Cross-floor route uses both staircase landings")
	for id in ["host_1", "host_2"]:
		game.sim.hire_host(id)
	game.sim.open_doors()
	var group = game.sim.customers.add_group("middle_aged_men", 3, 120, 0)
	group["wants_host"] = true
	group["host_requested_count"] = 2
	group["host_gender"] = "female"
	check(game.sim.assign_group(group["id"], "room_05") == "", "Party can check in to a VIP room")
	group["host_request"] = "PENDING"
	for id in ["host_1", "host_2"]:
		game.sim.assign_host(id, "room_05")
	venue._owner.walk_to(route)
	for i in 600:
		venue.advance_actors(0.1)
	var actor = venue._group_actors[group["id"]]
	check(not actor.is_moving() and venue._world_floor(actor.position) == 2 and actor.visible, "Customers walk upstairs and remain on the correct floor")
	check(venue._world_floor(venue._owner.position) == 2 and venue._host_actors["host_1"].visible, "Owner and companions also use stairs")
	check(game.sim.check_invariants().is_empty(), "Cross-floor services preserve simulation invariants")
	game._refresh()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://floor2-live.png")
	venue.set_floor(1)
	check(not actor.visible and not venue._owner.visible and not venue._host_actors["host_1"].visible, "Upstairs actors cannot appear over downstairs artwork")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://floor1-live.png")
	venue._stairs_button.pressed.emit()
	check(venue.current_floor == 2, "Clicking the staircase switches floors")
	print("two_floors: %d errors" % errors)
	quit(0 if errors == 0 else 1)
