class_name CashPile
extends Node3D
## Stack of bills that grows as pigeons pay. Walk over it to scoop it all up.

var value := 0
var visual: ItemPile
var radius := 1.2
var _collecting := false


func setup(cols := 2, rows := 3, cap := 48) -> void:
	visual = ItemPile.new()
	visual.cols = cols
	visual.rows = rows
	visual.spacing = Vector2(0.38, 0.22)
	visual.layer_h = Items.height("cash")
	visual.capacity = cap
	visual.jitter = 0.2
	add_child(visual)


func deposit(amount: int, from_global: Vector3) -> void:
	if amount <= 0:
		return
	value += amount
	var bills := clampi(amount / 8 + 1, 1, 5)
	for i in bills:
		if visual.is_full():
			break
		var off := Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2))
		visual.add_new("cash", from_global + off, 0.35 + i * 0.05, 0.9)


func near(p: Vector3) -> bool:
	var d := Vector2(p.x - global_position.x, p.z - global_position.z)
	return d.length_squared() < radius * radius


## Everything flies into the player's pocket.
func collect(player: Node3D) -> int:
	if value <= 0:
		return 0
	var v := value
	value = 0
	Game.add_money(v)
	var target := player.global_position + Vector3(0, 1.4, 0)
	var n := visual.count()
	for i in n:
		var b := visual.take()
		if b == null:
			break
		var tw := b.create_tween()
		tw.tween_interval(i * 0.012)
		var bb := b
		var tg := target
		tw.tween_callback(func() -> void: ItemPile.fly_away(bb, tg, 0.22, 0.9))
	var ticks := mini(8, maxi(1, n / 3))
	for k in ticks:
		var t := get_tree().create_timer(k * 0.05, false)
		var pitch := 1.0 + k * 0.07
		t.timeout.connect(func() -> void: Sfx.play("coin", -6.0, pitch, 0.0))
	Fx.float_text(player.global_position + Vector3(0, 2.6, 0), "+$" + Game.fmt(v), Color(1.0, 0.9, 0.3), 80)
	return v


func restore(v: int) -> void:
	value = v
	var bills := clampi(v / 10 + 1, 1, visual.capacity) if v > 0 else 0
	for i in bills:
		visual.add_instant("cash")
