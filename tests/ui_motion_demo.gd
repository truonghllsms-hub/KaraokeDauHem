extends SceneTree
## Reproducible visual review of walking, singing, impatience and rest.
## --fixed-fps 15 --write-movie preview.avi --script res://tests/ui_motion_demo.gd

func _initialize() -> void:
	_run()

func _run() -> void:
	var game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var sim = game.sim
	var venue = game.venue
	game.set_process(false)
	venue.set_process(false)
	sim.customers.spawning_enabled = false
	sim.service.enabled = false
	for id in ["host_1", "host_3", "host_5", "host_9", "host_10", "host_11"]:
		sim.hire_host(id)
	sim.set_guard(true)
	sim.open_doors()
	var first = sim.customers.add_group("middle_aged_men", 5, 120, sim.clock.minute)
	var second = sim.customers.add_group("aunties", 3, 120, sim.clock.minute)
	var queue = sim.customers.add_group("young_men", 4, 120, sim.clock.minute)
	for group in [first, second]:
		group["wants_host"] = true
		group["host_requested_count"] = 3
		group["host_request"] = "PENDING"
	first["host_gender"] = "female"
	second["host_gender"] = "male"
	sim.assign_group(first["id"], "room_01")
	sim.assign_group(second["id"], "room_02")
	for id in ["host_1", "host_3", "host_5"]:
		sim.assign_host(id, "room_01")
	for id in ["host_9", "host_10", "host_11"]:
		sim.assign_host(id, "room_02")
	venue._owner.walk_to(venue._route(venue.OWNER_HOME, venue._work_position("room_01")))
	for frame in 180:
		if frame == 55:
			venue._owner.walk_to(venue._route(venue._owner.position, venue.OWNER_HOME))
		if frame == 90:
			queue["arrived_at"] = sim.clock.minute - int(queue["patience"] * 0.75)
		if frame == 105:
			var host = sim.hosts.get_host("host_3")
			host["energy"] = 30
			sim.hosts._complete(host, sim.clock.minute)
		if frame == 140:
			queue["arrived_at"] = sim.clock.minute - queue["patience"] + 1
			first["satisfaction"] = 40
		sim.advance(1.0 / 15.0)
		venue.advance_actors(1.0 / 15.0)
		game._refresh()
		await process_frame
	assert(sim.check_invariants().is_empty())
	quit(0)
