extends SceneTree
const Art = preload("res://scripts/ui/character_art.gd")
var failures: int = 0
var game
var sim
var venue
func _initialize() -> void:
	_run()
func check(value: bool, label: String) -> void:
	print(("ok " if value else "FAIL ") + label)
	if not value: failures += 1
func advance(seconds: float) -> void:
	for i in int(seconds * 20): venue.advance_actors(0.05)
func order(room: String) -> int:
	sim.service._open(sim.rooms.get_room(room), {"kind": "ORDER", "product_id": "nuoc_ngot", "quantity": 2, "price": 50000, "text": "Nước ngọt"}, sim.clock.minute, 100)
	return sim.rooms.get_room(room)["request"]["id"]
func _run() -> void:
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
	check(sim.equip_room("room_05") == "", "Equip VIP during preparation")
	sim.open_doors()
	var party = sim.customers.add_group("company", 5, 120, sim.clock.minute)
	sim.assign_group(party["id"], "room_01")
	order("room_01")
	venue.advance_actors(0)
	check(not venue._owner.carrying, "Owner starts empty-handed")
	venue._add_task({"kind": "deliver", "room_id": "room_01"})
	advance(0.1)
	check(not venue._owner.carrying and party["bill_items"].is_empty(), "No tray or charge before fridge")
	var picked: bool = false
	for i in 400:
		venue.advance_actors(0.05)
		if venue._owner.carrying:
			picked = true
			check(venue._owner.position.distance_to(venue.PICKUP) < 20, "Owner acquires tray at fridge")
			break
	check(picked, "Owner reaches fridge")
	advance(20)
	check(not venue._owner.carrying and party["bill_items"].size() == 1, "Owner delivers once and returns empty-handed")
	sim.hire_staff("staff_3")
	sim.hire_staff("staff_5")
	sim.staff.enabled = true
	var request: int = order("room_01")
	for i in 4: sim.step_minute()
	var member: Dictionary = sim.staff.get_member("staff_3")
	check(member["task"].get("phase", "") == "PICKUP", "Waiter first travels to fridge")
	check(not sim.staff.confirm_delivery("staff_3", request, sim.clock.minute), "Cannot deliver before pickup")
	venue.advance_actors(0)
	var waiter = venue._staff_actors["staff_3"]
	check(not waiter.carrying, "Waiter empty-handed before pickup")
	picked = false
	for i in 400:
		venue.advance_actors(0.05)
		if member["task"].get("phase", "") == "CARRY":
			picked = true
			check(waiter.position.distance_to(venue.PICKUP) < 2, "Waiter picks up only at fridge")
			break
	check(picked and party["bill_items"].size() == 1, "Pickup does not bill customer")
	advance(15)
	check(member["task"].is_empty() and not waiter.carrying and party["bill_items"].size() == 2, "Waiter delivers once and clears tray")
	check(not sim.staff.confirm_delivery("staff_3", request, sim.clock.minute), "Duplicate delivery rejected")
	check(Art.staff_sprite(sim.staff.get_member("staff_1")) == "janitor_m" and Art.staff_sprite(sim.staff.get_member("staff_5")) == "reception_f", "Janitor and receptionist have distinct artwork")
	order("room_01")
	venue._add_task({"kind": "deliver", "room_id": "room_01"})
	advance(0.1)
	sim.deliver_order("room_01")
	advance(0.1)
	check(venue._current_task.is_empty() and not venue._owner.carrying, "Cancelled order clears owner tray")
	# Second-floor delivery must traverse the stair portals before returning idle.
	sim.staff.enabled = false
	var vip = sim.customers.add_group("company", 5, 120, sim.clock.minute)
	check(sim.assign_group(vip["id"], "room_05") == "", "Seat VIP group")
	order("room_05")
	venue._add_task({"kind": "deliver", "room_id": "room_05"})
	advance(40)
	check(vip["bill_items"].size() == 1 and not venue._owner.carrying and venue._owner.position.y > 1400, "VIP delivery uses stairs and ends empty-handed")
	var music = game._music
	for index in 3:
		music.select_track(index)
		check(music._player.stream != null and music._player.stream.get_length() > 30, "Music track decodes: " + str(index))
	music.set_volume(0.37)
	music.set_enabled(false)
	var config: ConfigFile = ConfigFile.new()
	config.load(music.SETTINGS_PATH)
	check(not music.enabled and (not music._player.playing or music._player.stream_paused) and is_equal_approx(config.get_value("music", "volume"), 0.37), "Music mute and volume persist separately")
	game._show_music()
	await process_frame
	check(game._overlay != null, "Music panel opens in game")
	game._close_overlay()
	print("FRIDGE FAILURES: ", failures)
	quit(1 if failures else 0)
