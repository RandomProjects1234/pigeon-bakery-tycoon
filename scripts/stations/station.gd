class_name Station
extends Node3D
## Base for everything built from a buy zone. A station owns "pads" (spots on
## the ground where a carrier stands to hand items over) and gets service()
## called every physics frame for every carrier in the world.

var id := ""
var def := {}
var world: Node = null
var pads := {}         # name -> {"pos": Vector3 global, "r": float}
var _cool := {}

static var _pad_mats := {}


func setup(w: Node, d: Dictionary) -> void:
	world = w
	def = d
	id = str(d["id"])
	name = id
	var p: Vector2 = d["pos"]
	position = Vector3(p.x, 0, p.y)
	build()


func build() -> void:
	pass


func service(_a: Carrier, _delta: float) -> void:
	pass


func save_state() -> Dictionary:
	return {}


func load_state(_d: Dictionary) -> void:
	pass


func pad_pos(pname: String) -> Vector3:
	var p: Dictionary = pads.get(pname, {})
	return p.get("pos", global_position)


func in_pad(a: Node3D, pname: String) -> bool:
	if not pads.has(pname):
		return false
	var p: Dictionary = pads[pname]
	var pp: Vector3 = p["pos"]
	var r: float = p["r"]
	var d := Vector2(a.global_position.x - pp.x, a.global_position.z - pp.z)
	return d.length_squared() < r * r


## Rate limiter per (agent, key): true once every `interval` seconds of contact.
func tick(a: Node, key: String, delta: float, interval: float) -> bool:
	var k := "%d_%s" % [a.get_instance_id(), key]
	var t: float = float(_cool.get(k, interval * 0.6)) + delta
	if t >= interval:
		_cool[k] = minf(t - interval, interval)
		return true
	_cool[k] = t
	return false


static func pad_material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if _pad_mats.has(key):
		return _pad_mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = Items.icon("fx_pad")
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.render_priority = -1
	_pad_mats[key] = m
	return m


## Registers a pad and draws its ground marker (with an item icon on it).
func add_pad(pname: String, local: Vector3, r: float, icon := "", color := Color(1, 1, 1, 0.95)) -> void:
	pads[pname] = {"pos": to_global(Vector3(local.x, 0, local.z)), "r": r}
	var m := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(r * 2.0, r * 2.0)
	m.mesh = q
	m.material_override = pad_material(color)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = Vector3(local.x, 0.035, local.z)
	add_child(m)
	if not icon.is_empty():
		var s := Sprite3D.new()
		s.texture = Items.icon(icon)
		s.axis = Vector3.AXIS_Y
		s.pixel_size = r * 1.05 / 128.0
		s.position = Vector3(local.x, 0.045, local.z)
		s.shaded = false
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		s.modulate = Color(1, 1, 1, 0.9)
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(s)


## Solid box for the player's physics and the walkers' nav grid.
func add_collider(size: Vector3, local: Vector3, nav_inflate := 0.3) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	body.position = local + Vector3(0, size.y * 0.5, 0)
	add_child(body)
	if world != null and world.get("nav") != null:
		var g := to_global(local)
		(world.get("nav") as NavGrid).set_rect(Vector2(g.x, g.z), Vector2(size.x, size.z), true, nav_inflate)


## Small billboard sign showing an icon, on a post.
func add_sign(icon: String, local: Vector3, size := 0.7) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = Items.icon(icon)
	s.pixel_size = size / 128.0
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.position = local
	s.shaded = false
	add_child(s)
	return s
