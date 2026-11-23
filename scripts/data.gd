class_name Data
extends RefCounted
## Oyun verileri. Süreler saniye (sulanmış tarlada). Susuz tarla yarı hızda büyür.

const CROPS := {
	"wheat":     {"name": "Buğday",    "icon": "🌾", "cost": 5,  "sell": 12,  "time": 20.0,  "xp": 2,  "level": 1, "color": "#f0c75e"},
	"carrot":    {"name": "Havuç",     "icon": "🥕", "cost": 10, "sell": 26,  "time": 45.0,  "xp": 4,  "level": 1, "color": "#fb8c00"},
	"tomato":    {"name": "Domates",   "icon": "🍅", "cost": 20, "sell": 52,  "time": 90.0,  "xp": 7,  "level": 2, "color": "#e53935"},
	"corn":      {"name": "Mısır",     "icon": "🌽", "cost": 30, "sell": 80,  "time": 150.0, "xp": 10, "level": 3, "color": "#ffd54f"},
	"sunflower": {"name": "Ayçiçeği",  "icon": "🌻", "cost": 45, "sell": 120, "time": 240.0, "xp": 15, "level": 4, "color": "#fdd835"},
	"pumpkin":   {"name": "Balkabağı", "icon": "🎃", "cost": 70, "sell": 190, "time": 360.0, "xp": 22, "level": 5, "color": "#fb8c00"},
}

const TREES := {
	"apple":  {"name": "Elma Ağacı",     "icon": "🍎", "cost": 150, "grow": 120.0, "regrow": 90.0,  "sell": 35, "xp": 8,  "level": 2, "fruit": "#e53935"},
	"orange": {"name": "Portakal Ağacı", "icon": "🍊", "cost": 300, "grow": 200.0, "regrow": 140.0, "sell": 60, "xp": 12, "level": 4, "fruit": "#fb8c00"},
	"cherry": {"name": "Kiraz Ağacı",    "icon": "🍒", "cost": 500, "grow": 300.0, "regrow": 200.0, "sell": 95, "xp": 18, "level": 6, "fruit": "#b71c1c"},
}

const ANIMALS := {
	"chicken": {"name": "Tavuk", "icon": "🐔", "product": "Yumurta", "picon": "🥚", "cost": 80,  "time": 60.0,  "sell": 18,  "xp": 4,  "level": 1, "color": "#fff8e1"},
	"sheep":   {"name": "Koyun", "icon": "🐑", "product": "Yün",     "picon": "🧶", "cost": 250, "time": 120.0, "sell": 45,  "xp": 9,  "level": 3, "color": "#ffffff"},
	"pig":     {"name": "Domuz", "icon": "🐷", "product": "Mantar",  "picon": "🍄", "cost": 400, "time": 180.0, "sell": 75,  "xp": 13, "level": 5, "color": "#8d6e63"},
	"cow":     {"name": "İnek",  "icon": "🐄", "product": "Süt",     "picon": "🥛", "cost": 600, "time": 240.0, "sell": 110, "xp": 18, "level": 6, "color": "#ffffff"},
}

const DECOR := {
	"path":      {"name": "Taş Yol",  "icon": "🪨", "cost": 2,  "level": 1},
	"fence":     {"name": "Çit",      "icon": "🪵", "cost": 4,  "level": 1},
	"flowers":   {"name": "Çiçeklik", "icon": "🌷", "cost": 15, "level": 1},
	"rock":      {"name": "Kaya",     "icon": "⛰️", "cost": 8,  "level": 1},
	"bush":      {"name": "Çalı",     "icon": "🌿", "cost": 12, "level": 2},
	"lantern":   {"name": "Fener",    "icon": "🏮", "cost": 40, "level": 2},
	"hay":       {"name": "Saman",    "icon": "🟡", "cost": 20, "level": 3},
	"scarecrow": {"name": "Korkuluk", "icon": "🧑‍🌾", "cost": 80, "level": 4, "info": "Çevresindeki (3 kare) ekinler %25 hızlı büyür"},
}

const BUILDINGS := {
	"house": "Çiftlik Evi", "barn": "Ahır", "silo": "Silo", "well": "Kuyu", "windmill": "Yel Değirmeni",
}

## Kaynaklar: hasatla ambara girer, satılır ya da siparişe verilir.
const RESOURCES := {
	"cereal":   {"name": "Tahıl",     "icon": "🌾", "price": 3},
	"veg":      {"name": "Sebze",     "icon": "🥕", "price": 4},
	"fruit":    {"name": "Meyve",     "icon": "🍎", "price": 6},
	"nut":      {"name": "Kuruyemiş", "icon": "🌻", "price": 8},
	"egg":      {"name": "Yumurta",   "icon": "🥚", "price": 5},
	"wool":     {"name": "Yün",       "icon": "🧶", "price": 9},
	"mushroom": {"name": "Mantar",    "icon": "🍄", "price": 12},
	"milk":     {"name": "Süt",       "icon": "🥛", "price": 14},
}

## Hangi hasat hangi kaynaktan kaç tane verir.
const YIELD := {
	"wheat": ["cereal", 2], "carrot": ["veg", 2], "tomato": ["veg", 3], "corn": ["cereal", 4],
	"sunflower": ["nut", 3], "pumpkin": ["veg", 6],
	"apple": ["fruit", 3], "orange": ["fruit", 4], "cherry": ["fruit", 5],
	"chicken": ["egg", 2], "sheep": ["wool", 2], "pig": ["mushroom", 2], "cow": ["milk", 3],
}

const BARN_CAP := 150

static func xp_for_level(lv: int) -> int:
	return int(round(40.0 * pow(lv, 1.6)))
