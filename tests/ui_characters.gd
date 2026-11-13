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
	game.sim.set_guard(true)
	game.sim.open_doors()
	game.venue.advance_actors(0.0)
	check(game.venue._guard.visible, "Hired guard appears on the sidewalk")
	var group = game.sim.customers.add_group("friends", 3, 120, game.sim.clock.minute)
	var birthday = game.sim.customers.add_group("birthday", 3, 120, game.sim.clock.minute)
	game.venue.advance_actors(0.0)
	check(game.sim.assign_group(group["id"], "room_01") == "" and game.sim.assign_group(birthday["id"], "room_02") == "", "Groups enter both open rooms")
	for i in 100:
		game.venue.advance_actors(0.1)
	var actor = game.venue._group_actors[group["id"]]
	check(not actor.is_moving() and actor._sprites[0].texture == Art.texture("friend_m", "seated"), "Guests switch from walking to seated singing after reaching the sofa")
	group["host_request"] = "PENDING"
	check(game.sim.assign_host("host_1", "room_01") == "", "Assign host to a genuine customer request")
	game.venue.advance_actors(0.1)
	var host_actor = game.venue._host_actors["host_1"]
	check(host_actor.is_moving() and host_actor._sprites[0].texture.get_meta("animation", "") == "walk", "Host stands up and walks to the assigned room")
	for i in 80:
		game.venue.advance_actors(0.1)
	check(host_actor.singing and host_actor._sprites[0].texture in [Art.texture("lancan_1", "seated"), Motion.expression_texture("lancan_1", "cheer")], "Host sits down and sings beside the guests")
	var sprite: Sprite2D = host_actor._sprites[0]
	check(absf(sprite.texture.get_height() * sprite.scale.y - 104.0) < 1.0 and is_zero_approx(sprite.offset.y + sprite.texture.get_height() * 0.5), "Pose scaling preserves the foot anchor and readable room size")
	game._refresh()
	await shot("01_characters_in_game")
	game._show_lancan()
	await shot("02_recruitment")
	var portraits: Array = game._overlay.find_children("*", "TextureRect", true, false)
	check(portraits.size() == 8 and portraits[0].texture == Art.texture("lancan_1"), "All eight recruitment portraits match the in-game characters")
	game._close_overlay()
	group["satisfaction"] = 40
	game.venue.advance_actors(0.0)
	check(actor.mood == "angry" and actor._sprites[0].texture == Motion.expression_texture("friend_m", "angry_seated"), "Dissatisfied guests frown while seated, without changing gameplay")
	group["satisfaction"] = 75
	var waiting = game.sim.customers.add_group("friends", 3, 120, game.sim.clock.minute)
	for i in 80:
		game.venue.advance_actors(0.1)
	waiting["wait_minutes"] = int(waiting["patience"] * 0.75)
	game.venue.advance_actors(0.0)
	var waiting_actor = game.venue._group_actors[waiting["id"]]
	check(waiting_actor.mood == "impatient" and waiting_actor._sprites[0].texture == Motion.expression_texture("friend_m", "impatient"), "Waiting guests cross their arms and frown as patience falls")
	var resting = game.sim.hosts.get_host("host_3")
	resting["state"] = "RESTING"
	resting["rest_end"] = game.sim.clock.minute + 10
	game.venue.advance_actors(0.0)
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
