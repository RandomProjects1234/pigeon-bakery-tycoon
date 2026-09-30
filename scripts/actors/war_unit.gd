class_name WarUnit
extends Node3D
## Friendly units from the HQ weapons:
##   fighter - a goggled pigeon ace (Air Squadron) that dogfights air crows
##   tank    - a pigeon-driven tank that hunts ground crows

var war: Node = null
var owner_weapon: HQWeapon
var kind := "fighter"
var idx := 0
var rig: PigeonRig
var _tank: Node3D
var _turret: Node3D
var _fire_t := 0.0
var _orbit := 0.0


func setup(w: Node, wpn: HQWeapon, k: String, i: int) -> void:
	war = w
	owner_weapon = wpn
	kind = k
	idx = i
	_orbit = i * TAU / 3.0
	if kind == "fighter":
		rig = PigeonRig.new("pilot")
		rig.scale = Vector3.ONE * 1.4
		add_child(rig)
		global_position = wpn.global_position + Vector3(0, 1, 0)
	else:
		_tank = Node3D.new()
		add_child(_tank)
		MeshBuilder.node(Models.cached("pigeon_tank", func() -> ArrayMesh:
			var b := MeshBuilder.new()
			var olive := Color(0.4, 0.5, 0.3)
			b.box(Vector3(1.6, 0.55, 2.2), Vector3(0, 0.55, 0), olive)
			for x in [-0.85, 0.85]:
				b.box(Vector3(0.35, 0.45, 2.3), Vector3(x, 0.3, 0), Color(0.2, 0.2, 0.22))
				for z in [-0.8, -0.27, 0.27, 0.8]:
					b.cyl(0.2, 0.2, 0.38, Vector3(x, 0.28, z), Color(0.35, 0.35, 0.38), Vector3(0, 0, 90), 8)
			return b.build()), _tank)
		_turret = Node3D.new()
		_turret.position = Vector3(0, 0.85, 0)
		_tank.add_child(_turret)
		MeshBuilder.node(Models.cached("pigeon_tank_turret", func() -> ArrayMesh:
			var b := MeshBuilder.new()
			b.cyl(0.55, 0.6, 0.4, Vector3(0, 0.2, 0), Color(0.45, 0.55, 0.33), Vector3.ZERO, 12)
			b.capsule(0.12, 1.4, Vector3(0, 0.25, -0.9), Color(0.88, 0.58, 0.26), Vector3(90, 0, 0))
			return b.build()), _turret)
		rig = PigeonRig.new("soldier")
		rig.scale = Vector3.ONE * 0.9
		rig.position = Vector3(0, 0.3, 0.15)
		_turret.add_child(rig)
		global_position = wpn.global_position + Vector3(2.0 * (i * 2 - 1), 0, 2.5)


func _process(delta: float) -> void:
	if war == null or not is_instance_valid(owner_weapon):
		return
	var center: Vector3 = war.get("center")
	_fire_t -= delta
	var disabled := owner_weapon.disabled_t > 0.0
	if kind == "fighter":
		var target: WarCrow = war.call("nearest_enemy", global_position, 22.0, "air")
		var goal := Vector3.ZERO
		if target != null and not disabled:
			var off := Vector3(cos(_orbit * 3.0), 0.6, sin(_orbit * 3.0)) * 2.5
			goal = target.global_position + off
		else:
			_orbit += delta * 0.4
			goal = center + Vector3(cos(_orbit + idx * 2.1) * 14.0, 7.0 + idx, sin(_orbit + idx * 2.1) * 14.0)
		_orbit += delta * 0.5
		var to := goal - global_position
		var spd := 9.0
		if to.length() > 0.1:
			global_position += to.normalized() * minf(spd * delta, to.length())
			rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), clampf(delta * 6.0, 0.0, 1.0))
		rig.animate(delta, 0.0, "fly")
		if target != null and not disabled and _fire_t <= 0.0 and global_position.distance_to(target.global_position) < 6.0:
			_fire_t = owner_weapon.rate()
			_seed_at(target)
	else:
		var target2: WarCrow = war.call("nearest_enemy", center, 24.0, "ground")
		var goal2 := Vector3.ZERO
		if target2 != null and not disabled:
			goal2 = target2.global_position
		else:
			_orbit += delta * 0.15
			goal2 = center + Vector3(cos(_orbit + idx * PI), 0, sin(_orbit + idx * PI)) * 14.0
		var to2 := Vector3(goal2.x - global_position.x, 0, goal2.z - global_position.z)
		var d := to2.length()
		if d > 6.0 or target2 == null:
			if d > 0.3:
				global_position += to2 / d * minf(3.5 * delta, d)
				rotation.y = lerp_angle(rotation.y, atan2(-to2.x, -to2.z), clampf(delta * 4.0, 0.0, 1.0))
		if target2 != null:
			var tl := target2.global_position - global_position
			_turret.global_rotation.y = lerp_angle(_turret.global_rotation.y, atan2(-tl.x, -tl.z), clampf(delta * 8.0, 0.0, 1.0))
			if not disabled and _fire_t <= 0.0 and d < 12.0:
				_fire_t = owner_weapon.rate()
				_shell_at(target2)
		rig.animate(delta, 0.0, "idle")


func _seed_at(target: WarCrow) -> void:
	var s := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.1
	sm.height = 0.2
	s.mesh = sm
	s.material_override = HQWeapon.ammo_material(Color(0.95, 0.8, 0.35))
	war.get("root").add_child(s)
	var from := global_position
	s.global_position = from
	var dmg := owner_weapon.damage()
	var wr: WeakRef = weakref(target)
	var move := func(t: float) -> void:
		var tr := wr.get_ref() as WarCrow
		if tr != null:
			s.global_position = from.lerp(tr.global_position + Vector3(0, 0.5, 0), t)
	var land := func() -> void:
		var tr := wr.get_ref() as WarCrow
		if tr != null and not tr.dead:
			tr.hit(dmg, s.global_position)
		s.queue_free()
	var tw := s.create_tween()
	tw.tween_method(move, 0.0, 1.0, 0.2)
	tw.tween_callback(land)
	Sfx.play("twang", -16.0, 1.6, 0.05)


func _shell_at(target: WarCrow) -> void:
	var s := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.1
	cm.height = 0.5
	s.mesh = cm
	s.material_override = HQWeapon.ammo_material(Color(0.88, 0.58, 0.26))
	war.get("root").add_child(s)
	var from := global_position + Vector3(0, 1.2, 0)
	s.global_position = from
	var dmg := owner_weapon.damage()
	var wr: WeakRef = weakref(target)
	var hold := {"goal": target.global_position}
	var move := func(t: float) -> void:
		var tr := wr.get_ref() as WarCrow
		if tr != null:
			hold["goal"] = tr.global_position + Vector3(0, 0.4, 0)
		var g: Vector3 = hold["goal"]
		s.global_position = from.lerp(g, t) + Vector3.UP * sin(t * PI) * 1.5
	var land := func() -> void:
		Fx.poof(s.global_position, Color(0.95, 0.8, 0.5), 8, 0.25)
		for e in war.call("enemies_near", s.global_position, 1.8, "ground"):
			(e as WarCrow).hit(dmg, s.global_position)
		s.queue_free()
	var tw := s.create_tween()
	tw.tween_method(move, 0.0, 1.0, 0.45)
	tw.tween_callback(land)
	Sfx.play("thud", -10.0, 1.5, 0.1)
