class_name Field
extends Station
## A plot of 3x4 plants. Walk through it and ripe plants pop into your stack;
## they regrow after GROW seconds.

const GROW := 6.0
const COLS := 3
const ROWS := 4
const HALF := Vector2(1.75, 2.25)

var crop := "wheat"
var tufts: Array[Dictionary] = []


func build() -> void:
	crop = str(def["crop"])
	MeshBuilder.node(Models.cached("plot", func() -> ArrayMesh:
		var b := MeshBuilder.new()
		b.box(Vector3(3.3, 0.14, 4.3), Vector3(0, 0.07, 0), Models.C_SOIL)
		for r in ROWS:
			b.box(Vector3(3.0, 0.03, 0.62), Vector3(0, 0.15, (r - 1.5) * 1.0), Models.C_SOIL_DARK)
		# wooden border
		b.box(Vector3(3.5, 0.2, 0.12), Vector3(0, 0.1, 2.2), Models.C_WOOD)
		b.box(Vector3(3.5, 0.2, 0.12), Vector3(0, 0.1, -2.2), Models.C_WOOD)
		b.box(Vector3(0.12, 0.2, 4.4), Vector3(1.7, 0.1, 0), Models.C_WOOD)
		b.box(Vector3(0.12, 0.2, 4.4), Vector3(-1.7, 0.1, 0), Models.C_WOOD)
		return b.build()), self)
	var ripe_mesh := Models.crop_mesh(crop, true)
	for r in ROWS:
		for c in COLS:
			var n := Node3D.new()
			n.position = Vector3((c - 1) * 1.0 + randf_range(-0.08, 0.08), 0.15, (r - 1.5) * 1.0 + randf_range(-0.06, 0.06))
			n.rotation.y = randf_range(-0.4, 0.4)
			add_child(n)
			var mi := MeshBuilder.node(ripe_mesh, n)
			tufts.append({"node": n, "mi": mi, "g": 1.0, "ripe": true})
	add_sign(crop, Vector3(-1.95, 1.2, 2.0), 0.55)
	var post := MeshBuilder.node(Models.cached("signpost", func() -> ArrayMesh:
		var b := MeshBuilder.new()
		b.box(Vector3(0.08, 0.9, 0.08), Vector3(0, 0.45, 0), Models.C_WOOD)
		return b.build()), self)
	post.position = Vector3(-1.95, 0, 2.0)


func in_field(p: Vector3) -> bool:
	var l := p - global_position
	return absf(l.x) < HALF.x and absf(l.z) < HALF.y


func _process(delta: float) -> void:
	for t in tufts:
		if t["ripe"]:
			continue
		var g: float = t["g"]
		g = minf(1.0, g + delta / GROW)
		t["g"] = g
		var n: Node3D = t["node"]
		n.scale = Vector3.ONE * lerpf(0.15, 0.85, g)
		if g >= 1.0:
			t["ripe"] = true
			(t["mi"] as MeshInstance3D).mesh = Models.crop_mesh(crop, true)
			n.scale = Vector3.ONE
			Fx.squash(n, 0.25, 0.4)


func service(a: Carrier, delta: float) -> void:
	if not in_field(a.global_position):
		return
	if a.pile.room() <= 0 or not a.wants_pick(self, "field", crop):
		return
	if not tick(a, "h", delta, a.interval() * 0.8):
		return
	var best: Dictionary = {}
	var best_d := 1.6 * 1.6
	var ap := a.global_position
	for t in tufts:
		if not t["ripe"]:
			continue
		var n: Node3D = t["node"]
		var d := Vector2(n.global_position.x - ap.x, n.global_position.z - ap.z).length_squared()
		if d < best_d:
			best_d = d
			best = t
	if best.is_empty():
		return
	harvest(best, a)


func harvest(t: Dictionary, a: Carrier) -> void:
	var n: Node3D = t["node"]
	t["ripe"] = false
	t["g"] = 0.0
	(t["mi"] as MeshInstance3D).mesh = Models.crop_mesh(crop, false)
	n.scale = Vector3.ONE * 0.15
	a.pile.add_new(crop, n.global_position + Vector3(0, 0.5, 0), 0.25, 0.8)
	if a.is_player:
		Sfx.play("pop", -3.0, 0.9 + a.pile.count() * 0.035)
		if world != null:
			world.call("notify", "harvest", self)


func ripe_count() -> int:
	var c := 0
	for t in tufts:
		if t["ripe"]:
			c += 1
	return c


## Closest ripe plant to `p`, or Vector3.INF.
func nearest_ripe(p: Vector3) -> Vector3:
	var best := Vector3.INF
	var best_d := INF
	for t in tufts:
		if not t["ripe"]:
			continue
		var n: Node3D = t["node"]
		var d := n.global_position.distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = n.global_position
	return best


func save_state() -> Dictionary:
	var g: Array = []
	for t in tufts:
		g.append(snappedf(float(t["g"]), 0.01))
	return {"g": g}


func load_state(d: Dictionary) -> void:
	var g: Array = d.get("g", [])
	for i in mini(g.size(), tufts.size()):
		var t := tufts[i]
		t["g"] = float(g[i])
		t["ripe"] = float(g[i]) >= 1.0
		if not t["ripe"]:
			(t["mi"] as MeshInstance3D).mesh = Models.crop_mesh(crop, false)
			(t["node"] as Node3D).scale = Vector3.ONE * lerpf(0.15, 0.85, float(g[i]))
