class_name Office
extends Station
## The manager's office: stand on the mat to open the upgrade menu. Staff
## walk out of its door when hired.

var _was_on := false
var _sign: Sprite3D


func build() -> void:
	MeshBuilder.node(Models.cached("office", func() -> ArrayMesh:
		var b := MeshBuilder.new()
		var wall := Color(0.98, 0.9, 0.7)
		b.box(Vector3(3.6, 2.5, 2.8), Vector3(0, 1.25, -0.3), wall)
		b.prism(Vector3(4.0, 1.0, 3.2), Vector3(0, 3.0, -0.3), Color(0.35, 0.55, 0.9))
		b.box(Vector3(0.9, 1.6, 0.06), Vector3(-0.8, 0.8, 1.11), Color(0.55, 0.36, 0.22))
		b.sphere(0.05, Vector3(-0.5, 0.8, 1.15), Models.C_GOLD)
		b.box(Vector3(1.1, 0.8, 0.06), Vector3(0.8, 1.4, 1.11), Color(0.6, 0.8, 1.0))
		b.box(Vector3(1.2, 0.08, 0.14), Vector3(0.8, 0.98, 1.14), Color(1, 1, 1))
		b.box(Vector3(0.08, 0.8, 0.07), Vector3(0.8, 1.4, 1.13), Color(1, 1, 1))
		b.box(Vector3(3.8, 0.12, 3.0), Vector3(0, 0.06, -0.3), Color(0.8, 0.72, 0.6))
		# awning over the door
		b.box(Vector3(1.4, 0.08, 0.7), Vector3(-0.8, 1.85, 1.4), Color(0.35, 0.55, 0.9), Vector3(-15, 0, 0))
		return b.build()), self)
	_sign = add_sign("ui_up", Vector3(0.0, 3.9, 0.9), 0.9)
	var label := Fx.label3d("UPGRADES", 38, Color(1, 1, 1), 12)
	label.position = Vector3(0, 3.3, 1.0)
	add_child(label)
	add_pad("desk", Vector3(0, 0, 2.1), 0.9, "ui_up", Color(0.75, 0.85, 1.0, 0.95))
	add_collider(Vector3(3.8, 2.6, 3.0), Vector3(0, 0, -0.3))


func door_pos() -> Vector3:
	return to_global(Vector3(-0.8, 0, 1.6))


func _process(_delta: float) -> void:
	if _sign != null:
		_sign.position.y = 3.9 + sin(Time.get_ticks_msec() / 300.0) * 0.08


func service(a: Carrier, _delta: float) -> void:
	if not a.is_player:
		return
	var on := in_pad(a, "desk")
	if on and not _was_on and Game.hud != null:
		Game.hud.call("open_upgrades")
		Sfx.play("click")
	elif not on and _was_on and Game.hud != null:
		Game.hud.call("close_upgrades")
	_was_on = on
