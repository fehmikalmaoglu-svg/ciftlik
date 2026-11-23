class_name Data
extends RefCounted
## Oyun verileri. Süreler saniye (sulanmış tarlada). Susuz tarla yarı hızda büyür.

const CROPS := {
	"wheat":     {"name": "Buğday",    "icon": "🌾", "cost": 5,  "sell": 12,  "time": 60.0,  "xp": 2,  "level": 1, "seasons": [0, 1, 2, 3], "color": "#f0c75e"},
	"carrot":    {"name": "Havuç",     "icon": "🥕", "cost": 10, "sell": 26,  "time": 135.0,  "xp": 4,  "level": 1, "seasons": [0, 2, 3], "color": "#fb8c00"},
	"lettuce":   {"name": "Marul",     "icon": "🥗", "cost": 8,  "sell": 20,  "time": 100.0, "xp": 3,  "level": 1, "seasons": [0, 2], "color": "#8bc34a"},
	"tomato":    {"name": "Domates",   "icon": "🍅", "cost": 20, "sell": 52,  "time": 270.0,  "xp": 7,  "level": 2, "seasons": [0, 1], "color": "#e53935"},
	"cabbage":   {"name": "Lahana",    "icon": "🥬", "cost": 25, "sell": 70,  "time": 380.0, "xp": 9,  "level": 3, "seasons": [2, 3], "color": "#9ccc65"},
	"corn":      {"name": "Mısır",     "icon": "🌽", "cost": 30, "sell": 80,  "time": 450.0, "xp": 10, "level": 3, "seasons": [1, 2], "color": "#ffd54f"},
	"sunflower": {"name": "Ayçiçeği",  "icon": "🌻", "cost": 45, "sell": 120, "time": 720.0, "xp": 15, "level": 4, "seasons": [1], "color": "#fdd835"},
	"pumpkin":   {"name": "Balkabağı", "icon": "🎃", "cost": 70, "sell": 190, "time": 1080.0, "xp": 22, "level": 5, "seasons": [2], "color": "#fb8c00"},
}

const TREES := {
	"apple":  {"name": "Elma Ağacı",     "icon": "🍎", "cost": 150, "grow": 360.0, "regrow": 270.0,  "sell": 35, "xp": 8,  "level": 2, "fruit": "#e53935"},
	"orange": {"name": "Portakal Ağacı", "icon": "🍊", "cost": 300, "grow": 600.0, "regrow": 420.0, "sell": 60, "xp": 12, "level": 4, "fruit": "#fb8c00"},
	"cherry": {"name": "Kiraz Ağacı",    "icon": "🍒", "cost": 500, "grow": 900.0, "regrow": 600.0, "sell": 95, "xp": 18, "level": 6, "fruit": "#b71c1c"},
}

const ANIMALS := {
	"chicken": {"name": "Tavuk", "icon": "🐔", "product": "Yumurta", "picon": "🥚", "cost": 80,  "time": 180.0,  "sell": 18,  "xp": 4,  "level": 1, "feed": 1, "color": "#fff8e1"},
	"sheep":   {"name": "Koyun", "icon": "🐑", "product": "Yün",     "picon": "🧶", "cost": 250, "time": 360.0, "sell": 45,  "xp": 9,  "level": 3, "feed": 2, "color": "#ffffff"},
	"pig":     {"name": "Domuz", "icon": "🐷", "product": "Mantar",  "picon": "🍄", "cost": 400, "time": 540.0, "sell": 75,  "xp": 13, "level": 5, "feed": 3, "color": "#8d6e63"},
	"cow":     {"name": "İnek",  "icon": "🐄", "product": "Süt",     "picon": "🥛", "cost": 600, "time": 720.0, "sell": 110, "xp": 18, "level": 6, "feed": 4, "color": "#ffffff"},
}

const DECOR := {
	"path":      {"name": "Taş Yol",  "icon": "🪨", "cost": 2,  "level": 1},
	"fence":     {"name": "Çit",      "icon": "🪵", "cost": 4,  "level": 1},
	"gate":      {"name": "Çit Kapısı", "icon": "🚪", "cost": 10, "level": 1, "info": "Çitin içinden geçilebilen kapı"},
	"flowers":   {"name": "Çiçeklik", "icon": "🌷", "cost": 15, "level": 1},
	"rock":      {"name": "Kaya",     "icon": "⛰️", "cost": 8,  "level": 1},
	"bush":      {"name": "Çalı",     "icon": "🌿", "cost": 12, "level": 2},
	"lantern":   {"name": "Fener",    "icon": "🏮", "cost": 40, "level": 2},
	"hay":       {"name": "Saman",    "icon": "🟡", "cost": 20, "level": 3},
	"scarecrow": {"name": "Korkuluk", "icon": "🧑‍🌾", "cost": 80, "level": 4, "info": "Çevresindeki (3 kare) ekinler %25 hızlı büyür"},
}

## Çiçekler (Aşama 4): kalıcı tarh, sabit büyüme süresi; hasattan sonra yeniden açar.
## Büyürken ıslak geçen süre oranı kazancı en fazla 3 katına çıkarır.
const FLOWERS := {
	"daisy":    {"name": "Papatya", "icon": "🌼", "cost": 25,  "time": 180.0,  "sell": 10, "xp": 3,  "level": 1, "color": "#ffffff", "center": "#fdd835"},
	"tulip":    {"name": "Lale",    "icon": "🌷", "cost": 45,  "time": 360.0, "sell": 22, "xp": 6,  "level": 2, "color": "#ec407a", "center": "#ffd54f"},
	"rose":     {"name": "Gül",     "icon": "🌹", "cost": 90,  "time": 600.0, "sell": 40, "xp": 10, "level": 4, "color": "#d32f2f", "center": "#8e0000"},
	"lavender": {"name": "Lavanta", "icon": "💜", "cost": 130, "time": 900.0, "sell": 62, "xp": 15, "level": 5, "color": "#9575cd", "center": "#673ab7"},
}
const FLOWER_WET_BONUS := 2.0   # tamamen sulu: ×(1 + 2)
const FLOWER_MAX_LV := 5
const FLOWER_HARVESTS_PER_LV := 5

## Balık göleti (Aşama 4): 2×2 kare, yem istemez.
const POND := {"name": "Balık Göleti", "icon": "🐟", "cost": 350, "time": 450.0, "sell": 40, "xp": 10, "level": 3, "info": "2×2 kare. Kendiliğinden balık üretir."}

## Tavuk kümesi: 2×2. Yakındaki tavuklar yumurtayı buraya bırakır, tek tıkla toplanır.
const COOP := {"name": "Tavuk Kümesi", "icon": "🛖", "cost": 200, "level": 1, "info": "2×2. Çevresindeki (6 kare) tavuklar buraya yumurtlar."}
const COOP_RANGE := 6
const COOP_CAP := 12

static func animal_shop() -> Dictionary:
	var d := ANIMALS.duplicate()
	d["coop"] = COOP
	return d

static func garden() -> Dictionary:
	var d := FLOWERS.duplicate()
	d["pond"] = POND
	return d

static func flower_mult(lv: int) -> float:
	return 1.0 + 0.2 * (lv - 1)

## Oyuncunun kurduğu yapılar (🏗️ Yapı aleti). w×d kare kaplar.
const BUILDINGS := {
	"barn":  {"name": "Ambar",       "icon": "📦", "cost": 50,  "level": 1, "w": 4, "d": 4, "xp": 15, "info": "4×4. Hasat burada saklanır (150 yer). Satış ve siparişler için gerekli."},
	"well":  {"name": "Su Kuyusu",   "icon": "🪣", "cost": 40,  "level": 1, "w": 1, "d": 1, "xp": 5,  "info": "Çevresindeki (5 kare) tarla ve çiçekler yarı hızda kurur."},
	"silo":  {"name": "Silo",        "icon": "🛢️", "cost": 150, "level": 2, "w": 2, "d": 2, "xp": 15, "info": "2×2. Ambara +100 yer açar."},
	"oven": {"name": "Fırın", "icon": "🔥", "cost": 250, "level": 3, "w": 2, "d": 2, "xp": 25, "info": "2×2. Undan poğaça, balık ekmek ve meyveli turta pişirir. Tıkla: fırın penceresi."},
	"house": {"name": "Çiftlik Evi", "icon": "🏠", "cost": 300, "level": 2, "w": 4, "d": 4, "xp": 40, "info": "4×4. Çiftliğin yuvası: her sabah kapıda küçük bir hediye bırakılır."},
}
const SILO_CAP := 100
const WELL_RANGE := 5

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
	"flower":   {"name": "Çiçek",     "icon": "🌷", "price": 7},
	"fish":     {"name": "Balık",     "icon": "🐟", "price": 10},
	"flour":    {"name": "Un",        "icon": "🥖", "price": 8},
	"pogaca":   {"name": "Poğaça",    "icon": "🥐", "price": 30},
	"fishbread": {"name": "Balık Ekmek", "icon": "🥪", "price": 45},
	"pie":      {"name": "Meyveli Turta", "icon": "🥧", "price": 72},
}

## Hangi hasat hangi kaynaktan kaç tane verir.
const YIELD := {
	"wheat": ["cereal", 2], "carrot": ["veg", 2], "tomato": ["veg", 3], "corn": ["cereal", 4],
	"sunflower": ["nut", 3], "pumpkin": ["veg", 6], "lettuce": ["veg", 2], "cabbage": ["veg", 4],
	"apple": ["fruit", 3], "orange": ["fruit", 4], "cherry": ["fruit", 5],
	"chicken": ["egg", 2], "sheep": ["wool", 2], "pig": ["mushroom", 2], "cow": ["milk", 3],
	"daisy": ["flower", 2], "tulip": ["flower", 3], "rose": ["flower", 4], "lavender": ["flower", 5],
	"pond": ["fish", 4],
}

const BARN_CAP := 150

## Mevsimler (Aşama 2). Her biri SEASON_LEN saniye; gün/gece döngüsünden bağımsız.
const SEASON_LEN := 1800.0
const SEASONS := [
	{"name": "İlkbahar", "icon": "🌸"},
	{"name": "Yaz",      "icon": "☀️"},
	{"name": "Sonbahar", "icon": "🍂"},
	{"name": "Kış",      "icon": "❄️"},
]

## Dolu su seviyesinin (1.0) normal havada tamamen kuruma süresi.
const WATER_DUR := 240.0
## Sulama/elle sulama bu seviyenin altındaysa yapılabilir.
const WATER_REFILL := 0.6

const WEATHER := {
	"rain":    {"name": "Yağmur",   "icon": "🌧️", "msg": "Yağmur başladı: tarlalar kendiliğinden sulanıyor"},
	"drought": {"name": "Kuraklık", "icon": "🔥", "msg": "Kuraklık! Toprak 3× hızlı kuruyor"},
	"snow":    {"name": "Kar",      "icon": "🌨️", "msg": "Kar yağıyor: sulamaya gerek yok, ekinler yavaş ama düzenli büyür"},
}
## Mevsim başında hava olayı ihtimalleri.
const WEATHER_CHANCE := [
	[["rain", 0.4]],
	[["drought", 0.35], ["rain", 0.15]],
	[["rain", 0.4]],
	[["snow", 0.6]],
]

## Hayvanlar (Aşama 3). Bir tam yem, FEED_CYCLES ürün süresi yeter; yem yoksa üretim durur.
## Yem tahıl ister ("feed" alanı); ambarda tahıl yoksa her eksik tahıl FEED_COIN altın.
const FEED_CYCLES := 3.0
const FEED_REFILL := 0.5
const FEED_COIN := 6
## Hayvan seviyesi: her seviyede HARVESTS_PER_LV × seviye toplama gerekir.
const ANIMAL_MAX_LV := 5
const HARVESTS_PER_LV := 4

static func animal_sell_mult(lv: int) -> float:
	return 1.0 + 0.15 * (lv - 1)

static func animal_extra_yield(lv: int) -> int:
	return (lv - 1) / 2

static func season_names(list: Array) -> String:
	var out := []
	for i in list:
		out.append(SEASONS[i].name)
	return ", ".join(out)

static func season_icons(list: Array) -> String:
	var out := ""
	for i in list:
		out += SEASONS[i].icon
	return out

static func xp_for_level(lv: int) -> int:
	return int(round(40.0 * pow(lv, 1.6)))
