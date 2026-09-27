class_name CafeTable
extends Station
## Terrace table with an umbrella and two perches. Pigeons that paid may sit
## here to eat; they leave a tip and crumbs. Walk past to clean + grab tips.

const SEAT_X := 1.2

var seats: Array[Dictionary] = []   # {"occ": Node, "dirty": bool, "mess": Node3D}
var tips: CashPile


func build() -> void:
	MeshBuilder.node(Models.cached("table", func() -> ArrayMesh:
		var b := MeshBuilder.new()
		b.cyl(0.62, 0.62, 0.08, Vector3(0, 0.72, 0), Color(0.98, 0.97, 0.95), Vector3.ZERO, 16)
		b.cyl(0.64, 0.64, 0.04, Vector3(0, 0.67, 0), Color(0.93, 0.35, 0.35), Vector3.ZERO, 16)
		b.cyl(0.06, 0.08, 0.7, Vector3(0, 0.35, 0), Models.C_METAL_DARK, Vector3.ZERO, 8)
		b.cyl(0.3, 0.34, 0.05, Vector3(0, 0.03, 0), Models.C_METAL_DARK, Vector3.ZERO, 12)
		# umbrella
		b.cyl(0.03, 0.03, 1.7, Vector3(0, 1.55, 0), Color(0.9, 0.9, 0.9), Vector3.ZERO, 6)
		b.cyl(0.0, 1.05, 0.45, Vector3(0, 2.28, 0), Color(0.95, 0.33, 0.33), Vector3.ZERO, 8)
		b.cyl(0.0, 0.52, 0.23, Vector3(0, 2.395, 0), Color(0.99, 0.98, 0.96), Vector3.ZERO, 8)
		b.torus(1.0, 0.04, Vector3(0, 2.06, 0), Color(0.99, 0.98, 0.96))
		b.sphere(0.06, Vector3(0, 2.52, 0), Models.C_WHITE)
		# two little stools (the pigeons' spots)
		for x in [-SEAT_X, SEAT_X]:
			b.cyl(0.26, 0.26, 0.06, Vector3(x, 0.26, 0), Models.C_WOOD, Vector3.ZERO, 12)
			b.cyl(0.05, 0.06, 0.24, Vector3(x, 0.12, 0), Models.C_WOOD.darkened(0.3), Vector3.ZERO, 6)
		return b.build()), self)
	for x in [-SEAT_X, SEAT_X]:
		var mess := MeshBuilder.node(Models.cached("mess", func() -> ArrayMesh:
			var b := MeshBuilder.new()
			for k in 9:
				var a := k * 2.4
				var r := 0.08 + (k % 3) * 0.07
				b.box(Vector3(0.05, 0.03, 0.05), Vector3(cos(a) * r, 0.0, sin(a) * r),
					Color(0.9, 0.7, 0.35) if k % 2 == 0 else Color(0.7, 0.5, 0.25), Vector3(0, k * 30.0, 0))
			b.cyl(0.13, 0.13, 0.01, Vector3(0.06, -0.01, 0.02), Color(0.75, 0.62, 0.45), Vector3.ZERO, 10)
			return b.build()), self)
		mess.position = Vector3(x * 0.35, 0.78, 0)
		mess.visible = false
		seats.append({"occ": null, "dirty": false, "mess": mess})
	tips = CashPile.new()
	add_child(tips)
	tips.setup(2, 2, 12)
	tips.radius = 2.0
	tips.position = Vector3(0, 0.77, 0.25)
	add_collider(Vector3(1.3, 0.8, 1.3), Vector3.ZERO, 0.2)


func seat_pos(i: int) -> Vector3:
	return to_global(Vector3(-SEAT_X if i == 0 else SEAT_X, 0, 0))


## Index of a clean, empty seat or -1.
func free_seat() -> int:
	for i in seats.size():
		if seats[i]["occ"] == null and not seats[i]["dirty"]:
			return i
	return -1


func reserve(i: int, p: Node) -> void:
	seats[i]["occ"] = p


func release(i: int, tip: int, from: Vector3) -> void:
	seats[i]["occ"] = null
	seats[i]["dirty"] = true
	(seats[i]["mess"] as Node3D).visible = true
	Fx.pop_in(seats[i]["mess"] as Node3D, 0.3)
	if tip > 0:
		tips.deposit(tip, from)


func dirty_count() -> int:
	var c := 0
	for s in seats:
		if s["dirty"]:
			c += 1
	return c


func clean_one() -> bool:
	for s in seats:
		if s["dirty"]:
			s["dirty"] = false
			(s["mess"] as Node3D).visible = false
			Fx.sparkle((s["mess"] as Node3D).global_position + Vector3(0, 0.2, 0), 8)
			Sfx.play("sparkle", -8.0, randf_range(0.95, 1.1))
			return true
	return false


func service(a: Carrier, delta: float) -> void:
	var d := Vector2(a.global_position.x - global_position.x, a.global_position.z - global_position.z)
	if d.length() > 2.0:
		return
	var can_clean := a.is_player or a.role == "janitor"
	if can_clean and dirty_count() > 0 and tick(a, "clean", delta, 0.35):
		clean_one()
		if a.is_player and world != null:
			world.call("notify", "cleaned", self)
	if a.is_player and tips.value > 0:
		tips.collect(a)


func save_state() -> Dictionary:
	var dirty: Array = []
	for s in seats:
		dirty.append(bool(s["dirty"]))
	return {"tips": tips.value, "dirty": dirty}


func load_state(d: Dictionary) -> void:
	tips.restore(int(d.get("tips", 0)))
	var dirty: Array = d.get("dirty", [])
	for i in mini(dirty.size(), seats.size()):
		if bool(dirty[i]):
			seats[i]["dirty"] = true
			(seats[i]["mess"] as Node3D).visible = true
