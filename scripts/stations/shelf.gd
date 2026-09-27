class_name Shelf
extends Station
## Display table in the bakery. Staff stock it from the front (south); pigeons
## queue up behind it (north) and take what they ordered.

const QUEUE_GAP := 1.05
const MAX_QUEUE := 6

var product := "bread"
var display: ItemPile
var queue: Array[Node] = []
var _price_label: Label3D


func build() -> void:
	product = str(def["product"])
	MeshBuilder.node(Models.cached("shelf", func() -> ArrayMesh:
		var b := MeshBuilder.new()
		b.box(Vector3(2.7, 0.12, 1.1), Vector3(0, 0.78, 0), Models.C_WOOD_LIGHT)
		b.box(Vector3(2.6, 0.5, 1.0), Vector3(0, 0.47, 0), Models.C_WOOD)
		b.box(Vector3(2.64, 0.08, 1.04), Vector3(0, 0.26, 0), Models.C_WOOD.darkened(0.2))
		for x in [-1.2, 1.2]:
			for z in [-0.42, 0.42]:
				b.box(Vector3(0.12, 0.25, 0.12), Vector3(x, 0.12, z), Models.C_WOOD.darkened(0.3))
		b.box(Vector3(2.62, 0.2, 0.04), Vector3(0, 0.55, 0.52), Color(0.98, 0.95, 0.88))
		return b.build()), self)
	display = ItemPile.new()
	display.cols = 3
	display.rows = 2
	display.spacing = Vector2(0.78, 0.42)
	display.layer_h = Items.height(product)
	display.capacity = 18
	display.jitter = 0.18
	display.position = Vector3(0, 0.84, 0)
	add_child(display)
	# sign with icon + price
	var post := MeshBuilder.node(Models.cached("shelfpost", func() -> ArrayMesh:
		var b := MeshBuilder.new()
		b.box(Vector3(0.06, 1.4, 0.06), Vector3(0, 0.7, 0), Models.C_METAL_DARK)
		return b.build()), self)
	post.position = Vector3(1.45, 0, -0.35)
	add_sign(product, Vector3(1.45, 1.85, -0.35), 0.75)
	_price_label = Fx.label3d("$%d" % Items.price(product), 40, Color(0.55, 1.0, 0.45), 12)
	_price_label.position = Vector3(1.45, 1.42, -0.35)
	add_child(_price_label)
	add_pad("stock", Vector3(0, 0, 1.3), 0.8, product)
	add_collider(Vector3(2.7, 1.0, 1.1), Vector3.ZERO)
	Game.upgrades_changed.connect(_refresh_price)
	_refresh_price()


func _refresh_price() -> void:
	_price_label.text = "$%d" % int(round(Items.price(product) * Game.profit_mult()))


func service(a: Carrier, delta: float) -> void:
	if display.is_full() or not in_pad(a, "stock"):
		return
	if not a.pile.has_type(product) or not a.wants_drop(self, "stock", product):
		return
	if tick(a, "stock", delta, a.interval()):
		a.pile.give_to(display, product, 0.26, 0.7)
		if a.is_player:
			Sfx.play("drop", -5.0, 0.95 + display.count() * 0.02)
			world.call("notify", "stocked", self)


func queue_slot(i: int) -> Vector3:
	return to_global(Vector3(0, 0, -1.3 - i * QUEUE_GAP))


func join(p: Node) -> void:
	if not queue.has(p):
		queue.append(p)


func leave(p: Node) -> void:
	queue.erase(p)


func index_of(p: Node) -> int:
	return queue.find(p)


func has_room_in_queue() -> bool:
	return queue.size() < MAX_QUEUE


func stock() -> int:
	return display.count()


func fill_ratio() -> float:
	return float(display.count()) / float(display.capacity)


func save_state() -> Dictionary:
	return {"n": display.count()}


func load_state(d: Dictionary) -> void:
	for i in mini(int(d.get("n", 0)), display.capacity):
		display.add_instant(product)
