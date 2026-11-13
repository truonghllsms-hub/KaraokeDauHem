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
	sim.clock.toggle_pause()
	sim.customers.spawning_enabled = false
	sim.service.enabled = false
	sim.hire_host("host_1")
	sim.hire_host("host_3")
	sim.set_guard(true)
	sim.open_doors()
	var first = sim.customers.add_group("friends", 3, 120, sim.clock.minute)
	var second = sim.customers.add_group("birthday", 3, 120, sim.clock.minute)
	var queue = sim.customers.add_group("bolero_regular", 3, 120, sim.clock.minute)
	sim.assign_group(first["id"], "room_01")
	sim.assign_group(second["id"], "room_02")
	first["host_request"] = "PENDING"
	sim.assign_host("host_1", "room_01")
	venue._owner.walk_to(venue._route(venue.OWNER_HOME, venue._work_position("room_01")))
	for frame in 180:
		if frame == 55:
			venue._owner.walk_to(venue._route(venue._owner.position, venue.OWNER_HOME))
		if frame == 90:
			queue["wait_minutes"] = int(queue["patience"] * 0.75)
		if frame == 105:
			var host = sim.hosts.get_host("host_3")
			host["state"] = "RESTING"
			host["rest_end"] = sim.clock.minute + 10
		if frame == 140:
			queue["wait_minutes"] = queue["patience"] - 1
			first["satisfaction"] = 40
		venue.advance_actors(1.0 / 15.0)
		game._refresh()
		await process_frame
	quit(0)
