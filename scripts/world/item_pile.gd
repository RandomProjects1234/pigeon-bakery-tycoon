class_name ItemPile
extends Node3D
## A visible pile of items: the stack in someone's arms, an oven tray, a shelf.
## Items fly between piles on a little arc (take() from one, add_node() to
## another). Grid piles fill cols x rows, then the next layer up; a single
## column (layer_h = 0) stacks by each item's own height.

var cols := 1
var rows := 1
var spacing := Vector2(0.42, 0.42)
var layer_h := 0.0
var capacity := 10
var types: Array[String] = []
var nodes: Array[Node3D] = []
var jitter := 0.25

## Where flying-away items live while they animate (set by the world).
static var fx_root: Node3D = null


func count() -> int:
	return types.size()


func room() -> int:
	return maxi(0, capacity - types.size())


func is_full() -> bool:
	return types.size() >= capacity


func is_empty() -> bool:
	return types.is_empty()


func count_of(t: String) -> int:
	var n := 0
	for x in types:
		if x == t:
			n += 1
	return n


func has_type(t: String) -> bool:
	return types.has(t)


func top_type() -> String:
	return types[types.size() - 1] if not types.is_empty() else ""


func top_height() -> float:
	return slot_pos(types.size()).y


func slot_pos(i: int) -> Vector3:
	if layer_h <= 0.0:
		var y := 0.0
		for k in mini(i, types.size()):
			y += Items.height(types[k])
		return Vector3(0, y, 0)
	var per := cols * rows
	var layer := i / per
	var j := i % per
	var cx := j % cols
	var rz := j / cols
	return Vector3((cx - (cols - 1) * 0.5) * spacing.x, layer * layer_h, (rz - (rows - 1) * 0.5) * spacing.y)


## Spawns a fresh item that flies in from `from_global`.
func add_new(t: String, from_global: Vector3, dur := 0.28, arc := 0.7) -> Node3D:
	var n := Models.item(t)
	add_child(n)
	n.global_position = from_global
	_push(n, t, dur, arc)
	return n


## Adds an item instantly (loading a save).
func add_instant(t: String) -> void:
	var n := Models.item(t)
	add_child(n)
	types.append(t)
	nodes.append(n)
	n.position = slot_pos(types.size() - 1)
	n.rotation.y = randf_range(-jitter, jitter)


## Moves an existing item node (usually from another pile's take()) into this pile.
func add_node(n: Node3D, t: String, dur := 0.26, arc := 0.7) -> void:
	if n.get_parent() != null:
		n.reparent(self, true)
	else:
		add_child(n)
	_push(n, t, dur, arc)


func _push(n: Node3D, t: String, dur: float, arc: float) -> void:
	types.append(t)
	nodes.append(n)
	var target := slot_pos(types.size() - 1)
	var yaw := randf_range(-jitter, jitter)
	fly(n, target, dur, arc, yaw)


## Removes and returns the top-most item (of type `t` if given). The node
## stays in the tree; hand it to another pile's add_node() or free it.
func take(t := "") -> Node3D:
	var idx := -1
	if t.is_empty():
		idx = types.size() - 1
	else:
		for k in range(types.size() - 1, -1, -1):
			if types[k] == t:
				idx = k
				break
	if idx < 0:
		return null
	var n := nodes[idx]
	types.remove_at(idx)
	nodes.remove_at(idx)
	if idx < types.size():
		for k in range(idx, types.size()):
			fly(nodes[k], slot_pos(k), 0.12, 0.0, nodes[k].rotation.y)
	return n


## Moves one item of type `t` from this pile into `other`. Returns true on success.
func give_to(other: ItemPile, t := "", dur := 0.26, arc := 0.7) -> bool:
	if other.is_full():
		return false
	var tt := t if not t.is_empty() else top_type()
	var n := take(tt)
	if n == null:
		return false
	other.add_node(n, tt, dur, arc)
	return true


func clear_all() -> void:
	for n in nodes:
		if is_instance_valid(n):
			n.queue_free()
	types.clear()
	nodes.clear()


static func fly(n: Node3D, target: Vector3, dur: float, arc: float, yaw := 0.0) -> void:
	if n.has_meta("tw"):
		var old: Variant = n.get_meta("tw")
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
	var a := n.position
	var s0 := n.scale
	var r0 := n.rotation
	var r1 := Vector3(0, yaw, 0)
	var tw := n.create_tween()
	tw.tween_method(func(t: float) -> void:
		n.position = a.lerp(target, t) + Vector3.UP * sin(t * PI) * arc
		n.scale = s0.lerp(Vector3.ONE, t)
		n.rotation = r0.lerp(r1, t), 0.0, 1.0, dur)
	n.set_meta("tw", tw)


## Flies a node to a global point and frees it (item consumed by a machine, eaten...).
static func fly_away(n: Node3D, target_global: Vector3, dur := 0.25, arc := 0.5, shrink := true) -> void:
	if fx_root != null and is_instance_valid(fx_root) and n.is_inside_tree():
		n.reparent(fx_root, true)
	var a := n.global_position
	var s0 := n.scale
	var tw := n.create_tween()
	tw.tween_method(func(t: float) -> void:
		n.global_position = a.lerp(target_global, t) + Vector3.UP * sin(t * PI) * arc
		if shrink:
			n.scale = s0 * (1.0 - t * 0.85), 0.0, 1.0, dur)
	tw.tween_callback(n.queue_free)
