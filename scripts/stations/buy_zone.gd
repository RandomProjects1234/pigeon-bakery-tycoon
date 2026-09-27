class_name BuyZone
extends Node3D
## The dashed square with a price card: stand on it and your cash pours in.
## Partial payments are remembered, so you can fill it over several trips.

const HALF := 0.95
const DELAY := 0.3

var def := {}
var id := ""
var cost := 10
var world: Node = null
var _stand := 0.0
var _acc := 0.0
var _fly_t := 0.0
var _t := 0.0
var _fill: MeshInstance3D
var _corners: MeshInstance3D
var _card: Node3D
var _price: Label3D
var _title: Label3D
var _broke_shown := false
var _done := false

static var _mat_corner: StandardMaterial3D
static var _mat_fill: StandardMaterial3D
static var _mat_back: StandardMaterial3D


func setup(w: Node, d: Dictionary) -> void:
	world = w
	def = d
	id = str(d["id"])
	name = "zone_" + id
	cost = Game.zone_cost(d)
	var p: Vector2 = d["pos"]
	position = Vector3(p.x, 0, p.y)
	_build()


func _build() -> void:
	if _mat_corner == null:
		_mat_corner = StandardMaterial3D.new()
		_mat_corner.albedo_texture = Items.icon("fx_zone")
		_mat_corner.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_corner.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_fill = StandardMaterial3D.new()
		_mat_fill.albedo_texture = Items.icon("fx_fill")
		_mat_fill.albedo_color = Color(0.35, 0.9, 0.35, 0.85)
		_mat_fill.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_fill.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_back = StandardMaterial3D.new()
		_mat_back.albedo_texture = Items.icon("fx_fill")
		_mat_back.albedo_color = Color(1, 1, 1, 0.18)
		_mat_back.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_back.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var back := MeshInstance3D.new()
	var bq := PlaneMesh.new()
	bq.size = Vector2(HALF * 2, HALF * 2)
	back.mesh = bq
	back.material_override = _mat_back
	back.position.y = 0.04
	back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(back)
	_fill = MeshInstance3D.new()
	var fq := PlaneMesh.new()
	fq.size = Vector2(HALF * 2, HALF * 2)
	fq.center_offset = Vector3(0, 0, -HALF)   # grows from the south edge up
	_fill.mesh = fq
	_fill.material_override = _mat_fill
	_fill.position = Vector3(0, 0.05, HALF)
	_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_fill)
	_corners = MeshInstance3D.new()
	var cq := PlaneMesh.new()
	cq.size = Vector2(HALF * 2.3, HALF * 2.3)
	_corners.mesh = cq
	_corners.material_override = _mat_corner
	_corners.position.y = 0.06
	_corners.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_corners)
	# floating card
	_card = Node3D.new()
	_card.position = Vector3(0, 1.55, 0)
	add_child(_card)
	var bg := Sprite3D.new()
	bg.texture = Items.icon("fx_card")
	bg.pixel_size = 0.0075
	bg.shaded = false
	bg.render_priority = 1
	_card.add_child(bg)
	var ic := Sprite3D.new()
	ic.texture = Items.icon(Layout.zone_icon(def))
	ic.pixel_size = 0.0068
	ic.position = Vector3(0, 0.18, 0.01)
	ic.shaded = false
	ic.render_priority = 2
	_card.add_child(ic)
	_price = Fx.label3d("", 46, Color(0.2, 0.62, 0.2), 0)
	_price.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_price.position = Vector3(0, -0.4, 0.02)
	_price.render_priority = 3
	_price.outline_render_priority = 2
	_card.add_child(_price)
	_title = Fx.label3d(str(def["name"]), 34, Color(1, 1, 1), 12)
	_title.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_title.position = Vector3(0, 0.95, 0)
	_card.add_child(_title)
	_refresh()


func remaining() -> int:
	return maxi(0, cost - Game.zone_paid(id))


func progress() -> float:
	return clampf(float(Game.zone_paid(id)) / float(maxi(cost, 1)), 0.0, 1.0)


func _refresh() -> void:
	var rem := remaining()
	_price.text = "$" + Game.fmt(rem)
	_price.modulate = Color(0.18, 0.6, 0.2) if Game.money >= rem else Color(0.45, 0.42, 0.5)
	_fill.scale = Vector3(1, 1, maxf(0.001, progress()))


func contains(p: Vector3) -> bool:
	var l := p - global_position
	return absf(l.x) < HALF and absf(l.z) < HALF


func _process(delta: float) -> void:
	_t += delta
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		_card.global_basis = cam.global_basis * Basis.from_scale(scale)
	_card.position.y = 1.55 + sin(_t * 2.6) * 0.07
	var pulse := 1.0 + sin(_t * 4.0) * 0.03
	_corners.scale = Vector3(pulse, 1, pulse)
	if int(_t * 10.0) % 3 == 0:
		_refresh()


func service(player: Node3D, delta: float) -> void:
	if _done:
		return
	if not contains(player.global_position):
		_stand = 0.0
		_broke_shown = false
		return
	_stand += delta
	if _stand < DELAY:
		return
	var rem := remaining()
	if rem <= 0:
		_complete()
		return
	if Game.money <= 0:
		if not _broke_shown:
			_broke_shown = true
			Sfx.play("nope", -6.0)
			Fx.float_text(global_position + Vector3(0, 2.4, 0), "Need $" + Game.fmt(rem), Color(1, 0.55, 0.5), 54)
			Fx.squash(_card, 0.2, 0.3)
		return
	var rate := maxf(float(cost) / 1.3, 12.0)
	_acc += rate * delta
	var amount := mini(mini(int(_acc), rem), Game.money)
	if amount > 0:
		_acc -= amount
		Game.spend(amount)
		Game.paid[id] = Game.zone_paid(id) + amount
		_refresh()
	_fly_t -= delta
	if _fly_t <= 0.0:
		_fly_t = 0.06
		_fly_bill(player)
		Sfx.play("tick", -10.0, 0.8 + progress() * 0.8, 0.05)
	if remaining() <= 0:
		_complete()


func _fly_bill(player: Node3D) -> void:
	var b := Models.item("cash")
	if ItemPile.fx_root == null:
		return
	ItemPile.fx_root.add_child(b)
	b.global_position = player.global_position + Vector3(0, 1.3, 0)
	ItemPile.fly_away(b, global_position + Vector3(0, 0.1, 0), 0.25, 0.9, true)


func _complete() -> void:
	if _done:
		return
	_done = true
	Game.unlock(id)
