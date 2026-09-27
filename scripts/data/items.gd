class_name Items
extends RefCounted
## Every carryable thing: raw crops, the in-between flour, the products pigeons
## buy, and the cash bills. `h` is the stacking height of one item.

const DEF := {
	"wheat": {"name": "Wheat", "price": 0, "h": 0.15},
	"sunflower": {"name": "Sunflower", "price": 0, "h": 0.1},
	"flour": {"name": "Flour", "price": 0, "h": 0.22},
	"tomato": {"name": "Tomato", "price": 0, "h": 0.2},
	"potato": {"name": "Potato", "price": 0, "h": 0.17},
	"bread": {"name": "Bread", "price": 5, "h": 0.2},
	"seeds": {"name": "Birdseed", "price": 9, "h": 0.27},
	"croissant": {"name": "Croissant", "price": 16, "h": 0.16},
	"pizza": {"name": "Pizza", "price": 30, "h": 0.1},
	"fries": {"name": "Fries", "price": 24, "h": 0.3},
	"cash": {"name": "Cash", "price": 0, "h": 0.065},
}

## Products in the order they unlock.
const PRODUCTS: Array[String] = ["bread", "seeds", "croissant", "pizza", "fries"]

static var _icons := {}


static func height(t: String) -> float:
	var d: Dictionary = DEF.get(t, {})
	return float(d.get("h", 0.2))


static func price(t: String) -> int:
	var d: Dictionary = DEF.get(t, {})
	return int(d.get("price", 0))


static func title(t: String) -> String:
	var d: Dictionary = DEF.get(t, {})
	return str(d.get("name", t.capitalize()))


## Card / bubble icon. Item icons are baked from the 3D models; everything
## else comes from tools/gen_art.py.
static func icon(name: String) -> Texture2D:
	if _icons.has(name):
		return _icons[name]
	var tex: Texture2D = null
	var path := "res://assets/icons/%s.png" % name
	if ResourceLoader.exists(path):
		tex = load(path)
	_icons[name] = tex
	return tex
