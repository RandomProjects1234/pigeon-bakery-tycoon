class_name Objectives
extends RefCounted
## Decides what the yellow arrow points at and what the top banner says:
## a short guided tutorial first, then "build the next thing" hints.

var world: Node
var text := ""
var icon := ""
var target := Vector3.INF
var step_label := ""

const TUT_STEPS := 9


func _init(w: Node) -> void:
	world = w


func update() -> void:
	var st: Dictionary = world.get("stations")
	var player: Player = world.get("player")
	var reg: Register = world.get("register")
	var crows: Array = world.get("crows")
	_advance_tutorial(st, player)
	target = Vector3.INF
	step_label = ""
	# a crow always takes priority once the tutorial is over
	if Game.tut >= TUT_STEPS and not crows.is_empty():
		var c: Node3D = crows[0]
		if is_instance_valid(c) and not bool(c.get("scared")):
			text = "Shoo the crow away!"
			icon = "ui_close"
			target = c.global_position + Vector3(0, 0.6, 0)
			return
	if Game.tut < TUT_STEPS:
		step_label = "%d/%d" % [Game.tut + 1, TUT_STEPS]
		match Game.tut:
			0:
				_zone_goal("field_wheat1", "Build a Wheat Field")
			1:
				_zone_goal("oven_bread", "Build the Bread Oven")
			2:
				_zone_goal("shelf_bread", "Build a Bread Shelf")
			3:
				text = "Walk through the field to harvest wheat"
				icon = "wheat"
				if st.has("field_wheat1"):
					target = (st["field_wheat1"] as Node3D).global_position + Vector3(0, 0.6, 0)
			4:
				text = "Drop the wheat at the oven"
				icon = "wheat"
				if st.has("oven_bread"):
					target = (st["oven_bread"] as Machine).pad_pos("in")
			5:
				text = "Grab the fresh bread"
				icon = "bread"
				if st.has("oven_bread"):
					target = (st["oven_bread"] as Machine).pad_pos("out")
			6:
				text = "Stock the bread shelf"
				icon = "bread"
				if st.has("shelf_bread"):
					target = (st["shelf_bread"] as Shelf).pad_pos("stock")
			7:
				text = "Stand at the till to serve pigeons"
				icon = "ui_coin"
				target = reg.pad_pos("cashier")
			8:
				text = "Collect your cash!"
				icon = "cash"
				target = reg.cash.global_position + Vector3(0, 0.4, 0)
		return
	# free play: point at the cheapest thing to build
	var best: Dictionary = {}
	var best_rem := 1 << 30
	var zones: Dictionary = world.get("zones")
	for id in zones:
		var z: BuyZone = zones[id]
		var rem := z.remaining()
		if rem < best_rem:
			best_rem = rem
			best = z.def
	if best.is_empty():
		if Game.has_flag("won"):
			text = "Your pigeon empire is complete!"
		else:
			text = "Keep the pigeons fed!"
		icon = "ui_crown"
		return
	var bz: BuyZone = zones[str(best["id"])]
	icon = Layout.zone_icon(best)
	if Game.money >= best_rem:
		text = "Build: " + str(best["name"])
		target = bz.global_position + Vector3(0, 0.3, 0)
	elif reg.cash.value > 0 and Game.money + reg.cash.value >= best_rem:
		text = "Collect your cash"
		icon = "cash"
		target = reg.cash.global_position + Vector3(0, 0.4, 0)
	else:
		text = "Next: %s  ($%s)" % [str(best["name"]), Game.fmt(best_rem)]


func _zone_goal(id: String, t: String) -> void:
	text = t
	var z := Layout.zone(id)
	icon = Layout.zone_icon(z)
	var zones: Dictionary = world.get("zones")
	if zones.has(id):
		target = (zones[id] as Node3D).global_position + Vector3(0, 0.3, 0)


func _advance_tutorial(st: Dictionary, player: Player) -> void:
	if Game.tut >= TUT_STEPS:
		return
	var before := Game.tut
	var oven: Machine = st.get("oven_bread", null)
	var shelf: Shelf = st.get("shelf_bread", null)
	match Game.tut:
		0:
			if Game.is_unlocked("field_wheat1"):
				Game.tut = 1
		1:
			if Game.is_unlocked("oven_bread"):
				Game.tut = 2
		2:
			if Game.is_unlocked("shelf_bread"):
				Game.tut = 3
		3:
			if player.pile.count_of("wheat") >= 4 or player.pile.is_full() \
					or (oven != null and (oven.fill_ratio("wheat") > 0.0 or oven.out_pile.count() > 0)):
				Game.tut = 4
		4:
			if oven != null and (oven.fill_ratio("wheat") > 0.0 or oven.out_pile.count() > 0):
				Game.tut = 5
		5:
			if player.pile.has_type("bread") or (shelf != null and shelf.stock() > 0):
				Game.tut = 6
		6:
			if shelf != null and shelf.stock() > 0:
				Game.tut = 7
		7:
			if int(Game.stats["served"]) >= 1:
				Game.tut = 8
		8:
			if Game.has_flag("first_cash"):
				Game.tut = 9
	if Game.tut != before:
		Sfx.play("sparkle", -6.0, 1.2)
		if Game.tut >= TUT_STEPS and Game.hud != null:
			Game.hud.call("toast", "Tutorial complete! Keep growing your bakery.", "ui_star")
