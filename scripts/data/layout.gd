class_name Layout
extends RefCounted
## The whole map as data. Every buy zone the player can unlock is one entry in
## ZONES; a zone becomes visible once everything in its `req` is unlocked
## ("flag:x" entries wait for Game.flags). Positions are world X/Z in metres.
##
## Map (camera looks north, -Z is up the screen):
##   z -22 .. -8   the bakery: shelves in a row, register on the left
##   x -27 .. -17  the cafe terrace (tables) left of the bakery
##   z  -7 ..  6   the yard: one production column per product
##                 (machine at z -4.6, its field below it at z 2.6)
##   z 7.5 .. 21   the back lot (bought as land), extra fields + landmarks

const X_W2 := -13.3
const X_BREAD := -9.5
const X_SEED := -5.7
const X_CROIS := -1.9
const X_MILL := 1.9
const X_PIZZA := 5.7
const X_FRIES := 9.5

const MACHINE_Z := -4.6
const FIELD_Z := 2.6
const SHELF_Z := -13.6
const BACK_FIELD_Z := 11.5

const SHOP_RECT := Rect2(-16.5, -22.5, 29.0, 14.5)      # x, z, w, d
const TERRACE_RECT := Rect2(-27.0, -22.0, 10.5, 14.5)
const YARD_RECT := Rect2(-18.0, -8.0, 36.0, 15.5)
const BACKLOT_RECT := Rect2(-18.0, 7.5, 36.0, 13.5)

const PLAYER_SPAWN := Vector2(-11.6, -1.0)
const REGISTER_POS := Vector2(-13.5, -10.6)
const OFFICE_DOOR := Vector2(15.5, -2.0)

const ZONES: Array[Dictionary] = [
	# ---------------------------------------------------------- tutorial --
	{"id": "field_wheat1", "kind": "field", "name": "Wheat Field", "cost": 10,
		"pos": Vector2(X_BREAD, FIELD_Z), "req": [], "crop": "wheat", "feeds": ["oven_bread"]},
	{"id": "oven_bread", "kind": "machine", "name": "Bread Oven", "cost": 10,
		"pos": Vector2(X_BREAD, MACHINE_Z), "req": ["field_wheat1"], "model": "oven",
		"inputs": ["wheat"], "output": "bread", "time": 1.4, "to": ["shelf_bread"]},
	{"id": "shelf_bread", "kind": "shelf", "name": "Bread Shelf", "cost": 10,
		"pos": Vector2(X_BREAD, SHELF_Z), "req": ["oven_bread"], "product": "bread"},
	# ------------------------------------------------------------- early --
	{"id": "table_1", "kind": "table", "name": "Cafe Table", "cost": 25,
		"pos": Vector2(-20.3, -11.5), "req": ["shelf_bread", "flag:first_cash"]},
	{"id": "field_wheat2", "kind": "field", "name": "Wheat Field", "cost": 45,
		"pos": Vector2(X_W2, FIELD_Z), "req": ["table_1"], "crop": "wheat", "feeds": ["oven_bread"]},
	{"id": "table_2", "kind": "table", "name": "Cafe Table", "cost": 60,
		"pos": Vector2(-24.3, -11.5), "req": ["field_wheat2"]},
	{"id": "office", "kind": "office", "name": "Manager's Office", "cost": 70,
		"pos": Vector2(15.5, -3.6), "req": ["field_wheat2"]},
	{"id": "hire_cashier", "kind": "hire", "name": "Hire Cashier", "cost": 100,
		"pos": Vector2(-11.5, -9.3), "req": ["office"], "role": "cashier", "station": "register"},
	{"id": "field_sun1", "kind": "field", "name": "Sunflower Patch", "cost": 90,
		"pos": Vector2(X_SEED, FIELD_Z), "req": ["office"], "crop": "sunflower", "feeds": ["packer_seed"]},
	{"id": "packer_seed", "kind": "machine", "name": "Seed Packer", "cost": 120,
		"pos": Vector2(X_SEED, MACHINE_Z), "req": ["field_sun1"], "model": "packer",
		"inputs": ["sunflower"], "output": "seeds", "time": 1.6, "to": ["shelf_seed"]},
	{"id": "shelf_seed", "kind": "shelf", "name": "Birdseed Shelf", "cost": 90,
		"pos": Vector2(X_SEED, SHELF_Z), "req": ["packer_seed"], "product": "seeds"},
	{"id": "hire_farmer_w1", "kind": "hire", "name": "Hire Farmer", "cost": 170,
		"pos": Vector2(X_BREAD, 5.8), "req": ["shelf_seed"], "role": "farmer", "station": "field_wheat1"},
	{"id": "table_3", "kind": "table", "name": "Cafe Table", "cost": 150,
		"pos": Vector2(-20.3, -15.5), "req": ["shelf_seed"]},
	{"id": "hire_baker_bread", "kind": "hire", "name": "Hire Baker", "cost": 210,
		"pos": Vector2(X_BREAD + 1.9, MACHINE_Z), "req": ["hire_farmer_w1"], "role": "baker", "station": "oven_bread"},
	{"id": "field_sun2", "kind": "field", "name": "Sunflower Patch", "cost": 260,
		"pos": Vector2(X_CROIS, FIELD_Z), "req": ["hire_baker_bread"], "crop": "sunflower", "feeds": ["packer_seed"]},
	{"id": "table_4", "kind": "table", "name": "Cafe Table", "cost": 240,
		"pos": Vector2(-24.3, -15.5), "req": ["table_3", "hire_baker_bread"]},
	# --------------------------------------------------------- croissant --
	{"id": "mill", "kind": "machine", "name": "Flour Mill", "cost": 450,
		"pos": Vector2(X_MILL, MACHINE_Z), "req": ["hire_baker_bread"], "model": "mill",
		"inputs": ["wheat"], "output": "flour", "time": 1.3, "to": ["oven_croissant", "oven_pizza"]},
	{"id": "field_wheat3", "kind": "field", "name": "Wheat Field", "cost": 300,
		"pos": Vector2(X_MILL, FIELD_Z), "req": ["mill"], "crop": "wheat", "feeds": ["mill"]},
	{"id": "oven_croissant", "kind": "machine", "name": "Croissant Oven", "cost": 600,
		"pos": Vector2(X_CROIS, MACHINE_Z), "req": ["mill"], "model": "croissant_oven",
		"inputs": ["flour"], "output": "croissant", "time": 1.8, "to": ["shelf_croissant"]},
	{"id": "shelf_croissant", "kind": "shelf", "name": "Croissant Shelf", "cost": 450,
		"pos": Vector2(X_CROIS, SHELF_Z), "req": ["oven_croissant"], "product": "croissant"},
	{"id": "hire_farmer_s1", "kind": "hire", "name": "Hire Farmer", "cost": 500,
		"pos": Vector2(X_SEED, 5.8), "req": ["shelf_croissant"], "role": "farmer", "station": "field_sun1"},
	{"id": "hire_baker_seed", "kind": "hire", "name": "Hire Packer", "cost": 600,
		"pos": Vector2(X_SEED + 1.9, MACHINE_Z), "req": ["hire_farmer_s1"], "role": "baker", "station": "packer_seed"},
	{"id": "hire_janitor", "kind": "hire", "name": "Hire Janitor", "cost": 450,
		"pos": Vector2(-22.3, -8.6), "req": ["table_4"], "role": "janitor", "station": "terrace"},
	{"id": "table_5", "kind": "table", "name": "Cafe Table", "cost": 600,
		"pos": Vector2(-20.3, -19.5), "req": ["shelf_croissant"]},
	{"id": "hire_farmer_w3", "kind": "hire", "name": "Hire Farmer", "cost": 800,
		"pos": Vector2(X_MILL, 5.8), "req": ["hire_baker_seed"], "role": "farmer", "station": "field_wheat3"},
	{"id": "hire_baker_mill", "kind": "hire", "name": "Hire Miller", "cost": 900,
		"pos": Vector2(X_MILL + 1.9, MACHINE_Z), "req": ["hire_farmer_w3"], "role": "baker", "station": "mill"},
	{"id": "hire_baker_crois", "kind": "hire", "name": "Hire Baker", "cost": 1000,
		"pos": Vector2(X_CROIS + 1.9, MACHINE_Z), "req": ["hire_baker_mill"], "role": "baker", "station": "oven_croissant"},
	{"id": "table_6", "kind": "table", "name": "Cafe Table", "cost": 800,
		"pos": Vector2(-24.3, -19.5), "req": ["table_5", "hire_baker_mill"]},
	# ------------------------------------------------------------- pizza --
	{"id": "field_tomato", "kind": "field", "name": "Tomato Patch", "cost": 1300,
		"pos": Vector2(X_PIZZA, FIELD_Z), "req": ["shelf_croissant", "hire_farmer_s1"], "crop": "tomato", "feeds": ["oven_pizza"]},
	{"id": "oven_pizza", "kind": "machine", "name": "Pizza Oven", "cost": 1800,
		"pos": Vector2(X_PIZZA, MACHINE_Z), "req": ["field_tomato"], "model": "pizza_oven",
		"inputs": ["flour", "tomato"], "output": "pizza", "time": 2.2, "to": ["shelf_pizza"]},
	{"id": "shelf_pizza", "kind": "shelf", "name": "Pizza Shelf", "cost": 1300,
		"pos": Vector2(X_PIZZA, SHELF_Z), "req": ["oven_pizza"], "product": "pizza"},
	{"id": "hire_farmer_t", "kind": "hire", "name": "Hire Farmer", "cost": 1800,
		"pos": Vector2(X_PIZZA, 5.8), "req": ["shelf_pizza"], "role": "farmer", "station": "field_tomato"},
	{"id": "hire_baker_pizza", "kind": "hire", "name": "Hire Pizzaiolo", "cost": 2200,
		"pos": Vector2(X_PIZZA + 1.9, MACHINE_Z), "req": ["hire_farmer_t"], "role": "baker", "station": "oven_pizza"},
	# ------------------------------------------------------------- fries --
	{"id": "field_potato", "kind": "field", "name": "Potato Patch", "cost": 3000,
		"pos": Vector2(X_FRIES, FIELD_Z), "req": ["shelf_pizza"], "crop": "potato", "feeds": ["fryer"]},
	{"id": "fryer", "kind": "machine", "name": "Fry Station", "cost": 3800,
		"pos": Vector2(X_FRIES, MACHINE_Z), "req": ["field_potato"], "model": "fryer",
		"inputs": ["potato"], "output": "fries", "time": 1.7, "to": ["shelf_fries"]},
	{"id": "shelf_fries", "kind": "shelf", "name": "Fries Shelf", "cost": 2600,
		"pos": Vector2(X_FRIES, SHELF_Z), "req": ["fryer"], "product": "fries"},
	{"id": "hire_farmer_p", "kind": "hire", "name": "Hire Farmer", "cost": 3500,
		"pos": Vector2(X_FRIES, 5.8), "req": ["shelf_fries"], "role": "farmer", "station": "field_potato"},
	{"id": "hire_baker_fries", "kind": "hire", "name": "Hire Fry Cook", "cost": 4200,
		"pos": Vector2(X_FRIES + 1.9, MACHINE_Z), "req": ["hire_farmer_p"], "role": "baker", "station": "fryer"},
	{"id": "hire_farmer_w2", "kind": "hire", "name": "Hire Farmer", "cost": 2500,
		"pos": Vector2(X_W2, 5.8), "req": ["shelf_fries"], "role": "farmer", "station": "field_wheat2"},
	# ---------------------------------------------------------- back lot --
	{"id": "backlot", "kind": "land", "name": "Buy the Back Lot", "cost": 6000,
		"pos": Vector2(0.0, 7.5), "req": ["hire_baker_fries"]},
	{"id": "fountain", "kind": "decor", "name": "Pigeon Fountain", "cost": 5000,
		"pos": Vector2(-8.0, 17.5), "req": ["backlot"], "model": "fountain", "popularity": 0.3},
	{"id": "field_tomato2", "kind": "field", "name": "Tomato Patch", "cost": 4000,
		"pos": Vector2(X_PIZZA, BACK_FIELD_Z), "req": ["backlot"], "crop": "tomato", "feeds": ["oven_pizza"]},
	{"id": "field_potato2", "kind": "field", "name": "Potato Patch", "cost": 5000,
		"pos": Vector2(X_FRIES, BACK_FIELD_Z), "req": ["backlot"], "crop": "potato", "feeds": ["fryer"]},
	{"id": "field_wheat4", "kind": "field", "name": "Wheat Field", "cost": 3000,
		"pos": Vector2(X_MILL, BACK_FIELD_Z), "req": ["backlot"], "crop": "wheat", "feeds": ["mill", "oven_bread"]},
	{"id": "hire_farmer_t2", "kind": "hire", "name": "Hire Farmer", "cost": 5000,
		"pos": Vector2(X_PIZZA, 14.8), "req": ["field_tomato2"], "role": "farmer", "station": "field_tomato2"},
	{"id": "hire_farmer_p2", "kind": "hire", "name": "Hire Farmer", "cost": 6000,
		"pos": Vector2(X_FRIES, 14.8), "req": ["field_potato2"], "role": "farmer", "station": "field_potato2"},
	{"id": "hire_farmer_w4", "kind": "hire", "name": "Hire Farmer", "cost": 4000,
		"pos": Vector2(X_MILL, 14.8), "req": ["field_wheat4"], "role": "farmer", "station": "field_wheat4"},
	{"id": "golden_perch", "kind": "decor", "name": "VIP Golden Perch", "cost": 12000,
		"pos": Vector2(-14.0, 17.0), "req": ["fountain"], "model": "perch", "popularity": 0.2},
	{"id": "statue", "kind": "statue", "name": "Founder's Statue", "cost": 30000,
		"pos": Vector2(-1.9, 17.5), "req": ["golden_perch", "hire_farmer_p2", "hire_farmer_t2"], "popularity": 0.5},
]


static func zone(id: String) -> Dictionary:
	for z in ZONES:
		if str(z["id"]) == id:
			return z
	return {}


static func v3(p: Vector2, y := 0.0) -> Vector3:
	return Vector3(p.x, y, p.y)


## Short line shown on the buy card / objective for a zone.
static func zone_icon(z: Dictionary) -> String:
	var kind: String = z["kind"]
	match kind:
		"field":
			return str(z["crop"])
		"machine":
			return str(z["output"])
		"shelf":
			return str(z["product"])
		"table":
			return "table"
		"office":
			return "office"
		"hire":
			return "hire_" + str(z["role"])
		"land":
			return "land"
		"decor":
			return "fountain" if str(z.get("model", "")) == "fountain" else "perch"
		"statue":
			return "statue"
	return "ui_star"
