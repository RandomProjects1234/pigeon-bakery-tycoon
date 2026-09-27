class_name NavGrid
extends RefCounted
## Walkability grid for pigeons and staff (the player uses real physics).
## Stations, walls and fences mark their footprint solid; paths come from
## AStarGrid2D and are then string-pulled so walkers cut corners naturally.

const CELL := 0.5
const ORIGIN := Vector2(-32.0, -27.0)
const SIZE := Vector2i(130, 104)   # x -32..33, z -27..25

var grid := AStarGrid2D.new()


func _init() -> void:
	grid.region = Rect2i(0, 0, SIZE.x, SIZE.y)
	grid.cell_size = Vector2(1, 1)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()


func cell(p: Vector3) -> Vector2i:
	return Vector2i(int(floor((p.x - ORIGIN.x) / CELL)), int(floor((p.z - ORIGIN.y) / CELL)))


func to_world(c: Vector2i, y := 0.0) -> Vector3:
	return Vector3(ORIGIN.x + (c.x + 0.5) * CELL, y, ORIGIN.y + (c.y + 0.5) * CELL)


func in_bounds(c: Vector2i) -> bool:
	return grid.is_in_boundsv(c)


func is_free(c: Vector2i) -> bool:
	return grid.is_in_boundsv(c) and not grid.is_point_solid(c)


func is_free_at(p: Vector3) -> bool:
	return is_free(cell(p))


## Marks the rectangle (centre, size in metres) solid or free, grown by `inflate`.
func set_rect(center: Vector2, size: Vector2, solid := true, inflate := 0.3) -> void:
	var half := size * 0.5 + Vector2(inflate, inflate)
	var a := cell(Vector3(center.x - half.x, 0, center.y - half.y))
	var b := cell(Vector3(center.x + half.x, 0, center.y + half.y))
	for x in range(a.x, b.x + 1):
		for y in range(a.y, b.y + 1):
			var c := Vector2i(x, y)
			if grid.is_in_boundsv(c):
				grid.set_point_solid(c, solid)


## Blocks a thin wall from a to b (x/z).
func set_line(a: Vector2, b: Vector2, solid := true, inflate := 0.35) -> void:
	var center := (a + b) * 0.5
	var size := Vector2(absf(b.x - a.x), absf(b.y - a.y))
	set_rect(center, size, solid, inflate)


func nearest_free(c: Vector2i) -> Vector2i:
	c = Vector2i(clampi(c.x, 0, SIZE.x - 1), clampi(c.y, 0, SIZE.y - 1))
	if is_free(c):
		return c
	for r in range(1, 10):
		for dx in range(-r, r + 1):
			for dy in [-r, r]:
				var cc := c + Vector2i(dx, dy)
				if is_free(cc):
					return cc
		for dy in range(-r + 1, r):
			for dx in [-r, r]:
				var cc := c + Vector2i(dx, dy)
				if is_free(cc):
					return cc
	return c


func path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var a := nearest_free(cell(from))
	var b := nearest_free(cell(to))
	var out := PackedVector3Array()
	if a == b or line_clear(a, b):
		out.append(Vector3(to.x, 0, to.z))
		return out
	var ids := grid.get_id_path(a, b, true)
	if ids.is_empty():
		out.append(Vector3(to.x, 0, to.z))
		return out
	# string pulling
	var anchor := 0
	var i := 2
	var keep: Array[Vector2i] = []
	while i < ids.size():
		if not line_clear(ids[anchor], ids[i]):
			keep.append(ids[i - 1])
			anchor = i - 1
		i += 1
	for c in keep:
		out.append(to_world(c))
	var end_c := ids[ids.size() - 1]
	if end_c == b:
		out.append(Vector3(to.x, 0, to.z))
	else:
		out.append(to_world(end_c))
	return out


## Grid line-of-sight (thick enough that walkers don't clip corners).
func line_clear(a: Vector2i, b: Vector2i) -> bool:
	var d := b - a
	var steps := maxi(absi(d.x), absi(d.y)) * 2
	if steps == 0:
		return is_free(a)
	for s in steps + 1:
		var t := float(s) / float(steps)
		var fx := a.x + d.x * t
		var fy := a.y + d.y * t
		var c := Vector2i(int(round(fx)), int(round(fy)))
		if not is_free(c):
			return false
		# also check the cells either side of a diagonal step
		var c2 := Vector2i(int(floor(fx + 0.5)), int(floor(fy + 0.5)))
		if c2 != c and not is_free(c2):
			return false
	return true
