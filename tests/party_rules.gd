extends SceneTree
const Loader = preload("res://scripts/core/data_loader.gd")
const Sim = preload("res://scripts/core/simulation.gd")
const Seats = preload("res://scripts/ui/seating_plan.gd")
var errors: int = 0
var checks: int = 0
var data: Dictionary

func _init() -> void:
	data = Loader.load_all()
	check(data["errors"].is_empty(), "Party data validates")
	policy()
	multi_service()
	partial_and_cancel()
	seating()
	print("party_rules: %d checks, %d errors" % [checks, errors])
	quit(0 if errors == 0 else 1)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		errors += 1
	print(("OK " if ok else "FAIL ") + label)

func new_sim(seed_value: int = 77):
	var sim = Sim.new(data, seed_value)
	sim.customers.spawning_enabled = false
	sim.service.enabled = false
	return sim

func step(sim, minutes: int) -> void:
	for i in minutes:
		sim.step_minute()

func request(group, gender: String, count: int) -> void:
	group["wants_host"] = true
	group["host_gender"] = gender
	group["host_requested_count"] = count
	group["host_request"] = "PENDING"
	group["host_request_at"] = 0

func fees(group) -> int:
	return group["bill_items"].filter(func(item): return item["type"] == "LANCAN_FEE").size()

func policy() -> void:
	var sim = new_sim()
	var male: int = 0
	var female: int = 0
	var women_ok: bool = true
	for i in 500:
		var men = sim.customers.add_group("middle_aged_men", 4, 90, 0)
		male += 1 if men["host_gender"] == "male" else 0
		female += 1 if men["host_gender"] == "female" else 0
		women_ok = women_ok and men["composition"] == "men" and men["sprites"].size() == 4
		sim.customers.remove_group(men)
		var women = sim.customers.add_group("aunties", 4, 90, 0)
		women_ok = women_ok and women["host_gender"] == "male" and women["composition"] == "women"
		sim.customers.remove_group(women)
	check(women_ok, "Actual all-male/all-female members determine host preference")
	check(male > 10 and male < 100 and female > 400, "Men usually request women, with occasional male requests")
	var forced_data: Dictionary = data.duplicate(true)
	for kind in forced_data["customers"]["types"]:
		if kind["id"] in ["couple", "family"]:
			kind["lancan_chance"] = 100
	var family_sim = Sim.new(forced_data, 9)
	family_sim.customers.spawning_enabled = false
	family_sim.service.enabled = false
	family_sim.hire_host("host_9")
	family_sim.open_doors()
	for kind in ["couple", "family"]:
		var group = family_sim.customers.add_group(kind, 2 if kind == "couple" else 4, 90, 0)
		check(not group["wants_host"], kind + " cannot request hosts even with chance 100")
		family_sim.assign_group(group["id"], "room_01" if kind == "couple" else "room_02")
		request(group, "male", 1)
		check(family_sim.assign_host("host_9", group["room_id"]) != "", kind + " rejects a forced host assignment")

func multi_service() -> void:
	var sim = new_sim()
	for id in ["host_1", "host_2", "host_3", "host_8", "host_9", "host_10"]:
		check(sim.hire_host(id) == "", "Hire " + id)
	check(sim.hire_host("host_11") != "", "Global staff limit is six")
	sim.open_doors()
	var men = sim.customers.add_group("middle_aged_men", 3, 120, 0)
	var women = sim.customers.add_group("aunties", 4, 120, 0)
	sim.assign_group(men["id"], "room_01")
	sim.assign_group(women["id"], "room_02")
	request(men, "female", 3)
	request(women, "male", 2)
	check(sim.assign_host("host_8", "room_01") != "" and sim.assign_host("host_1", "room_02") != "", "Gender mismatch rejected before assignment")
	check(sim.assign_host("host_1", "room_01") == "" and sim.assign_host("host_8", "room_02") == "", "Assign first host to both parties")
	step(sim, 2)
	check(sim.assign_host("host_2", "room_01") == "", "Second host can join an active request")
	step(sim, 2)
	check(sim.assign_host("host_3", "room_01") == "" and sim.assign_host("host_9", "room_02") == "", "Each party accepts all requested companions")
	check(sim.assign_host("host_10", "room_02") != "", "No extra staff beyond the requested count")
	var room = sim.rooms.get_room("room_01")
	check(room["host_ids"].size() == 3 and sim.hosts.get_host("host_1")["guest_index"] == 0 and sim.hosts.get_host("host_2")["guest_index"] == 1 and sim.hosts.get_host("host_3")["guest_index"] == 2, "Hosts pair with three different guests")
	check(sim.check_invariants().is_empty(), "Multi-host links are valid")
	step(sim, 26)
	check(fees(men) == 1 and room["host_ids"].size() == 2 and room["host_id"] == "host_2" and men["host_request"] == "ACTIVE", "First completion preserves other sessions")
	check(sim.check_invariants().is_empty(), "Staggered completion preserves both room links")
	step(sim, 4)
	check(fees(men) == 3 and fees(women) == 2 and men["host_request"] == "DONE" and women["host_request"] == "DONE", "Bill each completed host once")
	sim.hosts._complete(sim.hosts.get_host("host_1"), sim.clock.minute)
	check(fees(men) == 3, "Repeating a completed callback cannot duplicate fees")
	check(room["host_ids"].is_empty() and sim.rooms.get_room("room_02")["host_ids"].is_empty(), "All sessions release their own room links")
	step(sim, 86)
	check(sim.economy.total_for_day(1, "LANCAN_FEE") == 5 * data["balance"]["lancan_fee"], "Checkout collects five individual service fees")
	check(sim.check_invariants().is_empty() and sim.economy.ledger_matches_balance(), "Multi-host checkout balances the ledger")

func partial_and_cancel() -> void:
	var sim = new_sim(19)
	sim.hire_host("host_1")
	sim.hire_host("host_2")
	sim.open_doors()
	var group = sim.customers.add_group("drinking", 3, 90, 0)
	sim.assign_group(group["id"], "room_01")
	request(group, "female", 2)
	sim.assign_host("host_1", "room_01")
	step(sim, 20)
	check(group["host_request_closed"] and sim.hosts.get_host("host_1")["state"] == "SERVING" and sim.assign_host("host_2", "room_01") != "", "Timeout closes missing slots while preserving active service")
	step(sim, 10)
	check(fees(group) == 1 and group["host_request"] == "DONE", "Partial request charges only the completed host")
	var cancel_sim = new_sim(31)
	cancel_sim.hire_host("host_1")
	cancel_sim.hire_host("host_2")
	cancel_sim.open_doors()
	var leaving = cancel_sim.customers.add_group("drinking", 3, 90, 0)
	cancel_sim.assign_group(leaving["id"], "room_01")
	request(leaving, "female", 2)
	cancel_sim.assign_host("host_1", "room_01")
	cancel_sim.assign_host("host_2", "room_01")
	var room = cancel_sim.rooms.get_room("room_01")
	room["session_end"] = 10
	step(cancel_sim, 10)
	check(fees(leaving) == 0 and room["host_ids"].is_empty() and cancel_sim.hosts.get_host("host_1")["state"] != "SERVING" and cancel_sim.hosts.get_host("host_2")["state"] != "SERVING", "Early checkout cancels every unfinished companion without fees")
	check(cancel_sim.check_invariants().is_empty(), "Cancellation leaves no orphaned staff")

func seating() -> void:
	var valid: bool = true
	for right in [false, true]:
		var rect: Rect2 = Rect2(559 if right else 24, 820, 421 if right else 434, 408)
		for guests in range(1, 16):
			for companions in range(0, mini(guests, 6) + 1):
				var plan: Dictionary = Seats.build(rect, guests, companions)
				valid = valid and plan["guests"].size() == guests and plan["hosts"].size() == companions
				var points: Array = plan["guests"] + plan["hosts"]
				var body: Vector2 = Vector2(88, 108) * plan["scale"] * 0.98
				for i in points.size():
					valid = valid and rect.has_point(points[i])
					var first: Rect2 = Rect2(points[i] - Vector2(body.x * 0.5, body.y), body)
					for j in range(i + 1, points.size()):
						var second: Rect2 = Rect2(points[j] - Vector2(body.x * 0.5, body.y), body)
						valid = valid and not first.intersects(second)
	check(valid, "All sofa layouts up to 15 guests and 6 companions have separate seats inside both room columns")
