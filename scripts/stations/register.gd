class_name Register
extends Station
## The till. Pigeons queue on the north side; whoever stands on the cashier
## spot (the player, or the hired cashier) rings them up. Bills pile up on the
## cash stack next to it.

var queue: Array[Node] = []
var cash: CashPile
var _present := 0.0
var _present_player := false
var _serve := 0.0
var _bell: Node3D


func build() -> void:
	MeshBuilder.node(Models.cached("register", func() -> ArrayMesh:
		var b := MeshBuilder.new()
		b.box(Vector3(2.7, 0.95, 1.05), Vector3(0, 0.475, 0), Color(0.36, 0.6, 0.92))
		b.box(Vector3(2.8, 0.1, 1.15), Vector3(0, 1.0, 0), Models.C_WOOD_LIGHT)
		b.box(Vector3(2.5, 0.1, 0.05), Vector3(0, 0.25, 0.53), Color(0.98, 0.95, 0.88))
		b.box(Vector3(2.5, 0.1, 0.05), Vector3(0, 0.7, 0.53), Color(0.98, 0.95, 0.88))
		# the till itself
		b.box(Vector3(0.7, 0.28, 0.55), Vector3(0.45, 1.19, 0.0), Color(0.28, 0.28, 0.34))
		b.box(Vector3(0.62, 0.08, 0.5), Vector3(0.45, 1.36, 0.0), Color(0.4, 0.4, 0.46))
		b.box(Vector3(0.5, 0.3, 0.06), Vector3(0.45, 1.5, 0.12), Color(0.2, 0.2, 0.25), Vector3(-20, 0, 0))
		b.box(Vector3(0.42, 0.2, 0.02), Vector3(0.45, 1.5, 0.16), Color(0.5, 1.0, 0.6), Vector3(-20, 0, 0))
		for k in 3:
			b.box(Vector3(0.12, 0.03, 0.1), Vector3(0.28 + k * 0.17, 1.41, -0.12), Color(0.9, 0.9, 0.95))
		# little tray of seeds as decoration
		b.cyl(0.2, 0.16, 0.08, Vector3(-0.6, 1.09, 0.1), Color(0.95, 0.95, 0.98), Vector3.ZERO, 12)
		b.cyl(0.17, 0.17, 0.02, Vector3(-0.6, 1.13, 0.1), Color(0.85, 0.7, 0.4), Vector3.ZERO, 12)
		return b.build()), self)
	_bell = MeshBuilder.node(Models.cached("bell", func() -> ArrayMesh:
		var b := MeshBuilder.new()
		b.dome(0.1, Vector3(0, 0, 0), Models.C_GOLD, Vector3(1, 0.8, 1), 10)
		b.cyl(0.13, 0.13, 0.02, Vector3(0, 0, 0), Color(0.3, 0.3, 0.35), Vector3.ZERO, 10)
		b.sphere(0.025, Vector3(0, 0.09, 0), Models.C_GOLD)
		return b.build()), self)
	_bell.position = Vector3(-1.05, 1.06, 0.2)
	add_sign("ui_coin", Vector3(-1.05, 2.0, -0.2), 0.7)
	add_pad("cashier", Vector3(0, 0, 1.35), 0.8, "ui_coin", Color(1.0, 0.95, 0.6, 0.95))
	add_collider(Vector3(2.8, 1.1, 1.15), Vector3.ZERO)
	cash = CashPile.new()
	cash.name = "Cash"
	add_child(cash)
	cash.setup(2, 3, 48)
	cash.position = Vector3(-2.0, 0.0, 1.2)
	var mat := MeshBuilder.node(Models.cached("cashmat", func() -> ArrayMesh:
		var b := MeshBuilder.new()
		b.box(Vector3(1.1, 0.04, 1.1), Vector3(0, 0.02, 0), Color(0.36, 0.72, 0.36))
		return b.build()), self)
	mat.position = cash.position


func queue_slot(i: int) -> Vector3:
	if i < 8:
		return to_global(Vector3(0, 0, -1.4 - i * 1.1))
	return to_global(Vector3(1.1 * (i - 7), 0, -1.4 - 7 * 1.1))


func join(p: Node) -> void:
	if not queue.has(p):
		queue.append(p)


func leave(p: Node) -> void:
	queue.erase(p)


func index_of(p: Node) -> int:
	return queue.find(p)


func cashier_present() -> bool:
	return _present > 0.0


func service(a: Carrier, _delta: float) -> void:
	if a.is_cashier() and in_pad(a, "cashier"):
		_present = 0.15
		_present_player = a.is_player
		if a.is_player and world != null:
			world.call("notify", "at_register", self)
	if a.is_player and cash.value > 0 and cash.near(a.global_position):
		cash.collect(a)
		if world != null:
			world.call("notify", "collected", self)


func _process(delta: float) -> void:
	_present -= delta
	if _present <= 0.0 or queue.is_empty():
		_serve = 0.0
		return
	var front: Node = queue[0]
	if not is_instance_valid(front) or not bool(front.call("ready_to_pay")):
		_serve = 0.0
		return
	_serve += delta
	var interval := 0.45 if _present_player else maxf(0.3, 0.85 - 0.06 * Game.upgrade_level("staff_speed"))
	if _serve >= interval:
		_serve = 0.0
		var amount: int = front.call("pay")
		var from: Vector3 = (front as Node3D).global_position + Vector3(0, 1.0, 0)
		cash.deposit(amount, from)
		Sfx.play("kaching", -7.0, randf_range(0.95, 1.08), 0.08)
		Fx.squash(_bell, 0.3, 0.3)
		Game.stats["served"] = int(Game.stats["served"]) + 1
		if world != null:
			world.call("notify", "sale", self)


func save_state() -> Dictionary:
	return {"cash": cash.value}


func load_state(d: Dictionary) -> void:
	cash.restore(int(d.get("cash", 0)))
