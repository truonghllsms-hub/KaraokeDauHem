extends SceneTree
var errors: int = 0
var screenshot_path: String = "user://five-guests-fixed.png"
func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		screenshot_path = args[0]
	_run()
func check(ok: bool, label: String) -> void:
	print(("OK " if ok else "FAIL ") + label)
	if not ok:
		errors += 1
func _run() -> void:
	var game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.venue.set_process(false)
	var sim = game.sim
	sim.customers.spawning_enabled = false
	sim.service.enabled = false
	for id in ["host_1", "host_2", "host_3", "host_4", "host_5"]:
		sim.hire_host(id)
	sim.open_doors()
	var group = sim.customers.add_group("middle_aged_men", 5, 120, 0)
	group["wants_host"] = true
	group["host_gender"] = "female"
	group["host_requested_count"] = 5
	sim.assign_group(group["id"], "room_01")
	group["host_request"] = "PENDING"
	for id in ["host_1", "host_2", "host_3", "host_4", "host_5"]:
		check(sim.assign_host(id, "room_01") == "", "Five-guest party accepts " + id)
	for i in 800:
		game.venue.advance_actors(0.1)
	var actor = game.venue._group_actors[group["id"]]
	check(actor._sprites.size() == 5 and actor.scale == Vector2.ONE, "All five guests remain full-size")
	for sprite in actor._sprites:
		check(absf(sprite.texture.get_height() * sprite.scale.y - 94.0) < 0.01, "Guest seated height is fixed at 94 pixels")
	actor.set_highlight(true)
	check(actor.scale == Vector2.ONE, "Selecting a party cannot resize its people")
	for id in ["host_1", "host_2", "host_3", "host_4", "host_5"]:
		var host = game.venue._host_actors[id]
		var sprite = host._sprites[0]
		check(absf(sprite.texture.get_height() * sprite.scale.y - 104.0) < 0.01 and host.scale == Vector2.ONE, "Companion stays at fixed 104-pixel seated height")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(screenshot_path)
	check(sim.check_invariants().is_empty(), "Five-guest party and five companion links remain valid")
	print("ui_fixed_sizes: %d errors" % errors)
	quit(0 if errors == 0 else 1)
