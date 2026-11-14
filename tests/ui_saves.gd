extends SceneTree
const SaveManager = preload("res://scripts/core/save_manager.gd")
var errors: int = 0
var out_dir: String = "user://ui_saves"
var game
var venue
var sim
func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty(): out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()
func check(value: bool, label: String) -> void:
	print(("ok " if value else "FAIL ") + label)
	if not value: errors += 1
func advance(seconds: float) -> void:
	for i in int(seconds * 20): venue.advance_actors(0.05)
func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
func _run() -> void:
	for path in SaveManager.MANUAL_PATHS:
		for file in [path, SaveManager.backup_path(path)]:
			if FileAccess.file_exists(file): DirAccess.remove_absolute(file)
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	await shot("s01_mat_tien")
	menu._show_loads()
	await shot("s02_o_trong")
	menu.queue_free()
	await process_frame
	game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	sim = game.sim
	venue = game.venue
	game.set_process(false)
	venue.set_process(false)
	sim.customers.spawning_enabled = false
	sim.service.enabled = false
	sim.staff.enabled = false
	sim.open_doors()
	var party = sim.customers.add_group("company", 5, 120, sim.clock.minute)
	sim.assign_group(party["id"], "room_01")
	var room: Dictionary = sim.rooms.get_room("room_01")
	sim.service._open(room, {"kind": "ORDER", "product_id": "nuoc_ngot", "quantity": 2, "price": 50000, "text": "Nước ngọt"}, sim.clock.minute, 100)
	venue._add_task({"kind": "deliver", "room_id": "room_01"})
	for i in 400:
		venue.advance_actors(0.05)
		if venue._owner.carrying: break
	check(venue._owner.carrying and party["bill_items"].is_empty(), "Save test starts while carrying undelivered order")
	var position_before: Vector2 = venue._owner.position
	sim.clock.paused = true
	game._show_saves()
	await shot("s03_luu_game")
	var slot: Button = game._overlay.find_child("Slot1", true, false)
	slot.pressed.emit()
	check(SaveManager.has_save(SaveManager.MANUAL_PATHS[0]), "Click save slot creates manual save")
	await shot("s04_da_luu")
	Engine.set_meta("karaoke_load_save", true)
	Engine.set_meta("karaoke_load_path", SaveManager.MANUAL_PATHS[0])
	game.queue_free()
	await process_frame
	game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.venue.set_process(false)
	sim = game.sim
	venue = game.venue
	sim.customers.spawning_enabled = false
	sim.service.enabled = false
	sim.staff.enabled = false
	check(sim.state.phase == "OPEN" and venue._owner.carrying and venue._owner.position.distance_to(position_before) < 2, "Load restores owner position and carried tray")
	check(not venue._current_task.is_empty() and venue._current_task.get("picked", false), "Load restores in-flight delivery stage")
	advance(15)
	var restored_party: Dictionary = sim.state.groups[0]
	check(restored_party["bill_items"].size() == 1 and not venue._owner.carrying, "Resumed delivery bills exactly once and clears tray")
	check(sim.check_invariants().is_empty(), "Saved game remains consistent")
	game._show_saves()
	await process_frame
	slot = game._overlay.find_child("Slot1", true, false)
	var before: String = FileAccess.get_file_as_string(SaveManager.MANUAL_PATHS[0])
	slot.pressed.emit()
	check(slot.text.contains("Ghi đè") and FileAccess.get_file_as_string(SaveManager.MANUAL_PATHS[0]) == before, "Existing slot asks before overwrite")
	game._close_overlay()
	game.queue_free()
	await process_frame
	menu = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	check(menu._latest_path == SaveManager.MANUAL_PATHS[0], "Continue selects latest manual save")
	menu._show_loads()
	await shot("s05_tai_game")
	print("SAVE UI ERRORS: ", errors)
	quit(1 if errors else 0)
