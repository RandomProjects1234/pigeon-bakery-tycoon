class_name Military
extends RefCounted
## General Coo's supply contracts. Orders arrive at random once the Supply
## Depot exists. Each one lists products, a deadline and a reward, and you
## can haggle for more money or more time before accepting. Push too hard
## and the General storms off.

const RANKS := [[0, "Recruit Supplier"], [2, "Corporal Baker"], [5, "Sergeant Baker"], [9, "Captain of Crumbs"],
	[14, "Major Loaf"], [20, "Colonel Crust"], [30, "The General's Baker"]]
const MAX_HAGGLES := 3

var world: Node
var state := "idle"         # idle | offer | active
var order := {}             # need, got, time, total, reward, num
var next_offer := 45.0
var haggles := 0
var anger := 0


func _init(w: Node) -> void:
	world = w
	var saved: Dictionary = Game.military.get("order", {})
	if not saved.is_empty():
		order = saved.duplicate(true)
		state = "active"
	if float(Game.dev["offer_in"]) >= 0.0:
		next_offer = float(Game.dev["offer_in"])


static func rank_name(done: int) -> String:
	var name := str(RANKS[0][1])
	for r in RANKS:
		if done >= int(r[0]):
			name = str(r[1])
	return name


func depot() -> Node:
	var st: Dictionary = world.get("stations")
	return st.get("military_depot", null)


func tick(delta: float) -> void:
	if depot() == null or not Game.playing:
		return
	match state:
		"idle":
			next_offer -= delta
			if next_offer <= 0.0 and Game.hud != null and not bool(Game.hud.call("is_busy")):
				_make_offer()
		"active":
			order["time"] = float(order["time"]) - delta
			if _all_delivered():
				_complete()
			elif float(order["time"]) <= 0.0:
				_fail()
			Game.military["order"] = order


func _products() -> Array[String]:
	var out: Array[String] = []
	for s in world.call("shelves"):
		var p: String = (s as Shelf).product
		if p != "pie" and not out.has(p):   # the army can't afford pie
			out.append(p)
	return out


func _make_offer() -> void:
	var prods := _products()
	if prods.is_empty():
		next_offer = 30.0
		return
	prods.shuffle()
	var num := int(Game.military["done"]) + int(Game.military["failed"]) + 1
	var kinds := mini(prods.size(), 2 + (1 if num > 3 else 0) + (1 if num > 8 else 0))
	var need := {}
	var total := 0
	var value := 0
	for i in kinds:
		var t: String = prods[i]
		var q := randi_range(10, 18) + mini(num * 2, 30)
		if Items.price(t) >= 20:
			q = int(q * 0.7)
		need[t] = q
		total += q
		value += q * Items.price(t)
	var got := {}
	for t in need:
		got[t] = 0
	var secs := 50.0 + total * 2.8
	var rep := int(Game.military["rep"])
	var reward := Game.nice_number(value * 3.0 * Game.profit_mult() * (1.0 + 0.05 * clampi(rep, -5, 20)))
	order = {"need": need, "got": got, "time": secs, "total": secs, "reward": reward, "num": num}
	haggles = 0
	anger = 0
	state = "offer"
	Game.log_line("[order] #%d offer: %s in %ds for $%d" % [num, str(need), int(secs), reward])
	Sfx.play("bugle", -3.0)
	if Game.hud != null:
		Game.hud.call("military_offer", self)


## kind = "money" or "time". Returns {"ok": bool, "line": String, "left": bool}.
func haggle(kind: String) -> Dictionary:
	if state != "offer" or haggles >= MAX_HAGGLES:
		return {"ok": false, "line": "Enough talk, baker!", "left": false}
	var rep := int(Game.military["rep"])
	var chance := 0.0
	if kind == "money":
		chance = clampf(0.55 + 0.04 * rep - 0.2 * haggles, 0.15, 0.85)
	else:
		chance = clampf(0.7 + 0.04 * rep - 0.2 * haggles, 0.2, 0.9)
	haggles += 1
	if randf() < chance:
		if kind == "money":
			order["reward"] = Game.nice_number(float(order["reward"]) * 1.25)
			return {"ok": true, "left": false, "line": ["Hmph. Fine, the army can spare a few more coins.",
				"You drive a hard bargain. Deal.", "The treasury will weep, but alright."].pick_random()}
		order["time"] = float(order["time"]) * 1.4
		order["total"] = order["time"]
		return {"ok": true, "left": false, "line": ["Very well, take a little longer. But not a second more!",
			"The soldiers can tighten their belts a bit. Granted.", "More time? ...Fine."].pick_random()}
	anger += 1
	if anger >= 2:
		state = "idle"
		next_offer = randf_range(120.0, 180.0)
		Game.military["rep"] = rep - 1
		return {"ok": false, "left": true, "line": "THAT'S IT! I'll find another bakery. Good day, baker!"}
	order["reward"] = Game.nice_number(float(order["reward"]) * 0.9)
	return {"ok": false, "left": false, "line": ["Are you trying to rob the army?! My offer just went DOWN.",
		"Don't push your luck, baker. Less money for that cheek.", "Absolutely not! And now I'm paying you less."].pick_random()}


func accept() -> void:
	if state != "offer":
		return
	state = "active"
	Game.military["order"] = order
	var d := depot()
	if d != null:
		d.call("truck_arrive")
	Sfx.play("horn", -4.0)
	if Game.hud != null:
		Game.hud.call("toast", "Order accepted! Deliver to the Supply Depot.", "military")


func decline() -> void:
	if state != "offer":
		return
	state = "idle"
	next_offer = randf_range(90.0, 150.0)


func needs(t: String) -> bool:
	if state != "active":
		return false
	var need: Dictionary = order["need"]
	var got: Dictionary = order["got"]
	return need.has(t) and int(got[t]) < int(need[t])


func remaining(t: String) -> int:
	if not needs(t):
		return 0
	return int(order["need"][t]) - int(order["got"][t])


func needed_types() -> Array[String]:
	var out: Array[String] = []
	if state != "active":
		return out
	for t in order["need"]:
		if needs(str(t)):
			out.append(str(t))
	return out


func deliver(t: String) -> void:
	if not needs(t):
		return
	var got: Dictionary = order["got"]
	got[t] = int(got[t]) + 1


func _all_delivered() -> bool:
	for t in order["need"]:
		if needs(str(t)):
			return false
	return true


func _complete() -> void:
	var reward := int(order["reward"])
	Game.log_line("[order] complete with %ds left, +$%d" % [int(float(order["time"])), reward])
	Game.military["done"] = int(Game.military["done"]) + 1
	Game.military["rep"] = int(Game.military["rep"]) + 1
	Game.military["order"] = {}
	order = {}
	state = "idle"
	next_offer = randf_range(110.0, 190.0)
	var d := depot()
	if d != null:
		d.call("pay_out", reward)
		d.call("truck_leave")
	Sfx.play("fanfare", -2.0)
	Sfx.play("horn", -4.0)
	if Game.hud != null:
		Game.hud.call("big_card", "Order delivered!", "+$" + Game.fmt(reward),
			"Rank: " + rank_name(int(Game.military["done"])), "military")


func _fail() -> void:
	Game.log_line("[order] FAILED: got %s of %s" % [str(order["got"]), str(order["need"])])
	Game.military["failed"] = int(Game.military["failed"]) + 1
	Game.military["rep"] = maxi(-5, int(Game.military["rep"]) - 1)
	Game.military["order"] = {}
	order = {}
	state = "idle"
	next_offer = randf_range(150.0, 220.0)
	var d := depot()
	if d != null:
		d.call("truck_leave")
	Sfx.play("nope", -2.0)
	if Game.hud != null:
		Game.hud.call("toast", "Order failed! General Coo is disappointed.", "ui_close")
