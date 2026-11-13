extends SceneTree
## Integration checks for the approved illustrated characters and real room flow.
const Art = preload("res://scripts/ui/character_art.gd")
const Motion = preload("res://scripts/ui/character_motion.gd")
var errors: int = 0
var game
var out_dir: String = "user://characters"

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()

func check(ok: bool, label: String) -> void:
	print(("OK " if ok else "FAIL ") + label)
	if not ok:
		errors += 1

func _run() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.sim.clock.toggle_pause()
	game.sim.customers.spawning_enabled = false
	game.sim.service.enabled = false
	var coverage: bool = true
	for kind in game.sim.data["customers"]["types"]:
		for person in kind["sprites"]:
			coverage = coverage and Art.texture(person) is AtlasTexture
			coverage = coverage and Art.texture(person, "seated") != Art.texture(person)
	for host in game.sim.data["hosts"]:
		coverage = coverage and Art.texture(host["sprite"]) is AtlasTexture
		coverage = coverage and Art.texture(host["sprite"], "seated") != Art.texture(host["sprite"])
	check(coverage, "Every customer and recruit has illustrated standing and seated artwork")
	check(game.sim.hire_host("host_1") == "" and game.sim.hire_host("host_3") == "" and game.sim.hire_host("host_5") == "", "Recruit three approved hosts through simulation")
	for id in ["host_9", "host_10", "host_11"]:
		check(game.sim.hire_host(id) == "", "Recruit new male host " + id)
	game.sim.set_guard(true)
	game.sim.open_doors()
	game.venue.advance_actors(0.0)
	check(game.venue._guard.visible, "Hired guard appears on the sidewalk")
	var group = game.sim.customers.add_group("middle_aged_men", 3, 120, game.sim.clock.minute)
	var women = game.sim.customers.add_group("aunties", 3, 120, game.sim.clock.minute)
	game.venue.advance_actors(0.0)
	check(game.sim.assign_group(group["id"], "room_01") == "" and game.sim.assign_group(women["id"], "room_02") == "", "Groups enter both open rooms")
	for party in [group, women]:
		party["wants_host"] = true
		party["host_requested_count"] = 3
	group["host_gender"] = "female"
	women["host_gender"] = "male"
	var young = game.sim.customers.add_group("young_men", 4, 120, game.sim.clock.minute)
	for i in 100:
		game.venue.advance_actors(0.1)
	var actor = game.venue._group_actors[group["id"]]
	check(not actor.is_moving() and actor._sprites[0].texture == Art.texture("middle_m_1", "seated"), "Guests switch from walking to seated singing after reaching the sofa")
	var right_actor = game.venue._group_actors[women["id"]]
	check(right_actor._sprites.all(func(s): return s.flip_h) and actor._sprites.all(func(s): return not s.flip_h), "Both room columns face the television")
	check(game.venue._group_actors[young["id"]]._sprites.size() == 4, "Every young guest is rendered individually")
	group["host_request"] = "PENDING"
	check(game.sim.assign_host("host_1", "room_01") == "", "Assign host to a genuine customer request")
	for id in ["host_3", "host_5"]:
		check(game.sim.assign_host(id, "room_01") == "", "Assign another female companion " + id)
	women["host_request"] = "PENDING"
	for id in ["host_9", "host_10", "host_11"]:
		check(game.sim.assign_host(id, "room_02") == "", "Assign male companion " + id)
	game.venue.advance_actors(0.1)
	var host_actor = game.venue._host_actors["host_1"]
	check(host_actor.is_moving() and host_actor._sprites[0].texture.get_meta("animation", "") == "walk", "Host stands up and walks to the assigned room")
	for i in 80:
		game.venue.advance_actors(0.1)
	check(host_actor.singing and host_actor._sprites[0].texture in [Art.texture("lancan_1", "seated"), Motion.expression_texture("lancan_1", "cheer")], "Host sits down and sings beside the guests")
	var sprite: Sprite2D = host_actor._sprites[0]
	check(absf(sprite.texture.get_height() * sprite.scale.y - 104.0 * host_actor.seated_scale) < 1.0 and is_zero_approx(sprite.offset.y + sprite.texture.get_height() * 0.5), "Pose scaling preserves the foot anchor and readable room size")
	var paired_ok: bool = true
	for room_id in ["room_01", "room_02"]:
		var plan: Dictionary = game.venue._seating(room_id)
		var room = game.sim.rooms.get_room(room_id)
		var party_actor = game.venue._group_actors[room["group_id"]]
		for i in party_actor._sprites.size():
			if game.venue._actors.to_local(party_actor._sprites[i].global_position).distance_to(plan["guests"][i]) >= 2.0:
				print("SEAT ", room_id, " guest ", i, " actual ", game.venue._actors.to_local(party_actor._sprites[i].global_position), " wanted ", plan["guests"][i])
			paired_ok = paired_ok and game.venue._actors.to_local(party_actor._sprites[i].global_position).distance_to(plan["guests"][i]) < 2.0
		for id in room["host_ids"]:
			var paired = game.sim.hosts.get_host(id)
			var paired_actor = game.venue._host_actors[id]
			if paired_actor.position.distance_to(plan["hosts"][paired["guest_index"]]) >= 2.0 or paired_actor._sprites[0].flip_h != (room_id == "room_02"):
				print("PAIR ", id, " actual ", paired_actor.position, " wanted ", plan["hosts"][paired["guest_index"]], " left ", paired_actor._sprites[0].flip_h)
			paired_ok = paired_ok and paired_actor.position.distance_to(plan["hosts"][paired["guest_index"]]) < 2.0
			paired_ok = paired_ok and paired_actor._sprites[0].flip_h == (room_id == "room_02")
	check(paired_ok, "Each guest and companion has a separate sofa seat, facing the TV")
	game._refresh()
	await shot("01_characters_in_game")
	game._show_lancan()
	await shot("02_recruitment")
	var portraits: Array = game._overlay.find_children("*", "TextureRect", true, false)
	check(portraits.size() == game.sim.data["hosts"].size() and portraits[0].texture == Art.texture("lancan_1"), "All recruitment portraits match the in-game characters")
	var scrollers: Array = game._overlay.find_children("*", "ScrollContainer", true, false)
	scrollers[0].scroll_vertical = 100000
	await shot("02b_male_hosts")
	game._close_overlay()
	group["satisfaction"] = 40
	game.venue.advance_actors(0.0)
	check(actor.mood == "angry" and actor._sprites[0].texture == Motion.expression_texture("middle_m_1", "angry_seated"), "Dissatisfied guests frown while seated, without changing gameplay")
	group["satisfaction"] = 75
	women["satisfaction"] = 40
	game.venue.advance_actors(1.5)
	check(right_actor._sprites.all(func(s): return s.flip_h) and game.venue._host_actors["host_9"]._sprites[0].flip_h, "Right-room guests and male hosts keep facing TV after expression changes")
	women["satisfaction"] = 75
	var waiting = game.sim.customers.add_group("friends", 3, 120, game.sim.clock.minute)
	for i in 80:
		game.venue.advance_actors(0.1)
	waiting["wait_minutes"] = int(waiting["patience"] * 0.75)
	game.venue.advance_actors(0.0)
	var waiting_actor = game.venue._group_actors[waiting["id"]]
	check(waiting_actor.mood == "impatient" and waiting_actor._sprites[0].texture == Motion.expression_texture("friend_m", "impatient"), "Waiting guests cross their arms and frown as patience falls")
	var resting = game.sim.hosts.get_host("host_3")
	game.sim.hosts._complete(resting, game.sim.clock.minute)
	resting["state"] = "RESTING"
	resting["rest_end"] = game.sim.clock.minute + 10
	for i in 80:
		game.venue.advance_actors(0.1)
	check(game.venue._host_actors["host_3"]._sprites[0].texture == Motion.expression_texture("lancan_3", "tired"), "Resting hosts show a tired face and lowered microphone")
	await shot("03_emotions")
	actor.walk_to([Vector2(510, 800)])
	actor.advance(0.1)
	var left: float = INF
	var right: float = -INF
	for person_sprite in actor._sprites:
		var half_width: float = person_sprite.texture.get_width() * person_sprite.scale.x * 0.5
		left = minf(left, person_sprite.position.x - half_width)
		right = maxf(right, person_sprite.position.x + half_width)
	check(right - left <= 101.0, "Walking groups fit the central corridor instead of spreading through walls")
	var owner = game.venue._owner
	owner.walk_to([owner.position - Vector2(0, 100)])
	owner.advance(0.01)
	check(owner._sprites[0].texture == Motion.walk_texture("owner", int(owner._walk_distance / 26.0), "back"), "Owner faces backwards when walking up")
	var frames: Dictionary = {}
	for i in 30:
		owner.walk_to([owner.position - Vector2(0, 100)])
		owner.advance(0.025)
		frames[owner._sprites[0].texture] = true
	check(frames.size() == 4, "Walking cycles through four actual leg and arm drawings")
	var before: Texture2D = owner._sprites[0].texture
	var before_position: Vector2 = owner.position
	owner.advance(0.0)
	check(owner._sprites[0].texture == before and owner.position == before_position, "Pausing freezes both movement and walk frames")
	owner.walk_to([])
	owner.pose = "cleaning"
	owner.advance(0.0)
	check(owner._sprites[0].texture == Art.texture("owner", "cleaning"), "Cleaning uses the illustrated owner with a broom")
	check(game.sim.check_invariants().is_empty(), "Character rendering preserves gameplay invariants")
	print("ui_characters: %d errors" % errors)
	quit(0 if errors == 0 else 1)

func shot(file_name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file_name + ".png"))
