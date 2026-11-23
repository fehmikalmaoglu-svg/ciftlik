extends Node3D
## Çiftliğim 3D — ana oyun. Dünya, simülasyon, çiftçi, kamera, gün/gece, arayüz, ses ve kayıt.

## Arazi: çiftlik -farm_h..farm_h-1 karesi (yeni kariyer 16×16). 🗺️ Arazi menüsünden adım adım büyür, en fazla dünya (-20..19).
## Çim parçaları dünyayı 8×8'lik 5×5 parsele böler.
const FARM_H_START := 8
## Genişleme adımları: [yeni yarı boy, altın, seviye]
const EXPAND := [[10, 300, 2], [12, 700, 3], [14, 1500, 5], [16, 3000, 7], [18, 5500, 9], [20, 9000, 12]]
const WORLD_MIN := -20
const WORLD_MAX := 19
const PARCEL := 8
const DAY_LEN := 900.0   # gündüz ~%70, gece ~%30
const OLD_SAVE := "user://save.json"
const PROFILE := "user://profile.json"
const SLOTS := 3
## Sahne yeniden yüklenince hangi kariyerin açılacağı: {"slot": n, "new": bool, "name": str}
static var boot := {}
const POND_X := 29.0
const POND_Z := 6.0
const POND_R := 4.2
const OFFLINE_CAP := 6.0 * 3600.0
const QUEST_SLOTS := 4
## Çiftçinin geçemediği dekorlar.
## İş animasyonu süreleri (sn); çiftçi bu sürede yerinde kalır.
const ACT_DUR := {"plow": 0.55, "remove": 0.55, "move": 0.5, "water": 0.85, "plant": 0.55, "flower": 0.55, "tree": 0.6,
	"harvest": 0.5, "feed": 0.8, "coop": 0.4, "pond": 0.4, "animal": 0.4, "decor": 0.35, "build": 0.6}
const NET_PORT := 24565
## Geliştirici: --netport=N ile başka port (oyun açıkken test için).
func _net_port() -> int:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--netport="):
			return int(a.substr(10))
	return NET_PORT
const NET_COLORS := ["#4a90d9", "#9c5bd6", "#e0912f", "#2fae8f", "#d94a8c"]
const WALK_LIM := 56     # çiftçinin gezebileceği alan (±), görünen arazinin içi
const BLOCK_DECOR := ["fence", "rock", "lantern", "hay", "scarecrow", "bush", "flowers"]
const QUEST_SKIP_COOLDOWN := 24.0 * 3600.0
const QUEST_SKIP_GEMS := 2
const FSPEED := 5.2
## Zemin: köşe rengi + mevsim tonu (yaz kuru, sonbahar sarı, kış karlı).
const GROUND_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 tint : source_color = vec4(1.0);
uniform float amt = 0.0;
void fragment() {
	vec3 c = COLOR.rgb;
	c = mix(pow((c + vec3(0.055)) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	ALBEDO = mix(c, tint.rgb * (0.8 + 1.2 * lum), amt);
	ROUGHNESS = 1.0;
	SPECULAR = 0.3;
}
"""
## Gökyüzü: dikey renk geçişi, güneş, ay (hilal gölgeli), titreşen yıldızlar.
const SKY_SHADER := """
shader_type sky;
uniform vec3 top_col = vec3(0.3, 0.6, 0.95);
uniform vec3 hor_col = vec3(0.62, 0.83, 1.0);
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 moon_dir = vec3(0.0, -1.0, 0.0);
uniform float night = 0.0;
uniform float cloud = 0.0;
float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
void sky() {
	vec3 d = EYEDIR;
	float h = clamp(d.y, 0.0, 1.0);
	vec3 c = mix(hor_col, top_col, pow(h, 0.55));
	if (d.y < 0.0) { c = hor_col; }
	float clear = 1.0 - cloud;
	if (night > 0.01 && d.y > 0.0) {
		vec3 q = d * 260.0;
		vec3 id = floor(q);
		float r = hash(id);
		if (r > 0.993) {
			float s = smoothstep(0.42, 0.0, length(fract(q) - 0.5)) * 2.2;
			float tw = AT_CUBEMAP_PASS ? 0.8 : 0.65 + 0.35 * sin(TIME * (2.0 + r * 3.0) + r * 91.0);
			vec3 sc = mix(vec3(1.0, 0.85, 0.7), vec3(0.75, 0.85, 1.0), hash(id + 3.0));
			c += sc * s * tw * night * clear * smoothstep(0.0, 0.25, d.y) * (1.0 + 2.0 * step(0.9993, r));
		}
		float band = pow(max(0.0, 1.0 - abs(dot(d, normalize(vec3(0.4, 0.3, 1.0))) * 2.2)), 2.0);
		float neb = vnoise(d * 7.0) * 0.6 + vnoise(d * 19.0) * 0.4;
		c += vec3(0.3, 0.32, 0.5) * band * smoothstep(0.35, 0.9, neb) * 0.3 * night * clear;
	}
	vec3 md = normalize(moon_dir);
	float mdot = dot(d, md);
	float disc = smoothstep(0.99935, 0.99955, mdot);
	vec3 side = normalize(cross(md, vec3(0.0, 1.0, 0.0)));
	float shade = smoothstep(0.99935, 0.99955, dot(d, normalize(md + side * 0.022)));
	float crat = 0.85 + 0.15 * hash(floor(d * 900.0));
	vec3 moon = vec3(1.0, 0.97, 0.88) * disc * (1.0 - 0.85 * shade) * crat * 1.6;
	float halo = pow(max(mdot, 0.0), 400.0) * 0.6 + pow(max(mdot, 0.0), 24.0) * 0.07;
	c += (moon + vec3(0.6, 0.7, 1.0) * halo) * night * (1.0 - cloud * 0.8);
	vec3 sd = normalize(sun_dir);
	float sdot = dot(d, sd);
	c += vec3(1.0, 0.92, 0.75) * (smoothstep(0.9992, 0.9996, sdot) * 3.0 + pow(max(sdot, 0.0), 180.0) * 0.5) * (1.0 - night) * clear;
	COLOR = c;
}
"""
## Rüzgârda sallanan çim: kökten uca renk geçişi, mevsim tonu zeminle aynı.
const GRASS_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 root_col : source_color = vec4(0.30, 0.55, 0.18, 1.0);
uniform vec4 tip_col : source_color = vec4(0.62, 0.85, 0.35, 1.0);
uniform vec4 tint : source_color = vec4(1.0);
uniform float amt = 0.0;
varying float h;
void vertex() {
	h = UV.y;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = sin(TIME * 1.7 + wp.x * 0.55 + wp.z * 0.35) + 0.5 * sin(TIME * 3.1 + wp.x * 1.3);
	VERTEX.x += w * 0.045 * h * h;
	VERTEX.z += w * 0.025 * h * h;
}
void fragment() {
	vec3 c = mix(root_col.rgb, tip_col.rgb, h) * COLOR.rgb;
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	ALBEDO = mix(c, tint.rgb * (0.8 + 1.2 * lum), amt);
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
	BACKLIGHT = vec3(0.25, 0.35, 0.1);
}
"""
## Yardım sayfaları: [başlık, [[simge/tuş, açıklama], ...]]
const HELP_PAGES := [
	["🎮  Kontroller", [
		["Sol tık", "Seçili aleti kareye uygular. Sürükleyerek çok kareye iş verirsin; çiftçi sırayla yapar."],
		["Boş yere tık", "Çiftçi oraya yürür. WASD ile de yürütebilirsin."],
		["Sağ sürükle", "Kamerayı döndürür ve eğer. Q / E döndürür, R / F eğer."],
		["Orta sürükle", "Haritada gezersin. Ok tuşları da kamerayı kaydırır; Boşluk çiftçiye geri döner."],
		["Tekerlek", "Yakınlaştır / uzaklaştır."],
		["Tab · 🎒", "Çark menüyü açar: aletler imlecin çevresinde dizilir, birine tıkla. Sağ alttaki 🎒 düğmesi de açar."],
		["1 – 9 · 0 · -", "Aleti doğrudan seç: El, Çapa, Tohum, Sula, Ağaç, Hayvan, Dekor, Bahçe, Kaldır; 0 Yapı, - Taşı."],
		["🚚 · 🗑️", "Taşı: nesneye tıkla, sonra yeni yerine tıkla; seçiliyken kendisine tıkla ya da T ile döndür (Esc vazgeçer). Her nesnenin (bina, fener, çit, ağaç, hayvan…) üstünde basılı tut: Döndür / Taşı / Kaldır menüsü; ambar, ev, ağaç, hayvan, çit… hepsi taşınır, bedava. Kaldır: nesneyi siler, yarı fiyatı geri gelir."],
		["B · J · Esc", "B ambarı, J görev panelini açar; Esc iş kuyruğunu ve pencereleri kapatır."],
		["🎣", "Balık tutma: gölün batı kıyısındaki 🎣 Balıkçı tezgâhından olta ve yem al. Göle tıkla; ❗ çıkınca tıkla (ya da Boşluk), mini oyunda basılı tutarak yeşil alanı balığın üstünde tut. 6 tür var, yayın balığı geceleri çıkar; tezgâhta balık defterin durur."],
		["🔥", "Fırın (Yapı, seviye 3, 2×2): un ile poğaça (+yumurta), balık ekmek (+balık) ve meyveli turta (+süt, meyve) pişir. Tıkla ya da Boşluk ile körükle, ısıyı yeşil bantta tut; çabuk pişirirsen +1 ürün."],
		["🌬️", "Değirmen (çiftliğin kuzeydoğusu, seviye 2): 6 tahılı una çevirir. İbre yeşil bölgedeyken tıkla; 5 turun her isabeti 1 🥖 un, altın ortası fazladan XP."],
		["🏠", "Çiftlik evi her sabah kapına hediye altın bırakır (seviyenle artar)."],
		["G · 😄", "Emote çubuğu: el salla, gül, kalp, alkış… Yakında arkadaşın varsa karakterin ona döner; online iki tarafta da görünür."],
	]],
	["🌱  Tarım", [
		["⛏️", "Çapa ile toprağı sür, 🌱 tohum ek, 💧 sula, ✋ El ile topla."],
		["✋", "El akıllıdır: boş tarlaya seçili tohumu eker, susuz tarlayı sular, hazır olanı toplar."],
		["💧", "Sulanan toprak bir süre ıslak kalır ve ekin 2 kat hızlı büyür. Tarla üstünde 💧 görürsen su istiyor demektir."],
		["🧺", "Tarla üstündeki sepet, ürünün hasada hazır olduğunu gösterir."],
		["🧑‍🌾", "Korkuluk çevresindeki ekinleri %25 hızlandırır."],
		["📦", "Hasat ambara gider. Ambarda kaynak satar, pazar siparişlerini teslim edersin."],
	]],
	["🐔  Hayvanlar", [
		["🌾", "Hayvanlar yem ister (tahıl; yoksa altın). Aç hayvan üretmez; ✋ ile yemle."],
		["🐑", "Yan yana duran aynı tür hayvanlar ağıl olur; biri yemlenince hepsi yer."],
		["⭐", "Hayvanlar topladıkça seviye atlar ve daha çok kazandırır."],
		["🛖", "Kümes: çevresindeki tavuklar yumurtayı oraya bırakır, kümesten toplarsın."],
		["🚪", "Çiftçi çitlerden, kayalardan ve ağaçlardan geçmez; ağıla kapıdan girer."],
	]],
	["🌼  Bahçe ve Görevler", [
		["🌷", "Bahçe (9): çiçek tarhları kalıcıdır, sabit sürede açar. Büyürken sulu kalırsa 3 kata kadar kazandırır."],
		["🐟", "Gölet 2×2 kare kaplar ve kendiliğinden balık verir."],
		["📜", "Aynı anda 4 görev olur. Biten görev 🏅 madalya, 💎 elmas ve XP verir."],
		["✖️", "Günde bir görevi ücretsiz silebilirsin; sonrası 2 💎."],
	]],
	["🗺️  Arazi ve Mevsimler", [
		["🗺️", "Çiftlik küçük bir kareyle başlar. Üstteki 🗺️ Arazi düğmesinden (ya da L) altın ve seviyeyle adım adım genişlet; çit kendiliğinden dışarı taşınır."],
		["🏗️", "Yeni çiftlikte hiçbir şey hazır değil: Yapı aletiyle (0 tuşu) ambar, kuyu, silo ve ev kurarsın. Ambar olmadan hasat saklanmaz; kuyu yakındaki tarlaları geç kurutur, silo ambara yer açar, ev her sabah hediye bırakır."],
		["⚙️", "Ayarlar (⚙️ ya da ana menü): tam ekran (F11), grafik kalitesi, çözünürlük, gece parlaklığı ve ses."],
		["🌸", "Dört mevsim var, her biri 30 dakika. Bazı tohumlar yalnız kendi mevsiminde ekilir."],
		["🌧️", "Yağmur her şeyi sular. 🔥 Kuraklıkta su çabuk biter. 🌨️ Karda sulamaya gerek yok."],
		["🌙", "Gün 15 dakika sürer, gece kısadır; fenerler geceleri yanar."],
		["⭐", "Yeni kariyer bir hikâyeyle başlar: ot ve taş bürümüş araziyi temizle, ⭐ Hikâye görevlerini izle. Hikâye bitince günlük görevler gelir."],
		["📡", "Arkadaşınla oyna: sağ üstteki 📡 ile çiftliğini paylaş, arkadaşın ana menüde 🤝 Arkadaşa Katıl'a senin adresini yazsın. Aynı ağda doğrudan çalışır."],
		["💾", "Oyun otomatik kaydedilir; sen yokken de çiftlik büyür."],
	]],
]

## Doğa süsleri (Kenney Nature Kit, CC0): assets/nature
const NAT := "res://assets/nature/"
## Stilize doku modelleri (Quaternius Stylized Nature MegaKit, CC0): assets/megakit, .gltf uzantılı.
const MK := "res://assets/megakit/"
## MegaKit modelleri Kenney'den çok daha büyük: önek başına taban ölçek.
const MK_BASE := {"CommonTree": 0.22, "Pine": 0.22, "TwistedTree": 0.12, "DeadTree": 0.18, "Bush": 0.3, "Fern": 0.35,
	"Flower": 0.24, "Grass": 0.22, "Mushroom": 0.55, "Plant_1": 0.3, "Plant_7": 0.6, "Clover": 0.3,
	"Pebble": 1.3, "Rock_Medium": 0.16, "RockPath": 0.9}
const WILD_TREES := ["CommonTree_1.gltf", "CommonTree_2.gltf", "CommonTree_3.gltf", "CommonTree_5.gltf", "Pine_3.gltf", "Pine_1.gltf"]
const WILD_BUSH := ["Bush_Common.gltf", "Bush_Common_Flowers.gltf", "Fern_1.gltf", "Plant_1_Big.gltf", "Bush_Common.gltf", "Plant_1.gltf"]
const WILD_ROCK := ["Rock_Medium_1.gltf", "Rock_Medium_2.gltf", "Rock_Medium_3.gltf", "Pebble_Round_1.gltf", "Pebble_Round_3.gltf"]
const WILD_WOOD := ["stump_old.glb", "stump_roundDetailed.glb", "log_large.glb", "log.glb", "stump_round.glb"]
const WILD_FLOWER := ["Flower_3_Single.gltf", "Flower_4_Single.gltf", "Flower_3_Group.gltf", "Flower_4_Group.gltf", "flower_purpleA.glb", "flower_yellowB.glb"]
const WILD_MUSH := ["Mushroom_Common.gltf", "Mushroom_Laetiporus.gltf", "Mushroom_Common.gltf"]
const WILD_GRASS := ["Grass_Common_Short.gltf", "Grass_Common_Tall.gltf", "Grass_Wispy_Short.gltf", "Grass_Wispy_Tall.gltf", "Clover_1.gltf", "Clover_2.gltf", "Plant_7.gltf"]
## Kenney küçük süsleri bu sahnede ufak kalıyor: önek başına ölçek çarpanı.
const PROP_BOOST := {"flower_": 2.1, "mushroom_": 1.7, "grass_": 1.5, "plant_": 1.4, "rock_small": 1.4, "stone_small": 1.4, "lily_": 1.4}
const BIG_TREES := ["CommonTree_1.gltf", "CommonTree_2.gltf", "CommonTree_3.gltf", "CommonTree_4.gltf", "CommonTree_5.gltf",
	"Pine_1.gltf", "Pine_2.gltf", "Pine_4.gltf", "Pine_5.gltf", "TwistedTree_1.gltf", "TwistedTree_2.gltf"]


const SEASON_TINT := [["#7ccf4a", 0.0], ["#b8bf45", 0.3], ["#d0902e", 0.5], ["#eef3f8", 0.7]]

const TOOLS := [
	{"id": "hand", "icon": "✋", "name": "El", "shelf": "seed", "tip": "Akıllı el: ek, sula, topla"},
	{"id": "plow", "icon": "⛏️", "name": "Çapa", "shelf": "", "tip": "Boş çimeni tarlaya çevir"},
	{"id": "seed", "icon": "🌱", "name": "Tohum", "shelf": "seed", "tip": "Seçili tohumu ek"},
	{"id": "water", "icon": "💧", "name": "Sula", "shelf": "", "tip": "Toprağı ıslat: kuruyana kadar 2× hız"},
	{"id": "tree", "icon": "🌳", "name": "Ağaç", "shelf": "tree", "tip": "Meyve ağacı dik"},
	{"id": "animal", "icon": "🐔", "name": "Hayvan", "shelf": "animal", "tip": "Hayvan al"},
	{"id": "decor", "icon": "🌷", "name": "Dekor", "shelf": "decor", "tip": "Çit, yol, çiçek…"},
	{"id": "garden", "icon": "🌼", "name": "Bahçe", "shelf": "garden", "tip": "Çiçek tarhı ve balık göleti"},
	{"id": "build", "icon": "🏗️", "name": "Yapı", "shelf": "build", "tip": "Ambar, kuyu, silo, ev kur"},
	{"id": "remove", "icon": "🗑️", "name": "Kaldır", "shelf": "", "tip": "Nesneyi kaldır (yarı fiyatı geri gelir)"},
	{"id": "move", "icon": "🚚", "name": "Taşı", "shelf": "", "tip": "Nesneye tıkla, sonra yeni yerine tıkla  [-]"},
]
const ACT_TXT := {"plant": "🌱 Ek", "water": "💧 Sula", "harvest": "🧺 Topla", "feed": "🌾 Yemle", "flower": "🌼 Çiçek dik", "pond": "🐟 Gölet kur", "build": "🏗️ Kur", "coop": "🛖 Kümes kur", "plow": "⛏️ Sür", "tree": "🌳 Dik", "animal": "🐾 Yerleştir", "decor": "🎨 Yerleştir", "remove": "🗑️ Kaldır", "move": "🚚 Buraya taşı", "turn": "🔄 Döndür"}
## Yeni kariyerin başında temizlenecek yabani şeyler: [modeller, ölçek, altın, XP, yolu kapatır mı]
const DEBRIS := {
	"weed": [["Grass_Wispy_Tall.gltf", "Fern_1.gltf", "Plant_1_Big.gltf"], 1.5, 2, 1, false],
	"stone": [["Rock_Medium_1.gltf", "Rock_Medium_2.gltf", "Rock_Medium_3.gltf"], 1.4, 4, 1, true],
	"stump": [["stump_old.glb", "stump_roundDetailed.glb"], 1.5, 5, 2, true],
	"log": [["log_large.glb"], 1.3, 6, 2, true],
}
## Hikâye: sırayla açılan görevler. kind/arg _quest_event ile eşleşir.
const STORY := [
	{"kind": "clear", "arg": "", "need": 6, "text": "🪓 Araziyi temizle: 6 ot, taş ya da kütük kaldır (🗑️ Kaldır)", "coins": 40, "xp": 10,
		"say": "Taşların altından kara, yumuşak bir toprak çıktı. Teyzen haklıymış!"},
	{"kind": "build", "arg": "barn", "need": 1, "text": "📦 Hasat için bir ambar kur (🏗️ Yapı)", "coins": 30, "xp": 15,
		"say": "Ambar hazır! Topladığın her şey burada saklanacak."},
	{"kind": "plow", "arg": "", "need": 6, "text": "⛏️ Çapa ile 6 kare tarla sür", "coins": 30, "xp": 10,
		"say": "Tarla hazır. Ambarın önündeki çuvalda buğday tohumu var."},
	{"kind": "plant", "arg": "wheat", "need": 6, "text": "🌱 6 kare buğday ek (🌱 Tohum)", "coins": 20, "xp": 10,
		"say": "Toprak susamış görünüyor…"},
	{"kind": "water", "arg": "", "need": 6, "text": "💧 Ektiğin tarlaları sula", "coins": 20, "xp": 10,
		"say": "Sulanan ekin iki kat hızlı büyür. Biraz bekle, çiftliği gez."},
	{"kind": "crop", "arg": "wheat", "need": 6, "text": "🌾 İlk buğday hasadını topla (✋ El)", "coins": 80, "xp": 20,
		"say": "İlk hasat! Kasabalılar taze buğdaya bayılır."},
	{"kind": "sell", "arg": "", "need": 6, "text": "📦 Ambarda 6 ürün sat (B tuşu)", "coins": 100, "xp": 15,
		"say": "Biraz paran oldu. Bir çiftlik hayvansız olur mu?"},
	{"kind": "buy", "arg": "chicken", "need": 2, "text": "🐔 2 tavuk al (🐔 Hayvan)", "coins": 60, "xp": 15,
		"say": "Tavuklar yumurtlayacak bir yuva arıyor."},
	{"kind": "buy", "arg": "coop", "need": 1, "text": "🛖 Tavukların yanına kümes kur", "coins": 40, "xp": 20,
		"say": "Kümes hazır! Tavukların yanında olduğu sürece yumurtalar oraya bırakılır."},
	{"kind": "animal", "arg": "chicken", "need": 3, "text": "🥚 Kümesten 3 yumurta topla (✋ El)", "coins": 100, "xp": 30,
		"say": "Çiftlik canlanıyor! Artık başını sokacak bir evin olmalı."},
	{"kind": "build", "arg": "house", "need": 1, "text": "🏠 Kendine bir çiftlik evi kur (🏗️ Yapı)", "coins": 150, "xp": 40,
		"say": ""},
]
const STORY_PAGES := [
	["📮", "Bir mektup", "Bir sabah kapına eski, mühürlü bir zarf bırakılmış. Üzerinde tanıdık bir el yazısı var: Nermin Teyze."],
	["✉️", "Teyzenin sözleri", "\"Sevgili yeğenim, yaşım ilerledi, tepedeki çiftliğe artık bakamıyorum. Onu sana bırakıyorum. Her yeri ot ve taş bürüdü ama toprağı hâlâ bereketlidir. Ona iyi bak.\""],
	["🧳", "Yola çıkış", "Bavulunu topladın, kasabanın dışındaki tepeye tırmandın. Gıcırdayan kapının üstünde solmuş bir tabela: %s."],
	["🏚️", "Çiftlik", "Eski ev de ambar da çoktan yıkılmış; geriye ot, taş ve kütük bürümüş bir arazi kalmış. Cebinde biraz para ve bir çuval buğday tohumu var. Her şeyi sen kuracaksın."],
	["💪", "Hadi başlayalım!", "Önce araziyi temizle, sonra ilk tarlanı sür. Sol üstteki ⭐ Hikâye görevi sana yol gösterecek."],
]

const SHELF_COLS := 4
const SHELF_PER_PAGE := 8
const SHELF_TITLES := {"seed": "🌱 Tohumlar", "tree": "🌳 Meyve Ağaçları", "animal": "🐔 Hayvanlar", "decor": "🌷 Dekor", "garden": "🌼 Bahçe", "build": "🏗️ Yapılar"}
const MARKER_COL := {"hand": "#ffffff", "plow": "#a1673f", "seed": "#8bc34a", "water": "#4fc3f7", "tree": "#2e7d32", "animal": "#ffca28", "decor": "#ce93d8", "garden": "#f48fb1", "build": "#a1887f", "remove": "#e53935", "move": "#64b5f6"}

# ------------------------------------------------------------ durum
var coins := 120
var xp := 0
var level := 1
var day_time := 0.33
var day := 1
var tool := "hand"
var sel := {"seed": "wheat", "tree": "apple", "animal": "chicken", "decor": "path", "garden": "daisy", "build": "barn"}
var farm_name := "Çiftliğim"
var flv := {}            # çiçek türü -> {"lv", "n"}
var farm_h := FARM_H_START   # çiftlik karesinin yarı boyu
var gems := 0
var quests: Array = []   # en fazla QUEST_SLOTS görev
var quest_skip_at := 0.0 # son ücretsiz silme (unix sn)
var muted := false
var medals := 0
var res := {}            # kaynak -> adet
var order := {}          # {"need": {kaynak: adet}, "medals", "xp", "coins"}
var season := 0          # 0 ilkbahar … 3 kış
var season_t := 0.0      # mevsim içinde 0..1
var year := 1
var weather := ""        # "", rain, drought, snow
var weather_t := 0.0     # kalan saniye
var loading := false

var tiles := {}          # Vector2i -> entity (Dictionary)
var entities: Array = []
var lanterns: Array = []
var queue: Array = []
var parts: Array = []
var floats: Array = []

# sahne
var env: Environment
var sun: DirectionalLight3D
var cam: Camera3D
var farmer: Node3D
var fparts: Dictionary
var cursor: MeshInstance3D
var cursor_edge: MeshInstance3D
var grid: MeshInstance3D
var windmill: Node3D
var clouds: Array = []
var lamp_lights: Array = []
var frame_root: Node3D
var wild_root: Node3D       # çit dışındaki yabani doğa
var ground_mi: MeshInstance3D
var ground_h := -1          # zemin renkleri hangi kare boyuyla boyandı
var grass_mat: ShaderMaterial
var grass_mesh: ArrayMesh
var grass_chunks := {}     # parsel -> MultiMeshInstance3D
var grass_dirty := {}      # yeniden kurulacak parseller
var parcel_root: Node3D
var land_dlg: Control
var land_box: VBoxContainer
var ground_mat: ShaderMaterial
var rain_fx: GPUParticles3D
var snow_fx: GPUParticles3D
var wx_f := 0.0          # yağmur/kar görsel karışımı
var dr_f := 0.0          # kuraklık görsel karışımı
var font: SystemFont

# kamera ve girdi
var cam_yaw := 0.55
var cam_pitch := 0.88
var cam_dist := 20.0
var cam_target := Vector3(0.5, 0, 9)
var hover = null
var painting := false
var rotating := false
var panning := false
var cam_follow := true
var drag_moved := false
var mouse_pos := Vector2.ZERO

var walk_phase := 0.0
var move_target = null   # Vector3: tıklanan yere yürü
var walk_path: Array = []  # move_target'a giden ara noktalar
var move_marker: MeshInstance3D
var act_t := 0.0
var act_kind := ""          # oynanan iş animasyonu
var act_dur := 0.22
var act_pos := Vector3.ZERO
var act_fx := 0.0           # parçacık zamanlayıcısı
var night_f := 0.0
var day_f_last := 1.0
var fps_t := 0.0
var fps_n := 0
var clock_t := 0.0
var sim_acc := 0.0
var lamp_timer := 0.0
var save_timer := 0.0
var hud_dirty := true
var shown_coins := 120.0
var reset_armed := 0.0

# arayüz
var ui: Control
var lbl_level: Label
var lbl_xp: Label
var bar_xp: ProgressBar
var lbl_coins: Label
var lbl_medals: Label
var lbl_gems: Label
var quest_panel: PanelContainer
var quest_box: VBoxContainer
var quest_open := true
var barn: Control
var barn_box: VBoxContainer
var lbl_clock: Label
var lbl_queue: Label
var shelf_panel: PanelContainer
var shelf_box: GridContainer
var shelf_title: Label
var shelf_nav: HBoxContainer
var shelf_open := false
var shelf_page := {}
var entrance_doors := []
var frame_block := {}
var frame_fences := {}   # Vector2i → sınır çiti parçası (oyuncu çiti yanına gelince yeniden çizilir)
var frame_gate_z := 0
## Göl balıkçılığı. diff: mini oyunda ne kadar kaçak (0..1); w: kg aralığı; amt: ambara giden balık; chance: ağırlık.
const FISH := [
	{"id": "kizilkanat", "name": "Kızılkanat", "icon": "🐟", "diff": 0.12, "w": [0.1, 0.4], "amt": 1, "xp": 3, "chance": 40},
	{"id": "sazan", "name": "Sazan", "icon": "🐟", "diff": 0.32, "w": [0.8, 4.0], "amt": 2, "xp": 6, "chance": 30},
	{"id": "alabalik", "name": "Alabalık", "icon": "🐠", "diff": 0.5, "w": [0.4, 2.5], "amt": 2, "xp": 9, "chance": 18},
	{"id": "turna", "name": "Turna", "icon": "🐟", "diff": 0.68, "w": [1.5, 8.0], "amt": 3, "xp": 14, "chance": 8},
	{"id": "yayin", "name": "Yayın Balığı", "icon": "🐡", "diff": 0.8, "w": [4.0, 20.0], "amt": 4, "xp": 20, "chance": 3, "night": true},
	{"id": "altin", "name": "Altın Sazan", "icon": "✨", "diff": 0.9, "w": [1.0, 3.0], "amt": 5, "xp": 35, "chance": 1, "gems": 1},
]
## Balıkçı tezgâhı: [id, ad, fiyat, seviye, açıklama]
const FISH_SHOP := [
	["rod1", "🎣 Bambu Olta", 120, 1, "Balık tutmaya başla. Yakalama alanı dar."],
	["rod2", "🎣 Usta Oltası", 900, 5, "Yakalama alanı geniş, makara hızlı."],
	["bait", "🪱 Solucan ×10", 30, 1, "Her atış bir yem. Göldeki her balık sever."],
	["bait2", "✨ Parlak Yem ×5", 80, 3, "Nadir balıkları (alabalık, turna, yayın, altın sazan) 3 kat çeker."],
]
const STALL := Vector3(23.4, 0, 0.6)   # gölün batı kıyısı
## Fırın tarifleri: girdi kaynakları → ürün (Data.RESOURCES'da).
const RECIPES := [
	{"id": "pogaca", "name": "Poğaça", "icon": "🥐", "need": {"flour": 2, "egg": 1}, "level": 3, "xp": 6},
	{"id": "fishbread", "name": "Balık Ekmek", "icon": "🥪", "need": {"flour": 1, "fish": 2}, "level": 3, "xp": 8},
	{"id": "pie", "name": "Meyveli Turta", "icon": "🥧", "need": {"flour": 2, "milk": 1, "fruit": 2}, "level": 4, "xp": 12},
]
var bake_state := ""
var bake_g := {}
var bake_stoke := 0
var bake_ui: PanelContainer
var bake_therm: Control
var bake_bar: ProgressBar
var bake_msg: Label
## Değirmen: bir öğütme 6 tahıl alır, 5 vuruşun her isabeti 1 un verir.
const MILL_POS := Vector3(25, 0, -12)
const MILL_IN := 6
const MILL_ROUNDS := 5
const MILL_LEVEL := 2
var mill_state := ""    # "" | game
var mill_g := {}
var mill_spin := 0.0    # isabetlerde kanatlar hızlanır
var mill_ui: PanelContainer
var mill_dial: Control
var mill_msg: Label
var mill_row: Label
var fishgear := {"rod": 0, "bait": 0, "bait2": 0, "use2": false, "log": {}}
var fish_state := ""      # "" | walk | wait | bite | game
var fish_t := 0.0
var fish_at := Vector3.ZERO      # şamandıra
var fish_shore := Vector3.ZERO   # çiftçinin duracağı kıyı
var fish_bait2 := false          # bu atışta parlak yem mi
var fish_pick := {}              # oltaya gelen tür
var fish_g := {}                 # mini oyun durumu
var bobber: Node3D
var fish_line: MeshInstance3D
var fish_rod: Node3D
var fish_ui: PanelContainer
var fish_zone: ColorRect
var fish_icon: Label
var fish_bar: ProgressBar
var fish_track_w := 440.0
var shop_open := false
const EMOTES := ["👋", "😄", "❤️", "👍", "😂", "🎉", "😮", "😢"]
var emote_fx := []        # [{"n": Label3D, "t": float}]
var emote_bar: PanelContainer
var net_role := ""          # "" | "host" | "guest" | "joining"
var net_players := {}       # peer -> {"name", "node", "parts", "tp", "ry", "mv", "act_t"}
var net_applying := false   # uzaktan gelen işi uygularken
var net_actor := 1
var net_sync_t := 0.0
var move_src = null   # Taşı aleti: seçilen nesnenin köşe karesi (Vector2i) ya da null
var hold_ent = null   # bina üstünde sol tuş basılı: kısa tıklama mı, menü mü?
var hold_tile := Vector2i.ZERO
var hold_at := Vector2.ZERO
var hold_t := 0.0
var ctx_menu: PanelContainer
var ctx_box: VBoxContainer
var net_quest_dirty := false   # ev sahibi: görevler değişti, misafirlere hemen gönder
var net_quest_t := 0.0
var net_pos_t := 0.0
var player_name := "Çiftçi"
var net_dlg: PanelContainer
var net_box: VBoxContainer
var net_status: Label
var wheel: ColorRect         # çark menü katmanı
var wheel_btn: Button        # sağ alttaki 🎒 düğmesi
var wheel_info: Label      # çiftlik sınır çitinin kareleri (yürünmez)   # giriş kapısı kanatları
var sky_mat: ShaderMaterial
var story_step := 0        # STORY içindeki adım; STORY.size() = bitti
var story_have := 0
var story_ui: ColorRect
var look_up := 0.0   # yalnız ekran görüntüsü için (--lookup=N)
var tool_buttons := {}
var tip_panel: PanelContainer
var tip_label: Label
var toasts: VBoxContainer
var help: Control
var btn_sound: Button

# ses
var sounds := {}
var players: Array = []
var player_i := 0

# hata ayıklama: --shot=yol.png, --fresh, --night
var shot_path := ""
var save_path := ""      # açık kariyerin dosyası; boşsa kaydedilmez
var slot := 0
var playing := false
var ready_done := false
var menu_layer: CanvasLayer
var menu_box: VBoxContainer
var load_layer: CanvasLayer
var load_bar: ProgressBar
var del_armed := {}
var shot_t := 0.0

# ============================================================ yardımcılar
static func key(x: int, z: int) -> Vector2i:
	return Vector2i(x, z)

func in_farm(x: int, z: int) -> bool:
	return x >= -farm_h and x < farm_h and z >= -farm_h and z < farm_h

static func _parcel_of(x: int, z: int) -> Vector2i:
	return Vector2i(floori(float(x - WORLD_MIN) / PARCEL), floori(float(z - WORLD_MIN) / PARCEL))

static func _pc_of_str(st: String) -> Vector2i:
	var a := st.split(",")
	return Vector2i(int(a[0]), int(a[1]))

static func _pc_center(pc: Vector2i) -> Vector3:
	return Vector3(WORLD_MIN + pc.x * PARCEL + PARCEL / 2.0, 0, WORLD_MIN + pc.y * PARCEL + PARCEL / 2.0)

## Sürüm: project.godot application/config/version. Güncelleme duyurusu: ciftlik/update_url
## GitHub "releases/latest" API adresi ya da {"version": "0.2.0", "url": "https://…", "notes": "…"} döndüren bir adres.
const CHANNEL := "Erken Erişim"
var update_info := {}
## Ayarlar (profile.json "gfx"): kalite 0..3, tam ekran, vsync, çözünürlük %, FPS sınırı, ses %, gece parlaklığı %.
const GFX_DEFAULT := {"gv": 2, "q": 2, "fs": true, "vs": true, "scale": 100, "fps": 0, "vol": 80, "sfx": 100, "night": 50, "showfps": false}
const QUALITY_NAMES := ["Düşük", "Orta", "Yüksek", "Ultra"]
var gfx := GFX_DEFAULT.duplicate()
var grass_frac := 1.0
var set_layer: CanvasLayer
var set_box: VBoxContainer
var fps_lbl: Label

func _load_fishgear(d) -> void:
	fishgear = {"rod": 0, "bait": 0, "bait2": 0, "use2": false, "log": {}}
	if typeof(d) != TYPE_DICTIONARY:
		return
	fishgear.rod = clampi(int(d.get("rod", 0)), 0, 2)
	fishgear.bait = maxi(0, int(d.get("bait", 0)))
	fishgear.bait2 = maxi(0, int(d.get("bait2", 0)))
	fishgear.use2 = bool(d.get("use2", false))
	var lg = d.get("log", {})
	if typeof(lg) == TYPE_DICTIONARY:
		for k in lg:
			if typeof(lg[k]) == TYPE_DICTIONARY:
				fishgear.log[str(k)] = {"n": int(lg[k].get("n", 0)), "best": float(lg[k].get("best", 0.0))}

## Sıradaki genişleme adımı [yarı boy, altın, seviye]; en büyük karedeyse boş.
func _expand_next() -> Array:
	for st in EXPAND:
		if int(st[0]) > farm_h:
			return st
	return []

func _expand_farm() -> bool:
	var nx := _expand_next()
	if nx.is_empty() or net_role == "guest" or coins < int(nx[1]) or level < int(nx[2]):
		return false
	_spend(int(nx[1]))
	farm_h = int(nx[0])
	_on_farm_resized()
	for c in [Vector3(-farm_h, 0, -farm_h), Vector3(farm_h, 0, -farm_h), Vector3(-farm_h, 0, farm_h), Vector3(farm_h, 0, farm_h)]:
		_burst(c + Vector3(0, 1.0, 0), "#ffd54f", 14, 5.0)
		_burst(c + Vector3(0, 1.0, 0), "#81c784", 14, 5.0)
	if farmer != null:
		_float_text(farmer.position + Vector3(0, 1.6, 0), "-%d 🪙" % int(nx[1]), Color("#ffb4a8"))
	_toast("🗺️ Çiftlik büyüdü: artık %d×%d!" % [farm_h * 2, farm_h * 2], "level")
	_sfx("level")
	return true

## Kare boyu değişince: zemin rengi, çit, yabani doğa ve çim yeniden.
func _on_farm_resized() -> void:
	if ground_h != farm_h and ground_mi != null:
		_build_ground_mesh()
	_refresh_parcels()
	if grass_mesh != null:
		for px in 5:
			for pz in 5:
				grass_dirty[Vector2i(px, pz)] = true

## Eski sürüm (parsel/bölge) kaydı: 24×24 ev arazisi + alınmış parselleri kapsayan kare.
static func _farm_h_from_parcels(list: Array) -> int:
	var h := 12
	for pc in list:
		var a := str(pc).split(",")
		if a.size() != 2:
			continue
		var x0 := WORLD_MIN + int(a[0]) * PARCEL
		var z0 := WORLD_MIN + int(a[1]) * PARCEL
		h = maxi(h, maxi(maxi(-x0, x0 + PARCEL), maxi(-z0, z0 + PARCEL)))
	return clampi(h, FARM_H_START, WORLD_MAX + 1)

## Karenin dışında kalan bir şey varsa kareyi onu kapsayacak kadar büyüt (çift sayıya yuvarla).
func _fit_farm_h() -> void:
	for e in entities:
		var x := int(e.x)
		var z := int(e.z)
		var need := maxi(maxi(-x, x + int(e.get("w", 1))), maxi(-z, z + int(e.get("d", 1))))
		farm_h = maxi(farm_h, need)
	if farm_h % 2 == 1:
		farm_h += 1
	farm_h = clampi(farm_h, FARM_H_START, WORLD_MAX + 1)

static func tile_center(x: int, z: int) -> Vector3:
	return Vector3(x + 0.5, 0, z + 0.5)

static func fmt_time(s: float) -> String:
	if s < 60.0:
		return "%dsn" % roundi(s)
	if s < 3600.0:
		return "%ddk" % roundi(s / 60.0)
	return "%.1fsa" % (s / 3600.0)

static func bar(p: float) -> String:
	var n := clampi(roundi(p * 8.0), 0, 8)
	return "▰".repeat(n) + "▱".repeat(8 - n) + " %d%%" % int(p * 100.0)

func height_at(x: float, z: float) -> float:
	var d := maxf(absf(x), absf(z))
	var outside := smoothstep(21.5, 30.0, d)
	var h := (sin(x * 0.15) + cos(z * 0.13) + sin((x + z) * 0.07)) * 1.3 + 1.2
	h = maxf(0.0, h) * outside
	var pd := Vector2(x - POND_X, z - POND_Z).length()
	return lerpf(-0.7, h, smoothstep(POND_R - 0.6, POND_R + 2.5, pd))

# ============================================================ başlat
func _ready() -> void:
	randomize()
	get_tree().auto_accept_quit = false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot_path = a.substr(7)
	DisplayServer.window_set_title("Çiftliğim 3D")
	if not _is_dev_run():   # tam ekran yükleme ekranından önce
		var g0 = JSON.parse_string(_profile_get("gfx", "{}"))
		if not (g0 is Dictionary and int(g0.get("gv", 0)) >= 2 and not bool(g0.get("fs", true))):
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_make_font()
	_build_loading()
	await get_tree().process_frame
	await get_tree().process_frame
	_build_env()
	_build_terrain()
	_build_far_land()
	_load_step(0.35)
	await get_tree().process_frame
	_build_surroundings()
	_build_outskirts()
	_build_stall()
	_build_farm_frame()
	_build_grass()
	_build_cursor()
	farmer = Models.farmer()
	fparts = farmer.get_meta("parts")
	farmer.position = Vector3(0.5, 0, 9)
	add_child(farmer)
	_load_step(0.6)
	await get_tree().process_frame
	_build_sounds()
	_build_ui()
	_build_menu()
	_build_settings()
	_load_gfx()
	_check_update()
	_load_step(0.8)
	await get_tree().process_frame

	var args := OS.get_cmdline_user_args()
	_migrate_old_save()
	var dev := args.has("--selftest") or args.has("--fps") or args.has("--fresh") or args.has("--demo") or args.has("--barn") or shot_path != ""
	var start_play := dev
	var is_new := false
	var net_data = null
	if boot.has("net_state"):
		net_data = JSON.parse_string(str(boot.net_state))
		player_name = str(boot.get("player", "Misafir"))
		net_role = "guest"
		boot = {}
		slot = 0
		start_play = true
	elif boot.has("slot"):
		slot = int(boot.slot)
		is_new = bool(boot.get("new", false))
		if is_new:
			farm_name = str(boot.get("name", "Çiftliğim"))
		boot = {}
		start_play = true
	elif dev:
		slot = 0   # geliştirici çalıştırmaları kariyerlere dokunmaz (--slot=N verilmedikçe)
		for a in args:
			if a.begins_with("--slot="):
				slot = clampi(int(a.substr(7)), 1, SLOTS)
	else:
		slot = _last_slot()
	save_path = _slot_path(slot) if slot > 0 else ""
	if args.has("--selftest"):
		save_path = "user://selftest.json"
	var loaded := false
	if net_data != null:
		save_path = ""
		loaded = _load_dict(net_data, false)
		story_step = STORY.size()
		quests = []
		farmer.position = Vector3(0.5, 0, farm_h - 1.5)
	elif save_path != "" and not is_new and not args.has("--fresh"):
		loaded = _load()
	var story_new := false
	if not loaded:
		var nm := farm_name
		story_new = is_new or args.has("--story")
		if story_new:
			_new_story_game()
		else:
			_new_game()
		farm_name = nm
	if args.has("--night"):
		day_time = 0.88
	for a in args:
		if a.begins_with("--cam="):
			cam_dist = float(a.substr(6))
		elif a.begins_with("--season="):
			season = clampi(int(a.substr(9)), 0, 3)
		elif a.begins_with("--weather="):
			_start_weather(a.substr(10))
	_apply_season_visual(true)
	if args.has("--demo"):
		_demo()
	if args.has("--barn"):
		res = {"cereal": 24, "veg": 13, "fruit": 9, "milk": 6}
		order = {"need": {"veg": 10, "cereal": 30}, "medals": 3, "xp": 41, "coins": 240}
		_open_barn()
	if not in_farm(floori(farmer.position.x), floori(farmer.position.z)):
		farmer.position = Vector3(0.5, 0, farm_h - 1.5)
		cam_target = farmer.position
	_on_farm_resized()
	for pc in grass_dirty.keys():
		_build_grass_chunk(pc)
	grass_dirty.clear()
	_render_quests()
	_set_tool(tool)
	hud_dirty = true
	ready_done = true
	_load_step(1.0)
	_finish_loading()
	if args.has("--menu"):
		start_play = false
	if start_play:
		_start_play((is_new or (not loaded and not dev)) and not story_new)
		if story_new and (shot_path == "" or args.has("--storyshot")):
			_show_story(0)
	else:
		_show_menu()
	if net_role == "guest":
		_net_signals()
		rpc_id(1, "net_ready", player_name)
		if args.has("--nettest"):
			_net_selftest()
		_toast("🤝 %s çiftliğine katıldın! Ambar ve arazi alımı çiftlik sahibinde." % farm_name, "level")
	if boot.has("net_msg"):
		_toast(str(boot.net_msg), "warn")
		boot = {}
	for a in args:
		if a == "--nethost":
			_net_host()
			_net_host_probe()
		elif a.begins_with("--netjoin=") and net_role == "":
			_net_join(a.substr(10), "Deneme")
	if args.has("--selftest"):
		_selftest()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if ready_done:
			_save()
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED and ready_done:
		_save()

# ============================================================ dünya
func _make_font() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Nunito", "Segoe UI", "Arial"])
	font.font_weight = 700
	var emo := SystemFont.new()
	emo.font_names = PackedStringArray(["Segoe UI Emoji", "Noto Color Emoji", "Apple Color Emoji"])
	var fb: Array[Font] = [emo]
	font.fallbacks = fb

func _build_env() -> void:
	env = Environment.new()
	var ssh := Shader.new()
	ssh.code = SKY_SHADER
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = ssh
	var skyr := Sky.new()
	skyr.sky_material = sky_mat
	skyr.radiance_size = Sky.RADIANCE_SIZE_64
	skyr.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	env.background_mode = Environment.BG_SKY
	env.sky = skyr
	env.fog_sky_affect = 0.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#dff1ff")
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.8
	env.fog_enabled = true
	env.fog_light_color = Color("#9fd4ff")
	env.fog_density = 0.0025
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_hdr_threshold = 1.2
	env.ssao_enabled = true
	env.ssao_radius = 0.8
	env.ssao_intensity = 1.2
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 40.0
	sun.directional_shadow_split_1 = 0.08
	sun.directional_shadow_split_2 = 0.22
	sun.directional_shadow_split_3 = 0.5
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_fade_start = 0.85
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.6
	sun.light_angular_distance = 0.6
	sun.light_energy = 1.4
	add_child(sun)

	for i in 6:
		var l := OmniLight3D.new()
		l.light_color = Color("#ffc966")
		l.omni_range = 7.0
		l.light_energy = 0.0
		l.position = Vector3(0, -50, 0)
		add_child(l)
		lamp_lights.append(l)

	rain_fx = _weather_particles(1800, 0.8, Vector3(0.015, 0.45, 0.015), Color(0.8, 0.88, 1.0, 0.45), 20.0, 3.0, -9.8)
	snow_fx = _weather_particles(1200, 5.0, Vector3(0.045, 0.045, 0.045), Color(1, 1, 1, 0.85), 2.0, 25.0, -0.6)

	cam = Camera3D.new()
	cam.fov = 40.0
	cam.far = 480.0
	add_child(cam)
	cam.make_current()

func _weather_particles(n: int, life: float, sz: Vector3, col: Color, vel: float, spread: float, grav: float) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(18, 0.5, 18)
	pm.direction = Vector3(0, -1, 0)
	pm.spread = spread
	pm.initial_velocity_min = vel * 0.85
	pm.initial_velocity_max = vel * 1.15
	pm.gravity = Vector3(0.6, grav, 0.2)
	var mesh := BoxMesh.new()
	mesh.size = sz
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.albedo_color = col
	mesh.material = mm
	var g := GPUParticles3D.new()
	g.amount = n
	g.lifetime = life
	g.process_material = pm
	g.draw_pass_1 = mesh
	g.local_coords = false
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.visibility_aabb = AABB(Vector3(-25, -20, -25), Vector3(50, 30, 50))
	g.emitting = false
	add_child(g)
	return g

func _build_terrain() -> void:
	_build_ground_mesh()
	_build_terrain_rest()

## Zemin örgüsü; çiftlik karesi biraz daha açık yeşil, giriş yolu kapıdan başlar.
func _build_ground_mesh() -> void:
	var size := 120.0
	var seg := 120
	var n := seg + 1
	var hs := PackedFloat32Array()
	hs.resize(n * n)
	var cs := PackedColorArray()
	cs.resize(n * n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var c_sand := Color("#e3d28f")
	var c_road := Color("#c8a26b")
	var c_farm := Color("#76c24a")
	var c_grass := Color("#69b443")
	var c_hill := Color("#5fa83e")
	for j in n:
		for i in n:
			var x := -size / 2.0 + i * size / seg
			var z := -size / 2.0 + j * size / seg
			var y := height_at(x, z)
			hs[j * n + i] = y
			var c: Color
			var pd := Vector2(x - POND_X, z - POND_Z).length()
			if pd < POND_R + 1.2:
				c = c_sand
			elif absf(x) < 1.3 and z > farm_h + 0.4:
				c = c_road
			elif absf(x) <= farm_h + 0.6 and absf(z) <= farm_h + 0.6:
				c = c_farm
			elif x >= WORLD_MIN - 0.4 and x <= WORLD_MAX + 1.4 and z >= WORLD_MIN - 0.4 and z <= WORLD_MAX + 1.4:
				c = c_farm.lerp(c_grass, 0.6)
			else:
				c = c_grass.lerp(c_hill, smoothstep(0.0, 4.0, y))
			var v := rng.randf() * 0.06 - 0.03
			cs[j * n + i] = c.lightened(v) if v > 0.0 else c.darkened(-v)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in seg:
		for i in seg:
			var ids := [j * n + i, j * n + i + 1, (j + 1) * n + i, (j + 1) * n + i + 1]
			var p := []
			for id in ids:
				var ii: int = id % n
				var jj: int = id / n
				p.append(Vector3(-size / 2.0 + ii * size / seg, hs[id], -size / 2.0 + jj * size / seg))
			_tri(st, p[0], p[1], p[2], cs[ids[0]])
			_tri(st, p[1], p[3], p[2], cs[ids[3]])
	var m := st.commit()
	if ground_mat == null:
		var sh := Shader.new()
		sh.code = GROUND_SHADER
		ground_mat = ShaderMaterial.new()
		ground_mat.shader = sh
	if ground_mi == null:
		ground_mi = MeshInstance3D.new()
		ground_mi.material_override = ground_mat
		add_child(ground_mi)
	ground_mi.mesh = m
	ground_h = farm_h

func _build_terrain_rest() -> void:

	var water := MeshInstance3D.new()
	var wm := CylinderMesh.new()
	wm.top_radius = POND_R + 0.6
	wm.bottom_radius = POND_R + 0.6
	wm.height = 0.02
	wm.radial_segments = 28
	water.mesh = wm
	water.material_override = Models.water()
	water.position = Vector3(POND_X, -0.12, POND_Z)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	for i in 6:
		var a := i * 1.7
		var rr := 1.0 + (i % 3)
		var lp := Models.cyl(0.25, 0.25, 0.02, 8, "#5aa83c", POND_X + cos(a) * rr, -0.1, POND_Z + sin(a) * rr)
		add_child(lp)
		if i % 2 == 0:
			add_child(Models.ball(0.07, "#f8bbd0", lp.position.x, -0.04, lp.position.z))

## Uzak arazi: tepeler büyür, ufukta karlı dağlar yükselir.
func far_height(x: float, z: float) -> float:
	var r := Vector2(x, z).length()
	var h := height_at(x, z)
	var roll := (sin(x * 0.045 + 1.3) + cos(z * 0.05 + 0.4) + sin((x - z) * 0.03)) * 3.2 + 3.0
	h += maxf(0.0, roll) * smoothstep(62.0, 105.0, r)
	var ridge := 1.0 - absf(sin(x * 0.028 + cos(z * 0.021) * 2.0) * cos(z * 0.026 - 0.7))
	h += pow(ridge, 2.0) * 58.0 * smoothstep(125.0, 200.0, r) + smoothstep(160.0, 280.0, r) * 30.0
	return h

func _build_far_land() -> void:
	var size := 600.0
	var seg := 120
	var step := size / seg
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var fy := func(x: float, z: float) -> float:
		var d := maxf(absf(x), absf(z))
		return far_height(x, z) - 0.35 * (1.0 - smoothstep(60.0, 68.0, d))
	for j in seg:
		for i in seg:
			var x0 := -size / 2.0 + i * step
			var z0 := -size / 2.0 + j * step
			if maxf(absf(x0 + step / 2.0), absf(z0 + step / 2.0)) < 57.0:
				continue
			var a := Vector3(x0, fy.call(x0, z0), z0)
			var b := Vector3(x0 + step, fy.call(x0 + step, z0), z0)
			var c := Vector3(x0, fy.call(x0, z0 + step), z0 + step)
			var d := Vector3(x0 + step, fy.call(x0 + step, z0 + step), z0 + step)
			for tri in [[a, b, c], [b, d, c]]:
				var hy: float = (tri[0].y + tri[1].y + tri[2].y) / 3.0
				var nrm: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
				var slope := 1.0 - absf(nrm.y)
				var col := Color("#63ab40").lerp(Color("#3f7f34"), smoothstep(2.0, 14.0, hy))
				col = col.lerp(Color("#8c8a7e"), clampf(smoothstep(18.0, 30.0, hy) + slope * 1.6 - 0.4, 0.0, 1.0))
				col = col.lerp(Color("#f1f4f7"), smoothstep(44.0, 52.0, hy + slope * 6.0))
				var v := rng.randf() * 0.07 - 0.035
				col = col.lightened(v) if v > 0.0 else col.darkened(-v)
				_tri(st, tri[0], tri[1], tri[2], col)
	var land := MeshInstance3D.new()
	land.mesh = st.commit()
	land.material_override = ground_mat
	land.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(land)
	# uzak orman: iki ağaç biçimi, MultiMesh ile ucuz
	var shapes := [_far_tree_mesh(true), _far_tree_mesh(false)]
	for si in 2:
		var pts := []
		for k in 1400:
			var ang := rng.randf() * TAU
			var r := rng.randf_range(60.0, 170.0)
			var x := cos(ang) * r
			var z := sin(ang) * r
			if maxf(absf(x), absf(z)) < 58.0:
				continue
			var hy := far_height(x, z)
			if hy > (26.0 if si == 0 else 16.0):
				continue
			if rng.randf() > 0.55 + 0.45 * smoothstep(2.0, 10.0, hy):
				continue
			pts.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(1.6, 3.2)), Vector3(x, hy - 0.4, z)))
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = shapes[si]
		mm.instance_count = pts.size()
		for i in pts.size():
			mm.set_instance_transform(i, pts[i])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = ground_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	# ufuk bulutları
	for i in 14:
		var cl := Models.cloud()
		var ang := rng.randf() * TAU
		var r := rng.randf_range(150.0, 240.0)
		cl.position = Vector3(cos(ang) * r, rng.randf_range(32.0, 55.0), sin(ang) * r)
		cl.scale *= rng.randf_range(2.5, 4.5)
		add_child(cl)

func _far_tree_mesh(pine: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk := Color("#6d4c33")
	var n := 6
	var ring := func(r: float, y: float) -> Array:
		var a := []
		for i in n:
			var t := TAU * i / n
			a.append(Vector3(cos(t) * r, y, sin(t) * r))
		return a
	var tb: Array = ring.call(0.12, 0.0)
	var tt: Array = ring.call(0.1, 0.6)
	for i in n:
		var j := (i + 1) % n
		_tri(st, tb[i], tt[i], tb[j], trunk)
		_tri(st, tb[j], tt[i], tt[j], trunk)
	if pine:
		for lay in [[0.75, 0.5, 1.6, "#2f6d3a"], [0.55, 1.3, 2.3, "#3a7d41"]]:
			var base: Array = ring.call(lay[0], lay[1])
			var tip := Vector3(0, lay[2], 0)
			for i in n:
				var j := (i + 1) % n
				_tri(st, base[i], tip, base[j], Color(lay[3]))
				_tri(st, base[j], Vector3(0, lay[1], 0), base[i], Color(lay[3]).darkened(0.2))
	else:
		var col := Color("#4f9a3e")
		var mid: Array = ring.call(0.8, 1.25)
		var top := Vector3(0, 2.0, 0)
		var bot := Vector3(0, 0.55, 0)
		for i in n:
			var j := (i + 1) % n
			_tri(st, mid[i], top, mid[j], col)
			_tri(st, mid[j], bot, mid[i], col.darkened(0.25))
	return st.commit()

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	var nrm := (b - a).cross(c - a).normalized()
	if nrm.y < 0.0:
		nrm = -nrm
	st.set_color(col)
	st.set_normal(nrm)
	st.add_vertex(a)
	st.set_normal(nrm)
	st.add_vertex(b)
	st.set_normal(nrm)
	st.add_vertex(c)

func _build_surroundings() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 42
	for i in 260:
		var x := (r.randf() - 0.5) * 110.0
		var z := (r.randf() - 0.5) * 110.0
		if maxf(absf(x), absf(z)) < 22.5:
			continue
		if Vector2(x - POND_X, z - POND_Z).length() < POND_R + 2.0:
			continue
		if absf(x) < 3.0 and z > 12.0:
			continue
		if Vector2(x - 17.0, z + 8.0).length() < 3.0:
			continue
		var k := r.randf()
		var t: Node3D
		if k < 0.45:
			t = Visuals.scenery(0, 0.9 + r.randf() * 0.9, r.randf())
		elif k < 0.8:
			t = Visuals.scenery(1, 0.9 + r.randf() * 0.7, r.randf())
		else:
			t = Visuals.scenery(2, 0.8 + r.randf() * 0.6, r.randf())
		t.position = Vector3(x, height_at(x, z) - 0.05, z)
		t.rotation.y = r.randf() * TAU
		if maxf(absf(x), absf(z)) > 34.0:
			_no_shadow(t)
		add_child(t)
	for i in 160:
		var x := (r.randf() - 0.5) * 70.0
		var z := (r.randf() - 0.5) * 70.0
		if maxf(absf(x), absf(z)) < 21.0 or Vector2(x - POND_X, z - POND_Z).length() < POND_R + 1.0:
			continue
		var t := Models.tuft()
		t.position = Vector3(x, height_at(x, z), z)
		t.rotation.y = r.randf() * 6.0
		add_child(t)
	for i in 12:
		var c := Models.cloud()
		c.position = Vector3((r.randf() - 0.5) * 140.0, 42.0 + r.randf() * 8.0, (r.randf() - 0.5) * 140.0)
		c.scale *= 0.8 + r.randf()
		add_child(c)
		clouds.append(c)
	windmill = Models.building("windmill")
	windmill.position = Vector3(25, height_at(25, -12) - 0.1, -12)
	windmill.rotation.y = -0.9
	add_child(windmill)

## Doğa modeli yerleştirir; küçük süsler gölge düşürmez.
func _prop(parent: Node3D, file: String, sc: float, x: float, z: float, yaw: float, shadow := true) -> Node3D:
	var n := _nat_inst(file, sc, yaw)
	if n == null:
		return null
	n.position = Vector3(x, height_at(x, z) - 0.02, z)
	if not shadow:
		_no_shadow(n, 70.0)
	elif maxf(absf(x), absf(z)) > 34.0:
		_no_shadow(n)
	parent.add_child(n)
	return n

## Kenney (.glb) ya da MegaKit (.gltf) modelini ölçek düzeltmesiyle örnekler.
func _nat_inst(file: String, sc: float, yaw := 0.0) -> Node3D:
	var path := NAT + file
	var boost: Dictionary = PROP_BOOST
	if file.ends_with(".gltf"):
		path = MK + file
		boost = MK_BASE
	for pre in boost:
		if file.begins_with(pre):
			sc *= boost[pre]
			break
	return Assets.inst(path, sc, yaw)

## Gölgeyi kapatır; vis > 0 ise o mesafeden ötede çizmez (küçük süsler).
func _no_shadow(n: Node, vis := 0.0) -> void:
	if n is GeometryInstance3D:
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if vis > 0.0:
			n.visibility_range_end = vis
			n.visibility_range_end_margin = 6.0
			n.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	for c in n.get_children():
		_no_shadow(c, vis)

func _pick_of(r: RandomNumberGenerator, list: Array) -> String:
	return list[r.randi() % list.size()]

## Çitin dışından dünya kenarına kadar yabani doğa. Her 2×2 hücre kendi tohumuyla dizilir,
## kare büyüyünce yalnızca içeride kalanlar kaybolur; sis ya da tabela yok.
func _build_wild_ring() -> void:
	for cx in range(WORLD_MIN - 2, WORLD_MAX + 3, 2):
		for cz in range(WORLD_MIN - 2, WORLD_MAX + 3, 2):
			var r := RandomNumberGenerator.new()
			r.seed = (cx + 100) * 7331 + (cz + 100) * 1979 + 11
			var x := cx + r.randf_range(0.2, 1.8)
			var z := cz + r.randf_range(0.2, 1.8)
			var out := maxf(maxf(-farm_h - x, x - farm_h), maxf(-farm_h - z, z - farm_h))   # kareye uzaklık (m)
			if out < 1.5 or (absf(x) < 2.6 and z > 0.0):   # çitin dibi ve giriş yolu boş
				continue
			var roll := r.randf()
			if roll < 0.15 and out > 2.6:
				_prop(wild_root, _pick_of(r, WILD_TREES), r.randf_range(1.4, 2.0), x, z, r.randf() * TAU)
			elif roll < 0.38:
				_prop(wild_root, _pick_of(r, WILD_BUSH), r.randf_range(1.1, 1.7), x, z, r.randf() * TAU)
			elif roll < 0.47:
				_prop(wild_root, _pick_of(r, WILD_ROCK), r.randf_range(0.9, 1.5), x, z, r.randf() * TAU)
			elif roll < 0.51:
				_prop(wild_root, _pick_of(r, WILD_WOOD), r.randf_range(1.0, 1.4), x, z, r.randf() * TAU)
			elif roll < 0.63:
				var fl := _pick_of(r, WILD_FLOWER)
				for k in r.randi_range(3, 6):
					_prop(wild_root, fl, r.randf_range(0.9, 1.3), x + r.randf_range(-0.6, 0.6), z + r.randf_range(-0.6, 0.6), r.randf() * TAU, false)
			elif roll < 0.68:
				_prop(wild_root, _pick_of(r, WILD_MUSH), r.randf_range(0.9, 1.3), x, z, r.randf() * TAU, false)
			for k in r.randi_range(0, 2):
				var gx := cx + r.randf_range(0.1, 1.9)
				var gz := cz + r.randf_range(0.1, 1.9)
				if maxf(maxf(-farm_h - gx, gx - farm_h), maxf(-farm_h - gz, gz - farm_h)) > 1.2:
					_prop(wild_root, _pick_of(r, WILD_GRASS), r.randf_range(1.0, 1.6), gx, gz, r.randf() * TAU, false)

## Çiftlik dışı: çiçek tarlaları, çalılar, kütükler, kamp alanı, kano.
func _build_outskirts() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 77
	var root := Node3D.new()
	add_child(root)
	var camp := Vector2(-31, 14)
	var free := func(x: float, z: float) -> bool:
		if maxf(absf(x), absf(z)) < 22.0:
			return false
		if Vector2(x - POND_X, z - POND_Z).length() < POND_R + 1.5:
			return false
		if absf(x) < 3.0 and z > 12.0:
			return false
		if Vector2(x - 25.0, z + 12.0).length() < 3.5:
			return false
		return Vector2(x, z).distance_to(camp) > 5.0
	# çiçek tarlaları
	for i in 22:
		var cx := r.randf_range(-48, 48)
		var cz := r.randf_range(-48, 48)
		if not free.call(cx, cz):
			continue
		var fl := _pick_of(r, WILD_FLOWER)
		for k in r.randi_range(8, 14):
			var x := cx + r.randf_range(-1.8, 1.8)
			var z := cz + r.randf_range(-1.8, 1.8)
			if free.call(x, z):
				_prop(root, fl, r.randf_range(1.0, 1.5), x, z, r.randf() * TAU, false)
	# çalı, kaya, kütük, mantar, uzun ot
	var sets := [[WILD_BUSH, 70, 1.2, 2.0, true], [WILD_ROCK, 40, 1.0, 1.8, true], [WILD_WOOD, 18, 1.1, 1.5, true],
		[WILD_MUSH, 30, 1.0, 1.4, false], [WILD_GRASS, 260, 1.1, 1.8, false], [BIG_TREES, 90, 1.6, 2.6, true]]
	for st in sets:
		for i in st[1]:
			var x := r.randf_range(-55, 55)
			var z := r.randf_range(-55, 55)
			if free.call(x, z):
				_prop(root, _pick_of(r, st[0]), r.randf_range(st[2], st[3]), x, z, r.randf() * TAU, st[4])
	# kamp alanı
	_prop(root, "tent_detailedOpen.glb", 2.2, camp.x, camp.y - 1.0, 0.4)
	_prop(root, "campfire_stones.glb", 1.6, camp.x + 1.6, camp.y + 1.2, 0.0)
	_prop(root, "log.glb", 1.4, camp.x + 0.2, camp.y + 2.4, 0.3)
	_prop(root, "log.glb", 1.4, camp.x + 3.0, camp.y + 1.0, 1.6)
	_prop(root, "log_stackLarge.glb", 1.6, camp.x - 2.4, camp.y + 1.0, 1.2)
	_prop(root, "pot_large.glb", 1.4, camp.x + 1.0, camp.y - 2.6, 0.0)
	_prop(root, "sign.glb", 1.6, 3.6, 22.5, PI)
	_prop(root, "log_stack.glb", 1.6, -3.8, 24.0, 0.2)
	# gölet: kano, nilüfer, kıyı taşları
	_prop(root, "canoe.glb", 1.8, POND_X - POND_R + 0.4, POND_Z + 1.0, 1.2, false)
	for i in 10:
		var a := r.randf() * TAU
		_prop(root, "rock_smallFlatA.glb", r.randf_range(1.0, 1.6), POND_X + cos(a) * (POND_R + 0.6), POND_Z + sin(a) * (POND_R + 0.6), r.randf() * TAU, false)
	for i in 5:
		var a := r.randf() * TAU
		var n := _prop(root, "lily_small.glb", 1.5, POND_X + cos(a) * POND_R * 0.6, POND_Z + sin(a) * POND_R * 0.6, r.randf() * TAU, false)
		if n != null:
			n.position.y = -0.1

func _frame_tile(x: int, z: int) -> bool:
	if in_farm(x, z):
		return false
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			if in_farm(x + dx, z + dz):
				return true
	return false

func _frame_ring(x: int, z: int, gate_z: int) -> bool:
	return _frame_tile(x, z) and not ((x == -1 or x == 0) and z == gate_z)

## Çiftlik karesinin çevresine çit, giriş kapısı ve tabela; dışarıya yabani doğa.
func _refresh_parcels() -> void:
	for c in frame_root.get_children():
		c.queue_free()
	for c in parcel_root.get_children():
		c.queue_free()
	if wild_root == null:
		wild_root = Node3D.new()
		add_child(wild_root)
	for c in wild_root.get_children():
		c.queue_free()
	var gate_z := farm_h
	while in_farm(0, gate_z):
		gate_z += 1
	frame_block.clear()
	frame_fences.clear()
	frame_gate_z = gate_z
	for x in range(WORLD_MIN - 1, WORLD_MAX + 2):
		for z in range(WORLD_MIN - 1, WORLD_MAX + 2):
			if not _frame_ring(x, z, gate_z):
				continue
			frame_block[Vector2i(x, z)] = true
			_frame_fence_at(Vector2i(x, z))
	for x in [-1.15, 1.15]:
		frame_root.add_child(Models.box(0.22, 2.0, 0.22, "#8d5f3a", x, 1.0, gate_z + 0.5))
	frame_root.add_child(Models.box(2.9, 0.5, 0.1, "#c79a6a", 0, 1.85, gate_z + 0.5))
	entrance_doors.clear()
	for sx in [-1.0, 1.0]:
		var hinge := Models.node(sx * 1.03, 0, gate_z + 0.5)
		var leaf := Models.node(-sx * 0.5, 0, 0)
		for y in [0.25, 0.55, 0.85]:
			leaf.add_child(Models.box(0.98, 0.09, 0.05, "#d9ae7a", 0, y, 0))
		for x in [-0.42, 0.42]:
			leaf.add_child(Models.box(0.08, 1.0, 0.06, "#8d5f3a", x, 0.52, 0))
		var br := Models.box(1.05, 0.07, 0.05, "#c79a6a", 0, 0.55, 0.01)
		br.rotation.z = 0.55 * sx
		leaf.add_child(br)
		hinge.add_child(leaf)
		hinge.set_meta("sx", sx)
		frame_root.add_child(hinge)
		entrance_doors.append(hinge)
	var sign := Label3D.new()
	sign.text = farm_name.to_upper()
	sign.font = font
	sign.font_size = 72
	sign.pixel_size = 0.005
	sign.modulate = Color("#4e2f17")
	sign.outline_size = 0
	sign.position = Vector3(0, 1.85, gate_z + 0.56)
	frame_root.add_child(sign)
	_build_wild_ring()

func _build_grass() -> void:
	var sh := Shader.new()
	sh.code = GRASS_SHADER
	grass_mat = ShaderMaterial.new()
	grass_mat.shader = sh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for b in 7:
		var a := rng.randf() * TAU
		var r := rng.randf() * 0.1
		var base := Vector3(cos(a) * r, 0, sin(a) * r)
		var yaw := rng.randf() * TAU
		var side := Vector3(cos(yaw), 0, sin(yaw)) * 0.022
		var lean := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.02, 0.08)
		var hgt := rng.randf_range(0.16, 0.3)
		var top := base + lean + Vector3(0, hgt, 0)
		var mid_l := base - side * 0.8 + lean * 0.5 + Vector3(0, hgt * 0.5, 0)
		var mid_r := base + side * 0.8 + lean * 0.5 + Vector3(0, hgt * 0.5, 0)
		var n := side.cross(Vector3.UP).normalized()
		for tri in [[base - side, base + side, mid_r], [base - side, mid_r, mid_l], [mid_l, mid_r, top]]:
			for v in tri:
				st.set_normal(n.lerp(Vector3.UP, 0.6).normalized())
				st.set_uv(Vector2(0, v.y / hgt))
				st.add_vertex(v)
	grass_mesh = st.commit()
	for px in 5:
		for pz in 5:
			grass_dirty[Vector2i(px, pz)] = true

func _grass_mark(x: int, z: int) -> void:
	if grass_mesh != null and x >= WORLD_MIN and x <= WORLD_MAX and z >= WORLD_MIN and z <= WORLD_MAX:
		grass_dirty[_parcel_of(x, z)] = true

## Parseldeki boş karelere çim öbekleri dizer (dolu karelerde çim yok).
func _build_grass_chunk(pc: Vector2i) -> void:
	if grass_chunks.has(pc):
		grass_chunks[pc].queue_free()
	var pts := []
	var rng := RandomNumberGenerator.new()
	rng.seed = pc.x * 977 + pc.y * 131 + 7
	for i in PARCEL:
		for j in PARCEL:
			var x := WORLD_MIN + pc.x * PARCEL + i
			var z := WORLD_MIN + pc.y * PARCEL + j
			var wild := not in_farm(x, z)
			var t = tiles.get(key(x, z))
			var skip: bool = t != null and not (t.kind == "decor" and (t.type == "fence" or t.type == "gate" or t.type == "lantern"))
			for k in 3:
				var ox := rng.randf_range(0.12, 0.88)
				var oz := rng.randf_range(0.12, 0.88)
				var sc := rng.randf_range(0.75, 1.25) * (1.35 if wild else 1.0)
				var yaw := rng.randf() * TAU
				var shade := rng.randf_range(0.85, 1.1)
				if not skip:
					pts.append([Vector3(x + ox, 0.0, z + oz), sc, yaw, shade])
	pts.shuffle()   # yoğunluk düşürülünce çim eşit seyrelsin
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = grass_mesh
	mm.instance_count = pts.size()
	for i in pts.size():
		var q = pts[i]
		var b := Basis(Vector3.UP, q[2]).scaled(Vector3(q[1], q[1], q[1]))
		mm.set_instance_transform(i, Transform3D(b, q[0]))
		mm.set_instance_color(i, Color(q[3], q[3], q[3] * 0.95))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = grass_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if grass_frac < 1.0:
		mm.visible_instance_count = int(mm.instance_count * grass_frac)
	add_child(mi)
	grass_chunks[pc] = mi

func _update_grass() -> void:
	var n := 0
	for pc in grass_dirty.keys():
		_build_grass_chunk(pc)
		grass_dirty.erase(pc)
		n += 1
		if n >= 3 and ready_done:
			break

func _build_farm_frame() -> void:
	frame_root = Node3D.new()
	add_child(frame_root)
	parcel_root = Node3D.new()
	add_child(parcel_root)

	# tarla ızgarası
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(WORLD_MIN, WORLD_MAX + 2):
		im.surface_add_vertex(Vector3(i, 0, WORLD_MIN))
		im.surface_add_vertex(Vector3(i, 0, WORLD_MAX + 1))
		im.surface_add_vertex(Vector3(WORLD_MIN, 0, i))
		im.surface_add_vertex(Vector3(WORLD_MAX + 1, 0, i))
	im.surface_end()
	grid = MeshInstance3D.new()
	grid.mesh = im
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.albedo_color = Color(1, 1, 1, 0.16)
	grid.material_override = gm
	grid.position.y = 0.015
	grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grid.visible = false
	add_child(grid)

func _build_cursor() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(1, 1)
	cursor = MeshInstance3D.new()
	cursor.mesh = pm
	var cm := StandardMaterial3D.new()
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cm.albedo_color = Color(1, 1, 1, 0.35)
	cursor.material_override = cm
	cursor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cursor)
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var pts := [Vector3(-0.5, 0, -0.5), Vector3(0.5, 0, -0.5), Vector3(0.5, 0, 0.5), Vector3(-0.5, 0, 0.5)]
	for i in 4:
		im.surface_add_vertex(pts[i])
		im.surface_add_vertex(pts[(i + 1) % 4])
	im.surface_end()
	move_marker = Models.torus(0.28, 0.035, Models.emissive("#ffffff", "#ffe082", 1.2))
	move_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	move_marker.visible = false
	add_child(move_marker)
	cursor_edge = MeshInstance3D.new()
	cursor_edge.mesh = im
	var em := StandardMaterial3D.new()
	em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	em.albedo_color = Color.WHITE
	cursor_edge.material_override = em
	add_child(cursor_edge)

# ============================================================ varlıklar
func _add_entity(d: Dictionary) -> Dictionary:
	var e := d.duplicate()
	var g := Node3D.new()
	e.group = g
	if e.kind == "pond" or e.kind == "coop":
		e.w = 2
		e.d = 2
	if e.kind == "coop":
		for f in ["eggs", "value", "xp", "yield"]:
			if not e.has(f):
				e[f] = 0
	if e.has("w"):
		g.position = Vector3(e.x + e.w / 2.0, 0, e.z + e.d / 2.0)
		for i in int(e.w):
			for j in int(e.d):
				tiles[key(e.x + i, e.z + j)] = e
	else:
		g.position = tile_center(e.x, e.z)
		tiles[key(e.x, e.z)] = e
	if not e.has("rot"):
		var flat: bool = e.kind == "plot" or e.kind == "pond" or e.kind == "coop" or e.get("type", "") == "gate" or e.get("type", "") == "fence" or e.get("type", "") == "path"
		e.rot = 0.0 if flat else float(randi() % 8) * PI / 4.0
	g.rotation.y = e.rot
	add_child(g)
	entities.append(e)
	_grass_mark(e.x, e.z)
	if e.has("w"):
		_grass_mark(e.x + e.w - 1, e.z + e.d - 1)
	if e.kind == "animal":
		e.wander = {"x": 0.0, "z": 0.0, "tx": 0.0, "tz": 0.0, "wait": randf() * 3.0, "phase": randf() * 6.0}
		if not e.has("t"):
			e.t = 0.0
		if not e.has("ready"):
			e.ready = false
		if not e.has("food"):
			e.food = 1.0
		if not e.has("lv"):
			e.lv = 1
		if not e.has("hv"):
			e.hv = 0
	if e.kind == "flower" or e.kind == "pond":
		if not e.has("t"):
			e.t = 0.0
		if not e.has("ready"):
			e.ready = false
	if e.kind == "flower":
		if not e.has("water"):
			e.water = 0.0
		if not e.has("wet_t"):
			e.wet_t = 0.0
	if e.kind == "plot":
		if e.has("watered"):
			e.water = 1.0 if e.watered else 0.0
			e.erase("watered")
		if not e.has("water"):
			e.water = 0.0
	if e.get("type", "") == "lantern":
		lanterns.append(e)
	_refresh(e)
	if e.get("type", "") == "fence" or e.get("type", "") == "gate":
		_refresh_fence_neighbors(e.x, e.z)
	if e.get("type", "") == "scarecrow":
		_recompute_boosts()
	if e.kind == "plot":
		e.boost = _scarecrow_near(e.x, e.z)
	return e

func _remove_entity(e: Dictionary) -> void:
	e.group.queue_free()
	_grass_mark(e.x, e.z)
	if e.has("w"):
		_grass_mark(e.x + e.w - 1, e.z + e.d - 1)
	entities.erase(e)
	if e.has("w"):
		for i in int(e.w):
			for j in int(e.d):
				tiles.erase(key(e.x + i, e.z + j))
	else:
		tiles.erase(key(e.x, e.z))
	lanterns.erase(e)
	if e.get("type", "") == "fence" or e.get("type", "") == "gate":
		_refresh_fence_neighbors(e.x, e.z)
	if e.get("type", "") == "scarecrow":
		_recompute_boosts()

func _is_fence(x: int, z: int) -> bool:
	return _player_fence(x, z) or frame_block.has(Vector2i(x, z))

func _refresh_fence_neighbors(x: int, z: int) -> void:
	for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var t = tiles.get(key(x + dd.x, z + dd.y))
		if t != null and (t.get("type", "") == "fence" or t.get("type", "") == "gate"):
			_refresh(t)
		if frame_fences.has(Vector2i(x + dd.x, z + dd.y)):
			_frame_fence_at(Vector2i(x + dd.x, z + dd.y))

func _scarecrow_near(x: int, z: int) -> bool:
	for dx in range(-3, 4):
		for dz in range(-3, 4):
			var t = tiles.get(key(x + dx, z + dz))
			if t != null and t.get("type", "") == "scarecrow":
				return true
	return false

func _recompute_boosts() -> void:
	for e in entities:
		if e.kind == "plot":
			e.boost = _scarecrow_near(e.x, e.z)
		if e.kind == "plot" or e.kind == "flower":
			e.wn = _well_near(e.x, e.z)

static func crop_stage(e: Dictionary) -> int:
	return 3 if e.progress >= 1.0 else mini(2, int(e.progress * 3.0))

func _refresh(e: Dictionary) -> void:
	var g: Node3D = e.group
	for c in g.get_children():
		g.remove_child(c)
		c.free()
	match e.kind:
		"plot":
			e.wet_shown = _wet(e)
			g.add_child(Models.soil(e.wet_shown, e.x * 7919 + e.z * 104729))
			if e.crop != null:
				e.stage = crop_stage(e)
				g.add_child(Visuals.crop(e.crop, e.stage))
			e.mark = _make_mark(g, 1.65 if e.crop == "corn" or e.crop == "sunflower" else 0.95)
			_update_mark(e)
		"tree":
			g.add_child(Visuals.tree(e.type, e.age >= 1.0, e.has_fruit))
		"debris":
			var dd: Array = DEBRIS.get(e.type, DEBRIS.weed)
			var files: Array = dd[0]
			var h := absi(e.x * 31 + e.z * 17)
			var m := _nat_inst(files[h % files.size()], dd[1] * (0.9 + (h % 5) * 0.06))
			if m != null:
				g.add_child(m)
				if e.type == "weed":
					var m2 := Assets.inst(NAT + "grass_leafs.glb", 1.6, 1.3, Vector3(0.25, 0, -0.2))
					if m2 != null:
						g.add_child(m2)
			else:
				g.add_child(Models.decor("rock" if dd[4] else "bush", {}))
		"animal":
			e.model = Visuals.animal(e.type)
			g.add_child(e.model)
			e.icon = Models.product(e.type)
			e.icon.position.y = 1.35
			e.icon.visible = e.ready
			g.add_child(e.icon)
			var hl := Label3D.new()
			hl.text = "🌾❔"
			hl.font = font
			hl.font_size = 64
			hl.pixel_size = 0.01
			hl.no_depth_test = true
			hl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			hl.outline_size = 12
			hl.outline_modulate = Color(0.15, 0.1, 0.05, 0.6)
			hl.position.y = 1.0
			g.add_child(hl)
			e.hungry_lbl = hl
			_update_hungry(e)
		"flower":
			var f = Data.FLOWERS[e.type]
			e.wet_shown = _wet(e)
			e.stage = 3 if e.ready else mini(2, int(e.t * 3.0))
			g.add_child(Models.flower_bed(f.color, f.center, e.stage, e.wet_shown))
			e.mark = _make_mark(g, 0.75)
			_update_mark(e)
		"coop":
			g.add_child(Models.coop())
			var el := Label3D.new()
			el.font = font
			el.font_size = 56
			el.pixel_size = 0.01
			el.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			el.no_depth_test = true
			el.outline_size = 12
			el.outline_modulate = Color(0.2, 0.12, 0.05, 0.7)
			el.position.y = 2.1
			g.add_child(el)
			e.icon = el
			_update_coop(e)
		"pond":
			g.add_child(Models.fish_pond())
			var fl := Label3D.new()
			fl.text = "🐟"
			fl.font = font
			fl.font_size = 64
			fl.pixel_size = 0.012
			fl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			fl.no_depth_test = true
			fl.outline_size = 12
			fl.outline_modulate = Color(0.1, 0.2, 0.3, 0.6)
			fl.position.y = 0.9
			fl.visible = e.ready
			g.add_child(fl)
			e.icon = fl
		"decor":
			g.add_child(Visuals.decor(e.type, {"n": _is_fence(e.x, e.z - 1), "s": _is_fence(e.x, e.z + 1), "e": _is_fence(e.x + 1, e.z), "w": _is_fence(e.x - 1, e.z)}))
		"building":
			g.add_child(Models.building(e.type))

# ============================================================ simülasyon
func _wet(e: Dictionary) -> bool:
	return e.water > 0.0

func _grow_rate(e: Dictionary) -> float:
	var r := 0.5
	if weather == "snow":
		r = 0.6
	elif _wet(e):
		r = 1.0
	return r * (1.25 if e.boost else 1.0)

func _in_season(c) -> bool:
	return c == null or not c.has("seasons") or c.seasons.has(season)

func _simulate(dt: float) -> void:
	season_t += dt / Data.SEASON_LEN
	while season_t >= 1.0:
		season_t -= 1.0
		season = (season + 1) % 4
		if season == 0:
			year += 1
		_on_season_start()
	if weather != "":
		weather_t -= dt
		if weather_t <= 0.0:
			_end_weather()
	var drain := 0.0 if weather == "snow" else dt / Data.WATER_DUR * (3.0 if weather == "drought" else 1.0)
	for e in entities:
		match e.kind:
			"plot":
				if weather == "rain":
					e.water = minf(1.0, e.water + dt / 8.0)
				elif e.water > 0.0:
					e.water = maxf(0.0, e.water - drain * (0.5 if e.get("wn", false) else 1.0))
				var refreshed := false
				if e.crop != null and e.progress < 1.0:
					var c = Data.CROPS[e.crop]
					e.progress = minf(1.0, e.progress + dt * _grow_rate(e) / c.time)
					if crop_stage(e) != e.stage:
						_refresh(e)
						refreshed = true
				if not refreshed and _wet(e) != e.wet_shown:
					_refresh(e)
			"tree":
				var t = Data.TREES[e.type]
				var tdt := dt
				if e.age < 1.0:
					e.age = minf(1.0, e.age + tdt / t.grow)
					if e.age >= 1.0:
						_refresh(e)
				elif not e.has_fruit:
					e.fruit_t += tdt / t.regrow
					if e.fruit_t >= 1.0:
						e.has_fruit = true
						e.fruit_t = 0.0
						_refresh(e)
			"flower":
				if weather == "rain":
					e.water = minf(1.0, e.water + dt / 8.0)
				elif e.water > 0.0:
					e.water = maxf(0.0, e.water - drain * (0.5 if e.get("wn", false) else 1.0))
				if not e.ready:
					var ft: float = Data.FLOWERS[e.type].time
					var step := minf(dt, (1.0 - e.t) * ft)
					if _wet(e) or weather == "snow":
						e.wet_t += step
					e.t += step / ft
					if e.t >= 0.9999:
						e.t = 1.0
						e.ready = true
				var st := 3 if e.ready else mini(2, int(e.t * 3.0))
				if st != e.stage or _wet(e) != e.wet_shown:
					_refresh(e)
			"pond":
				if not e.ready:
					e.t += dt / Data.POND.time
					if e.t >= 1.0:
						e.t = 0.0
						e.ready = true
						e.icon.visible = true
			"animal":
				if not e.ready and e.food > 0.0:
					var at: float = Data.ANIMALS[e.type].time
					var step := minf(dt, e.food * at * Data.FEED_CYCLES)
					e.food = maxf(0.0, e.food - step / (at * Data.FEED_CYCLES))
					e.t += step / at
					if e.t >= 1.0:
						e.t = 0.0
						if not _lay_egg(e):
							e.ready = true
							e.icon.visible = true
					if e.food <= 0.0 or e.ready:
						_update_hungry(e)

# ============================================================ ekonomi
func _spend(n: int) -> void:
	coins -= n
	hud_dirty = true

func _gain(c: int, x: int, pos: Vector3, icon: String) -> void:
	if c > 0:
		_quest_event("earn", "", c)
	coins += c
	xp += x
	hud_dirty = true
	if c > 0:
		_float_text(pos, "+%d 🪙" % c, Color("#ffe066"))
	if x > 0:
		_float_text(pos + Vector3(0, -0.3, 0), "+%d XP" % x, Color("#b9ff7a"))
	_float_text(pos + Vector3(0, 0.4, 0), icon, Color.WHITE)
	while xp >= Data.xp_for_level(level):
		xp -= Data.xp_for_level(level)
		level += 1
		_on_level_up()

func _on_level_up() -> void:
	var names := []
	for list in [Data.CROPS, Data.TREES, Data.ANIMALS, Data.DECOR]:
		for k in list:
			if list[k].level == level:
				names.append("%s %s" % [list[k].icon, list[k].name])
	var msg := "⭐ Seviye %d!" % level
	if names.size() > 0:
		msg += "\nYeni: " + ", ".join(names)
	_toast(msg, "level")
	_sfx("level")
	var cols := ["#ffd54f", "#ff5c8a", "#4fc3f7", "#81c784"]
	for i in 4:
		_burst(farmer.position + Vector3(0, 1.2, 0), cols[i], 14, 5.0)
	_render_shelf()

# ============================================================ eylemler
func _unlocked(item) -> bool:
	return item != null and item.level <= level

func _resolve(t: String, arg, x: int, z: int):
	if not in_farm(x, z):
		return null
	var e = tiles.get(key(x, z))
	match t:
		"hand":
			if e == null:
				return null
			if e.kind == "plot":
				if e.crop == null:
					var c = Data.CROPS.get(arg)
					return "plant" if _unlocked(c) and _in_season(c) and coins >= c.cost else null
				if e.progress >= 1.0:
					return "harvest"
				if e.water < Data.WATER_REFILL and weather != "snow":
					return "water"
				return null
			if e.kind == "tree" and e.has_fruit:
				return "harvest"
			if e.kind == "pond" and e.ready:
				return "harvest"
			if e.kind == "coop" and e.eggs > 0:
				return "harvest"
			if e.kind == "flower":
				if e.ready:
					return "harvest"
				if e.water < Data.WATER_REFILL and weather != "snow":
					return "water"
				return null
			if e.kind == "animal":
				if e.ready:
					return "harvest"
				if e.food < Data.FEED_REFILL and _can_feed(e):
					return "feed"
			return null
		"plow":
			return "plow" if e == null else null
		"seed":
			var c = Data.CROPS.get(arg)
			return "plant" if e != null and e.kind == "plot" and e.crop == null and _unlocked(c) and _in_season(c) and coins >= c.cost else null
		"water":
			if e != null and e.kind == "flower":
				return "water" if e.water < Data.WATER_REFILL and weather != "snow" and not e.ready else null
			return "water" if e != null and e.kind == "plot" and e.water < Data.WATER_REFILL and weather != "snow" and (e.crop == null or e.progress < 1.0) else null
		"tree":
			var c = Data.TREES.get(arg)
			return "tree" if e == null and _unlocked(c) and coins >= c.cost else null
		"animal":
			if arg == "coop":
				return "coop" if _unlocked(Data.COOP) and coins >= Data.COOP.cost and _free_area(x, z, 2, 2) else null
			var c = Data.ANIMALS.get(arg)
			return "animal" if e == null and _unlocked(c) and coins >= c.cost else null
		"decor":
			var c = Data.DECOR.get(arg)
			return "decor" if e == null and _unlocked(c) and coins >= c.cost else null
		"garden":
			if arg == "pond":
				return "pond" if _unlocked(Data.POND) and coins >= Data.POND.cost and _free_area(x, z, 2, 2) else null
			var c = Data.FLOWERS.get(arg)
			return "flower" if e == null and _unlocked(c) and coins >= c.cost else null
		"build":
			var b = Data.BUILDINGS.get(arg)
			return "build" if b != null and _unlocked(b) and coins >= b.cost and _free_area(x, z, b.w, b.d) else null
		"remove":
			if e != null and e.kind == "building" and e.type == "barn" and _count_buildings("barn") <= 1 and _res_total() > 0:
				return null   # son ambar doluyken yıkılmaz
			return "remove" if e != null else null
		"move":
			var src = _move_entity_of(arg)
			if src == null:
				return null
			var w := int(src.get("w", 1))
			var d := int(src.get("d", 1))
			if x == src.x and z == src.z:
				return "turn"   # kendi yerine: 90° döndür
			for i in w:
				for j in d:
					var o = tiles.get(key(x + i, z + j))
					if not in_farm(x + i, z + j) or (o != null and o != src):
						return null
			return "move"
	return null

## Taşı aletinin argümanı "x,z" (seçilen nesnenin köşesi) → o nesne.
func _move_entity_of(arg):
	if arg == null or str(arg) == "":
		return null
	var a := str(arg).split(",")
	if a.size() != 2:
		return null
	var e = tiles.get(key(int(a[0]), int(a[1])))
	if e == null or e.kind == "debris":
		return null
	return e

## Karakterin başında bir süre duran emoji balonu.
func _show_emote(who: Node3D, i: int) -> void:
	if who == null or not is_instance_valid(who) or i < 0 or i >= EMOTES.size():
		return
	for f in emote_fx.duplicate():   # aynı karakterin eski balonu gitsin
		if is_instance_valid(f.n) and f.n.get_parent() == who:
			f.n.queue_free()
			emote_fx.erase(f)
	var l := Label3D.new()
	l.text = EMOTES[i]
	l.font = font
	l.font_size = 96
	l.pixel_size = 0.006
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.outline_size = 0
	l.position = Vector3(0, 2.3, 0)
	who.add_child(l)
	emote_fx.append({"n": l, "t": 0.0})

func _update_emotes(dt: float) -> void:
	for f in emote_fx.duplicate():
		if not is_instance_valid(f.n):
			emote_fx.erase(f)
			continue
		f.t += dt
		var k: float = f.t
		f.n.position.y = 2.3 + minf(k, 0.25) * 1.2 + k * 0.08
		f.n.scale = Vector3.ONE * (minf(1.0, k * 5.0) * (1.0 + 0.15 * sin(k * 9.0) * maxf(0.0, 1.0 - k)))
		f.n.modulate.a = clampf((3.0 - k) / 0.5, 0.0, 1.0)
		if k > 3.0:
			f.n.queue_free()
			emote_fx.erase(f)

## Kendi karakterinle emote: yakında başka oyuncu varsa ona döner.
func _emote(i: int) -> void:
	if emote_bar != null:
		emote_bar.visible = false
	var best = null
	var bd := 6.0
	for id in net_players:
		var m: Node3D = net_players[id].node
		var dd := m.position.distance_to(farmer.position)
		if dd < bd:
			bd = dd
			best = m
	if best != null:
		farmer.rotation.y = atan2(best.position.x - farmer.position.x, best.position.z - farmer.position.z)
	_show_emote(farmer, i)
	_sfx("place")
	if net_role == "guest":
		rpc_id(1, "net_req", "@emote", str(i), 0, 0)
	elif net_role == "host" and multiplayer.get_peers().size() > 0:
		rpc("net_do", "@emote", str(i), 0, 0, 1)

func _toggle_emote_bar() -> void:
	if emote_bar == null:
		emote_bar = _panel(8)
		emote_bar.mouse_filter = Control.MOUSE_FILTER_STOP
		ui.add_child(emote_bar)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 4)
		emote_bar.add_child(h)
		for i in EMOTES.size():
			var ii := i
			var b := _small_btn(" %s " % EMOTES[i], func(): _emote(ii))
			b.add_theme_font_size_override("font_size", 26)
			b.tooltip_text = "%d" % (i + 1)
			h.add_child(b)
		emote_bar.visible = false
	emote_bar.visible = not emote_bar.visible
	if emote_bar.visible:
		emote_bar.reset_size()
		var vs := get_viewport().get_visible_rect().size
		emote_bar.position = Vector2((vs.x - emote_bar.size.x) / 2.0, vs.y - emote_bar.size.y - 120)

## Nesneyi kendi yerinde 90° döndürür (ağda ev sahibinden geçer).
func _turn_entity(e) -> void:
	if e != null and e.kind != "debris" and e.kind != "plot":
		_perform({"tool": "move", "arg": "%d,%d" % [e.x, e.z], "x": e.x, "z": e.z})

## Nesnenin simgesi ve adı (menü başlığı).
func _ent_label(e: Dictionary) -> String:
	var def = null
	match e.kind:
		"building": def = Data.BUILDINGS.get(e.type)
		"decor": def = Data.DECOR.get(e.type)
		"tree": def = Data.TREES.get(e.type)
		"animal": def = Data.ANIMALS.get(e.type)
		"flower": def = Data.FLOWERS.get(e.type)
		"pond": def = Data.POND
		"coop": def = Data.COOP
	if def == null:
		return str(e.get("type", e.kind))
	return "%s %s" % [def.get("icon", "📦"), def.get("name", str(e.get("type", "")))]

## Nesnenin üstünde basılı tutunca: Döndür / Taşı / Kaldır.
func _open_ctx(e) -> void:
	if ctx_menu == null:
		ctx_menu = _panel(10)
		ctx_menu.mouse_filter = Control.MOUSE_FILTER_STOP
		ui.add_child(ctx_menu)
		ctx_box = VBoxContainer.new()
		ctx_box.add_theme_constant_override("separation", 6)
		ctx_menu.add_child(ctx_box)
	for c in ctx_box.get_children():
		ctx_box.remove_child(c)
		c.queue_free()
	var t := Label.new()
	t.text = _ent_label(e)
	t.add_theme_font_size_override("font_size", 17)
	ctx_box.add_child(t)
	var ee = e
	ctx_box.add_child(_small_btn("  🔄 Döndür  ", func():
		_turn_entity(ee)))
	ctx_box.add_child(_small_btn("  🚚 Taşı  ", func():
		ctx_menu.visible = false
		_set_tool("move")
		_move_pick(ee)))
	var can_rm := _resolve("remove", null, e.x, e.z) != null
	ctx_box.add_child(_small_btn("  🗑️ Kaldır  +%d 🪙  " % _refund_of(e), func():
		ctx_menu.visible = false
		_perform({"tool": "remove", "arg": null, "x": ee.x, "z": ee.z}), can_rm))
	if not can_rm:
		var w := Label.new()
		w.text = "📦 İçi dolu son ambar kaldırılamaz"
		w.add_theme_font_size_override("font_size", 12)
		w.add_theme_color_override("font_color", Color("#c62828"))
		ctx_box.add_child(w)
	ctx_menu.visible = true
	ctx_menu.reset_size()
	var vs := get_viewport().get_visible_rect().size
	ctx_menu.position = Vector2(clampf(hold_at.x + 12, 8, vs.x - ctx_menu.size.x - 8), clampf(hold_at.y - 20, 8, vs.y - ctx_menu.size.y - 8))
	_sfx("place")

## Sol tuş bırakıldı ya da süre doldu: basılı tutma kararı.
func _update_hold(dt: float) -> void:
	if hold_ent == null:
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		hold_t += dt
		if mouse_pos.distance_to(hold_at) > 16.0:
			# sürükledi: normal tıklama gibi işle ve sürükleyerek boyamaya devam et
			var hv0 := hold_tile
			hold_ent = null
			_click_tile(hv0, hold_at)
			painting = true
			drag_moved = true
		elif hold_t >= 0.45:
			var he = hold_ent
			hold_ent = null
			if tiles.get(key(he.x, he.z)) == he:
				_open_ctx(he)
		return
	var hv := hold_tile
	hold_ent = null
	_click_tile(hv, hold_at)

## Kareye normal tıklama (alete göre iş, ambar penceresi, yürüme).
func _click_tile(hv: Vector2i, at: Vector2) -> void:
	var he = tiles.get(key(hv.x, hv.y))
	if he != null and he.kind == "building" and (he.type == "barn" or he.type == "silo") and tool != "remove" and tool != "build" and tool != "move":
		_open_barn()
		return
	if he != null and he.kind == "building" and he.type == "oven" and tool != "remove" and tool != "build" and tool != "move":
		_open_oven()
		return
	if _resolve(tool, _current_arg(), hv.x, hv.y) != null:
		_enqueue(hv)
	else:
		_walk_to(_pick_point(at))
		_explain_fail(_current_arg(), hv.x, hv.y)

## Kaldırınca geri gelen altın: satın alma fiyatının yarısı.
func _refund_of(e: Dictionary) -> int:
	var def = null
	match e.kind:
		"tree": def = Data.TREES.get(e.type)
		"animal": def = Data.ANIMALS.get(e.type)
		"decor": def = Data.DECOR.get(e.type)
		"flower": def = Data.FLOWERS.get(e.type)
		"pond": def = Data.POND
		"coop": def = Data.COOP
		"building": def = Data.BUILDINGS.get(e.type)
	if def == null:
		return 0
	return int(def.cost * 0.5)

## Taşı aleti: nesneyi seç / bırak (seçilince hafifçe havalanır).
func _move_pick(e) -> void:
	if move_src != null:
		var old = tiles.get(key(move_src.x, move_src.y))
		if old != null and old.has("group") and is_instance_valid(old.group):
			old.group.position.y = 0.0
	move_src = null
	if e == null:
		return
	move_src = Vector2i(e.x, e.z)
	e.group.position.y = 0.35
	_sfx("place")
	_toast("🚚 Seçildi. Yeni yerine tıkla · kendisine tıkla ya da T: döndür · Esc: vazgeç", "hint")

func _count_buildings(type: String) -> int:
	var n := 0
	for e in entities:
		if e.kind == "building" and e.type == type:
			n += 1
	return n

## Ambar kapasitesi: her ambar 150, her silo +100. Ambar yoksa 0.
func _barn_cap() -> int:
	var cap := 0
	for e in entities:
		if e.kind == "building":
			if e.type == "barn":
				cap += Data.BARN_CAP
			elif e.type == "silo":
				cap += Data.SILO_CAP
	return cap if _count_buildings("barn") > 0 else 0

func _well_near(x: int, z: int) -> bool:
	for e in entities:
		if e.kind == "building" and e.type == "well" and maxi(absi(e.x - x), absi(e.z - z)) <= Data.WELL_RANGE:
			return true
	return false

func _free_area(x: int, z: int, w: int, d: int) -> bool:
	for i in w:
		for j in d:
			if not in_farm(x + i, z + j) or tiles.has(key(x + i, z + j)):
				return false
	return true

func _perform(item: Dictionary) -> bool:
	if net_role == "guest" and not net_applying:
		var act = _resolve(item.tool, item.arg, item.x, item.z)
		if act == null:
			return false
		_act_anim(act, tile_center(item.x, item.z))
		rpc_id(1, "net_req", item.tool, "" if item.arg == null else str(item.arg), item.x, item.z)
		return true
	var ok := _perform_local(item)
	if ok and net_role == "host" and multiplayer.get_peers().size() > 0:
		rpc("net_do", item.tool, "" if item.arg == null else str(item.arg), item.x, item.z, net_actor)
	return ok

func _perform_local(item: Dictionary) -> bool:
	var x: int = item.x
	var z: int = item.z
	var arg = item.arg
	var act = _resolve(item.tool, arg, x, z)
	if act == null:
		return false
	var e = tiles.get(key(x, z))
	var pos := tile_center(x, z)
	if act != "remove" and act != "move" and act != "turn":
		_act_anim(act, pos)
	match act:
		"plow":
			_add_entity({"kind": "plot", "x": x, "z": z, "crop": null, "progress": 0.0, "water": 0.0})
			_quest_event("plow", "", 1)
			_burst(pos + Vector3(0, 0.15, 0), "#8b5a3c", 8, 2.0)
			_sfx("plow")
		"plant":
			var c = Data.CROPS[arg]
			_spend(c.cost)
			_quest_event("plant", arg, 1)
			e.crop = arg
			e.progress = 0.0
			_refresh(e)
			_float_text(pos, "-%d 🪙" % c.cost, Color("#ffb4a8"))
			_burst(pos + Vector3(0, 0.2, 0), "#8bc34a", 6, 2.0)
			_sfx("plant")
		"water":
			e.water = 1.0
			_refresh(e)
			_quest_event("water", "", 1)
			_burst(pos + Vector3(0, 0.5, 0), "#4fc3f7", 12, 2.5)
			_sfx("water")
		"harvest":
			if e.kind == "plot":
				var ck: String = e.crop
				var c = Data.CROPS[ck]
				_burst(pos + Vector3(0, 0.4, 0), c.color, 12, 3.5)
				e.crop = null
				e.progress = 0.0
				_refresh(e)
				_gain(c.sell, c.xp, pos, c.icon)
				_store(ck, pos)
				_quest_event("crop", ck, 1)
			elif e.kind == "tree":
				var t = Data.TREES[e.type]
				e.has_fruit = false
				e.fruit_t = 0.0
				_refresh(e)
				_burst(pos + Vector3(0, 1.2, 0), t.fruit, 14, 3.0)
				_gain(t.sell, t.xp, pos, t.icon)
				_store(e.type, pos, 0)
				_quest_event("fruit", e.type, 1)
			elif e.kind == "animal":
				var a = Data.ANIMALS[e.type]
				e.ready = false
				e.t = 0.0
				e.icon.visible = false
				_burst(pos + Vector3(0, 1.0, 0), a.color, 10, 3.0)
				_gain(int(round(a.sell * Data.animal_sell_mult(e.lv))), a.xp, pos, a.picon)
				_store(e.type, pos, Data.animal_extra_yield(e.lv))
				_animal_harvested(e, pos)
				_quest_event("animal", e.type, 1)
				_update_hungry(e)
			elif e.kind == "flower":
				_harvest_flower(e, pos)
			elif e.kind == "coop":
				var cc := Vector3(e.x + 1.0, 0, e.z + 1.0)
				var n: int = e.eggs
				_burst(cc + Vector3(0, 1.0, 0), "#fff8e1", 12, 3.0)
				_gain(e.value, e.xp, cc, "🥚")
				_store("chicken", cc, e.yield - Data.YIELD.chicken[1])
				_quest_event("animal", "chicken", n)
				e.eggs = 0
				e.value = 0
				e.xp = 0
				e.yield = 0
				_update_coop(e)
			elif e.kind == "pond":
				var pd = Data.POND
				e.ready = false
				e.t = 0.0
				e.icon.visible = false
				var pc := Vector3(e.x + 1.0, 0, e.z + 1.0)
				_burst(pc + Vector3(0, 0.4, 0), "#4fc3f7", 14, 3.5)
				_gain(pd.sell, pd.xp, pc, pd.icon)
				_store("pond", pc, 0)
				_quest_event("fish", "", 1)
			_sfx("harvest")
		"feed":
			_feed_pen(e)
		"flower":
			var f = Data.FLOWERS[arg]
			_spend(f.cost)
			_add_entity({"kind": "flower", "type": arg, "x": x, "z": z})
			_float_text(pos, "-%d 🪙" % f.cost, Color("#ffb4a8"))
			_burst(pos + Vector3(0, 0.2, 0), f.color, 8, 2.0)
			_sfx("plant")
		"build":
			var b = Data.BUILDINGS[arg]
			_spend(b.cost)
			_add_entity({"kind": "building", "type": arg, "x": x, "z": z, "w": b.w, "d": b.d, "rot": 0.0})
			var bc := Vector3(x + b.w / 2.0, 0, z + b.d / 2.0)
			_float_text(bc + Vector3(0, 0.6, 0), "-%d 🪙" % b.cost, Color("#ffb4a8"))
			_gain(0, b.xp, bc, b.icon)
			_burst(bc + Vector3(0, 0.8, 0), "#d7b98e", 22, 4.0)
			_burst(bc + Vector3(0, 0.4, 0), "#9e9e9e", 14, 3.0)
			_recompute_boosts()
			_quest_event("build", arg, 1)
			_sfx("place")
		"coop":
			_spend(Data.COOP.cost)
			_add_entity({"kind": "coop", "type": "coop", "x": x, "z": z})
			_quest_event("buy", "coop", 1)
			var ccp := Vector3(x + 1.0, 0, z + 1.0)
			_float_text(ccp, "-%d 🪙" % Data.COOP.cost, Color("#ffb4a8"))
			_burst(ccp + Vector3(0, 0.5, 0), "#c9874d", 14, 3.0)
			_sfx("place")
		"pond":
			_spend(Data.POND.cost)
			_add_entity({"kind": "pond", "type": "pond", "x": x, "z": z})
			var pc := Vector3(x + 1.0, 0, z + 1.0)
			_float_text(pc, "-%d 🪙" % Data.POND.cost, Color("#ffb4a8"))
			_burst(pc + Vector3(0, 0.3, 0), "#4fc3f7", 16, 3.0)
			_sfx("water")
		"tree":
			var t = Data.TREES[arg]
			_spend(t.cost)
			_quest_event("tree", arg, 1)
			_add_entity({"kind": "tree", "type": arg, "x": x, "z": z, "age": 0.0, "fruit_t": 0.0, "has_fruit": false})
			_float_text(pos, "-%d 🪙" % t.cost, Color("#ffb4a8"))
			_burst(pos + Vector3(0, 0.3, 0), "#66bb6a", 10, 2.5)
			_sfx("place")
		"animal":
			var a = Data.ANIMALS[arg]
			_spend(a.cost)
			_add_entity({"kind": "animal", "type": arg, "x": x, "z": z, "t": 0.0, "ready": false})
			_quest_event("buy", arg, 1)
			_float_text(pos, "-%d 🪙" % a.cost, Color("#ffb4a8"))
			_burst(pos + Vector3(0, 0.5, 0), "#ffffff", 10, 2.5)
			_sfx("animal")
		"decor":
			var dd = Data.DECOR[arg]
			_spend(dd.cost)
			_add_entity({"kind": "decor", "type": arg, "x": x, "z": z})
			_burst(pos + Vector3(0, 0.2, 0), "#d7ccc8", 6, 2.0)
			_sfx("place")
		"remove":
			var def = null
			if e.kind == "tree":
				def = Data.TREES[e.type]
			elif e.kind == "animal":
				def = Data.ANIMALS[e.type]
			elif e.kind == "decor":
				def = Data.DECOR[e.type]
			elif e.kind == "flower":
				def = Data.FLOWERS[e.type]
			elif e.kind == "pond":
				def = Data.POND
			elif e.kind == "coop":
				def = Data.COOP
			elif e.kind == "building":
				def = Data.BUILDINGS.get(e.type)
			if e.kind == "debris":
				var dd: Array = DEBRIS.get(e.type, DEBRIS.weed)
				_remove_entity(e)
				_burst(pos + Vector3(0, 0.3, 0), "#8d6e63" if dd[4] else "#7cb342", 12, 2.5)
				_gain(dd[2], dd[3], pos, "🪓")
				_quest_event("clear", e.type, 1)
				_act_anim("remove", pos)
				_sfx("remove")
				return true
			_remove_entity(e)
			_act_anim("remove", pos)
			_burst(pos + Vector3(0, 0.3, 0), "#9e9e9e", 10, 2.5)
			if e.kind == "building":
				_recompute_boosts()
			var back := _refund_of(e)
			if back > 0:
				coins += back
				hud_dirty = true
				_float_text(pos, "+%d 🪙" % back, Color("#ffe066"))
			_sfx("remove")
		"turn":
			var te = _move_entity_of(arg)
			te.rot = fmod(float(te.rot) + PI / 2.0, TAU)
			te.group.rotation.y = te.rot
			_burst(te.group.position + Vector3(0, 0.4, 0), "#bbdefb", 6, 1.5)
			_sfx("place")
		"move":
			var src = _move_entity_of(arg)
			var d := _ent_base(_ent_dict(src))
			if src.has("w"):
				d.w = src.w
				d.d = src.d
			d.x = x
			d.z = z
			if move_src != null and move_src == Vector2i(src.x, src.z):
				move_src = null
			_remove_entity(src)
			var ne := _add_entity(d)
			var c: Vector3 = ne.group.position
			_act_anim("plant", c)
			_burst(c + Vector3(0, 0.3, 0), "#bbdefb", 12, 2.5)
			if ne.kind == "building" or ne.get("type", "") == "scarecrow":
				_recompute_boosts()
			_sfx("place")
	return true

func _current_arg():
	match tool:
		"move": return "" if move_src == null else "%d,%d" % [move_src.x, move_src.y]
		"hand", "seed": return sel.seed
		"tree": return sel.tree
		"animal": return sel.animal
		"garden": return sel.garden
		"decor": return sel.decor
		"build": return sel.build
	return null

func _enqueue(t: Vector2i) -> void:
	var arg = _current_arg()
	for q in queue:
		if q.x == t.x and q.z == t.y:
			return
	if _resolve(tool, arg, t.x, t.y) == null:
		if in_farm(t.x, t.y) and not drag_moved:
			_explain_fail(arg, t.x, t.y)
		return
	if queue.size() > 300:
		return
	var m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.86, 0.86)
	m.mesh = pm
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var col := Color(MARKER_COL[tool])
	col.a = 0.45
	mm.albedo_color = col
	m.material_override = mm
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = Vector3(t.x + 0.5, 0.14, t.y + 0.5)
	add_child(m)
	queue.append({"x": t.x, "z": t.y, "tool": tool, "arg": arg, "marker": m})
	move_target = null

func _explain_fail(arg, x: int, z: int) -> void:
	var e = tiles.get(key(x, z))
	var list = {"seed": Data.CROPS, "hand": Data.CROPS, "tree": Data.TREES, "animal": Data.animal_shop(), "decor": Data.DECOR, "garden": Data.garden(), "build": Data.BUILDINGS}.get(tool)
	var def = list.get(arg) if list != null and arg != null else null
	if def != null and not _unlocked(def):
		_toast("🔒 %s için seviye %d gerekli" % [def.name, def.level], "warn")
		return
	var seedish := tool == "hand" or tool == "seed"
	if def != null and seedish and not _in_season(def) and e != null and e.kind == "plot" and e.crop == null:
		_sfx("error")
		_toast("%s %s bu mevsim ekilmez (%s)" % [Data.SEASONS[season].icon, def.name, Data.season_names(def.seasons)], "warn")
		return
	if (tool == "hand") and e != null and e.kind == "animal" and not e.ready and e.food < Data.FEED_REFILL and not _can_feed(e):
		_sfx("error")
		_toast("🌾 Yem için ambarda tahıl ya da yeterli altın yok", "warn")
		return
	if tool == "water" and weather == "snow":
		_toast("🌨️ Kar yağarken sulamaya gerek yok", "hint")
		return
	var target_ok: bool = (e != null and e.kind == "plot" and e.crop == null) if seedish else e == null
	if def != null and coins < def.cost and target_ok:
		_sfx("error")
		_toast("🪙 Yeterli altının yok", "warn")
		return
	if tool == "animal" and arg == "coop" and not _free_area(x, z, 2, 2):
		_toast("🛖 Kümes için 2×2 boş alan gerekli", "hint")
		return
	if tool == "build" and def != null and not _free_area(x, z, def.w, def.d):
		_toast("%s %s için %d×%d boş alan gerekli" % [def.icon, def.name, def.w, def.d], "hint")
		return
	if tool == "remove" and e != null and e.kind == "building" and e.type == "barn" and _resolve("remove", null, x, z) == null:
		_toast("📦 İçi dolu son ambar yıkılamaz", "hint")
		return
	if tool == "garden" and arg == "pond" and not _free_area(x, z, 2, 2):
		_toast("🐟 Gölet için 2×2 boş alan gerekli", "hint")
		return
	if tool == "seed" and e == null:
		_toast("⛏️ Önce Çapa ile toprağı sür (2)", "hint")
	if tool == "move" and arg != null and arg != "":
		_toast("🚚 Oraya sığmıyor: boş ve çiftlik içinde bir yer seç", "hint")

func _clear_queue() -> void:
	for q in queue:
		q.marker.queue_free()
	queue.clear()

# ============================================================ çiftçi
func _update_farmer(dt: float) -> void:
	var moving := false
	var kx := (1.0 if _key(KEY_D) else 0.0) - (1.0 if _key(KEY_A) else 0.0)
	var kf := (1.0 if _key(KEY_W) else 0.0) - (1.0 if _key(KEY_S) else 0.0)
	var dir := Vector3.ZERO
	var seek = null   # yol izlerken sıradaki ara nokta
	if kx != 0.0 or kf != 0.0:
		var fwd := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
		var right := Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
		dir = (fwd * kf + right * kx).normalized()
		move_target = null
		cam_follow = true
	elif move_target != null:
		var nxt = _path_next(walk_path)
		if nxt == null:
			move_target = null
		else:
			seek = nxt
			dir = Vector3(nxt.x - farmer.position.x, 0, nxt.z - farmer.position.z).normalized()
	elif act_t <= 0.0:
		while queue.size() > 0 and _resolve(queue[0].tool, queue[0].arg, queue[0].x, queue[0].z) == null:
			queue.pop_front().marker.queue_free()
		if queue.size() > 0:
			var q = queue[0]
			var rect := _target_rect(q)
			var adj := _target_adjacent(q)
			var fp := Vector2(farmer.position.x, farmer.position.z)
			var dist := _rect_dist(fp, rect)
			if not q.has("path"):
				q.path = _find_path(farmer.position, rect, 0.75 if adj else 0.0)
			var tc := rect.get_center()
			if dist <= (0.85 if adj else 0.3):
				var dd := Vector2(tc.x - fp.x, tc.y - fp.y)
				if dd.length() > 0.01:
					farmer.rotation.y = atan2(dd.x, dd.y)
				_perform(q)
				q.marker.queue_free()
				queue.pop_front()
				hud_dirty = true
			else:
				var nxt = null if q.path == null else _path_next(q.path)
				if nxt == null:
					if dist <= 1.6:
						_perform(q)
					else:
						_toast("🚧 Oraya ulaşılamıyor. Çite 🚪 kapı ekle (Dekor).", "warn")
					q.marker.queue_free()
					queue.pop_front()
					hud_dirty = true
				else:
					seek = nxt
					dir = Vector3(nxt.x - farmer.position.x, 0, nxt.z - farmer.position.z).normalized()
	if dir != Vector3.ZERO:
		var step := dir * FSPEED * dt
		if seek != null:
			var rem: Vector3 = seek - farmer.position
			rem.y = 0.0
			if step.length() > rem.length():
				step = rem
		var np := farmer.position + step
		if _blocked(np) and not _blocked(farmer.position):
			# bina: eksen boyunca kaymayı dene
			if not _blocked(Vector3(np.x, 0, farmer.position.z)):
				np = Vector3(np.x, 0, farmer.position.z)
			elif not _blocked(Vector3(farmer.position.x, 0, np.z)):
				np = Vector3(farmer.position.x, 0, np.z)
			else:
				np = farmer.position
				move_target = null
		farmer.position = Vector3(clampf(np.x, -WALK_LIM, WALK_LIM), farmer.position.y, clampf(np.z, -WALK_LIM, WALK_LIM))
		farmer.rotation.y = lerp_angle(farmer.rotation.y, atan2(dir.x, dir.z), minf(1.0, dt * 14.0))
		moving = true
	farmer.position.y = maxf(0.0, height_at(farmer.position.x, farmer.position.z))
	move_marker.visible = move_target != null
	if move_target != null:
		move_marker.rotation.y += dt * 3.0
	if moving:
		walk_phase += dt * 11.0
	var sw := sin(walk_phase) * 0.7 if moving else 0.0
	fparts.leg_l.rotation.x = lerpf(fparts.leg_l.rotation.x, sw, 0.3)
	fparts.leg_r.rotation.x = lerpf(fparts.leg_r.rotation.x, -sw, 0.3)
	fparts.arm_l.rotation.x = lerpf(fparts.arm_l.rotation.x, -sw * 0.8, 0.3)
	fparts.body.position.y = absf(sin(walk_phase)) * 0.05 if moving else 0.0
	_animate_action(dt, sw)

## İş başlarken çağrılır: tür, süre ve hedef konum.
func _act_anim(kind: String, pos: Vector3) -> void:
	if net_applying:
		return
	act_kind = kind
	act_dur = ACT_DUR.get(kind, 0.3)
	act_t = act_dur
	act_pos = pos
	act_fx = 0.0
	move_target = null

## Eldeki eşya seçili alete göre; iş sırasında işe göre.
func _hold_prop() -> String:
	var k := act_kind if act_t > 0.0 else ""
	match k:
		"plow", "remove": return "hoe"
		"water": return "can"
		"plant", "flower", "tree", "feed": return "bag"
		"harvest": return "basket"
	match tool:
		"plow", "remove": return "hoe"
		"water": return "can"
		"seed", "garden", "tree": return "bag"
	return ""

func _animate_action(dt: float, sw: float) -> void:
	var fp: Dictionary = fparts
	var hold := _hold_prop()
	for pr in ["hoe", "can", "bag", "basket"]:
		if fp.has(pr):
			fp[pr].visible = pr == hold
	var body: Node3D = fp.body
	var ar: Node3D = fp.arm_r
	var al: Node3D = fp.arm_l
	if act_t <= 0.0:
		ar.rotation.x = lerpf(ar.rotation.x, sw * 0.8, 0.3)
		body.rotation.x = lerpf(body.rotation.x, 0.0, 0.25)
		if fp.has("can"):
			fp.can.rotation.x = lerpf(fp.can.rotation.x, 0.0, 0.25)
		return
	act_t = maxf(0.0, act_t - dt)
	var k := 1.0 - act_t / act_dur
	var bump := sin(k * PI)
	act_fx -= dt
	match act_kind:
		"plow", "remove":
			# iki çapa vuruşu, her vuruşta toprak sıçrar
			var sw2 := absf(sin(k * TAU))
			ar.rotation.x = -2.2 * sw2
			body.rotation.x = 0.22 * sw2
			if (k > 0.5 and k - dt / act_dur <= 0.5) or act_t == 0.0:
				_burst(act_pos + Vector3(0, 0.12, 0), "#8b5a3c" if act_kind == "plow" else "#9e9e9e", 5, 1.6)
		"water":
			# kovayı kaldır, eğ, damlalar tarlaya aksın
			ar.rotation.x = -1.15 * minf(1.0, k * 4.0) * (1.0 if k < 0.85 else (1.0 - k) / 0.15)
			fp.can.rotation.x = 0.9 * smoothstep(0.15, 0.35, k) * (1.0 - smoothstep(0.8, 0.95, k))
			body.rotation.x = 0.1 * bump
			if k > 0.25 and k < 0.82 and act_fx <= 0.0:
				act_fx = 0.03
				var sp: Vector3 = fp.spout.global_position
				_drop(sp, Vector3(randf_range(-0.3, 0.3), -0.5, randf_range(-0.3, 0.3)) + (act_pos - sp).normalized() * 1.2, "#7fd3ff", 0.05)
			if act_t == 0.0:
				_burst(act_pos + Vector3(0, 0.12, 0), "#7fd3ff", 6, 1.2)
		"plant", "flower", "tree":
			# çömel, tohumu serp
			body.position.y = -0.16 * bump
			body.rotation.x = 0.35 * bump
			ar.rotation.x = -0.9 * bump
			if k > 0.35 and k < 0.7 and act_fx <= 0.0:
				act_fx = 0.06
				var hp: Vector3 = fp.bag.global_position
				_drop(hp, Vector3(randf_range(-0.6, 0.6), 0.6, randf_range(-0.6, 0.6)), "#6d4c33", 0.035)
		"harvest":
			body.rotation.x = 0.4 * bump
			ar.rotation.x = -1.3 * bump
			al.rotation.x = -0.9 * bump
		"feed":
			# avuçla yem saç: kol öne savrulur, taneler hayvanlara uçar
			var th := sin(k * PI * 2.0)
			ar.rotation.x = -1.6 * absf(th)
			body.rotation.x = 0.12 * bump
			if k > 0.15 and k < 0.75 and act_fx <= 0.0:
				act_fx = 0.035
				var hp: Vector3 = fp.bag.global_position
				var to := (act_pos - hp)
				to.y = 0.0
				_drop(hp, to * 1.4 + Vector3(randf_range(-0.5, 0.5), 2.0, randf_range(-0.5, 0.5)), "#f0c75e", 0.04)
		_:
			ar.rotation.x = -1.4 * bump

## Tek parçacık (damla, tohum, tane): verilen hızla fırlar, yerçekimiyle düşer.
func _drop(pos: Vector3, vel: Vector3, color: String, size: float) -> void:
	var m := Models.box(size, size, size, Models.mat(color))
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = pos
	add_child(m)
	parts.append({"m": m, "v": vel, "t": 0.25})

## Oyun tuşu basılı mı? Menüdeyken, yardım açıkken ya da bir yazı kutusuna yazılırken hayır.
func _key(k: Key) -> bool:
	if not playing or help.visible or (set_layer != null and set_layer.visible):
		return false
	var f := get_viewport().gui_get_focus_owner()
	if f is LineEdit or f is TextEdit:
		return false
	return Input.is_physical_key_pressed(k)

func _update_camera(dt: float) -> void:
	if _key(KEY_Q):
		cam_yaw += dt * 1.8
	if _key(KEY_E):
		cam_yaw -= dt * 1.8
	var px := (1.0 if _key(KEY_RIGHT) else 0.0) - (1.0 if _key(KEY_LEFT) else 0.0)
	var pz := (1.0 if _key(KEY_UP) else 0.0) - (1.0 if _key(KEY_DOWN) else 0.0)
	if px != 0.0 or pz != 0.0:
		_pan_camera(Vector2(px, -pz) * dt * cam_dist * 1.1)
	if _key(KEY_R):
		cam_pitch = clampf(cam_pitch + dt * 0.8, 0.3, 1.4)
	if _key(KEY_F):
		cam_pitch = clampf(cam_pitch - dt * 0.8, 0.3, 1.4)
	if cam_follow:
		cam_target = cam_target.lerp(farmer.position, 1.0 - exp(-dt * 4.0))
	var cp := cos(cam_pitch)
	cam.position = cam_target + Vector3(sin(cam_yaw) * cp * cam_dist, sin(cam_pitch) * cam_dist, cos(cam_yaw) * cp * cam_dist)
	cam.look_at(cam_target + Vector3(0, 0.5 + look_up, 0), Vector3.UP)

# ============================================================ girdi
## Fare ışınının araziye (tepeler dahil) çarptığı nokta.
func _ground_hit(mp: Vector2):
	var from := cam.project_ray_origin(mp)
	var dir := cam.project_ray_normal(mp)
	var prev := 0.0
	var t := 0.0
	while t < 400.0:
		t += 0.5 if t < 120.0 else 2.0
		var p := from + dir * t
		if p.y <= far_height(p.x, p.z):
			var lo := prev
			var hi := t
			for i in 12:
				var m := (lo + hi) * 0.5
				var q := from + dir * m
				if q.y <= far_height(q.x, q.z):
					hi = m
				else:
					lo = m
			return from + dir * hi
		prev = t
	return null

func _pick(mp: Vector2):
	var hit = _ground_hit(mp)
	if hit == null:
		return null
	return Vector2i(floori(hit.x), floori(hit.z))

func _pick_point(mp: Vector2):
	return _ground_hit(mp)

func _walk_to(p) -> void:
	if p == null:
		return
	p.x = clampf(p.x, -WALK_LIM + 0.1, WALK_LIM - 0.1)
	p.z = clampf(p.z, -WALK_LIM + 0.1, WALK_LIM - 0.1)
	p.y = 0.0
	var tx := floori(p.x)
	var tz := floori(p.z)
	var ok := _walkable(tx, tz)
	var path = _find_path(farmer.position, Rect2(tx, tz, 1, 1), 0.0 if ok else 0.75)
	if path == null:
		_toast("🚧 Oraya yol yok", "hint")
		return
	if ok:
		path.append(Vector3(p.x, 0, p.z))
	elif path.is_empty():
		return
	else:
		p = path[path.size() - 1]
	walk_path = path
	move_target = p
	move_marker.position = Vector3(p.x, height_at(p.x, p.z) + 0.05, p.z)
	move_marker.visible = true

## Sınır çiti parçası: komşu sınır çitlerine ve içerideki oyuncu çitlerine bağlanır.
func _frame_fence_at(p: Vector2i) -> void:
	if frame_fences.has(p) and is_instance_valid(frame_fences[p]):
		frame_fences[p].queue_free()
	var c := func(dx: int, dz: int) -> bool:
		return _frame_ring(p.x + dx, p.y + dz, frame_gate_z) or _player_fence(p.x + dx, p.y + dz)
	var f := Models.fence(c.call(0, -1), c.call(0, 1), c.call(1, 0), c.call(-1, 0))
	f.position = Vector3(p.x + 0.5, 0, p.y + 0.5)
	frame_root.add_child(f)
	frame_fences[p] = f

func _player_fence(x: int, z: int) -> bool:
	var t = tiles.get(key(x, z))
	return t != null and (t.get("type", "") == "fence" or t.get("type", "") == "gate")

func _walkable(x: int, z: int) -> bool:
	if x < -WALK_LIM or x >= WALK_LIM or z < -WALK_LIM or z >= WALK_LIM:
		return false
	if frame_block.has(Vector2i(x, z)):
		return false
	if absf(x + 0.5 - STALL.x) < 1.3 and absf(z + 0.5 - STALL.z) < 1.3:   # balıkçı tezgâhı
		return false
	if Vector2(x + 0.5 - POND_X, z + 0.5 - POND_Z).length() < POND_R - 0.2:
		return false
	var t = tiles.get(key(x, z))
	if t == null:
		return true
	match t.kind:
		"building", "pond", "coop", "tree":
			return false
		"decor":
			return not BLOCK_DECOR.has(t.type)
		"debris":
			return not DEBRIS.get(t.type, DEBRIS.weed)[4]
	return true

func _blocked(p: Vector3) -> bool:
	return not _walkable(floori(p.x), floori(p.z))

static func _rect_dist(p: Vector2, r: Rect2) -> float:
	var dx := maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dz := maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	return Vector2(dx, dz).length()

## İş sırası öğesinin hedef alanı (çok kareli nesnelerde tüm kaplama).
func _target_rect(q) -> Rect2:
	var e = tiles.get(key(q.x, q.z))
	if e != null and e.has("w"):
		return Rect2(e.x, e.z, e.w, e.d)
	if (q.tool == "garden" and q.arg == "pond") or (q.tool == "animal" and q.arg == "coop"):
		return Rect2(q.x, q.z, 2, 2)
	if q.tool == "build" and Data.BUILDINGS.has(q.arg):
		return Rect2(q.x, q.z, Data.BUILDINGS[q.arg].w, Data.BUILDINGS[q.arg].d)
	return Rect2(q.x, q.z, 1, 1)

## Hedefe yanından mı ulaşılır (engel ya da engel olacak bir şey yerleştiriliyor)?
func _target_adjacent(q) -> bool:
	if not _walkable(q.x, q.z):
		return true
	match q.tool:
		"tree":
			return true
		"animal":
			return q.arg == "coop"
		"garden":
			return q.arg == "pond"
		"build":
			return true
		"decor":
			return BLOCK_DECOR.has(q.arg)
	return false

func _line_clear(a: Vector3, b: Vector3) -> bool:
	var d := Vector3(b.x - a.x, 0, b.z - a.z)
	var n := int(ceil(d.length() / 0.2))
	var side := Vector3(-d.z, 0, d.x).normalized() * 0.18
	for i in range(1, n + 1):
		var p := a + d * (float(i) / n)
		if _blocked(p) or _blocked(p + side) or _blocked(p - side):
			return false
	return true

## Yol izlerken sıradaki noktayı verir; ulaşılanları ve görüşte olanları atlar.
func _path_next(path: Array):
	while path.size() > 0:
		var p: Vector3 = path[0]
		if Vector2(p.x - farmer.position.x, p.z - farmer.position.z).length() < 0.1:
			path.pop_front()
			continue
		break
	while path.size() >= 2 and _line_clear(farmer.position, path[1]):
		path.pop_front()
	return path[0] if path.size() > 0 else null

## Izgara üzerinde A*: merkezinin hedef dikdörtgene uzaklığı <= thr olan yürünebilir kareye.
## Ulaşılamazsa null; zaten hedefteyse boş dizi.
func _find_path(from: Vector3, goal: Rect2, thr: float):
	var start := Vector2i(floori(from.x), floori(from.z))
	var gc := goal.get_center()
	var is_goal := func(c: Vector2i) -> bool:
		return _walkable(c.x, c.y) and _rect_dist(Vector2(c.x + 0.5, c.y + 0.5), goal) <= thr + 0.001
	if is_goal.call(start) and thr > 0.0:
		return []
	var open: Array = [[0.0, start]]
	var gs := {start: 0.0}
	var came := {}
	var closed := {}
	var found = null
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	var n := 0
	while open.size() > 0 and n < 16000:
		var cur: Vector2i = _hpop(open)[1]
		if closed.has(cur):
			continue
		closed[cur] = true
		n += 1
		if is_goal.call(cur):
			found = cur
			break
		for d in dirs:
			var nb: Vector2i = cur + d
			if closed.has(nb) or not _walkable(nb.x, nb.y):
				continue
			if d.x != 0 and d.y != 0 and (not _walkable(cur.x + d.x, cur.y) or not _walkable(cur.x, cur.y + d.y)):
				continue
			var g: float = gs[cur] + (1.414 if d.x != 0 and d.y != 0 else 1.0)
			if g < gs.get(nb, INF):
				gs[nb] = g
				came[nb] = cur
				_hpush(open, [g + Vector2(nb.x + 0.5 - gc.x, nb.y + 0.5 - gc.y).length(), nb])
	if found == null:
		return null
	var out := []
	var c: Vector2i = found
	while c != start:
		out.push_front(Vector3(c.x + 0.5, 0, c.y + 0.5))
		c = came[c]
	return out

static func _hpush(h: Array, it: Array) -> void:
	h.append(it)
	var i := h.size() - 1
	while i > 0:
		var p := (i - 1) / 2
		if h[p][0] <= h[i][0]:
			break
		var t = h[p]
		h[p] = h[i]
		h[i] = t
		i = p

static func _hpop(h: Array) -> Array:
	var top = h[0]
	var last = h.pop_back()
	if h.size() > 0:
		h[0] = last
		var i := 0
		while true:
			var l := i * 2 + 1
			var r := l + 1
			var m := i
			if l < h.size() and h[l][0] < h[m][0]:
				m = l
			if r < h.size() and h[r][0] < h[m][0]:
				m = r
			if m == i:
				break
			var t = h[m]
			h[m] = h[i]
			h[i] = t
			i = m
	return top

# ------------------------------------------------------------ tavuk kümesi
func _coop_for(e: Dictionary):
	var best = null
	var bd := 1e9
	for c in entities:
		if c.kind != "coop" or c.eggs >= Data.COOP_CAP:
			continue
		var d := _rect_dist(Vector2(e.x + 0.5, e.z + 0.5), Rect2(c.x, c.z, 2, 2))
		if d <= Data.COOP_RANGE and d < bd:
			bd = d
			best = c
	return best

func _lay_egg(e: Dictionary) -> bool:
	if e.type != "chicken":
		return false
	var c = _coop_for(e)
	if c == null:
		return false
	var a = Data.ANIMALS.chicken
	c.eggs += 1
	c.value += int(round(a.sell * Data.animal_sell_mult(e.lv)))
	c.xp += a.xp
	c.yield += Data.YIELD.chicken[1] + Data.animal_extra_yield(e.lv)
	if not loading:
		_animal_harvested(e, tile_center(e.x, e.z))
	_update_coop(c)
	return true

func _update_coop(c: Dictionary) -> void:
	if c.has("icon") and c.icon != null:
		c.icon.text = "🥚 %d" % c.eggs
		c.icon.visible = c.eggs > 0

## Kamerayı yer düzleminde kaydırır (ekran yönüne göre); çiftçiyi takip etmeyi bırakır.
func _pan_camera(v: Vector2) -> void:
	var fwd := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
	var right := Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
	cam_target += right * v.x - fwd * v.y
	cam_target.x = clampf(cam_target.x, -WALK_LIM, WALK_LIM)
	cam_target.z = clampf(cam_target.z, -WALK_LIM, WALK_LIM)
	cam_target.y = 0.0
	cam_follow = false

func _input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.physical_keycode == KEY_F11:
			gfx.fs = not gfx.fs
			_apply_gfx(true)
			_save_gfx()
			if set_layer.visible:
				_render_settings()
			get_viewport().set_input_as_handled()
			return
		if ev.physical_keycode == KEY_ESCAPE and set_layer != null and set_layer.visible:
			set_layer.visible = false
			get_viewport().set_input_as_handled()
			return
	if fps_lbl != null and fps_lbl.visible:
		fps_lbl.text = "%d FPS" % Engine.get_frames_per_second()
	if not playing:
		return
	if ev is InputEventMouseMotion:
		mouse_pos = ev.position
		if rotating:
			cam_yaw -= ev.relative.x * 0.008
			cam_pitch = clampf(cam_pitch + ev.relative.y * 0.005, 0.3, 1.4)
		if panning:
			_pan_camera(-ev.relative * cam_dist * 0.0017)
	elif ev is InputEventMouseButton and not ev.pressed:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			painting = false
		elif ev.button_index == MOUSE_BUTTON_RIGHT:
			rotating = false
		elif ev.button_index == MOUSE_BUTTON_MIDDLE:
			panning = false

func _unhandled_input(ev: InputEvent) -> void:
	if not playing:
		return
	if ev is InputEventMouseButton and ev.pressed:
		match ev.button_index:
			MOUSE_BUTTON_LEFT:
				if shelf_open:
					shelf_open = false
					_render_shelf()
					return
				if ctx_menu != null and ctx_menu.visible:
					ctx_menu.visible = false
					return
				if fish_state != "" and _fish_click():
					return
				if mill_state != "":
					_mill_hit()
					return
				if bake_state != "":
					bake_stoke += 1
					return
				var gp = _pick_point(ev.position)
				if gp != null and _near_mill(gp):
					_open_mill()
					return
				if gp != null and _near_stall(gp):
					_open_fish_shop()
					return
				if gp != null and _in_lake(gp):
					_start_fishing(gp)
					return
				painting = true
				drag_moved = false
				hover = _pick(ev.position)
				if hover != null and not in_farm(hover.x, hover.y):
					if tool != "hand":
						_toast("🗺️ Burası çiftliğin dışı. Genişletmek için üstteki 🗺️ Arazi düğmesi.", "hint")
					_walk_to(_pick_point(ev.position))
					return
				if hover != null and tool == "move":
					painting = false
					var me = tiles.get(key(hover.x, hover.y))
					if move_src == null:
						if me != null and me.kind != "debris":
							_move_pick(me)
						return
					if me != null and Vector2i(me.x, me.z) == move_src:
						_turn_entity(me)   # seçili nesneye yeniden tıkla: döndür
						return
					if _resolve("move", _current_arg(), hover.x, hover.y) != null:
						_enqueue(hover)
						move_src = null   # nesne, çiftçi varınca taşınır
					else:
						_explain_fail(_current_arg(), hover.x, hover.y)
					return
				if hover != null:
					var he = tiles.get(key(hover.x, hover.y))
					if he != null and he.kind != "plot" and he.kind != "debris":
						# kısa tıklama bırakınca işlenir; basılı tutulursa menü açılır
						painting = false
						hold_ent = he
						hold_tile = hover
						hold_at = ev.position
						hold_t = 0.0
						return
					_click_tile(hover, ev.position)
			MOUSE_BUTTON_RIGHT:
				rotating = true
			MOUSE_BUTTON_MIDDLE:
				panning = true
			MOUSE_BUTTON_WHEEL_UP:
				cam_dist = clampf(cam_dist * 0.9, 5.0, 60.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				cam_dist = clampf(cam_dist * 1.1, 5.0, 60.0)
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		var k: int = ev.physical_keycode
		if emote_bar != null and emote_bar.visible and k >= KEY_1 and k < KEY_1 + EMOTES.size():
			_emote(k - KEY_1)
		elif k >= KEY_1 and k <= KEY_9 and k - KEY_1 < TOOLS.size():
			_set_tool(TOOLS[k - KEY_1].id, TOOLS[k - KEY_1].id != "hand")
		elif k == KEY_0 and TOOLS.size() >= 10:
			_set_tool(TOOLS[9].id, false)
		elif k == KEY_MINUS and TOOLS.size() >= 11:
			_set_tool(TOOLS[10].id, false)
		elif k == KEY_TAB:
			if wheel.visible:
				_close_wheel()
			else:
				_open_wheel(mouse_pos)
		elif k == KEY_SPACE and (fish_state == "bite" or fish_state == "wait"):
			_fish_click()
		elif k == KEY_SPACE and mill_state != "":
			_mill_hit()
		elif k == KEY_SPACE and bake_state != "":
			bake_stoke += 1
		elif k == KEY_G:
			_toggle_emote_bar()
		elif k == KEY_T:
			if move_src != null:
				_turn_entity(tiles.get(key(move_src.x, move_src.y)))
			elif hover != null:
				_turn_entity(tiles.get(key(hover.x, hover.y)))
		elif k == KEY_ESCAPE:
			if ctx_menu != null and ctx_menu.visible:
				ctx_menu.visible = false
				return
			if fish_state != "":
				_fish_end()
				return
			if bake_state != "":
				bake_state = ""
				bake_ui.visible = false
				_toast("🔥 Pişirme yarıda kaldı, malzeme harcanmadı.", "hint")
				return
			if mill_state != "":
				mill_state = ""
				mill_ui.visible = false
				_toast("🌬️ Öğütme yarıda kaldı, tahıl harcanmadı.", "hint")
				return
			if emote_bar != null and emote_bar.visible:
				emote_bar.visible = false
				return
			if move_src != null:
				_move_pick(null)
				return
			if wheel.visible:
				_close_wheel()
				return
			if shelf_open:
				shelf_open = false
				_render_shelf()
				return
			_clear_queue()
			land_dlg.visible = false
			help.visible = false
			barn.visible = false
		elif k == KEY_SPACE:
			cam_follow = true
		elif k == KEY_L:
			if land_dlg.visible:
				land_dlg.visible = false
			else:
				_open_land()
		elif k == KEY_J:
			quest_open = not quest_open
			_render_quests()
		elif k == KEY_B:
			if barn.visible:
				barn.visible = false
			else:
				_open_barn()

func _update_hover() -> void:
	var over_ui := get_viewport().gui_get_hovered_control() != null
	var p = null if over_ui else _pick(mouse_pos)
	if painting and p != null and (hover == null or p != hover):
		drag_moved = true
		_enqueue(p)
	hover = p

func _update_cursor() -> void:
	if hover == null:
		cursor.visible = false
		cursor_edge.visible = false
		tip_panel.visible = false
		return
	var x: int = hover.x
	var z: int = hover.y
	var arg = _current_arg()
	var act = _resolve(tool, arg, x, z)
	var col: Color
	if act != null:
		col = Color("#ff5252") if tool == "remove" else Color("#b9ff7a")
	else:
		col = Color.WHITE if in_farm(x, z) else Color("#ff8a80")
	var e = tiles.get(key(x, z))
	var c := tile_center(x, z)
	var s := Vector3.ONE
	var msrc = _move_entity_of(arg) if tool == "move" else null
	if msrc != null:
		var mw := int(msrc.get("w", 1))
		var md := int(msrc.get("d", 1))
		c = Vector3(x + mw / 2.0, 0, z + md / 2.0)
		s = Vector3(mw, 1, md)
	elif e != null and e.has("w"):
		c = Vector3(e.x + e.w / 2.0, 0, e.z + e.d / 2.0)
		s = Vector3(e.w, 1, e.d)
	elif e == null and tool == "garden" and arg == "pond":
		c = Vector3(x + 1.0, 0, z + 1.0)
		s = Vector3(2, 1, 2)
	elif e == null and tool == "build" and Data.BUILDINGS.has(arg):
		var bd = Data.BUILDINGS[arg]
		c = Vector3(x + bd.w / 2.0, 0, z + bd.d / 2.0)
		s = Vector3(bd.w, 1, bd.d)
	cursor.position = c + Vector3(0, 0.13, 0)
	cursor.scale = s
	cursor_edge.position = cursor.position
	cursor_edge.scale = s
	var cm: StandardMaterial3D = cursor.material_override
	cm.albedo_color = Color(col, 0.35 if act != null else 0.15)
	var em: StandardMaterial3D = cursor_edge.material_override
	em.albedo_color = col
	cursor.visible = true
	cursor_edge.visible = true
	var info := _describe(e, act, arg, x, z)
	if info != "":
		tip_label.text = info
		tip_panel.visible = true
		tip_panel.reset_size()
		var vp := get_viewport().get_visible_rect().size
		tip_panel.position = Vector2(minf(mouse_pos.x + 16, vp.x - tip_panel.size.x - 8), minf(mouse_pos.y + 18, vp.y - tip_panel.size.y - 8))
	else:
		tip_panel.visible = false

func _describe(e, act, arg, x: int, z: int) -> String:
	if not in_farm(x, z) and e == null:
		return ""
	var s := ""
	if e != null:
		match e.kind:
			"plot":
				if e.crop == null:
					s = "Sürülmüş toprak"
				else:
					var c = Data.CROPS[e.crop]
					s = "%s %s\n" % [c.icon, c.name]
					if e.progress >= 1.0:
						s += "✅ Hasada hazır!"
					else:
						var rate := _grow_rate(e)
						s += "%s · %s" % [bar(e.progress), fmt_time((1.0 - e.progress) * c.time / rate)]
					if e.boost:
						s += " · 🧑‍🌾+25%"
				if weather == "snow":
					s += "\n🌨️ kar: sabit hız, sulama gerekmez"
				elif _wet(e):
					s += "\n💧 " + bar(e.water)
				else:
					s += "\n🏜️ kuru · yarı hız"
			"tree":
				var t = Data.TREES[e.type]
				s = "%s %s\n" % [t.icon, t.name]
				if e.age < 1.0:
					s += "büyüyor " + bar(e.age)
				elif e.has_fruit:
					s += "✅ Meyve hazır!"
				else:
					s += "meyve " + bar(e.fruit_t)
			"animal":
				var a = Data.ANIMALS[e.type]
				s = "%s %s · ⭐ Sv %d" % [a.icon, a.name, e.lv]
				if e.lv < Data.ANIMAL_MAX_LV:
					s += " (%d/%d)" % [e.hv, e.lv * Data.HARVESTS_PER_LV]
				var pen := _pen(e)
				if pen.size() > 1:
					s += " · ağıl: %d" % pen.size()
				s += "\n"
				s += ("✅ %s %s hazır!" % [a.picon, a.product]) if e.ready else ("%s %s" % [a.picon, bar(e.t)])
				if e.food <= 0.0 and not e.ready:
					s += "\n🍽️ Aç! Üretim durdu"
				else:
					s += "\n🌾 yem " + bar(e.food)
			"flower":
				var f = Data.FLOWERS[e.type]
				var fl := _flower_lv(e.type)
				s = "%s %s · ⭐ Sv %d" % [f.icon, f.name, fl.lv]
				if fl.lv < Data.FLOWER_MAX_LV:
					s += " (%d/%d)" % [fl.n, fl.lv * Data.FLOWER_HARVESTS_PER_LV]
				s += "\n"
				s += "✅ Çiçekler açtı!" if e.ready else "%s · %s" % [bar(e.t), fmt_time((1.0 - e.t) * f.time)]
				s += "\n💐 sulama bonusu ×%.1f" % (1.0 + Data.FLOWER_WET_BONUS * _flower_wet_frac(e))
				if weather == "snow":
					s += " · 🌨️ kar sular"
				elif _wet(e):
					s += " · 💧 " + bar(e.water)
				else:
					s += " · 🏜️ kuru"
			"coop":
				s = "🛖 %s\n🥚 %d / %d yumurta" % [Data.COOP.name, e.eggs, Data.COOP_CAP]
				if e.eggs == 0:
					s += "\nÇevredeki tavuklar buraya yumurtlar"
			"pond":
				s = "🐟 %s\n" % Data.POND.name
				s += "✅ Balıklar hazır!" if e.ready else "🐟 " + bar(e.t)
			"decor":
				s = "%s %s" % [Data.DECOR[e.type].icon, Data.DECOR[e.type].name]
			"building":
				var bd: Dictionary = Data.BUILDINGS.get(e.type, {"icon": "🏠", "name": e.type, "info": ""})
				s = "%s %s\n%s" % [bd.icon, bd.name, bd.info]
				if e.type == "barn" or e.type == "silo":
					s += "\n📦 %d / %d" % [_res_total(), _barn_cap()]

	if e != null and e.kind != "plot" and e.kind != "debris":
		s += ("\n" if s != "" else "") + "🖱️ Basılı tut: döndür · taşı · kaldır"
	if act != null:
		var extra := ""
		match act:
			"plant": extra = " %s %s  -%d🪙" % [Data.CROPS[arg].icon, Data.CROPS[arg].name, Data.CROPS[arg].cost]
			"feed": extra = " " + _feed_cost_text(e)
			"flower": extra = " %s %s  -%d🪙" % [Data.FLOWERS[arg].icon, Data.FLOWERS[arg].name, Data.FLOWERS[arg].cost]
			"pond": extra = "  -%d🪙" % Data.POND.cost
			"coop": extra = "  -%d🪙" % Data.COOP.cost
			"build": extra = " %s %s  -%d🪙" % [Data.BUILDINGS[arg].icon, Data.BUILDINGS[arg].name, Data.BUILDINGS[arg].cost]
			"tree": extra = " %s  -%d🪙" % [Data.TREES[arg].icon, Data.TREES[arg].cost]
			"animal": extra = " %s  -%d🪙" % [Data.ANIMALS[arg].icon, Data.ANIMALS[arg].cost]
			"decor": extra = " %s  -%d🪙" % [Data.DECOR[arg].icon, Data.DECOR[arg].cost]
			"remove": extra = ("  +%d🪙" % _refund_of(e)) if e != null and _refund_of(e) > 0 else ""
		s += ("\n" if s != "" else "") + "👉 " + ACT_TXT[act] + extra
	return s

# ============================================================ efektler
func _burst(pos: Vector3, color: String, n := 10, up := 2.5) -> void:
	var mat := Models.mat(color)
	for i in n:
		var m := Models.box(0.08, 0.08, 0.08, mat)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.position = pos + Vector3(randf_range(-0.2, 0.2), randf() * 0.2, randf_range(-0.2, 0.2))
		add_child(m)
		parts.append({"m": m, "v": Vector3(randf_range(-1.2, 1.2), up * (0.6 + randf() * 0.6), randf_range(-1.2, 1.2)), "t": 0.0})

func _update_parts(dt: float) -> void:
	for i in range(parts.size() - 1, -1, -1):
		var p = parts[i]
		p.t += dt
		p.v.y -= 9.0 * dt
		var m: MeshInstance3D = p.m
		m.position += p.v * dt
		m.rotation += Vector3(dt * 6.0, dt * 4.0, 0)
		m.scale = Vector3.ONE * maxf(0.01, 1.0 - p.t / 0.9)
		if p.t > 0.9:
			m.queue_free()
			parts.remove_at(i)

func _float_text(pos: Vector3, text: String, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = font
	l.font_size = 56
	l.pixel_size = 0.006
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.modulate = col
	l.outline_size = 14
	l.outline_modulate = Color(0.15, 0.1, 0.05, 0.7)
	l.position = pos + Vector3(0, 1.3, 0)
	add_child(l)
	floats.append({"l": l, "t": 0.0})

func _update_floats(dt: float) -> void:
	for i in range(floats.size() - 1, -1, -1):
		var f = floats[i]
		f.t += dt
		var l: Label3D = f.l
		l.position.y += dt * 0.9
		var a := 1.0 - maxf(0.0, (f.t - 0.8) / 0.6)
		l.modulate.a = a
		l.outline_modulate.a = a * 0.7
		if f.t > 1.4:
			l.queue_free()
			floats.remove_at(i)

func _toast(msg: String, kind := "") -> void:
	if loading:
		return
	for c in toasts.get_children():
		if c.get_meta("msg", "") == msg:
			return
	var p := PanelContainer.new()
	p.set_meta("msg", msg)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := Color(0.18, 0.12, 0.08, 0.92)
	if kind == "level":
		bg = Color("#f4a300")
	elif kind == "warn":
		bg = Color(0.63, 0.16, 0.12, 0.92)
	p.add_theme_stylebox_override("panel", _sb(bg, 12, Color.WHITE if kind == "level" else Color(0, 0, 0, 0), 2 if kind == "level" else 0, 10))
	var l := Label.new()
	l.text = msg
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color("#5a3500") if kind == "level" else Color.WHITE)
	l.add_theme_font_size_override("font_size", 19 if kind == "level" else 15)
	p.add_child(l)
	toasts.add_child(p)
	var life := 3.2 if kind == "level" else 1.9
	var tw := create_tween()
	tw.tween_interval(life)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)

# ============================================================ ses
func _build_sounds() -> void:
	sounds = {
		"plow": _synth([[160, 70, "tri", 0.14, 0.4, 0.0]]),
		"plant": _synth([[520, 760, "sine", 0.1, 0.3, 0.0]]),
		"water": _synth([[1200, 380, "sine", 0.18, 0.22, 0.0]]),
		"harvest": _synth([[660, 990, "tri", 0.09, 0.32, 0.0], [990, 1320, "tri", 0.1, 0.25, 0.07]]),
		"place": _synth([[300, 480, "tri", 0.12, 0.35, 0.0]]),
		"animal": _synth([[700, 900, "square", 0.06, 0.12, 0.0], [900, 650, "square", 0.08, 0.12, 0.08]]),
		"remove": _synth([[400, 120, "saw", 0.15, 0.15, 0.0]]),
		"error": _synth([[220, 160, "saw", 0.12, 0.15, 0.0]]),
		"cast": _synth([[900, 300, "sine", 0.22, 0.18, 0.0]]),
		"bite": _synth([[300, 160, "sine", 0.12, 0.35, 0.0], [520, 300, "sine", 0.1, 0.3, 0.1]]),
		"level": _synth([[523, 528, "tri", 0.22, 0.3, 0.0], [659, 665, "tri", 0.22, 0.3, 0.11], [784, 791, "tri", 0.22, 0.3, 0.22], [1046, 1056, "tri", 0.3, 0.3, 0.33]]),
	}
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)

func _synth(segs: Array) -> AudioStreamWAV:
	var rate := 22050
	var total := 0.0
	for s in segs:
		total = maxf(total, s[5] + s[3])
	var n := int(total * rate) + 1
	var buf := PackedFloat32Array()
	buf.resize(n)
	for s in segs:
		var f0: float = s[0]
		var f1: float = s[1]
		var dur: float = s[3]
		var vol: float = s[4]
		var start := int(s[5] * rate)
		var phase := 0.0
		for i in int(dur * rate):
			var t := float(i) / rate
			var f := f0 * pow(f1 / f0, t / dur)
			phase += f / rate
			var fr := phase - floorf(phase)
			var w := 0.0
			match s[2]:
				"sine": w = sin(fr * TAU)
				"tri": w = 4.0 * absf(fr - 0.5) - 1.0
				"square": w = 1.0 if fr < 0.5 else -1.0
				_: w = 2.0 * fr - 1.0
			var env_v := vol * exp(-t / dur * 5.0) * minf(1.0, t * 400.0)
			if start + i < n:
				buf[start + i] += w * env_v
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav

func _sfx(kind: String) -> void:
	if muted or not sounds.has(kind):
		return
	var p: AudioStreamPlayer = players[player_i]
	player_i = (player_i + 1) % players.size()
	p.stream = sounds[kind]
	p.play()

# ============================================================ gün/gece
func _update_day(dt: float) -> void:
	day_time += dt / DAY_LEN * lerpf(1.8, 0.7, day_f_last)
	if day_time >= 1.0:
		day_time -= 1.0
		day += 1
		hud_dirty = true
		if _count_buildings("house") > 0 and not loading and net_role != "guest":
			var gift := 20 + level * 5
			_gain(gift, 2, farmer.position, "🏠")
			_toast("🏠 Günaydın! Evinin kapısında %d 🪙 hediye var." % gift, "level")
	var ang := (day_time - 0.25) * TAU
	var elev := sin(ang)
	var day_f := smoothstep(-0.12, 0.3, elev)
	night_f = 1.0 - smoothstep(-0.15, 0.1, elev)
	day_f_last = smoothstep(-0.05, 0.05, elev)
	var set_f := maxf(0.0, 1.0 - absf(elev) / 0.32) * (1.0 if elev > -0.3 else 0.0)
	var sky := Color("#0d1633").lerp(Color("#9fd4ff"), day_f).lerp(Color("#ffa66b"), set_f * 0.55)
	wx_f = move_toward(wx_f, 1.0 if weather == "rain" or weather == "snow" else 0.0, dt * 0.3)
	dr_f = move_toward(dr_f, 1.0 if weather == "drought" else 0.0, dt * 0.3)
	var grey := Color("#c3cbd5") if weather == "snow" or season == 3 else Color("#7f8b99")
	sky = sky.lerp(grey.lerp(Color("#151a26"), night_f), wx_f * 0.7)
	sky = sky.lerp(Color("#f2d79c"), dr_f * 0.35 * day_f)
	env.fog_density = 0.0025 + 0.012 * wx_f
	var ep := cam_target + Vector3(0, 14, 0)
	rain_fx.global_position = ep
	snow_fx.global_position = ep
	rain_fx.emitting = weather == "rain"
	snow_fx.emitting = weather == "snow"
	var top := Color("#03061a").lerp(Color("#4c9ce6"), day_f).lerp(Color("#6a74b8"), set_f * 0.35)
	top = top.lerp(grey.darkened(0.15).lerp(Color("#0c1019"), night_f), wx_f * 0.75)
	sky = sky.lerp(Color("#121c3d"), night_f * 0.5)
	env.fog_light_color = sky
	sky_mat.set_shader_parameter("hor_col", Vector3(sky.r, sky.g, sky.b))
	sky_mat.set_shader_parameter("top_col", Vector3(top.r, top.g, top.b))
	sky_mat.set_shader_parameter("sun_dir", Vector3(cos(ang) * 30.0, sin(ang) * 35.0, 12.0).normalized())
	sky_mat.set_shader_parameter("moon_dir", Vector3(-cos(ang) * 30.0, -sin(ang) * 35.0, 16.0).normalized())
	sky_mat.set_shader_parameter("night", night_f)
	sky_mat.set_shader_parameter("cloud", wx_f)
	var nb: float = gfx.night / 100.0
	env.ambient_light_color = Color("#5d76c4").lerp(Color("#dff1ff"), day_f)
	env.ambient_light_energy = 0.3 + 0.2 * day_f + (0.02 + 0.16 * nb) * night_f
	env.tonemap_exposure = 0.8 + 0.12 * nb * night_f
	var wm: ShaderMaterial = Models.water()
	wm.set_shader_parameter("moon_dir", Vector3(-cos(ang) * 30.0, absf(sin(ang)) * 35.0, 16.0).normalized())
	wm.set_shader_parameter("night", night_f * (1.0 - wx_f))
	# gündüz güneş, gece ay ışık verir; ufukta geçişte gölge yumuşakça kaybolur
	var qang := ang if elev >= 0.0 else ang + PI
	var s_elev := maxf(sin(qang), 0.15)
	var off := Vector3(cos(qang) * 30.0, s_elev * 35.0, 12.0 if elev >= 0.0 else 16.0)
	sun.look_at_from_position(off, Vector3.ZERO, Vector3.UP)
	sun.shadow_opacity = smoothstep(0.02, 0.14, absf(elev)) * (1.0 - 0.6 * wx_f)
	sun.light_energy = (1.15 * day_f + (0.24 + 0.26 * nb) * night_f + 0.05) * (1.0 - 0.5 * wx_f)
	sun.light_color = Color("#9db2ff") if night_f > 0.5 else Color("#ffb37a").lerp(Color("#fff3d6"), smoothstep(0.0, 0.5, elev)).lerp(Color("#ffcf86"), dr_f * 0.5)
	Models.glow().emission_energy_multiplier = night_f * 3.0
	Models.emissive("#ffffff", "#ffffff", 0.35).emission_energy_multiplier = 0.35 * day_f + 0.02
	var hh := int(day_time * 24.0)
	var mm := int(day_time * 24.0 * 60.0) % 60
	var icon := "🌙" if night_f > 0.6 else ("🌅" if set_f > 0.4 else "☀️")
	var sn = Data.SEASONS[season]
	var left := ceili((1.0 - season_t) * Data.SEASON_LEN / 60.0)
	var txt := "%s %02d:%02d · Gün %d   ·   %s %s (%d dk) · Yıl %d" % [icon, hh, mm - mm % 10, day, sn.icon, sn.name, left, year]
	if weather != "":
		txt += "   ·   %s %s" % [Data.WEATHER[weather].icon, Data.WEATHER[weather].name]
	lbl_clock.text = txt

func _update_lamps(dt: float) -> void:
	lamp_timer -= dt
	if lamp_timer <= 0.0:
		lamp_timer = 0.5
		var list := lanterns.duplicate()
		var ct := cam_target
		list.sort_custom(func(a, b): return Vector2(a.x - ct.x, a.z - ct.z).length_squared() < Vector2(b.x - ct.x, b.z - ct.z).length_squared())
		for i in lamp_lights.size():
			var l: OmniLight3D = lamp_lights[i]
			l.position = Vector3(list[i].x + 0.5, 1.5, list[i].z + 0.5) if i < list.size() else Vector3(0, -50, 0)
	for l in lamp_lights:
		l.light_energy = night_f * 1.4

func _find_door(n: Node) -> Node3D:
	if n.has_meta("door"):
		return n
	for c in n.get_children():
		var f := _find_door(c)
		if f != null:
			return f
	return null

## Çiftçi yaklaşınca kapılar ondan uzağa doğru açılır, uzaklaşınca kapanır.
func _update_gates(dt: float) -> void:
	var fp := farmer.global_position
	var k := 1.0 - exp(-dt * 7.0)
	for e in entities:
		if e.get("type", "") != "gate":
			continue
		if not e.has("door") or not is_instance_valid(e.door):
			e.door = _find_door(e.group)
			if e.door == null:
				continue
		var dr: Node3D = e.door
		var par: Node3D = dr.get_parent()
		var near := Vector2(fp.x - par.global_position.x, fp.z - par.global_position.z).length() < 1.5
		var target := 0.0
		if near:
			if absf(dr.rotation.y) < 0.05:
				dr.set_meta("side", -1.0 if par.to_local(fp).z < 0.0 else 1.0)
			target = 1.75 * float(dr.get_meta("side", 1.0))
		dr.rotation.y = lerpf(dr.rotation.y, target, k)
	for h in entrance_doors:
		if not is_instance_valid(h):
			continue
		var hd: Node3D = h
		var near := Vector2(fp.x, fp.z - hd.global_position.z).length() < 2.6
		var target := 0.0
		if near:
			if absf(hd.rotation.y) < 0.05:
				hd.set_meta("side", -1.0 if fp.z < hd.global_position.z else 1.0)
			target = 1.6 * float(hd.get_meta("side", 1.0)) * float(hd.get_meta("sx"))
		hd.rotation.y = lerpf(hd.rotation.y, target, k)

func _animate_world(dt: float) -> void:
	clock_t += dt
	var blades: Node3D = windmill.get_meta("blades")
	mill_spin = move_toward(mill_spin, 0.0, dt * 1.5)
	blades.rotation.z += dt * (0.8 + mill_spin)
	for c in clouds:
		c.position.x += dt * 0.6
		if c.position.x > 65.0:
			c.position.x = -65.0
	for e in entities:
		if e.kind == "pond" and e.ready:
			e.icon.position.y = 0.9 + absf(sin(clock_t * 3.0 + e.x)) * 0.25
			continue
		if e.kind != "animal":
			continue
		var w = e.wander
		var m: Node3D = e.model
		var head = m.get_meta("head") if m.has_meta("head") else null
		if w.wait > 0.0:
			w.wait -= dt
			if head != null:
				head.rotation.x = maxf(0.0, sin(clock_t * 6.0 + w.phase)) * 0.6 if e.type == "chicken" else sin(clock_t * 1.5 + w.phase) * 0.12
			if w.wait <= 0.0:
				w.tx = randf_range(-0.35, 0.35)
				w.tz = randf_range(-0.35, 0.35)
				_animal_anim(m, true)
		else:
			var dx: float = w.tx - w.x
			var dz: float = w.tz - w.z
			var d := Vector2(dx, dz).length()
			if d < 0.02:
				w.wait = 1.0 + randf() * 3.0
				_animal_anim(m, false)
			else:
				var s := minf(d, dt * 0.45)
				w.x += dx / d * s
				w.z += dz / d * s
				m.rotation.y = atan2(dx, dz)
				m.position.y = absf(sin(clock_t * 12.0)) * 0.03
		m.position.x = w.x
		m.position.z = w.z
		if e.get("hop_t", 0.0) > 0.0:
			e.hop_t -= dt
			m.position.y = absf(sin(e.hop_t * 11.0)) * 0.22 * minf(1.0, e.hop_t)
			if head != null:
				head.rotation.x = maxf(0.0, sin(clock_t * 14.0)) * 0.7
		if e.ready:
			e.icon.position.y = 1.35 + sin(clock_t * 3.0 + w.phase) * 0.08
			e.icon.rotation.y += dt * 1.5
		elif e.hungry_lbl.visible:
			e.hungry_lbl.position.y = 1.0 + absf(sin(clock_t * 2.5 + w.phase)) * 0.12

func _animal_anim(m: Node3D, walking: bool) -> void:
	if not m.has_meta("anim"):
		return
	var ap: AnimationPlayer = m.get_meta("anim")
	var walk: String = m.get_meta("walk", "")
	var target: String = walk if walking and walk != "" else m.get_meta("idle", "")
	if target != "" and ap.current_animation != target:
		ap.play(target, 0.25)

# ============================================================ arayüz
func _sb(bg: Color, r := 16, border := Color(0, 0, 0, 0), bw := 0, pad := 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(r)
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_content_margin_all(pad)
	s.anti_aliasing = true
	return s

func _card() -> StyleBoxFlat:
	var s := _sb(Color("#fffaeef0"), 18, Color.WHITE, 2, 8)
	s.shadow_color = Color(0.29, 0.2, 0.14, 0.25)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 4)
	return s

func _panel(pad := 8) -> PanelContainer:
	var p := PanelContainer.new()
	var s := _card()
	s.set_content_margin_all(pad)
	p.add_theme_stylebox_override("panel", s)
	return p

func _btn_styles(b: Button, normal: Color, hover: Color, border := Color(0, 0, 0, 0), bw := 0) -> void:
	b.add_theme_stylebox_override("normal", _sb(normal, 14, border, bw, 4))
	b.add_theme_stylebox_override("hover", _sb(hover, 14, border, bw, 4))
	b.add_theme_stylebox_override("pressed", _sb(hover.darkened(0.08), 14, border, bw, 4))
	b.add_theme_stylebox_override("disabled", _sb(normal, 14, border, bw, 4))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font = font
	th.default_font_size = 15
	th.set_color("font_color", "Label", Color("#4a3424"))
	th.set_color("font_color", "Button", Color("#4a3424"))
	th.set_color("font_hover_color", "Button", Color("#4a3424"))
	th.set_color("font_pressed_color", "Button", Color("#4a3424"))
	th.set_color("font_disabled_color", "Button", Color("#4a3424"))
	ui.theme = th
	layer.add_child(ui)

	# --- üst bar
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 12
	top.offset_top = 12
	top.offset_right = -12
	top.add_theme_constant_override("separation", 10)
	ui.add_child(top)

	var stats := _panel(8)
	top.add_child(stats)
	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", 12)
	stats.add_child(sh)
	var badge := PanelContainer.new()
	var bs := _sb(Color("#f4b400"), 23, Color.WHITE, 3, 0)
	bs.shadow_color = Color("#c78f00")
	bs.shadow_size = 0
	badge.add_theme_stylebox_override("panel", bs)
	badge.custom_minimum_size = Vector2(46, 46)
	lbl_level = Label.new()
	lbl_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_level.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_level.add_theme_font_size_override("font_size", 20)
	lbl_level.add_theme_color_override("font_color", Color("#6b4200"))
	badge.add_child(lbl_level)
	sh.add_child(badge)
	var xv := VBoxContainer.new()
	xv.alignment = BoxContainer.ALIGNMENT_CENTER
	sh.add_child(xv)
	lbl_xp = Label.new()
	lbl_xp.add_theme_font_size_override("font_size", 12)
	lbl_xp.add_theme_color_override("font_color", Color("#8a7260"))
	xv.add_child(lbl_xp)
	bar_xp = ProgressBar.new()
	bar_xp.show_percentage = false
	bar_xp.custom_minimum_size = Vector2(140, 10)
	bar_xp.add_theme_stylebox_override("background", _sb(Color("#eadcc6"), 6, Color(0, 0, 0, 0), 0, 0))
	bar_xp.add_theme_stylebox_override("fill", _sb(Color("#5cbf2f"), 6, Color(0, 0, 0, 0), 0, 0))
	xv.add_child(bar_xp)
	sh.add_child(VSeparator.new())
	lbl_coins = Label.new()
	lbl_coins.custom_minimum_size = Vector2(100, 0)
	lbl_coins.add_theme_font_size_override("font_size", 21)
	lbl_coins.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sh.add_child(lbl_coins)
	lbl_medals = Label.new()
	lbl_medals.add_theme_font_size_override("font_size", 21)
	lbl_medals.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sh.add_child(lbl_medals)
	lbl_gems = Label.new()
	lbl_gems.add_theme_font_size_override("font_size", 21)
	lbl_gems.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sh.add_child(lbl_gems)

	var clockp := _panel(12)
	top.add_child(clockp)
	lbl_clock = Label.new()
	clockp.add_child(lbl_clock)

	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)

	var acts := _panel(6)
	top.add_child(acts)
	var ah := HBoxContainer.new()
	acts.add_child(ah)
	btn_sound = _icon_btn("🔊", "Ses aç/kapa")
	btn_sound.pressed.connect(func():
		muted = not muted
		btn_sound.text = "🔇" if muted else "🔊")
	ah.add_child(btn_sound)
	var bemo := _icon_btn("😄", "Emote: arkadaşına el salla, gül, kalp gönder  [G]")
	bemo.pressed.connect(_toggle_emote_bar)
	ah.add_child(bemo)
	var bland := _icon_btn("🗺️", "Arazi: çiftliği genişlet  [L]")
	bland.pressed.connect(_open_land)
	ah.add_child(bland)
	var bset := _icon_btn("⚙️", "Ayarlar: grafik, ses, tam ekran  (F11 tam ekran)")
	bset.pressed.connect(_open_settings)
	ah.add_child(bset)
	var bb := _icon_btn("📦", "Ambar  [B]")
	bb.pressed.connect(_open_barn)
	ah.add_child(bb)
	var bh := _icon_btn("❔", "Yardım")
	bh.pressed.connect(func(): help.visible = not help.visible)
	ah.add_child(bh)
	var bn := _icon_btn("📡", "Çiftliğini paylaş / oyuncular")
	bn.pressed.connect(func():
		if net_role == "":
			_net_host()
		else:
			_show_net_dlg())
	ah.add_child(bn)
	var br := _icon_btn("🏠", "Ana menü (kaydeder)")
	br.pressed.connect(func():
		_save()
		if net_role == "guest":
			_net_leave("")
			return
		_net_close()
		_show_menu())
	ah.add_child(br)

	# --- alt: raf + alet çubuğu
	var bottom := VBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.anchor_left = 0.5
	bottom.anchor_right = 0.5
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_bottom = -12
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.add_theme_constant_override("separation", 8)
	ui.add_child(bottom)

	lbl_queue = Label.new()
	lbl_queue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_queue.add_theme_color_override("font_color", Color.WHITE)
	lbl_queue.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	lbl_queue.add_theme_constant_override("outline_size", 4)
	bottom.add_child(lbl_queue)

	shelf_panel = _panel(14)
	shelf_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bottom.add_child(shelf_panel)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 10)
	shelf_panel.add_child(sv)
	var shd := HBoxContainer.new()
	sv.add_child(shd)
	shelf_title = Label.new()
	shelf_title.add_theme_font_size_override("font_size", 19)
	shelf_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shd.add_child(shelf_title)
	var sx_btn := _small_btn("✕", func():
		shelf_open = false
		_render_shelf())
	sx_btn.custom_minimum_size = Vector2(32, 30)
	sx_btn.tooltip_text = "Kapat  [Esc]"
	shd.add_child(sx_btn)
	shelf_box = GridContainer.new()
	shelf_box.columns = SHELF_COLS
	shelf_box.add_theme_constant_override("h_separation", 8)
	shelf_box.add_theme_constant_override("v_separation", 8)
	sv.add_child(shelf_box)
	shelf_nav = HBoxContainer.new()
	shelf_nav.alignment = BoxContainer.ALIGNMENT_CENTER
	shelf_nav.add_theme_constant_override("separation", 14)
	sv.add_child(shelf_nav)

	_build_wheel()

	# --- ipucu
	tip_panel = PanelContainer.new()
	tip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_panel.add_theme_stylebox_override("panel", _sb(Color(0.18, 0.12, 0.08, 0.92), 10, Color(0, 0, 0, 0), 0, 9))
	tip_label = Label.new()
	tip_label.add_theme_color_override("font_color", Color.WHITE)
	tip_label.add_theme_font_size_override("font_size", 14)
	tip_panel.add_child(tip_label)
	tip_panel.visible = false
	ui.add_child(tip_panel)

	# --- bildirimler
	toasts = VBoxContainer.new()
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toasts.anchor_left = 0.5
	toasts.anchor_right = 0.5
	toasts.offset_top = 84
	toasts.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	toasts.add_theme_constant_override("separation", 6)
	ui.add_child(toasts)

	# --- yardım: tam ekran sayfa, solda bölümler, sağda maddeler
	help = ColorRect.new()
	help.color = Color(0.1, 0.16, 0.07, 0.75)
	help.set_anchors_preset(Control.PRESET_FULL_RECT)
	help.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(help)
	var hm := MarginContainer.new()
	hm.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		hm.add_theme_constant_override("margin_" + side, 40)
	help.add_child(hm)
	var hp := _panel(24)
	hm.add_child(hp)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 14)
	hp.add_child(hv)
	var htop := HBoxContainer.new()
	hv.add_child(htop)
	var h1 := Label.new()
	h1.text = "🌾 Nasıl Oynanır?"
	h1.add_theme_font_size_override("font_size", 28)
	h1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	htop.add_child(h1)
	var go := Button.new()
	go.text = "Başlayalım!"
	go.focus_mode = Control.FOCUS_NONE
	go.custom_minimum_size = Vector2(170, 42)
	go.add_theme_font_size_override("font_size", 17)
	go.add_theme_color_override("font_color", Color.WHITE)
	go.add_theme_color_override("font_hover_color", Color.WHITE)
	go.add_theme_color_override("font_pressed_color", Color.WHITE)
	_btn_styles(go, Color("#6fbf3b"), Color("#7fcf4b"))
	go.pressed.connect(func(): help.visible = false)
	htop.add_child(go)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 20)
	hv.add_child(row)
	var tabs := VBoxContainer.new()
	tabs.custom_minimum_size = Vector2(210, 0)
	tabs.add_theme_constant_override("separation", 6)
	row.add_child(tabs)
	var sc := ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(sc)
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 12)
	sc.add_child(page)
	var tab_btns := []
	for i in HELP_PAGES.size():
		var b := Button.new()
		b.text = HELP_PAGES[i][0]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 44)
		b.add_theme_font_size_override("font_size", 17)
		tabs.add_child(b)
		tab_btns.append(b)
	var show_page := func(idx: int) -> void:
		for c in page.get_children():
			c.queue_free()
		for j in tab_btns.size():
			var on: bool = j == idx
			_btn_styles(tab_btns[j], Color("#6fbf3b") if on else Color(1, 1, 1, 0.55), Color("#7fcf4b") if on else Color(1, 1, 1, 0.85))
			var fc := Color.WHITE if on else Color("#4a3b2a")
			for st in ["font_color", "font_hover_color", "font_pressed_color"]:
				tab_btns[j].add_theme_color_override(st, fc)
		for item in HELP_PAGES[idx][1]:
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 12)
			var ic := Label.new()
			ic.text = item[0]
			ic.custom_minimum_size = Vector2(120 if item[0].length() > 3 else 40, 0)
			ic.add_theme_font_size_override("font_size", 18 if item[0].length() > 3 else 24)
			ic.vertical_alignment = VERTICAL_ALIGNMENT_TOP
			line.add_child(ic)
			var tx := Label.new()
			tx.text = item[1]
			tx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			tx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tx.add_theme_font_size_override("font_size", 17)
			line.add_child(tx)
			page.add_child(line)
			page.add_child(HSeparator.new())
		sc.scroll_vertical = 0
	for i in tab_btns.size():
		var idx := i
		tab_btns[i].pressed.connect(func(): show_page.call(idx))
	show_page.call(0)
	help.visible = false
	_build_barn_ui()
	_build_quest_ui()
	_build_land_ui()

func _round_style(b: Button, bg: Color, hover: Color, r: int, border := Color.WHITE, bw := 3) -> void:
	for st in [["normal", bg], ["hover", hover], ["pressed", hover.darkened(0.08)], ["disabled", bg]]:
		var sb := _sb(st[1], r, border, bw, 2)
		sb.shadow_color = Color(0.2, 0.14, 0.08, 0.3)
		sb.shadow_size = 5
		sb.shadow_offset = Vector2(0, 3)
		b.add_theme_stylebox_override(st[0], sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

## Çark menü: sağ altta 🎒 düğmesi; açılınca aletler imlecin çevresinde daire olur.
func _build_wheel() -> void:
	wheel_btn = Button.new()
	wheel_btn.focus_mode = Control.FOCUS_NONE
	wheel_btn.custom_minimum_size = Vector2(92, 92)
	wheel_btn.size = Vector2(92, 92)
	wheel_btn.anchor_left = 1.0
	wheel_btn.anchor_right = 1.0
	wheel_btn.anchor_top = 1.0
	wheel_btn.anchor_bottom = 1.0
	wheel_btn.offset_left = -112
	wheel_btn.offset_right = -20
	wheel_btn.offset_top = -112
	wheel_btn.offset_bottom = -20
	wheel_btn.add_theme_font_size_override("font_size", 15)
	wheel_btn.tooltip_text = "Aletler  [Tab]"
	_round_style(wheel_btn, Color("#6fbf3b"), Color("#7fcf4b"), 46, Color.WHITE, 4)
	for st in ["font_color", "font_hover_color", "font_pressed_color"]:
		wheel_btn.add_theme_color_override(st, Color.WHITE)
	wheel_btn.pressed.connect(func(): _open_wheel(wheel_btn.global_position + wheel_btn.size / 2.0))
	ui.add_child(wheel_btn)
	var bag := Label.new()
	bag.text = "🎒"
	bag.add_theme_font_size_override("font_size", 22)
	bag.position = Vector2(-6, -8)
	bag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wheel_btn.add_child(bag)

	wheel = ColorRect.new()
	wheel.color = Color(0.05, 0.08, 0.03, 0.28)
	wheel.set_anchors_preset(Control.PRESET_FULL_RECT)
	wheel.mouse_filter = Control.MOUSE_FILTER_STOP
	wheel.visible = false
	wheel.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			_close_wheel())
	ui.add_child(wheel)
	var hub := PanelContainer.new()
	hub.name = "hub"
	hub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hs := _sb(Color("#fffaee"), 64, Color("#e7d7bf"), 3, 10)
	hs.shadow_color = Color(0.2, 0.14, 0.08, 0.3)
	hs.shadow_size = 8
	hub.add_theme_stylebox_override("panel", hs)
	hub.custom_minimum_size = Vector2(128, 128)
	hub.size = Vector2(128, 128)
	wheel.add_child(hub)
	wheel_info = Label.new()
	wheel_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wheel_info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wheel_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wheel_info.custom_minimum_size = Vector2(108, 0)
	wheel_info.add_theme_font_size_override("font_size", 13)
	hub.add_child(wheel_info)
	for i in TOOLS.size():
		var t = TOOLS[i]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(84, 84)
		b.size = Vector2(84, 84)
		b.add_theme_font_size_override("font_size", 15)
		b.tooltip_text = "%s  [%d]" % [t.tip, (i + 1) % 10]
		var id: String = t.id
		var tip: String = "%s\n%s\n[%d]" % [t.icon, t.tip, (i + 1) % 10]
		b.mouse_entered.connect(func(): wheel_info.text = tip)
		b.mouse_exited.connect(func(): _wheel_info_default())
		b.pressed.connect(func():
			_close_wheel()
			_set_tool(id, id != "hand"))
		wheel.add_child(b)
		tool_buttons[id] = b

func _wheel_info_default() -> void:
	if wheel_info == null:
		return
	var t := ""
	for tt in TOOLS:
		if tt.id == tool:
			t = "%s %s" % [tt.icon, tt.name]
	wheel_info.text = "%s\n\nSeç ya da\nboşluğa tıkla" % t

func _open_wheel(at: Vector2) -> void:
	if shelf_open:
		shelf_open = false
		_render_shelf()
	var vs := ui.get_viewport_rect().size
	var rad := 150.0
	at.x = clampf(at.x, rad + 60.0, vs.x - rad - 60.0)
	at.y = clampf(at.y, rad + 60.0, vs.y - rad - 60.0)
	var hub: Control = wheel.get_node("hub")
	hub.position = at - hub.size / 2.0
	var n := TOOLS.size()
	for i in n:
		var b: Button = tool_buttons[TOOLS[i].id]
		var a := -PI / 2.0 + TAU * i / n
		var target := at + Vector2(cos(a), sin(a)) * rad - b.size / 2.0
		b.position = at - b.size / 2.0
		b.scale = Vector2(0.4, 0.4)
		b.pivot_offset = b.size / 2.0
		var tw := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "position", target, 0.18 + i * 0.012)
		tw.tween_property(b, "scale", Vector2.ONE, 0.18 + i * 0.012)
	_wheel_info_default()
	wheel.visible = true
	_sfx("click")

func _close_wheel() -> void:
	wheel.visible = false

func _icon_btn(icon: String, tip: String) -> Button:
	var b := Button.new()
	b.text = icon
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(40, 40)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 18)
	_btn_styles(b, Color(0, 0, 0, 0), Color("#f3e6cf"))
	return b

# ============================================================ yükleme, ana menü, kariyerler
func _build_loading() -> void:
	load_layer = CanvasLayer.new()
	load_layer.layer = 20
	add_child(load_layer)
	var bg := ColorRect.new()
	bg.color = Color("#8fd16a")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	load_layer.add_child(bg)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(cc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	cc.add_child(v)
	var t := Label.new()
	t.text = "🌾 Çiftliğim 3D"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_override("font", font)
	t.add_theme_font_size_override("font_size", 54)
	t.add_theme_color_override("font_color", Color.WHITE)
	t.add_theme_color_override("font_outline_color", Color("#4a7a2a"))
	t.add_theme_constant_override("outline_size", 12)
	v.add_child(t)
	var lv := Label.new()
	lv.text = "v%s · %s" % [_version(), CHANNEL]
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv.add_theme_font_size_override("font_size", 16)
	lv.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	v.add_child(lv)
	load_bar = ProgressBar.new()
	load_bar.custom_minimum_size = Vector2(380, 16)
	load_bar.show_percentage = false
	load_bar.max_value = 1.0
	load_bar.value = 0.1
	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color(1, 1, 1, 0.35)
	sb_bg.set_corner_radius_all(8)
	var sb_fill := StyleBoxFlat.new()
	sb_fill.bg_color = Color("#fff3c4")
	sb_fill.set_corner_radius_all(8)
	load_bar.add_theme_stylebox_override("background", sb_bg)
	load_bar.add_theme_stylebox_override("fill", sb_fill)
	v.add_child(load_bar)
	var tips := ["İpucu: Sulanan toprak bir süre ıslak kalır.", "İpucu: Kümes kur, tavuklar yumurtayı oraya bıraksın.", "İpucu: Orta tıkla sürükleyerek haritada gezebilirsin.", "İpucu: Görevler madalya ve elmas verir."]
	var tl := Label.new()
	tl.text = "Yükleniyor…\n" + tips[randi() % tips.size()]
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.add_theme_font_override("font", font)
	tl.add_theme_font_size_override("font_size", 16)
	tl.add_theme_color_override("font_color", Color("#2f5a17"))
	v.add_child(tl)

func _load_step(f: float) -> void:
	if load_bar != null:
		load_bar.value = f

func _finish_loading() -> void:
	var tw := create_tween()
	tw.tween_interval(0.15)
	tw.tween_property(load_layer.get_child(0), "modulate:a", 0.0, 0.5)
	tw.tween_callback(load_layer.queue_free)

static func _slot_path(n: int) -> String:
	return "user://career_%d.json" % n

func _slot_info(n: int) -> Dictionary:
	var pth := _slot_path(n)
	if not FileAccess.file_exists(pth):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(pth))
	if typeof(d) != TYPE_DICTIONARY:
		return {}
	return {"name": str(d.get("name", "Çiftliğim")), "level": int(d.get("level", 1)), "coins": int(d.get("coins", 0)),
		"day": int(d.get("day", 1)), "saved_at": float(d.get("saved_at", 0))}

func _last_slot() -> int:
	if FileAccess.file_exists(PROFILE):
		var d = JSON.parse_string(FileAccess.get_file_as_string(PROFILE))
		if typeof(d) == TYPE_DICTIONARY:
			var n := int(d.get("last", 0))
			if n >= 1 and n <= SLOTS and FileAccess.file_exists(_slot_path(n)):
				return n
	for n in range(1, SLOTS + 1):
		if FileAccess.file_exists(_slot_path(n)):
			return n
	return 0

func _set_last(n: int) -> void:
	_profile_set("last", str(n))

## Eski tek kayıt dosyası (save.json) ilk kariyer yuvasına taşınır.
func _migrate_old_save() -> void:
	if FileAccess.file_exists(OLD_SAVE) and not FileAccess.file_exists(_slot_path(1)):
		DirAccess.rename_absolute(ProjectSettings.globalize_path(OLD_SAVE), ProjectSettings.globalize_path(_slot_path(1)))
		_set_last(1)

func _show_story(i: int) -> void:
	if story_ui == null:
		story_ui = ColorRect.new()
		story_ui.color = Color(0.06, 0.09, 0.05, 0.82)
		story_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
		story_ui.mouse_filter = Control.MOUSE_FILTER_STOP
		ui.add_child(story_ui)
	for c in story_ui.get_children():
		c.queue_free()
	if i >= STORY_PAGES.size():
		story_ui.visible = false
		_render_quests()
		return
	story_ui.visible = true
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	story_ui.add_child(cc)
	var pn := _panel(30)
	pn.custom_minimum_size = Vector2(620, 0)
	cc.add_child(pn)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	pn.add_child(v)
	var pg: Array = STORY_PAGES[i]
	var ic := Label.new()
	ic.text = pg[0]
	ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ic.add_theme_font_size_override("font_size", 64)
	v.add_child(ic)
	var tl := Label.new()
	tl.text = pg[1]
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.add_theme_font_size_override("font_size", 26)
	v.add_child(tl)
	var tx := Label.new()
	tx.text = pg[2] % farm_name.to_upper() if pg[2].contains("%s") else pg[2]
	tx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tx.add_theme_font_size_override("font_size", 18)
	v.add_child(tx)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var dots := Label.new()
	var dt := ""
	for k in STORY_PAGES.size():
		dt += "● " if k == i else "○ "
	dots.text = dt
	dots.add_theme_color_override("font_color", Color("#a0731b"))
	row.add_child(dots)
	var last := i == STORY_PAGES.size() - 1
	if not last:
		var sk := _small_btn("Geç", func(): _show_story(STORY_PAGES.size()))
		sk.custom_minimum_size = Vector2(80, 40)
		row.add_child(sk)
	var go := Button.new()
	go.text = "Çiftliğe git!" if last else "İleri  ▶"
	go.focus_mode = Control.FOCUS_NONE
	go.custom_minimum_size = Vector2(170, 44)
	go.add_theme_font_size_override("font_size", 17)
	for st in ["font_color", "font_hover_color", "font_pressed_color"]:
		go.add_theme_color_override(st, Color.WHITE)
	_btn_styles(go, Color("#6fbf3b"), Color("#7fcf4b"))
	go.pressed.connect(func(): _show_story(i + 1))
	row.add_child(go)

# ============================================================ online (ENet, ev sahibi yetkili)
func _profile_get(k: String, def: String) -> String:
	if not FileAccess.file_exists(PROFILE):
		return def
	var d = JSON.parse_string(FileAccess.get_file_as_string(PROFILE))
	return str(d.get(k, def)) if typeof(d) == TYPE_DICTIONARY else def

func _profile_set(k: String, v: String) -> void:
	var dev_args := OS.get_cmdline_user_args()
	if dev_args.has("--selftest") or (dev_args.has("--fresh") and k != "last"):
		return
	var d := {}
	if FileAccess.file_exists(PROFILE):
		var r = JSON.parse_string(FileAccess.get_file_as_string(PROFILE))
		if typeof(r) == TYPE_DICTIONARY:
			d = r
	d[k] = v
	var f := FileAccess.open(PROFILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))

func _net_signals() -> void:
	var mp := multiplayer
	for pair in [[mp.peer_connected, _on_peer_connected], [mp.peer_disconnected, _on_peer_disconnected],
			[mp.server_disconnected, _on_server_lost], [mp.connected_to_server, _on_net_connected], [mp.connection_failed, _on_net_failed]]:
		if not pair[0].is_connected(pair[1]):
			pair[0].connect(pair[1])

func _local_ips() -> Array:
	var out := []
	for a in IP.get_local_addresses():
		if a.contains(".") and not a.begins_with("127.") and not a.begins_with("169.254."):
			out.append(a + _ip_kind(a))
	return out

## Adresin hangi ağa ait olduğu (sanal ağ adresleri arkadaşa verilecek olanlardır).
static func _ip_kind(a: String) -> String:
	var p := a.split(".")
	var b0 := int(p[0])
	var b1 := int(p[1]) if p.size() > 1 else 0
	if b0 == 25:
		return "   ← Hamachi"
	if b0 == 100 and b1 >= 64 and b1 <= 127:
		return "   ← Tailscale"
	if b0 == 192 and b1 == 168 or b0 == 10 or (b0 == 172 and b1 >= 16 and b1 <= 31):
		return "   (ev ağı)"
	return ""

func _net_host() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(_net_port(), 4)
	if err != OK:
		_toast("📡 Paylaşım açılamadı (port %d kullanımda olabilir)." % NET_PORT, "warn")
		return
	multiplayer.multiplayer_peer = peer
	net_role = "host"
	player_name = _profile_get("player", "Çiftçi")
	_net_signals()
	_toast("📡 Çiftliğin paylaşıma açıldı!", "level")
	_show_net_dlg()

func _net_join(ip: String, nm: String) -> void:
	ip = ip.strip_edges()
	nm = nm.strip_edges()
	if nm == "":
		nm = "Çiftçi"
	if ip == "":
		if net_status != null:
			net_status.text = "Adres yaz."
		return
	_profile_set("last_ip", ip)
	_profile_set("player", nm)
	_net_close()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, _net_port())
	if err != OK:
		if net_status != null:
			net_status.text = "Bağlanılamadı."
		return
	multiplayer.multiplayer_peer = peer
	net_role = "joining"
	player_name = nm
	_net_signals()
	if net_status != null:
		net_status.text = "Bağlanıyor…"

func _net_close() -> void:
	for id in net_players.keys():
		_net_drop(id)
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	net_role = ""
	if net_dlg != null:
		net_dlg.visible = false

## Misafir ayrılır ya da bağlantı kopar: kendi oyununa döner.
func _net_leave(msg: String) -> void:
	_net_close()
	boot = {"net_msg": msg} if msg != "" else {}
	get_tree().reload_current_scene()

func _on_net_connected() -> void:
	if net_role == "joining":
		rpc_id(1, "net_hello", player_name)

func _on_net_failed() -> void:
	_net_close()
	if net_status != null:
		net_status.text = "❌ Bağlanılamadı. Adresi ve arkadaşının 📡 paylaşımını kontrol et.
Hamachi/sanal ağ kullanıyorsanız: çiftlik sahibinin bilgisayarında Windows Güvenlik Duvarı oyuna o ağda izin vermeli (Hamachi ağını \"Özel\" yapın)."

func _on_server_lost() -> void:
	if net_role == "guest":
		_net_leave("📡 Çiftlik sahibiyle bağlantı koptu.")
	else:
		_net_close()

func _on_peer_connected(_id: int) -> void:
	pass

func _on_peer_disconnected(id: int) -> void:
	if net_players.has(id):
		_toast("👋 %s ayrıldı." % net_players[id].name)
		_net_drop(id)
		_render_net_dlg()

@rpc("any_peer", "reliable")
func net_hello(nm: String) -> void:
	if net_role != "host":
		return
	var id := multiplayer.get_remote_sender_id()
	rpc_id(id, "net_welcome", JSON.stringify(_state_dict()))

@rpc("authority", "reliable")
func net_welcome(state: String) -> void:
	if net_role != "joining":
		return
	boot = {"net_state": state, "player": player_name}
	get_tree().reload_current_scene()

@rpc("any_peer", "reliable")
func net_ready(nm: String) -> void:
	if net_role != "host":
		return
	var id := multiplayer.get_remote_sender_id()
	_net_spawn(id, nm.left(14))
	_toast("👋 %s çiftliğine geldi!" % nm.left(14), "level")
	_net_roster()
	_render_net_dlg()
	net_sync_t = 99.0

func _net_roster() -> void:
	var r := {1: player_name}
	for id in net_players:
		r[id] = net_players[id].name
	rpc("net_roster", r)

@rpc("authority", "reliable")
func net_roster(r: Dictionary) -> void:
	var me := multiplayer.get_unique_id()
	for id in r:
		if int(id) != me and not net_players.has(int(id)):
			_net_spawn(int(id), str(r[id]))
	for id in net_players.keys():
		if not r.has(id):
			_net_drop(id)

func _net_spawn(id: int, nm: String) -> void:
	if net_players.has(id):
		return
	var m := Models.farmer(NET_COLORS[absi(id) % NET_COLORS.size()])
	add_child(m)
	m.position = Vector3(0.5, 0, farm_h + 0.5)
	var l := Label3D.new()
	l.text = nm
	l.font = font
	l.font_size = 48
	l.pixel_size = 0.006
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.outline_size = 10
	l.position.y = 2.0
	m.add_child(l)
	var pp: Dictionary = m.get_meta("parts")
	for pr in ["hoe", "can", "bag", "basket"]:
		pp[pr].visible = false
	net_players[id] = {"name": nm, "node": m, "parts": pp, "tp": m.position, "ry": 0.0, "mv": false, "act_t": 0.0, "ph": 0.0}

func _net_drop(id) -> void:
	if net_players.has(id):
		if is_instance_valid(net_players[id].node):
			net_players[id].node.queue_free()
		net_players.erase(id)

@rpc("any_peer", "unreliable_ordered")
func net_pos(x: float, z: float, ry: float, mv: bool) -> void:
	var id := multiplayer.get_remote_sender_id()
	if net_players.has(id):
		var p: Dictionary = net_players[id]
		p.tp = Vector3(x, 0, z)
		p.ry = ry
		p.mv = mv

@rpc("any_peer", "reliable")
func net_req(t: String, a: String, x: int, z: int) -> void:
	if net_role != "host":
		return
	if t == "@skip":   # misafir görev silmek istedi: ev sahibinin kurallarıyla (ücretsiz hak / elmas)
		if x >= 0 and x < quests.size():
			_skip_quest(x)
		return
	if t == "@sell":   # misafir ambardan sattı
		_sell(a, x)
		net_quest_dirty = true
		return
	if t == "@deliver":
		_deliver()
		net_quest_dirty = true
		return
	if t == "@bake":
		_bake_finish(a, x)
		return
	if t == "@mill":   # misafir öğüttü: x isabet, z mükemmel
		_mill_finish(x, z)
		return
	if t == "@fishbuy":
		_fish_buy(a)
		return
	if t == "@bait":
		if a == "2":
			fishgear.bait2 = maxi(0, int(fishgear.bait2) - 1)
		else:
			fishgear.bait = maxi(0, int(fishgear.bait) - 1)
		net_quest_dirty = true
		return
	if t == "@fish":
		if not _fish_def(a).is_empty():
			_fish_reward(a, clampf(x / 10.0, 0.1, 25.0))
			if net_players.has(multiplayer.get_remote_sender_id()):
				_toast("🎣 %s %s yakaladı!" % [net_players[multiplayer.get_remote_sender_id()].name, _fish_def(a).name], "hint")
		return
	if t == "@emote":
		var sid := multiplayer.get_remote_sender_id()
		if net_players.has(sid):
			_show_emote(net_players[sid].node, int(a))
		rpc("net_do", "@emote", a, 0, 0, sid)
		return
	var id := multiplayer.get_remote_sender_id()
	net_actor = id
	net_applying = true
	_perform({"tool": t, "arg": null if a == "" else a, "x": x, "z": z})
	net_applying = false
	net_actor = 1
	if net_players.has(id):
		net_players[id].act_t = 0.5

@rpc("authority", "reliable")
func net_do(t: String, a: String, x: int, z: int, actor: int, msg := "") -> void:
	if net_role != "guest":
		return
	if t == "@toast":
		_toast(msg, a)
		return
	if t == "@emote":
		if actor != multiplayer.get_unique_id() and net_players.has(actor):
			_show_emote(net_players[actor].node, int(a))
		return
	var keep := coins
	coins = 1 << 30
	net_applying = true
	_perform_local({"tool": t, "arg": null if a == "" else a, "x": x, "z": z})
	net_applying = false
	coins = keep
	if net_players.has(actor):
		net_players[actor].act_t = 0.5
	hud_dirty = true

## Ortak görevler: hikâye adımı, günlük görevler, madalya ve elmas ev sahibinde tutulur.
func _net_quest_dict() -> Dictionary:
	return {"quests": quests, "story": story_step, "sh": story_have, "medals": medals, "gems": gems}

## Görev paketi net_sync içinde gelir (ayrı RPC yok: yeni RPC'ler süreçler arası sırayı bozuyor).
func net_quests(d: Dictionary) -> void:
	if net_role != "guest":
		return
	var ql := []
	for q in d.get("quests", []):
		if typeof(q) == TYPE_DICTIONARY and q.has("kind"):
			ql.append({"kind": str(q.kind), "arg": str(q.get("arg", "")), "text": str(q.get("text", "")),
				"need": int(q.need), "have": int(q.get("have", 0)), "medals": int(q.medals), "gems": int(q.gems), "xp": int(q.xp)})
	var st := clampi(int(d.get("story", STORY.size())), 0, STORY.size())
	var sh := int(d.get("sh", 0))
	medals = int(d.get("medals", medals))
	gems = int(d.get("gems", gems))
	hud_dirty = true
	if ql != quests or st != story_step or sh != story_have:
		quests = ql
		story_step = st
		story_have = sh
		_render_quests()

## Ev sahibinde: herkese duyur (görev tamamlandı vb.). Duyuru net_do kanalıyla gider.
func _toast_all(msg: String, kind := "") -> void:
	_toast(msg, kind)
	if net_role == "host" and multiplayer.get_peers().size() > 0:
		rpc("net_do", "@toast", kind, 0, 0, 1, msg)

## Ev sahibinden misafirlere: para, zaman, hava ve tüm varlıkların durumu.
func _net_sync_dict() -> Dictionary:
	var ents := []
	for e in entities:
		ents.append(_ent_dict(e))
	return {"coins": coins, "xp": xp, "level": level, "day_time": day_time, "day": day, "season": season, "season_t": season_t,
		"year": year, "weather": weather, "weather_t": weather_t, "fh": farm_h, "res": res, "ents": ents, "q": _net_quest_dict(), "order": order, "fg": fishgear}

@rpc("authority", "reliable")
func net_sync(d: Dictionary) -> void:
	if net_role != "guest":
		return
	coins = int(d.coins)
	xp = int(d.xp)
	level = int(d.level)
	day_time = float(d.day_time)
	day = int(d.day)
	year = int(d.year)
	season_t = float(d.season_t)
	if int(d.season) != season:
		season = int(d.season)
		_apply_season_visual(false)
	weather_t = float(d.weather_t)
	if str(d.weather) != weather:
		if str(d.weather) == "":
			_end_weather()
		else:
			_start_weather(str(d.weather))
	res = d.res
	if int(d.get("fh", farm_h)) != farm_h:
		farm_h = int(d.fh)
		_on_farm_resized()
	_net_apply_ents(d.ents)
	if d.has("q"):
		net_quests(d.q)
	if d.has("order") and typeof(d.order) == TYPE_DICTIONARY:
		order = d.order
	if d.has("fg"):
		var use2 := bool(fishgear.use2)
		_load_fishgear(d.fg)
		fishgear.use2 = use2   # yem seçimi her oyuncunun kendisinde
		if shop_open and land_dlg.visible:
			_open_fish_shop()
	if barn != null and barn.visible:
		_render_barn()
	hud_dirty = true

func _vis_sig(e: Dictionary) -> String:
	match e.kind:
		"plot": return "%s|%d|%s" % [e.crop, crop_stage(e) if e.crop != null else -1, _wet(e)]
		"tree": return "%s|%s" % [e.age >= 1.0, e.has_fruit]
		"animal": return "%s|%s" % [e.ready, e.food > 0.0]
		"flower", "pond": return "%s|%d" % [e.ready, int(e.get("t", 0.0) * 3.0)]
		"coop": return str(e.eggs)
	return ""

func _net_apply_ents(list: Array) -> void:
	var seen := {}
	for s in list:
		var k := key(int(s.x), int(s.z))
		seen[k] = true
		var e = tiles.get(k)
		var base := _ent_base(s)
		if e != null and (e.kind != base.kind or e.get("type", "") != base.get("type", "") or e.x != base.x or e.z != base.z):
			_remove_entity(e)
			e = null
		if e == null:
			_add_entity(base)
			continue
		var before := _vis_sig(e)
		for f in base:
			if f != "rot":
				e[f] = base[f]
		if _vis_sig(e) != before:
			_refresh(e)
	for e in entities.duplicate():
		if not seen.has(key(e.x, e.z)):
			_remove_entity(e)

func _net_tick(dt: float) -> void:
	net_pos_t -= dt
	if net_pos_t <= 0.0 and multiplayer.get_peers().size() > 0:
		net_pos_t = 0.1
		rpc("net_pos", farmer.position.x, farmer.position.z, farmer.rotation.y, move_target != null or walk_phase != 0.0)
	if net_role == "host":
		net_sync_t += dt
		if net_sync_t > 3.0 and multiplayer.get_peers().size() > 0:
			net_sync_t = 0.0
			net_quest_dirty = false
			rpc("net_sync", _net_sync_dict())
		net_quest_t -= dt
		if net_quest_dirty and net_quest_t <= 0.0 and multiplayer.get_peers().size() > 0:
			net_quest_dirty = false
			net_quest_t = 1.0
			net_sync_t = 0.0
			rpc("net_sync", _net_sync_dict())
	for id in net_players:
		var p: Dictionary = net_players[id]
		var m: Node3D = p.node
		var to: Vector3 = p.tp
		var moving := Vector2(to.x - m.position.x, to.z - m.position.z).length() > 0.05
		m.position = m.position.lerp(Vector3(to.x, height_at(to.x, to.z), to.z), minf(1.0, dt * 10.0))
		m.rotation.y = lerp_angle(m.rotation.y, p.ry, minf(1.0, dt * 12.0))
		if moving:
			p.ph += dt * 11.0
		var sw := sin(p.ph) * 0.7 if moving else 0.0
		var pp: Dictionary = p.parts
		pp.leg_l.rotation.x = lerpf(pp.leg_l.rotation.x, sw, 0.3)
		pp.leg_r.rotation.x = lerpf(pp.leg_r.rotation.x, -sw, 0.3)
		pp.arm_l.rotation.x = lerpf(pp.arm_l.rotation.x, -sw * 0.8, 0.3)
		if p.act_t > 0.0:
			p.act_t -= dt
			pp.arm_r.rotation.x = -1.6 * sin((1.0 - p.act_t / 0.5) * PI)
		else:
			pp.arm_r.rotation.x = lerpf(pp.arm_r.rotation.x, sw * 0.8, 0.3)

func _show_net_dlg() -> void:
	if net_dlg == null:
		net_dlg = _panel(18)
		net_dlg.anchor_left = 0.5
		net_dlg.anchor_right = 0.5
		net_dlg.anchor_top = 0.5
		net_dlg.anchor_bottom = 0.5
		net_dlg.grow_horizontal = Control.GROW_DIRECTION_BOTH
		net_dlg.grow_vertical = Control.GROW_DIRECTION_BOTH
		net_dlg.custom_minimum_size = Vector2(440, 0)
		ui.add_child(net_dlg)
		net_box = VBoxContainer.new()
		net_box.add_theme_constant_override("separation", 10)
		net_dlg.add_child(net_box)
	net_dlg.visible = true
	_render_net_dlg()

func _render_net_dlg() -> void:
	if net_dlg == null or not net_dlg.visible:
		return
	for c in net_box.get_children():
		c.queue_free()
	var t := Label.new()
	t.text = "📡 Çiftlik paylaşımı" if net_role == "host" else "🤝 Misafirsin"
	t.add_theme_font_size_override("font_size", 22)
	net_box.add_child(t)
	var b := Label.new()
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if net_role == "host":
		var ips := _local_ips()
		b.text = "Arkadaşın ana menüde 🤝 Arkadaşa Katıl'a basıp şu adresi yazsın:\n\n   %s\n\nAynı ağda (ev Wi-Fi'ı) ev ağı adresiyle çalışır. Uzaktan: ikiniz de Hamachi/Tailscale/ZeroTier'a girin ve arkadaşın sanal ağ adresini yazsın; ya da modemde %d (UDP) portunu açın.

Bağlanamıyorsa: bu bilgisayarda Windows Güvenlik Duvarı oyuna yalnız \"Özel\" ağlarda izin veriyor olabilir; Hamachi ağını Özel yapın." % [("\n   ".join(ips)) if ips.size() > 0 else "(ağ bulunamadı)", NET_PORT]
	else:
		b.text = "Çiftlik sahibinin dünyasındasın. Ekip biçebilir, sulayabilir, yemleyebilirsin; ambar ve arazi alımı sahibinde."
	net_box.add_child(b)
	var pl := Label.new()
	var names := ["🧑‍🌾 %s (sen)" % player_name]
	for id in net_players:
		names.append("🧑‍🌾 " + net_players[id].name)
	pl.text = "Oyuncular (%d):\n%s" % [names.size(), "\n".join(names)]
	net_box.add_child(pl)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	net_box.add_child(row)
	row.add_child(_small_btn("  Kapat  ", func(): net_dlg.visible = false))
	if net_role == "host":
		row.add_child(_small_btn("  Paylaşımı durdur  ", func():
			_net_close()
			_toast("📡 Paylaşım kapandı.")))

## İki süreçli ağ denemesi (misafir tarafı): çapala, ev sahibinden onay bekle.
var qok_sell_fail := false
func _net_host_probe() -> void:
	res["cereal"] = 10   # deneme: misafir 3 tanesini satacak
	if quests.size() > 0:   # deneme: misafirin çapası bu göreve sayılmalı
		quests[0] = {"kind": "plow", "arg": "", "text": "⛏️ Deneme: 5 kare sür", "need": 5, "have": 0, "medals": 1, "gems": 0, "xp": 1}
		_render_quests()
	var plots0 := entities.filter(func(e): return e.kind == "plot").size()
	var seen := 0
	for i in 170:
		await get_tree().create_timer(0.1).timeout
		seen = maxi(seen, net_players.size())
	var plots1 := entities.filter(func(e): return e.kind == "plot").size()
	if int(res.get("cereal", 0)) != 7: qok_sell_fail = true
	if int(fishgear.rod) != 1: qok_sell_fail = true
	var qok: bool = not qok_sell_fail and (quests.is_empty() or quests[0].kind != "plow" or quests[0].have == 1)
	print("NET HOST ", "OK" if plots1 == plots0 + 1 and seen == 1 and qok else "FAIL", " tarla %d→%d oyuncu=%d görev+satış=%s" % [plots0, plots1, seen, qok])
	get_tree().quit()

func _net_selftest() -> void:
	var fails := []
	var tx := 0
	var tz := 0
	for x in range(-10, 10):
		for z in range(-10, 10):
			if tx == 0 and tz == 0 and _resolve("plow", null, x, z) != null:
				tx = x
				tz = z
	await get_tree().create_timer(1.5).timeout
	if not net_players.has(1): fails.append("ev sahibi avatarı yok")
	if entities.size() < 10: fails.append("çiftlik yüklenmedi")
	if tiles.has(key(tx, tz)): fails.append("deneme karesi dolu")
	if quests.is_empty() and not _story_on(): fails.append("görevler misafire gelmedi")
	var qsig := str(quests) + str(story_have) + str(story_step)
	_perform({"tool": "plow", "arg": null, "x": tx, "z": tz})
	await get_tree().create_timer(2.0).timeout
	var e = tiles.get(key(tx, tz))
	if e == null or e.kind != "plot": fails.append("çapa ev sahibinden dönmedi")
	await get_tree().create_timer(3.5).timeout
	if coins <= 0: fails.append("senkron para yok")
	var c0 := coins
	if int(res.get("cereal", 0)) != 10: fails.append("ambar misafire gelmedi")
	_sell("cereal", 3)
	await get_tree().create_timer(2.5).timeout
	if int(res.get("cereal", 0)) != 7 or coins <= c0: fails.append("misafir satışı")
	if int(fishgear.rod) != 0: fails.append("olta baştan var")
	_fish_buy("rod1")
	_fish_reward("turna", 5.0)
	await get_tree().create_timer(2.0).timeout
	if int(fishgear.rod) != 1: fails.append("misafirin oltası eşitlenmedi")
	var plow_q := false
	for q in quests:
		if q.kind == "plow":
			plow_q = true
	if plow_q and str(quests) + str(story_have) + str(story_step) == qsig: fails.append("misafirin işi göreve sayılmadı")
	print("NET GUEST ", "OK" if fails.is_empty() else "FAIL: " + ", ".join(fails))
	_net_close()
	get_tree().quit()

func _start_play(show_help := false) -> void:
	playing = true
	menu_layer.visible = false
	ui.visible = true
	cam_follow = true
	cam_dist = 20.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cam="):
			cam_dist = float(a.substr(6))
	cam_target = farmer.position
	hud_dirty = true
	if slot > 0:
		_set_last(slot)
	_save()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pitch="):
			cam_pitch = float(a.substr(8))
		elif a.begins_with("--lookup="):
			look_up = float(a.substr(9))
		elif a.begins_with("--yaw="):
			cam_yaw = float(a.substr(6))
		elif a.begins_with("--at="):   # geliştirici: çiftçiyi x,z noktasına koy
			var xz := a.substr(5).split(",")
			farmer.position = Vector3(float(xz[0]), 0, float(xz[1]))
			cam_target = farmer.position
		elif a == "--land":   # geliştirici: arazi penceresini aç
			_open_land()
		elif a == "--settings":
			_open_settings()
	if (show_help and shot_path == "") or OS.get_cmdline_user_args().has("--showhelp"):
		help.visible = true

func _show_menu() -> void:
	playing = false
	_clear_queue()
	painting = false
	rotating = false
	panning = false
	ui.visible = false
	menu_layer.visible = true
	_render_menu("main")

static func _version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))

## a, b'den yeni mi? ("0.10.0" > "0.9.3")
static func _ver_newer(a: String, b: String) -> bool:
	var pa := a.split(".")
	var pb := b.split(".")
	for i in maxi(pa.size(), pb.size()):
		var x := int(pa[i]) if i < pa.size() else 0
		var y := int(pb[i]) if i < pb.size() else 0
		if x != y:
			return x > y
	return false

## Açılışta bir kez: adres ayarlıysa son sürümü sorar, yeniyse menüde duyurur. Adres boşsa ağa çıkmaz.
func _check_update() -> void:
	var url := str(ProjectSettings.get_setting("ciftlik/update_url", ""))
	var args := OS.get_cmdline_user_args()
	if url == "" or args.has("--selftest") or args.has("--fresh"):
		return
	var req := HTTPRequest.new()
	req.timeout = 8.0
	req.max_redirects = 4
	add_child(req)
	req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray):
		req.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			return
		var d = JSON.parse_string(body.get_string_from_utf8())
		if not d is Dictionary:
			return
		# kendi JSON'umuz ya da GitHub "releases/latest" yanıtı
		var ver := str(d.get("version", d.get("tag_name", ""))).trim_prefix("v")
		var notes := str(d.get("notes", d.get("name", "")))
		if _ver_newer(ver, _version()):
			update_info = {"version": ver, "url": str(d.get("url", d.get("html_url", ""))), "notes": notes.left(160)}
			if menu_layer.visible:
				_render_menu("main"))
	if req.request(url, ["User-Agent: Ciftligim3D", "Accept: application/vnd.github+json"]) != OK:
		req.queue_free()

# ============================================================ ayarlar
func _is_dev_run() -> bool:
	var a := OS.get_cmdline_user_args()
	return shot_path != "" or a.has("--selftest") or a.has("--fps") or a.has("--fresh") or DisplayServer.get_name() == "headless"

func _load_gfx() -> void:
	gfx = GFX_DEFAULT.duplicate()
	if not _is_dev_run():
		var d = JSON.parse_string(_profile_get("gfx", "{}"))
		if d is Dictionary:
			for k in d:
				if gfx.has(k):
					gfx[k] = d[k]
			if int(d.get("gv", 0)) < 2:   # 0.3.0: tam ekran varsayılan oldu
				gfx.fs = true
				gfx.gv = 2
	_apply_gfx(not _is_dev_run())

func _save_gfx() -> void:
	_profile_set("gfx", JSON.stringify(gfx))

## Ayarları uygular. window: pencere kipine de dokunsun mu (geliştirici çalıştırmalarında hayır).
func _apply_gfx(window := false) -> void:
	var q: int = clampi(int(gfx.q), 0, 3)
	var vp := get_viewport()
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_2X, Viewport.MSAA_4X][q]
	RenderingServer.directional_shadow_atlas_set_size([2048, 4096, 8192, 8192][q], true)
	RenderingServer.directional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_HIGH, RenderingServer.SHADOW_QUALITY_SOFT_ULTRA][q])
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if q == 0 else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = [28.0, 34.0, 40.0, 55.0][q]
	env.ssao_enabled = q >= 2
	env.glow_enabled = q >= 1
	env.ssr_enabled = q >= 2      # su ve parlak yüzeylerde gerçek yansıma
	env.ssr_max_steps = 48 if q == 2 else 80
	env.ssr_fade_in = 0.1
	env.ssr_fade_out = 1.5
	cam.far = [220.0, 320.0, 480.0, 480.0][q]
	grass_frac = [0.35, 0.65, 1.0, 1.0][q]
	for pc in grass_chunks:
		var gm: MultiMesh = grass_chunks[pc].multimesh
		gm.visible_instance_count = -1 if grass_frac >= 1.0 else int(gm.instance_count * grass_frac)
	var sc: float = clampf(float(gfx.scale) / 100.0, 0.5, 1.0)
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if sc < 1.0 else Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = sc
	Engine.max_fps = int(gfx.fps)
	if window:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if gfx.vs else DisplayServer.VSYNC_DISABLED)
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if gfx.fs else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want:
			DisplayServer.window_set_mode(want)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(gfx.vol) / 100.0, 0.0001)))
	for p in players:
		p.volume_db = linear_to_db(maxf(float(gfx.sfx) / 100.0, 0.0001))
	fps_lbl.visible = bool(gfx.showfps)

func _build_settings() -> void:
	set_layer = CanvasLayer.new()
	set_layer.layer = 12
	add_child(set_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = ui.theme
	set_layer.add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0.08, 0.12, 0.05, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(cc)
	var p := _panel(24)
	p.custom_minimum_size = Vector2(620, 0)
	cc.add_child(p)
	set_box = VBoxContainer.new()
	set_box.add_theme_constant_override("separation", 8)
	p.add_child(set_box)
	set_layer.visible = false
	fps_lbl = Label.new()
	fps_lbl.position = Vector2(12, 0)
	fps_lbl.anchor_top = 1.0
	fps_lbl.anchor_bottom = 1.0
	fps_lbl.offset_top = -30
	fps_lbl.add_theme_font_size_override("font_size", 14)
	fps_lbl.add_theme_color_override("font_color", Color.WHITE)
	fps_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	fps_lbl.add_theme_constant_override("outline_size", 5)
	fps_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fps_lbl.visible = false
	ui.add_child(fps_lbl)

func _open_settings() -> void:
	_render_settings()
	set_layer.visible = true
	_sfx("click")

func _set_gfx(k: String, v) -> void:
	gfx[k] = v
	_apply_gfx(k == "fs" or k == "vs")
	_save_gfx()
	_render_settings()

func _set_row(title: String, ctl: Control) -> void:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 10)
	var l := Label.new()
	l.text = title
	l.custom_minimum_size = Vector2(190, 0)
	r.add_child(l)
	ctl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(ctl)
	set_box.add_child(r)

## Yan yana seçenek düğmeleri; seçili olan yeşil.
func _seg(k: String, opts: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	for o in opts:
		var v = o[1]
		var b := _small_btn(" %s " % o[0], func(): _set_gfx(k, v), true, gfx[k] == v)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(b)
	return h

func _slider(k: String, lo: float, hi: float, unit := "%") -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 5
	s.value = float(gfx[k])
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_NONE
	var l := Label.new()
	l.text = "%d%s" % [int(s.value), unit]
	l.custom_minimum_size = Vector2(54, 0)
	s.value_changed.connect(func(v: float):
		gfx[k] = int(v)
		l.text = "%d%s" % [int(v), unit]
		_apply_gfx())
	s.drag_ended.connect(func(_c: bool): _save_gfx())
	h.add_child(s)
	h.add_child(l)
	return h

func _set_head(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 19)
	l.add_theme_color_override("font_color", Color("#6a8a2a"))
	set_box.add_child(l)

func _render_settings() -> void:
	for c in set_box.get_children():
		set_box.remove_child(c)
		c.queue_free()
	var top := HBoxContainer.new()
	var t := Label.new()
	t.text = "⚙️ Ayarlar"
	t.add_theme_font_size_override("font_size", 28)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	top.add_child(_small_btn("  ✕  ", func(): set_layer.visible = false))
	set_box.add_child(top)
	_set_head("🖥️ Görüntü")
	_set_row("Tam ekran  (F11)", _seg("fs", [["Açık", true], ["Kapalı", false]]))
	_set_row("Dikey eşitleme", _seg("vs", [["Açık", true], ["Kapalı", false]]))
	_set_row("FPS sınırı", _seg("fps", [["30", 30], ["60", 60], ["120", 120], ["Sınırsız", 0]]))
	_set_row("FPS göster", _seg("showfps", [["Açık", true], ["Kapalı", false]]))
	_set_head("🎨 Grafik")
	_set_row("Kalite", _seg("q", [["Düşük", 0], ["Orta", 1], ["Yüksek", 2], ["Ultra", 3]]))
	var qi := Label.new()
	qi.text = ["Gölgeler sert, çim seyrek, görüş kısa: zayıf bilgisayarlar için.", "Yumuşak gölge, orta çim; yansıma ve ortam gölgesi kapalı.",
		"Yumuşak gölge, tam çim, ortam gölgesi ve suda yansıma.", "En yumuşak gölge, 4× kenar yumuşatma, uzak gölgeler."][clampi(int(gfx.q), 0, 3)]
	qi.add_theme_font_size_override("font_size", 13)
	qi.add_theme_color_override("font_color", Color("#8a7260"))
	set_box.add_child(qi)
	_set_row("Çözünürlük", _slider("scale", 50, 100))
	_set_row("Gece parlaklığı", _slider("night", 0, 100))
	_set_head("🔊 Ses")
	_set_row("Ana ses", _slider("vol", 0, 100))
	_set_row("Efektler", _slider("sfx", 0, 100))
	var foot := HBoxContainer.new()
	var v := Label.new()
	v.text = "v%s · %s" % [_version(), CHANNEL]
	v.add_theme_font_size_override("font_size", 13)
	v.add_theme_color_override("font_color", Color("#a08a70"))
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(v)
	foot.add_child(_small_btn("  Varsayılanlar  ", func():
		var keep_fs: bool = gfx.fs
		gfx = GFX_DEFAULT.duplicate()
		gfx.fs = keep_fs
		_apply_gfx(true)
		_save_gfx()
		_render_settings()))
	set_box.add_child(foot)

func _build_menu() -> void:
	menu_layer = CanvasLayer.new()
	menu_layer.layer = 10
	add_child(menu_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = ui.theme
	menu_layer.add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0.1, 0.18, 0.06, 0.25)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var p := _panel(26)
	p.position = Vector2(48, 60)
	p.custom_minimum_size = Vector2(400, 0)
	root.add_child(p)
	menu_box = VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 10)
	p.add_child(menu_box)
	menu_layer.visible = false

func _menu_btn(text: String, cb: Callable, primary := false, enabled := true) -> Button:
	var b := _small_btn(text, cb, enabled, primary)
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_font_size_override("font_size", 18)
	return b

func _render_menu(page: String, arg := 0) -> void:
	for c in menu_box.get_children():
		menu_box.remove_child(c)
		c.queue_free()
	var t := Label.new()
	t.text = "🌾 Çiftliğim 3D"
	t.add_theme_font_size_override("font_size", 36)
	menu_box.add_child(t)
	var ver := Label.new()
	ver.text = "v%s · %s" % [_version(), CHANNEL]
	ver.add_theme_font_size_override("font_size", 13)
	ver.add_theme_color_override("font_color", Color("#a08a70"))
	menu_box.add_child(ver)
	if page == "main" and not update_info.is_empty():
		var up := PanelContainer.new()
		up.add_theme_stylebox_override("panel", _sb(Color("#fff3c4"), 12, Color("#f0c75e"), 2, 10))
		var uv := VBoxContainer.new()
		up.add_child(uv)
		var ul := Label.new()
		ul.text = "🔔 Yeni sürüm var: v%s\n%s" % [update_info.get("version", ""), update_info.get("notes", "")]
		ul.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		uv.add_child(ul)
		var link := str(update_info.get("url", ""))
		if link.begins_with("https://"):
			uv.add_child(_small_btn("  İndirme sayfasını aç  ", func(): OS.shell_open(link), true, true))
		menu_box.add_child(up)
	match page:
		"main":
			var cur := _slot_info(slot) if slot > 0 else {}
			if not cur.is_empty():
				var sub := Label.new()
				sub.text = "%s · Seviye %d · 🪙 %d" % [cur.name, cur.level, cur.coins]
				sub.add_theme_color_override("font_color", Color("#8a7260"))
				menu_box.add_child(sub)
				menu_box.add_child(_menu_btn("▶  Devam Et", func(): _start_play(), true))
			menu_box.add_child(_menu_btn("🌱  Yeni Kariyer", func(): _render_menu("new", _free_slot()), cur.is_empty()))
			menu_box.add_child(_menu_btn("📂  Kariyerler", func(): _render_menu("list")))
			menu_box.add_child(_menu_btn("🤝  Arkadaşa Katıl", func(): _render_menu("join")))
			menu_box.add_child(_menu_btn("❔  Nasıl Oynanır", func():
				_start_play()
				help.visible = true, false, not cur.is_empty()))
			menu_box.add_child(_menu_btn("⚙️  Ayarlar", _open_settings))
			menu_box.add_child(_menu_btn("🚪  Çıkış", func():
				_save()
				get_tree().quit()))
		"join":
			var h := Label.new()
			h.text = "🤝 Arkadaşının çiftliğine katıl\nArkadaşın oyunda 📡 düğmesine basıp\nsana adresini söylesin."
			menu_box.add_child(h)
			var ip := LineEdit.new()
			ip.placeholder_text = "Adres (ör. 192.168.1.20)"
			ip.text = _profile_get("last_ip", "")
			ip.custom_minimum_size = Vector2(0, 40)
			ip.add_theme_font_size_override("font_size", 18)
			menu_box.add_child(ip)
			var nm := LineEdit.new()
			nm.placeholder_text = "Adın"
			nm.text = _profile_get("player", "Çiftçi")
			nm.max_length = 14
			nm.custom_minimum_size = Vector2(0, 40)
			nm.add_theme_font_size_override("font_size", 18)
			menu_box.add_child(nm)
			net_status = Label.new()
			net_status.add_theme_color_override("font_color", Color("#8a7260"))
			menu_box.add_child(net_status)
			menu_box.add_child(_menu_btn("Bağlan", func(): _net_join(ip.text, nm.text), true))
			menu_box.add_child(_menu_btn("←  Geri", func():
				_net_close()
				_render_menu("main")))
		"list":
			var h := Label.new()
			h.text = "📂 Kariyerler"
			h.add_theme_font_size_override("font_size", 20)
			menu_box.add_child(h)
			for n in range(1, SLOTS + 1):
				var info := _slot_info(n)
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 8)
				var l := Label.new()
				l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				l.custom_minimum_size = Vector2(250, 0)
				if info.is_empty():
					l.text = "%d. Boş yuva" % n
					l.add_theme_color_override("font_color", Color("#a89580"))
					row.add_child(l)
					var nn := n
					row.add_child(_small_btn(" Yeni ", func(): _render_menu("new", nn), true, true))
				else:
					var when := Time.get_datetime_string_from_unix_time(int(info.saved_at) + int(Time.get_time_zone_from_system().bias) * 60, true).substr(0, 16)
					l.text = "%d. %s%s\nSeviye %d · 🪙 %d · %s" % [n, info.name, "  (açık)" if n == slot else "", info.level, info.coins, when]
					row.add_child(l)
					var nn := n
					row.add_child(_small_btn(" Oyna ", func(): _open_slot(nn), true, true))
					row.add_child(_small_btn(" Sil " if not del_armed.get(n, false) else " Emin misin? ", func(): _delete_slot(nn)))
				menu_box.add_child(row)
			menu_box.add_child(_menu_btn("←  Geri", func(): _render_menu("main")))
		"new":
			if arg <= 0:
				var w := Label.new()
				w.text = "Tüm yuvalar dolu. Kariyerler'den birini sil."
				w.add_theme_color_override("font_color", Color("#c62828"))
				menu_box.add_child(w)
				menu_box.add_child(_menu_btn("←  Geri", func(): _render_menu("main")))
				return
			var h := Label.new()
			h.text = "🌱 Yeni Kariyer (%d. yuva)\nÇiftliğinin adı:" % arg
			menu_box.add_child(h)
			var le := LineEdit.new()
			le.text = "Çiftliğim"
			le.max_length = 18
			le.custom_minimum_size = Vector2(0, 40)
			le.add_theme_font_size_override("font_size", 18)
			menu_box.add_child(le)
			var nn := arg
			menu_box.add_child(_menu_btn("Başla", func(): _new_career(nn, le.text), true))
			menu_box.add_child(_menu_btn("←  Geri", func(): _render_menu("main")))

func _free_slot() -> int:
	for n in range(1, SLOTS + 1):
		if not FileAccess.file_exists(_slot_path(n)):
			return n
	return 0

func _new_career(n: int, nm: String) -> void:
	nm = nm.strip_edges()
	if nm == "":
		nm = "Çiftliğim"
	_save()
	boot = {"slot": n, "new": true, "name": nm}
	get_tree().reload_current_scene()

func _open_slot(n: int) -> void:
	if n == slot and save_path != "":
		_start_play()
		return
	_save()
	boot = {"slot": n}
	get_tree().reload_current_scene()

func _delete_slot(n: int) -> void:
	if not del_armed.get(n, false):
		del_armed[n] = true
		_render_menu("list")
		return
	del_armed.erase(n)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_slot_path(n)))
	if n == slot:
		slot = 0
		save_path = ""
	_render_menu("list")

func _set_tool(id: String, open := false) -> void:
	if id != "move" and move_src != null:
		_move_pick(null)
	tool = id
	shelf_open = open and _shelf_key_of(id) != ""
	for k in tool_buttons:
		var b: Button = tool_buttons[k]
		var on: bool = k == id
		if on:
			_round_style(b, Color("#6fbf3b"), Color("#7fcf4b"), 42)
		else:
			_round_style(b, Color("#fffaee"), Color("#f3e6cf"), 42, Color("#e7d7bf"), 3)
		b.add_theme_color_override("font_color", Color.WHITE if on else Color("#4a3424"))
		b.add_theme_color_override("font_hover_color", Color.WHITE if on else Color("#4a3424"))
	grid.visible = id != "hand"
	_render_shelf()

func _shelf_key_of(id: String) -> String:
	for t in TOOLS:
		if t.id == id:
			return t.shelf
	return ""

func _shelf_list(cat: String) -> Dictionary:
	return {"seed": Data.CROPS, "tree": Data.TREES, "animal": Data.animal_shop(), "decor": Data.DECOR, "garden": Data.garden(), "build": Data.BUILDINGS}[cat]

## Alet düğmeleri seçili eşyanın simgesini de gösterir (ör. 🌱🥗 Tohum).
func _update_tool_labels() -> void:
	for t in TOOLS:
		if not tool_buttons.has(t.id):
			continue
		var b: Button = tool_buttons[t.id]
		var extra := ""
		if t.shelf != "":
			var list := _shelf_list(t.shelf)
			var k = sel[t.shelf]
			if list.has(k):
				extra = list[k].icon
		b.text = "%s%s\n%s" % [t.icon, extra, t.name]
		if t.id == tool and wheel_btn != null:
			wheel_btn.text = "%s%s\n%s" % [t.icon, extra, t.name]

func _shelf_key() -> String:
	for t in TOOLS:
		if t.id == tool:
			return t.shelf
	return ""

func _render_shelf() -> void:
	var cat := _shelf_key()
	_update_tool_labels()
	if cat == "" or not shelf_open:
		shelf_panel.visible = false
		return
	shelf_panel.visible = true
	for c in shelf_box.get_children():
		shelf_box.remove_child(c)
		c.queue_free()
	for c in shelf_nav.get_children():
		c.queue_free()
	var list = _shelf_list(cat)
	var keys: Array = list.keys()
	var pages := maxi(1, ceili(keys.size() / float(SHELF_PER_PAGE)))
	var pg := clampi(int(shelf_page.get(cat, 0)), 0, pages - 1)
	shelf_page[cat] = pg
	shelf_title.text = SHELF_TITLES.get(cat, "")
	if pages > 1:
		var prev := _small_btn("  ◀  ", func():
			shelf_page[cat] = pg - 1
			_render_shelf())
		prev.disabled = pg == 0
		shelf_nav.add_child(prev)
		var pl := Label.new()
		pl.text = "%d / %d" % [pg + 1, pages]
		pl.add_theme_font_size_override("font_size", 16)
		shelf_nav.add_child(pl)
		var nxt := _small_btn("  ▶  ", func():
			shelf_page[cat] = pg + 1
			_render_shelf())
		nxt.disabled = pg >= pages - 1
		shelf_nav.add_child(nxt)
	shelf_nav.visible = pages > 1
	for k in keys.slice(pg * SHELF_PER_PAGE, (pg + 1) * SHELF_PER_PAGE):
		var it = list[k]
		var locked: bool = it.level > level
		var meta := ""
		match cat:
			"seed": meta = "⏱%s → %d🪙" % [fmt_time(it.time), it.sell] if _in_season(it) else "🚫 " + Data.season_icons(it.seasons)
			"tree": meta = "🍃%s → %d🪙" % [fmt_time(it.regrow), it.sell]
			"animal": meta = "🥚 yuva 2×2" if k == "coop" else "%s%s → %d🪙" % [it.picon, fmt_time(it.time), it.sell]
			"decor": meta = "✨ bonus" if it.has("info") else " "
			"build": meta = "%d×%d · +%d XP" % [it.w, it.d, it.xp]
			"garden":
				if k == "pond":
					meta = "🐟%s → %d🪙" % [fmt_time(it.time), it.sell]
				else:
					meta = "⏱%s → %d🪙 💧×3" % [fmt_time(it.time), int(round(it.sell * Data.flower_mult(_flower_lv(k).lv)))]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(124, 100)
		b.add_theme_font_size_override("font_size", 13)
		b.text = "%s\n%s\n🪙 %d\n%s" % [it.icon, it.name, it.cost, ("🔒 Sv %d" % it.level) if locked else meta]
		b.tooltip_text = it.get("info", it.name)
		if cat == "garden" and k != "pond":
			b.tooltip_text = "%s · Sv %d\nKalıcı tarh: hasattan sonra yeniden açar.\nBüyürken sulu tutarsan kazanç 3 katına kadar çıkar." % [it.name, _flower_lv(k).lv]
		if cat == "seed":
			b.tooltip_text = "%s\nMevsim: %s" % [it.name, Data.season_names(it.seasons)]
		var selected: bool = sel[cat] == k
		_btn_styles(b, Color("#f1ffe6") if selected else Color.WHITE, Color("#fbf3e4"), Color("#6fbf3b") if selected else Color("#e7d7bf"), 2)
		if locked or (cat == "seed" and not _in_season(it)):
			b.modulate = Color(0.7, 0.7, 0.7, 0.75)
		b.set_meta("cost", it.cost)
		var kk: String = k
		b.pressed.connect(func():
			if locked:
				_toast("🔒 Seviye %d gerekli" % it.level, "warn")
				return
			sel[cat] = kk
			shelf_open = false
			_render_shelf())
		shelf_box.add_child(b)
	_update_afford()

func _update_afford() -> void:
	for b in shelf_box.get_children():
		if b.is_queued_for_deletion():
			continue
		var poor: bool = b.get_meta("cost", 0) > coins
		b.add_theme_color_override("font_color", Color("#c62828") if poor else Color("#4a3424"))
		b.add_theme_color_override("font_hover_color", Color("#c62828") if poor else Color("#4a3424"))

func _update_hud(dt: float) -> void:
	shown_coins = lerpf(shown_coins, coins, minf(1.0, dt * 10.0))
	if absf(shown_coins - coins) < 0.5:
		shown_coins = coins
	lbl_coins.text = "🪙 %d" % roundi(shown_coins)
	lbl_queue.text = ("İş sırası: %d · Esc iptal" % queue.size()) if queue.size() > 0 else ""
	if not hud_dirty:
		return
	hud_dirty = false
	var need := Data.xp_for_level(level)
	lbl_level.text = str(level)
	lbl_medals.text = "🏅 %d" % medals
	lbl_gems.text = "💎 %d" % gems
	lbl_xp.text = "Seviye · %d / %d XP" % [xp, need]
	bar_xp.max_value = need
	bar_xp.value = xp
	_update_afford()

# ============================================================ kayıt
func _save() -> void:
	if save_path == "" or not playing:
		return
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_state_dict()))
		f.close()

## Kayıt ve ağ için çiftliğin tüm durumu.
func _state_dict() -> Dictionary:
	var ents := []
	for e in entities:
		ents.append(_ent_dict(e))
	return {"v": 1, "bv": 1, "sv": 2, "story": story_step, "sh": story_have, "fh": farm_h, "fg": fishgear, "name": farm_name, "gems": gems, "quests": quests, "qskip": quest_skip_at, "flv": flv, "season": season, "season_t": season_t, "year": year, "weather": weather, "weather_t": weather_t, "medals": medals, "res": res, "order": order, "coins": coins, "xp": xp, "level": level, "day_time": day_time, "day": day, "sel": sel, "muted": muted,
		"saved_at": Time.get_unix_time_from_system(), "ents": ents, "fx": farmer.position.x, "fz": farmer.position.z}

func _ent_dict(e: Dictionary) -> Dictionary:
		var s := {"k": e.kind, "x": e.x, "z": e.z, "r": e.rot}
		if e.has("type"): s.t = e.type
		match e.kind:
			"plot":
				s.c = e.crop
				s.p = e.progress
				s.w = snappedf(e.water, 0.001)
			"tree":
				s.a = e.age
				s.f = e.fruit_t
				s.h = e.has_fruit
			"animal":
				s.at = e.t
				s.rd = e.ready
				s.fd = snappedf(e.food, 0.001)
				s.lv = e.lv
				s.hv = e.hv
			"flower":
				s.at = e.t
				s.rd = e.ready
				s.wa = snappedf(e.water, 0.001)
				s.wt = snappedf(e.wet_t, 0.01)
			"pond":
				s.at = e.t
				s.rd = e.ready
			"coop":
				s.eg = e.eggs
				s.ev = e.value
				s.ex = e.xp
				s.ey = e.yield
		return s

func _load() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	return _load_dict(data, true)

func _load_dict(data, offline: bool) -> bool:
	if typeof(data) != TYPE_DICTIONARY or int(data.get("v", 0)) != 1:
		return false
	coins = int(data.coins)
	xp = int(data.xp)
	level = int(data.level)
	day_time = float(data.day_time)
	day = int(data.get("day", 1))
	muted = bool(data.get("muted", false))
	medals = int(data.get("medals", 0))
	gems = int(data.get("gems", 0))
	_load_fishgear(data.get("fg", {}))
	farm_h = int(data.get("fh", 0))
	if farm_h <= 0:
		farm_h = _farm_h_from_parcels(data.get("parcels", []))
	farm_h = clampi(farm_h, FARM_H_START, WORLD_MAX + 1)
	farm_name = str(data.get("name", "Çiftliğim"))
	quest_skip_at = float(data.get("qskip", 0.0))
	story_step = clampi(int(data.get("story", STORY.size())), 0, STORY.size())
	story_have = int(data.get("sh", 0))
	quests = []
	var qd = data.get("quests", [])
	if typeof(qd) == TYPE_ARRAY:
		for q in qd:
			if typeof(q) == TYPE_DICTIONARY and q.has("kind"):
				quests.append({"kind": str(q.kind), "arg": str(q.get("arg", "")), "text": str(q.get("text", "")),
					"need": int(q.need), "have": int(q.get("have", 0)), "medals": int(q.medals), "gems": int(q.gems), "xp": int(q.xp)})
	flv = {}
	var fd = data.get("flv", {})
	if typeof(fd) == TYPE_DICTIONARY:
		for k in fd:
			flv[k] = {"lv": int(fd[k].lv), "n": int(fd[k].n)}
	season = clampi(int(data.get("season", 0)), 0, 3)
	season_t = float(data.get("season_t", 0.0))
	year = int(data.get("year", 1))
	weather = str(data.get("weather", ""))
	if not Data.WEATHER.has(weather):
		weather = ""
	weather_t = float(data.get("weather_t", 0.0))
	res = {}
	for k in data.get("res", {}):
		res[k] = int(data.res[k])
	order = {}
	var od = data.get("order", {})
	if typeof(od) == TYPE_DICTIONARY and od.has("need"):
		var need := {}
		for k in od.need:
			need[k] = int(od.need[k])
		order = {"need": need, "medals": int(od.medals), "xp": int(od.xp), "coins": int(od.coins)}
	for k in data.get("sel", {}):
		sel[k] = data.sel[k]
	for s in data.ents:
		if tiles.has(key(int(s.x), int(s.z))):
			continue
		_add_entity(_ent_base(s))
	_load_finish(data, offline)
	return true

## Kayıttaki varlık sözlüğünden _add_entity girdisi.
func _ent_base(s: Dictionary) -> Dictionary:
		var x := int(s.x)
		var z := int(s.z)
		var base := {"kind": s.k, "x": x, "z": z, "rot": float(s.get("r", 0.0))}
		if s.has("t"):
			base.type = s.t
		match s.k:
			"plot":
				base.crop = s.get("c")
				base.progress = float(s.get("p", 0.0))
				var w = s.get("w", 0.0)
				base.water = (1.0 if w else 0.0) if typeof(w) == TYPE_BOOL else float(w)
			"tree":
				base.age = float(s.get("a", 0.0))
				base.fruit_t = float(s.get("f", 0.0))
				base.has_fruit = bool(s.get("h", false))
			"animal":
				base.t = float(s.get("at", 0.0))
				base.ready = bool(s.get("rd", false))
				base.food = float(s.get("fd", 1.0))
				base.lv = int(s.get("lv", 1))
				base.hv = int(s.get("hv", 0))
			"coop":
				base.eggs = int(s.get("eg", 0))
				base.value = int(s.get("ev", 0))
				base.xp = int(s.get("ex", 0))
				base.yield = int(s.get("ey", 0))
			"building":
				var bd: Dictionary = Data.BUILDINGS.get(s.get("t", ""), {"w": 4, "d": 4})
				base.w = bd.w
				base.d = bd.d
			"flower", "pond":
				base.t = float(s.get("at", 0.0))
				base.ready = bool(s.get("rd", false))
				base.water = float(s.get("wa", 0.0))
				base.wet_t = float(s.get("wt", 0.0))
		return base

func _load_finish(data: Dictionary, offline: bool) -> void:
	if not data.has("bv"):
		_add_default_buildings()   # binaların kayda girmediği eski sürüm
	_fit_farm_h()
	call_deferred("_story_catchup")
	if int(data.get("sv", 1)) < 2 and story_step > 0:
		story_step = STORY.size() if story_step >= 9 else story_step + 1   # ambar adımı araya girdi
	_recompute_boosts()
	var has_gate := false
	for e in entities:
		if e.get("type", "") == "gate":
			has_gate = true
			break
	var old_side = tiles.get(key(-3, 3))
	if not has_gate and old_side != null and old_side.get("type", "") == "fence":
		_remove_entity(old_side)
		_add_entity({"kind": "decor", "type": "gate", "x": -3, "z": 3})
	if order.is_empty():
		_new_order()
	_fill_quests()
	farmer.position = Vector3(float(data.get("fx", 0.5)), 0, float(data.get("fz", 9.0)))
	cam_target = farmer.position
	btn_sound.text = "🔇" if muted else "🔊"
	var away := minf(OFFLINE_CAP, Time.get_unix_time_from_system() - float(data.get("saved_at", 0)))
	if offline and away > 20.0:
		var left := away
		loading = true
		while left > 0.0:
			_simulate(minf(5.0, left))
			left -= 5.0
		loading = false
		_toast("🌙 Sen yokken çiftliğin %s boyunca büyüdü!" % fmt_time(away), "level")

## Eski kayıtlarda ve tanıtım çiftliğinde hazır gelen binalar (yeni kariyerde hiçbiri yok).
func _add_default_buildings() -> void:
	for d in [["house", -11, -12], ["barn", 5, -12], ["silo", 10, -12], ["well", -5, -10]]:
		var b = Data.BUILDINGS[d[0]]
		if _free_area(d[1], d[2], b.w, b.d):
			_add_entity({"kind": "building", "type": d[0], "x": d[1], "z": d[2], "w": b.w, "d": b.d, "rot": 0.0})

## Hikâyeli yeni kariyer: ot ve taş bürümüş boş arazi; ev, ambar, yol, çit — her şeyi oyuncu kurar.
func _new_story_game() -> void:
	farm_h = FARM_H_START
	var r := RandomNumberGenerator.new()
	r.seed = 2026
	var kinds := ["weed", "weed", "weed", "stone", "weed", "stump", "stone", "weed", "log", "stone"]
	var n := 0
	var tries := 0
	while n < 20 and tries < 400:
		tries += 1
		var x := r.randi_range(-7, 6)
		var z := r.randi_range(-7, 6)
		if x >= -3 and x <= 2:
			continue
		if tiles.has(key(x, z)) or tiles.has(key(x + 1, z)) or tiles.has(key(x, z + 1)):
			continue
		_add_entity({"kind": "debris", "type": kinds[n % kinds.size()], "x": x, "z": z})
		n += 1
	coins = 60
	sel.seed = "wheat"
	story_step = 0
	story_have = 0
	_new_order()
	_recompute_boosts()
	quests = []
	_render_quests()

func _new_game() -> void:
	farm_h = 12
	story_step = STORY.size()
	_add_default_buildings()
	for z in range(-6, 12):
		for x in [-1, 0]:
			_add_entity({"kind": "decor", "type": "path", "x": x, "z": z})
	for x in range(-10, -1):
		for z in [-7, -6]:
			_add_entity({"kind": "decor", "type": "path", "x": x, "z": z})
	var i := 0
	for x in range(2, 8):
		for z in range(1, 5):
			var planted := i < 16
			_add_entity({"kind": "plot", "x": x, "z": z, "crop": ("wheat" if i < 8 else "carrot") if planted else null,
				"progress": (1.0 if i < 4 else 0.15 + (i % 5) * 0.15) if planted else 0.0, "watered": planted and i % 3 != 0})
			i += 1
	_add_entity({"kind": "animal", "type": "chicken", "x": -8, "z": 2, "ready": true, "t": 0.0})
	_add_entity({"kind": "animal", "type": "chicken", "x": -6, "z": 2, "t": 0.6})
	_add_entity({"kind": "animal", "type": "chicken", "x": -7, "z": 4, "t": 0.5, "food": 0.0})
	_add_entity({"kind": "coop", "type": "coop", "x": -5, "z": 2, "eggs": 2, "value": 36, "xp": 8, "yield": 4})
	for x in range(-9, -2):
		_add_entity({"kind": "decor", "type": "fence", "x": x, "z": 1})
		_add_entity({"kind": "decor", "type": "fence", "x": x, "z": 5})
	for z in range(2, 5):
		_add_entity({"kind": "decor", "type": "fence", "x": -9, "z": z})
		_add_entity({"kind": "decor", "type": "gate" if z == 4 else "fence", "x": -3, "z": z})
	_add_entity({"kind": "tree", "type": "apple", "x": -6, "z": -3, "age": 1.0, "fruit_t": 0.0, "has_fruit": true})
	_add_entity({"kind": "tree", "type": "apple", "x": -3, "z": -3, "age": 0.4, "fruit_t": 0.0, "has_fruit": false})
	_new_order()
	for d in [["flowers", -11, -7], ["flowers", -11, -6], ["lantern", -2, 10], ["lantern", 1, 10], ["lantern", -3, -5], ["bush", 10, 9], ["hay", 5, -6], ["rock", 9, 6]]:
		_add_entity({"kind": "decor", "type": d[0], "x": d[1], "z": d[2]})
	_recompute_boosts()
	quests = []
	_fill_quests()

# ============================================================ döngü
func _process(delta: float) -> void:
	if not ready_done:
		return
	if not grass_dirty.is_empty():
		_update_grass()
	var dt := minf(0.1, delta)
	if shot_path != "" and not playing:
		shot_t += delta
		if shot_t > 4.0:
			get_viewport().get_texture().get_image().save_png(shot_path)
			get_tree().quit()
	if not playing:
		sim_acc += dt
		if sim_acc > 0.1:
			_simulate(sim_acc)
			sim_acc = 0.0
		cam_follow = false
		cam_yaw += dt * 0.04
		cam_target = cam_target.lerp(Vector3(0, 0, 0), minf(1.0, dt * 0.8))
		cam_dist = lerpf(cam_dist, 34.0, minf(1.0, dt * 0.8))
		_update_camera(dt)
		_update_day(dt)
		_update_lamps(dt)
		_animate_world(dt)
		_update_parts(dt)
		_update_floats(dt)
		return
	if painting and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		painting = false
	_update_hold(dt)
	_update_emotes(dt)
	_update_fishing(dt)
	_update_mill(dt)
	_update_bake(dt)
	sim_acc += dt
	if sim_acc > 0.1:
		_simulate(sim_acc)
		sim_acc = 0.0
	_update_farmer(dt)
	if net_role == "host" or net_role == "guest":
		_net_tick(dt)
	_update_gates(dt)
	_update_camera(dt)
	_update_day(dt)
	_update_lamps(dt)
	_animate_world(dt)
	_update_parts(dt)
	_update_floats(dt)
	_update_hover()
	_update_cursor()
	_update_hud(dt)
	save_timer += dt
	if save_timer > 10.0:
		save_timer = 0.0
		if shot_path == "":
			_save()
	if OS.get_cmdline_user_args().has("--fps"):
		fps_t += delta
		if fps_t > 3.0:
			fps_n += 1
		if fps_t > 8.0:
			print("FPS ortalama: %.1f" % (fps_n / (fps_t - 3.0)))
			get_tree().quit()
	if shot_path != "":
		shot_t += delta
		if shot_t > 3.0 and shot_t - delta <= 3.0:
			for a in OS.get_cmdline_user_args():
				if a.begins_with("--tool="):
					_set_tool(a.substr(7), true)
				elif a == "--wheel":
					_open_wheel(Vector2(640, 380))
				elif a == "--oven" or a == "--bakegame":   # geliştirici: fırın
					level = maxi(level, 4)
					res = {"flour": 6, "egg": 3, "fish": 2, "milk": 1, "fruit": 4}
					if a == "--oven":
						_open_oven()
					else:
						_bake_start("pogaca")
						bake_g.t = 4.0
						bake_g.p = 0.55
						bake_g.h = 0.6
				elif a == "--mill":   # geliştirici: değirmen penceresi
					level = maxi(level, 2)
					res["cereal"] = 14
					_open_mill()
				elif a == "--millgame":   # geliştirici: değirmen mini oyunu
					level = maxi(level, 2)
					res["cereal"] = 14
					_mill_start()
					mill_g.hits = [2, 1, 0]
					mill_g.round = 3
					mill_g.a = float(mill_g.zone) - 0.8
				elif a == "--fishshop":   # geliştirici: balıkçı tezgâhı
					fishgear.rod = 1
					fishgear.bait = 7
					fishgear.log = {"sazan": {"n": 3, "best": 2.4}, "kizilkanat": {"n": 5, "best": 0.3}}
					_open_fish_shop()
				elif a == "--fishgame":   # geliştirici: mini oyun
					fishgear.rod = 1
					fishgear.bait = 5
					farmer.position = Vector3(POND_X - POND_R - 0.75, 0, POND_Z)
					fish_shore = farmer.position
					fish_at = Vector3(POND_X - 1.5, 0, POND_Z)
					_fish_cast()
					fish_state = "bite"
					_fish_start_game()
					fish_g.fx = 0.45
					fish_g.p = 0.6
				elif a == "--emote":   # geliştirici: emote çubuğu ve balon
					_toggle_emote_bar()
					_show_emote(farmer, 2)
				elif a == "--ctx":   # geliştirici: ambarın basılı tut menüsü
					for e in entities:
						if e.kind == "building" and e.type == "barn":
							hold_at = Vector2(640, 300)
							_open_ctx(e)
							break
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--act=") and shot_t > 3.45 and shot_t - delta <= 3.45:
				farmer.rotation.y = 0.0
				_act_anim(a.substr(6), farmer.position + Vector3(0, 0, 0.9))
		if shot_t > 4.0:
			get_viewport().get_texture().get_image().save_png(shot_path)
			get_tree().quit()

# ============================================================ öz test (--selftest)
func _selftest() -> void:
	var fails := []
	playing = true
	quests = []
	season = 0
	season_t = 0.0
	weather = ""
	var c0 := coins
	if not _perform({"x": 2, "z": 1, "tool": "hand", "arg": "wheat"}): fails.append("hasat")
	if coins != c0 + 12: fails.append("hasat altını %d" % coins)
	if tiles[key(2, 1)].crop != null: fails.append("hasat sonrası tarla boş değil")
	if not _perform({"x": 2, "z": 1, "tool": "hand", "arg": "carrot"}): fails.append("el ile ekim")
	if not _perform({"x": 2, "z": 1, "tool": "water", "arg": null}): fails.append("sulama")
	if not _perform({"x": 0, "z": 0, "tool": "plow", "arg": null}) == false: fails.append("yol üstüne sürme engellenmedi")
	if not _perform({"x": 9, "z": 2, "tool": "plow", "arg": null}): fails.append("sürme")
	if not _perform({"x": 9, "z": 2, "tool": "seed", "arg": "wheat"}): fails.append("tohum")
	if _perform({"x": 9, "z": 3, "tool": "seed", "arg": "tomato"}): fails.append("kilitli ekin ekildi")
	coins = 5000
	level = 6
	if not _perform({"x": 9, "z": 5, "tool": "tree", "arg": "cherry"}): fails.append("ağaç")
	if not _perform({"x": 10, "z": 5, "tool": "animal", "arg": "cow"}): fails.append("hayvan")
	if not _perform({"x": 8, "z": 5, "tool": "decor", "arg": "scarecrow"}): fails.append("korkuluk")
	if not tiles[key(9, 2)].boost: fails.append("korkuluk bonusu")
	if not _perform({"x": 10, "z": 5, "tool": "remove", "arg": null}): fails.append("kaldır")
	if not _perform({"x": 9, "z": 2, "tool": "water", "arg": null}): fails.append("sulama 2")
	_simulate(Data.CROPS.wheat.time * 0.85)
	if tiles[key(9, 2)].progress < 1.0: fails.append("büyüme %.2f" % tiles[key(9, 2)].progress)
	# tıklanan yere yürüme + bina engeli
	farmer.position = Vector3(0.5, 0, 9)
	_clear_queue()
	_walk_to(Vector3(6.3, 0, 11.2))
	for i in 200:
		_update_farmer(0.05)
	if farmer.position.distance_to(Vector3(6.3, 0, 11.2)) > 0.1: fails.append("yürüme %s" % farmer.position)
	_walk_to(Vector3(-9, 0, -10))
	for i in 200:
		_update_farmer(0.05)
	if _blocked(farmer.position): fails.append("binanın içine girdi")
	# Aşama 1: kaynak, satış, sipariş
	res = {}
	medals = 0
	var tree_e = tiles[key(9, 5)]
	tree_e.age = 1.0
	tree_e.has_fruit = true
	coins = 100
	var c1 := coins
	if not _perform({"x": 9, "z": 5, "tool": "hand", "arg": "wheat"}): fails.append("meyve hasadı")
	if res.get("fruit", 0) != 5: fails.append("kiraz kaynağı %s" % res)
	_sell("fruit", 2)
	if res.fruit != 3 or coins != c1 + 95 + 12: fails.append("satış altını %d" % coins)
	order = {"need": {"fruit": 3}, "medals": 2, "xp": 10, "coins": 30}
	_deliver()
	if medals != 2 or res.fruit != 0: fails.append("sipariş teslimi")
	if order.is_empty(): fails.append("yeni sipariş oluşmadı")
	res = {"veg": _barn_cap() - 1}
	_store("pumpkin", Vector3.ZERO)
	if _res_total() != _barn_cap(): fails.append("ambar kapasitesi %d" % _res_total())
	res = {}
	_selftest_seasons(fails)
	_selftest_animals(fails)
	_selftest_garden(fails)
	_selftest_quests(fails)
	_selftest_paths(fails)
	_selftest_gates(fails)
	_selftest_net(fails)
	_selftest_story(fails)
	_selftest_parcels(fails)
	_selftest_build(fails)
	for qq in 4:
		gfx.q = qq
		_apply_gfx()
	if env.ssr_enabled != true or grass_frac != 1.0: fails.append("ultra ayarı")
	gfx.q = 0
	_apply_gfx()
	if env.ssao_enabled or grass_frac >= 1.0: fails.append("düşük ayarı")
	gfx = GFX_DEFAULT.duplicate()
	_apply_gfx()
	if not _ver_newer("0.10.0", "0.9.3") or _ver_newer("0.1.0", "0.1.0") or not _ver_newer("1.0", "0.9.9") or _ver_newer("0.1.0", "0.2"):
		fails.append("sürüm karşılaştırma")
	if _version() == "0.0.0": fails.append("sürüm numarası yok")
	var n_before := entities.size()
	_save()
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	var lv_ok := false
	for se in data.ents:
		if se.k == "animal" and se.has("lv"):
			lv_ok = true
	if not lv_ok: fails.append("hayvan seviyesi kaydedilmedi")
	if data.ents.size() != n_before: fails.append("kayıt varlık sayısı %d / %d" % [data.ents.size(), n_before])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	print("SELFTEST ", "OK" if fails.is_empty() else "FAIL: " + ", ".join(fails))
	get_tree().quit()

## --demo: ekran görüntüleri için her türden örnek yerleştirir.
func _demo() -> void:
	coins = 5000
	level = 6
	var crops := ["wheat", "carrot", "lettuce", "tomato", "cabbage", "corn", "sunflower", "pumpkin"]
	for i in crops.size():
		for st in 4:
			var x := 2 + st
			var z := -5 + i
			if tiles.has(key(x, z)):
				continue
			_add_entity({"kind": "plot", "x": x, "z": z, "crop": crops[i], "progress": [0.0, 0.4, 0.75, 1.0][st], "watered": st < 3})
	var an := [["cow", 8, 2], ["pig", 9, 3], ["sheep", 10, 2], ["cow", 10, 4]]
	for a in an:
		_add_entity({"kind": "animal", "type": a[0], "x": a[1], "z": a[2], "ready": a[1] == 9})
	var tr := [["apple", -6, 7, 1.0, true], ["orange", -4, 7, 1.0, true], ["cherry", -2, 7, 1.0, true], ["apple", -6, 9, 1.0, false], ["orange", -4, 9, 0.3, false]]
	for t in tr:
		if not tiles.has(key(t[1], t[2])):
			_add_entity({"kind": "tree", "type": t[0], "x": t[1], "z": t[2], "age": t[3], "fruit_t": 0.0, "has_fruit": t[4]})
	var fls := [["daisy", 8, 0.0, false, 1.0], ["tulip", 9, 0.5, false, 0.0], ["rose", 10, 0.8, false, 1.0], ["lavender", 11, 1.0, true, 0.0], ["tulip", 7, 1.0, true, 1.0]]
	for f in fls:
		if not tiles.has(key(f[1], -1)):
			_add_entity({"kind": "flower", "type": f[0], "x": f[1], "z": -1, "t": f[2], "ready": f[3], "water": f[4]})
	if _free_area(8, -4, 2, 2):
		_add_entity({"kind": "pond", "type": "pond", "x": 8, "z": -4, "ready": true})
	farmer.position = Vector3(6.5, 0, 1.5)
	cam_target = farmer.position
	cam_dist = 11.0

# ============================================================ balıkçılık
func _in_lake(p: Vector3) -> bool:
	return Vector2(p.x - POND_X, p.z - POND_Z).length() < POND_R - 0.2

func _near_stall(p: Vector3) -> bool:
	return Vector2(p.x - STALL.x, p.z - STALL.z).length() < 1.7

## Gölün kıyısındaki balıkçı tezgâhı.
func _build_stall() -> void:
	var g := Models.node(STALL.x, height_at(STALL.x, STALL.z), STALL.z)
	g.rotation.y = -PI / 2.0   # yüzü çiftliğe (batıya)
	for x in [-1.0, 1.0]:
		for z in [-0.55, 0.55]:
			g.add_child(Models.box(0.12, 2.1, 0.12, "#8d5f3a", x, 1.05, z))
	g.add_child(Models.box(2.3, 0.8, 0.9, "#c79a6a", 0, 0.4, 0.15))
	g.add_child(Models.box(2.4, 0.08, 1.0, "#a0703f", 0, 0.82, 0.15))
	for i in 6:   # çizgili tente
		g.add_child(Models.box(0.4, 0.07, 1.5, "#e57373" if i % 2 == 0 else "#fff3e0", -1.0 + i * 0.4, 2.15, 0.05))
	g.add_child(Models.box(1.0, 0.25, 0.5, "#7a5030", 0.6, 0.98, 0.15))   # balık kasası
	for i in 3:
		g.add_child(Models.ball(0.12, "#90caf9", 0.35 + i * 0.25, 1.12, 0.15))
	g.add_child(Models.cyl(0.03, 0.03, 1.4, 6, "#5d4037", -0.85, 1.4, 0.45))   # dayalı olta
	var l := Label3D.new()
	l.font = font
	l.text = "🎣 BALIKÇI"
	l.font_size = 72
	l.pixel_size = 0.006
	l.outline_size = 10
	l.outline_modulate = Color(0.2, 0.12, 0.05, 0.8)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = Vector3(0, 2.7, 0)
	g.add_child(l)
	add_child(g)

func _fish_def(id: String) -> Dictionary:
	for f in FISH:
		if f.id == id:
			return f
	return {}

## Oltaya hangi tür gelir: gece yayın balığı, parlak yemde nadirler daha sık.
func _fish_roll(special: bool) -> Dictionary:
	var night := day_time > 0.78 or day_time < 0.22
	var total := 0.0
	var ws := []
	for f in FISH:
		var c := float(f.chance)
		if f.get("night", false):
			c *= 6.0 if night else 0.3
		if special and float(f.diff) >= 0.5:
			c *= 3.0
		ws.append(c)
		total += c
	var r := randf() * total
	for i in FISH.size():
		r -= ws[i]
		if r <= 0.0:
			return FISH[i]
	return FISH[0]

func _fish_buy(id: String) -> bool:
	for it in FISH_SHOP:
		if it[0] != id:
			continue
		if coins < int(it[2]) or level < int(it[3]):
			return false
		if (id == "rod1" and int(fishgear.rod) >= 1) or (id == "rod2" and int(fishgear.rod) >= 2):
			return false
		if net_role == "guest":
			rpc_id(1, "net_req", "@fishbuy", id, 0, 0)
			_toast("🎣 %s alındı" % it[1], "level")
			return true
		_spend(int(it[2]))
		match id:
			"rod1": fishgear.rod = 1
			"rod2": fishgear.rod = 2
			"bait": fishgear.bait = int(fishgear.bait) + 10
			"bait2": fishgear.bait2 = int(fishgear.bait2) + 5
		_toast("🎣 %s alındı" % it[1], "level")
		_sfx("place")
		net_quest_dirty = true
		if shop_open:
			_open_fish_shop()
		return true
	return false

## Yakalanan balık: ambara balık, XP, defter (en büyük ağırlık), görev.
func _fish_reward(id: String, w: float) -> void:
	var f := _fish_def(id)
	if f.is_empty():
		return
	var lg: Dictionary = fishgear.log
	var rec: Dictionary = lg.get(id, {"n": 0, "best": 0.0})
	var record := w > float(rec.best)
	lg[id] = {"n": int(rec.n) + 1, "best": maxf(float(rec.best), w)}
	if net_role == "guest":
		return
	var pos := fish_shore if fish_state != "" else farmer.position
	if _barn_cap() > 0:
		var add := mini(int(f.amt), _barn_cap() - _res_total())
		if add > 0:
			res["fish"] = res.get("fish", 0) + add
		if add < int(f.amt):
			_toast("📦 Ambar dolu! B ile aç, kaynak sat.", "warn")
	else:
		_toast("📦 Ambarın yok: balık saklanamadı. 🏗️ Yapı ile ambar kur.", "warn")
	gems += int(f.get("gems", 0))
	_gain(0, int(f.xp), pos, f.icon)
	_quest_event("fish", "", 1)
	net_quest_dirty = true
	if barn.visible:
		_render_barn()
	if record and int(rec.n) > 0:
		_toast("🏆 Yeni rekor: %s %.1f kg!" % [f.name, w], "level")

## Göle tıklandı: kıyıya yürü, sonra oltayı at.
func _start_fishing(p: Vector3) -> void:
	if int(fishgear.rod) <= 0:
		_toast("🎣 Oltan yok. Gölün kıyısındaki 🎣 Balıkçı tezgâhından al.", "hint")
		return
	if int(fishgear.bait) <= 0 and int(fishgear.bait2) <= 0:
		_toast("🪱 Yemin bitti. 🎣 Balıkçı tezgâhından yem al.", "hint")
		return
	_fish_end(false)
	var c := Vector3(POND_X, 0, POND_Z)
	var d := Vector3(p.x - c.x, 0, p.z - c.z)
	if d.length() < 0.1:
		d = Vector3(farmer.position.x - c.x, 0, farmer.position.z - c.z)
	d = d.normalized()
	fish_shore = c + d * (POND_R + 0.75)
	fish_at = c + d * clampf(Vector2(p.x - c.x, p.z - c.z).length(), 0.6, POND_R - 1.2)
	fish_state = "walk"
	fish_t = 0.0
	_walk_to(fish_shore)

func _fish_cast() -> void:
	fish_bait2 = bool(fishgear.use2) and int(fishgear.bait2) > 0
	if fish_bait2:
		fishgear.bait2 = int(fishgear.bait2) - 1
	elif int(fishgear.bait) > 0:
		fishgear.bait = int(fishgear.bait) - 1
	else:
		fish_bait2 = int(fishgear.bait2) > 0
		fishgear.bait2 = int(fishgear.bait2) - 1
	if net_role == "guest":
		rpc_id(1, "net_req", "@bait", "2" if fish_bait2 else "1", 0, 0)
	net_quest_dirty = true
	farmer.rotation.y = atan2(fish_at.x - farmer.position.x, fish_at.z - farmer.position.z)
	if fish_rod == null:
		fish_rod = Node3D.new()
		var stick := Models.cyl(0.02, 0.035, 1.7, 6, "#6d4c41", 0, 0.85, 0)
		fish_rod.add_child(stick)
		fish_rod.add_child(Models.cyl(0.06, 0.06, 0.08, 8, "#9e9e9e", 0, 0.25, 0.05))
		fish_rod.position = Vector3(0.28, 0.85, 0.2)
		fish_rod.rotation.x = 0.95
		farmer.add_child(fish_rod)
	fish_rod.visible = true
	if bobber == null:
		bobber = Node3D.new()
		bobber.add_child(Models.ball(0.09, "#e53935", 0, 0.03, 0))
		bobber.add_child(Models.ball(0.08, "#fafafa", 0, -0.04, 0))
		var ex := Label3D.new()
		ex.name = "Ex"
		ex.text = "❗"
		ex.font = font
		ex.font_size = 96
		ex.pixel_size = 0.006
		ex.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		ex.no_depth_test = true
		ex.position = Vector3(0, 0.7, 0)
		bobber.add_child(ex)
		add_child(bobber)
		fish_line = MeshInstance3D.new()
		var lm := StandardMaterial3D.new()
		lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lm.albedo_color = Color(1, 1, 1, 0.8)
		lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fish_line.material_override = lm
		fish_line.mesh = ImmediateMesh.new()
		add_child(fish_line)
	bobber.get_node("Ex").visible = false
	bobber.position = fish_at + Vector3(0, -0.06, 0)
	bobber.visible = true
	fish_line.visible = true
	_burst(fish_at, "#bbdefb", 10, 2.0)
	_sfx("cast")
	fish_state = "wait"
	fish_t = randf_range(2.0, 6.5) * (0.8 if fish_bait2 else 1.0)

## Balığı bitir/iptal et. keep: kamera ve çiftçi kalsın mı (zararsız).
func _fish_end(_keep := true) -> void:
	fish_state = ""
	fish_g = {}
	if bobber != null:
		bobber.visible = false
	if fish_line != null:
		fish_line.visible = false
	if fish_rod != null:
		fish_rod.visible = false
	if fish_ui != null:
		fish_ui.visible = false

## Balıkçılık sırasında sol tık / boşluk. true: tık burada tüketildi.
func _fish_click() -> bool:
	match fish_state:
		"wait":
			_toast("🎣 Oltayı erken çektin, yem suya gitti.", "hint")
			_fish_end()
			return true
		"bite":
			_fish_start_game()
			return true
		"game":
			return true
		"walk":
			_fish_end()
	return false

func _fish_start_game() -> void:
	fish_pick = _fish_roll(fish_bait2)
	var rod := int(fishgear.rod)
	fish_g = {"zx": 0.35, "zv": 0.0, "zw": 0.30 if rod <= 1 else 0.40, "fx": 0.5, "ftx": 0.5, "ft": 0.0,
		"p": 0.35, "diff": float(fish_pick.diff), "fill": 0.30 if rod <= 1 else 0.38}
	fish_state = "game"
	bobber.get_node("Ex").visible = false
	_build_fish_ui()
	fish_ui.visible = true
	_sfx("bite")

## Mini oyunun bir adımı (testte de kullanılır). hold: tuş basılı. "" sürüyor, "catch", "escape".
func _fish_game_step(dt: float, hold: bool) -> String:
	var g := fish_g
	g.zv = clampf(float(g.zv) + (2.8 if hold else -2.4) * dt, -1.1, 1.1)
	g.zx = float(g.zx) + float(g.zv) * dt
	if g.zx < 0.0:
		g.zx = 0.0
		g.zv = 0.0
	elif g.zx > 1.0 - float(g.zw):
		g.zx = 1.0 - float(g.zw)
		g.zv = 0.0
	var dif := float(g.diff)
	g.ft = float(g.ft) - dt
	if g.ft <= 0.0:
		g.ftx = clampf(float(g.fx) + randf_range(-0.6, 0.6) * (0.4 + dif), 0.03, 0.97)
		g.ft = randf_range(0.35, 1.7 - dif)
	g.fx = move_toward(float(g.fx), float(g.ftx), (0.18 + dif * 0.85) * dt)
	var inside: bool = g.fx >= g.zx and g.fx <= g.zx + g.zw
	g.p = float(g.p) + (float(g.fill) * dt if inside else -(0.12 + 0.16 * dif) * dt)
	g["in"] = inside
	if g.p >= 1.0:
		return "catch"
	if g.p <= 0.0:
		return "escape"
	return ""

func _build_fish_ui() -> void:
	if fish_ui != null:
		return
	fish_ui = _panel(14)
	fish_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(fish_ui)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fish_ui.add_child(v)
	var t := Label.new()
	t.text = "🎣 Balık takıldı!  Basılı tut (sol tık / Boşluk): yeşil alanı sağa it. Balığı alanın içinde tut."
	t.add_theme_font_size_override("font_size", 15)
	v.add_child(t)
	var track := Control.new()
	track.custom_minimum_size = Vector2(fish_track_w, 46)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(track)
	var bg := ColorRect.new()
	bg.color = Color("#4f7fa8")
	bg.size = Vector2(fish_track_w, 46)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(bg)
	fish_zone = ColorRect.new()
	fish_zone.color = Color(0.55, 0.9, 0.35, 0.75)
	fish_zone.size = Vector2(100, 46)
	fish_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(fish_zone)
	fish_icon = Label.new()
	fish_icon.text = "🐟"
	fish_icon.add_theme_font_size_override("font_size", 30)
	fish_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(fish_icon)
	fish_bar = ProgressBar.new()
	fish_bar.show_percentage = false
	fish_bar.custom_minimum_size = Vector2(fish_track_w, 12)
	fish_bar.max_value = 1.0
	fish_bar.step = 0.001
	fish_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fish_bar.add_theme_stylebox_override("background", _sb(Color("#eadcc6"), 4, Color(0, 0, 0, 0), 0, 0))
	fish_bar.add_theme_stylebox_override("fill", _sb(Color("#f2a900"), 4, Color(0, 0, 0, 0), 0, 0))
	v.add_child(fish_bar)

func _layout_fish_ui() -> void:
	var g := fish_g
	fish_zone.position.x = float(g.zx) * fish_track_w
	fish_zone.size.x = float(g.zw) * fish_track_w
	fish_zone.color = Color(0.55, 0.9, 0.35, 0.85) if g.get("in", false) else Color(0.55, 0.9, 0.35, 0.45)
	fish_icon.position = Vector2(float(g.fx) * fish_track_w - 18.0, 2.0)
	fish_bar.value = float(g.p)
	fish_ui.reset_size()
	var vs := get_viewport().get_visible_rect().size
	fish_ui.position = Vector2((vs.x - fish_ui.size.x) / 2.0, vs.y - fish_ui.size.y - 130)

func _update_fishing(dt: float) -> void:
	if fish_state == "":
		return
	match fish_state:
		"walk":
			var d := Vector2(farmer.position.x - fish_shore.x, farmer.position.z - fish_shore.z).length()
			if d < 0.6 or (move_target == null and d < 1.6):
				_fish_cast()
			elif move_target == null:
				_toast("🚧 Kıyıya ulaşılamadı", "hint")
				_fish_end()
			return
		"wait", "bite":
			if Vector2(farmer.position.x - fish_shore.x, farmer.position.z - fish_shore.z).length() > 1.8:
				_fish_end()   # yürüyüp gitti
				return
			fish_t -= dt
			var tm := float(Time.get_ticks_msec()) / 1000.0
			if fish_state == "wait":
				bobber.position.y = -0.06 + sin(tm * 3.0) * 0.015
				if fish_t <= 0.0:
					fish_state = "bite"
					fish_t = 1.3
					bobber.get_node("Ex").visible = true
					_burst(fish_at, "#e3f2fd", 8, 1.5)
					_sfx("bite")
			else:
				bobber.position.y = -0.16 + sin(tm * 18.0) * 0.04
				if fish_t <= 0.0:
					_toast("🐟 Balık yemi kaptı ve kaçtı! Ünlem çıkınca hemen tıkla.", "hint")
					_fish_end()
					return
		"game":
			var hold := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_key_pressed(KEY_SPACE)
			var r := _fish_game_step(dt, hold)
			_layout_fish_ui()
			bobber.position.y = -0.12 + sin(float(Time.get_ticks_msec()) / 60.0) * 0.03
			if r == "catch":
				var w := snappedf(randf_range(fish_pick.w[0], fish_pick.w[1]), 0.1)
				_toast("%s %s yakaladın!  %.1f kg  +%d 🐟" % [fish_pick.icon, fish_pick.name, w, fish_pick.amt], "level")
				_sfx("harvest")
				_burst(fish_at + Vector3(0, 0.3, 0), "#90caf9", 16, 3.0)
				if net_role == "guest":
					rpc_id(1, "net_req", "@fish", fish_pick.id, int(w * 10.0), 0)
				_fish_reward(fish_pick.id, w)
				_fish_end()
				return
			if r == "escape":
				_toast("🐟 %s kaçtı… Bir dahaki sefere!" % fish_pick.name, "hint")
				_sfx("error")
				_fish_end()
				return
	if fish_rod != null and fish_rod.visible and fish_line != null:
		var tip := fish_rod.global_transform * Vector3(0, 1.7, 0)
		var im: ImmediateMesh = fish_line.mesh
		im.clear_surfaces()
		im.surface_begin(Mesh.PRIMITIVE_LINES)
		im.surface_add_vertex(tip)
		im.surface_add_vertex(bobber.position + Vector3(0, 0.05, 0))
		im.surface_end()

## Balıkçı tezgâhı: olta, yem, yem seçimi ve balık defteri.
func _open_fish_shop() -> void:
	for c in land_box.get_children():
		land_box.remove_child(c)
		c.queue_free()
	shop_open = true
	var t := Label.new()
	t.text = "🎣 Balıkçı Tezgâhı"
	t.add_theme_font_size_override("font_size", 26)
	land_box.add_child(t)
	var st := Label.new()
	var rods := ["yok", "Bambu Olta", "Usta Oltası"]
	st.text = "Oltan: %s   ·   🪱 %d   ✨ %d" % [rods[clampi(int(fishgear.rod), 0, 2)], int(fishgear.bait), int(fishgear.bait2)]
	st.add_theme_color_override("font_color", Color("#7a5a3a"))
	land_box.add_child(st)
	for it in FISH_SHOP:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var l := Label.new()
		l.text = "%s\n%s" % [it[1], it[4]]
		l.custom_minimum_size = Vector2(300, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 13)
		row.add_child(l)
		var owned: bool = (it[0] == "rod1" and int(fishgear.rod) >= 1) or (it[0] == "rod2" and int(fishgear.rod) >= 2)
		var lbl := "Sende" if owned else ("🔒 Sv %d" % it[3] if level < int(it[3]) else "%d 🪙" % it[2])
		var id: String = it[0]
		row.add_child(_small_btn("  %s  " % lbl, func(): _fish_buy(id), not owned and level >= int(it[3]) and coins >= int(it[2]), true))
		land_box.add_child(row)
	if int(fishgear.bait2) > 0:
		var tg := CheckBox.new()
		tg.text = "✨ Parlak yemi kullan (bitince solucana geçer)"
		tg.button_pressed = bool(fishgear.use2)
		tg.toggled.connect(func(on: bool): fishgear.use2 = on)
		land_box.add_child(tg)
	var jt := Label.new()
	jt.text = "📖 Balık defteri"
	jt.add_theme_font_size_override("font_size", 18)
	land_box.add_child(jt)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	for f in FISH:
		var e: Dictionary = fishgear.log.get(f.id, {})
		var fl := Label.new()
		fl.add_theme_font_size_override("font_size", 13)
		if e.is_empty():
			fl.text = "❔ ???"
			fl.add_theme_color_override("font_color", Color("#a08a70"))
		else:
			fl.text = "%s %s  ×%d · en büyük %.1f kg" % [f.icon, f.name, int(e.n), float(e.best)]
		grid.add_child(fl)
	land_box.add_child(grid)
	var hint := Label.new()
	hint.text = "Göle tıkla: çiftçi kıyıya yürür, oltayı atar. ❗ çıkınca tıkla, sonra mini oyunda balığı yeşil alanda tut. Yayın balığı geceleri çıkar."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color("#8a7260"))
	land_box.add_child(hint)
	land_box.add_child(_small_btn("  Kapat  ", func():
		shop_open = false
		land_dlg.visible = false, true, true))
	land_dlg.visible = true

# ============================================================ fırın
func _recipe(id: String) -> Dictionary:
	for rc in RECIPES:
		if rc.id == id:
			return rc
	return {}

func _recipe_ok(rc: Dictionary) -> bool:
	if rc.is_empty() or level < int(rc.level):
		return false
	for r in rc.need:
		if int(res.get(r, 0)) < int(rc.need[r]):
			return false
	return true

static func _recipe_text(rc: Dictionary) -> String:
	var parts := []
	for r in rc.need:
		parts.append("%d %s" % [rc.need[r], Data.RESOURCES[r].icon])
	return " + ".join(parts)

func _open_oven() -> void:
	for c in land_box.get_children():
		land_box.remove_child(c)
		c.queue_free()
	shop_open = false
	var t := Label.new()
	t.text = "🔥 Fırın"
	t.add_theme_font_size_override("font_size", 26)
	land_box.add_child(t)
	var d := Label.new()
	d.text = "Bir tarif seç, sonra körükle fırını ısıt: ısıyı yeşil bantta tutarak hamuru pişir. Çabuk ve iyi pişirirsen +1 ürün."
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.add_theme_color_override("font_color", Color("#7a5a3a"))
	land_box.add_child(d)
	for rc in RECIPES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var l := Label.new()
		var have := []
		for r in rc.need:
			have.append("%s %d/%d" % [Data.RESOURCES[r].icon, int(res.get(r, 0)), int(rc.need[r])])
		l.text = "%s %s  (%d 🪙)\n%s" % [rc.icon, rc.name, int(Data.RESOURCES[rc.id].price), "   ".join(have)]
		l.custom_minimum_size = Vector2(300, 0)
		row.add_child(l)
		var id: String = rc.id
		var lbl := ("🔒 Sv %d" % rc.level) if level < int(rc.level) else "Pişir"
		row.add_child(_small_btn("  %s  " % lbl, func():
			land_dlg.visible = false
			_bake_start(id), _recipe_ok(rc), true))
		land_box.add_child(row)
	var tip := Label.new()
	tip.text = "Un değirmenden, yumurta kümesten, balık gölden, süt inekten, meyve ağaçlardan gelir. Fırın ürünleri pazar siparişlerinde de istenir."
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_theme_font_size_override("font_size", 12)
	tip.add_theme_color_override("font_color", Color("#8a7260"))
	land_box.add_child(tip)
	land_box.add_child(_small_btn("  Kapat  ", func(): land_dlg.visible = false, true, true))
	land_dlg.visible = true

func _bake_start(id: String) -> bool:
	var rc := _recipe(id)
	if bake_state != "" or mill_state != "" or not _recipe_ok(rc):
		return false
	_fish_end()
	bake_state = "game"
	bake_stoke = 0
	bake_g = {"id": id, "h": 0.25, "c": 0.55, "t": 0.0, "p": 0.0, "in": false, "end": 0.0, "res": ""}
	_build_bake_ui()
	bake_ui.visible = true
	bake_msg.text = "🔥 Körükle: tıkla / Boşluk"
	return true

## Pişirme adımı: stokes körük sayısı. "" sürüyor, "done" pişti, "time" süre bitti.
func _bake_step(dt: float, stokes: int) -> String:
	var g := bake_g
	g.t = float(g.t) + dt
	g.h = clampf(float(g.h) + 0.085 * stokes - 0.15 * dt, 0.0, 1.0)
	g.c = 0.55 + 0.17 * sin(float(g.t) * 0.8)
	g["in"] = absf(float(g.h) - float(g.c)) < 0.1
	if g["in"]:
		g.p = float(g.p) + dt / 5.5
	elif float(g.h) >= 0.98:
		g.p = maxf(0.0, float(g.p) - dt * 0.25)   # yanıyor
	if float(g.p) >= 1.0:
		return "done"
	if float(g.t) >= 16.0:
		return "time"
	return ""

func _update_bake(dt: float) -> void:
	if bake_state != "game":
		return
	if float(bake_g.end) > 0.0:
		bake_g.end = float(bake_g.end) - dt
		if float(bake_g.end) <= 0.0:
			bake_state = ""
			bake_ui.visible = false
			var qty := 0
			if bake_g.res == "done":
				qty = 2 if float(bake_g.t) <= 9.5 else 1
			elif float(bake_g.p) >= 0.5:
				qty = 1
			if net_role == "guest":
				rpc_id(1, "net_req", "@bake", bake_g.id, qty, 0)
				var rc := _recipe(bake_g.id)
				for r in rc.need:
					res[r] = maxi(0, int(res.get(r, 0)) - int(rc.need[r]))
				res[bake_g.id] = int(res.get(bake_g.id, 0)) + qty
			else:
				_bake_finish(bake_g.id, qty)
		return
	var r := _bake_step(dt, bake_stoke)
	bake_stoke = 0
	if r != "":
		bake_g.res = r
		bake_g.end = 0.8
		if r == "done":
			bake_msg.text = "✨ Altın kıvamında!" if float(bake_g.t) <= 9.5 else "👍 Pişti!"
			_sfx("level")
		else:
			bake_msg.text = "⏳ Süre bitti" + (" · biraz çiğ ama yenir" if float(bake_g.p) >= 0.5 else " · hamur çiğ kaldı")
			_sfx("error")
	elif float(bake_g.h) >= 0.98:
		bake_msg.text = "🔥🔥 Çok sıcak! Yanıyor!"
	elif bake_g["in"]:
		bake_msg.text = "👌 Tam kıvamında"
	else:
		bake_msg.text = "🔥 Körükle: tıkla / Boşluk" if float(bake_g.h) < float(bake_g.c) else "Biraz soğusun…"
	bake_bar.value = float(bake_g.p)
	bake_therm.queue_redraw()
	bake_ui.reset_size()
	var vs := get_viewport().get_visible_rect().size
	bake_ui.position = Vector2((vs.x - bake_ui.size.x) / 2.0, (vs.y - bake_ui.size.y) / 2.0 + 30.0)

## Ev sahibinde: malzemeyi düş, ürünü ambara koy.
func _bake_finish(id: String, qty: int) -> bool:
	var rc := _recipe(id)
	if not _recipe_ok(rc):
		return false
	qty = clampi(qty, 0, 2)
	for r in rc.need:
		res[r] = int(res.get(r, 0)) - int(rc.need[r])
	if qty > 0:
		res[id] = int(res.get(id, 0)) + qty
		_gain(0, int(rc.xp) * qty, farmer.position, rc.icon)
		_quest_event("bake", id, 1)
		_toast("%s %s pişti! +%d %s" % [rc.icon, rc.name, qty, rc.icon], "level")
	else:
		_toast("🥲 %s çiğ kaldı, malzeme gitti." % rc.name, "warn")
	net_quest_dirty = true
	hud_dirty = true
	if barn.visible:
		_render_barn()
	return true

func _build_bake_ui() -> void:
	if bake_ui != null:
		return
	bake_ui = _panel(14)
	bake_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(bake_ui)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bake_ui.add_child(v)
	var t := Label.new()
	t.text = "🔥 Fırın ısısı"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 20)
	v.add_child(t)
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(cc)
	bake_therm = Control.new()
	bake_therm.custom_minimum_size = Vector2(90, 230)
	bake_therm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bake_therm.draw.connect(_draw_bake)
	cc.add_child(bake_therm)
	bake_msg = Label.new()
	bake_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bake_msg.custom_minimum_size = Vector2(280, 0)
	bake_msg.add_theme_font_size_override("font_size", 16)
	v.add_child(bake_msg)
	bake_bar = ProgressBar.new()
	bake_bar.show_percentage = false
	bake_bar.max_value = 1.0
	bake_bar.step = 0.001
	bake_bar.custom_minimum_size = Vector2(280, 12)
	bake_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bake_bar.add_theme_stylebox_override("background", _sb(Color("#eadcc6"), 4, Color(0, 0, 0, 0), 0, 0))
	bake_bar.add_theme_stylebox_override("fill", _sb(Color("#d98b5f"), 4, Color(0, 0, 0, 0), 0, 0))
	v.add_child(bake_bar)
	var h := Label.new()
	h.text = "Her tık ısıyı artırır, fırın kendiliğinden soğur · Esc: vazgeç"
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_font_size_override("font_size", 12)
	h.add_theme_color_override("font_color", Color("#8a7260"))
	v.add_child(h)

func _draw_bake() -> void:
	if bake_g.is_empty():
		return
	var w := 46.0
	var hh := 210.0
	var x0 := (bake_therm.size.x - w) / 2.0
	var y0 := 8.0
	bake_therm.draw_rect(Rect2(x0 - 4, y0 - 4, w + 8, hh + 8), Color("#6d4c41"))
	bake_therm.draw_rect(Rect2(x0, y0, w, hh), Color("#3e2723"))
	var c := float(bake_g.c)
	bake_therm.draw_rect(Rect2(x0, y0 + hh * (1.0 - c - 0.1), w, hh * 0.2), Color(0.49, 0.77, 0.31, 0.9))
	var hv := float(bake_g.h)
	var col := Color("#ffb74d").lerp(Color("#e53935"), hv)
	bake_therm.draw_rect(Rect2(x0 + 12, y0 + hh * (1.0 - hv), w - 24, hh * hv), col)
	bake_therm.draw_rect(Rect2(x0 - 8, y0 + hh * (1.0 - hv) - 2, w + 16, 4), Color.WHITE)
	bake_therm.draw_circle(Vector2(x0 + w / 2.0, y0 + hh + 10), 14.0, col)

# ============================================================ değirmen
func _near_mill(p: Vector3) -> bool:
	return Vector2(p.x - MILL_POS.x, p.z - MILL_POS.z).length() < 2.8

func _open_mill() -> void:
	for c in land_box.get_children():
		land_box.remove_child(c)
		c.queue_free()
	shop_open = false
	var t := Label.new()
	t.text = "🌬️ Değirmen"
	t.add_theme_font_size_override("font_size", 26)
	land_box.add_child(t)
	var d := Label.new()
	d.text = "Tahılı una çevir: %d 🌾 Tahıl → en çok %d 🥖 Un. Un ambarda tahıldan çok daha değerli (🌾 %d 🪙, 🥖 %d 🪙)." % [MILL_IN, MILL_ROUNDS, Data.RESOURCES.cereal.price, Data.RESOURCES.flour.price]
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.add_theme_color_override("font_color", Color("#7a5a3a"))
	land_box.add_child(d)
	var st := Label.new()
	st.text = "Ambarda: 🌾 %d   ·   🥖 %d" % [int(res.get("cereal", 0)), int(res.get("flour", 0))]
	st.add_theme_font_size_override("font_size", 18)
	land_box.add_child(st)
	var how := Label.new()
	how.text = "Nasıl: taşın etrafında ibre döner. İbre yeşil bölgedeyken tıkla (ya da Boşluk). Altın ortası ✨ mükemmel: fazladan XP. %d tur, her tur biraz daha hızlı." % MILL_ROUNDS
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.add_theme_font_size_override("font_size", 13)
	how.add_theme_color_override("font_color", Color("#8a7260"))
	land_box.add_child(how)
	var why := ""
	if level < MILL_LEVEL:
		why = "⭐ Değirmen seviye %d'de açılır" % MILL_LEVEL
	elif int(res.get("cereal", 0)) < MILL_IN:
		why = "🌾 En az %d tahıl gerekli (buğday ve mısır hasadı ambara tahıl olarak gelir)" % MILL_IN
	if why != "":
		var w := Label.new()
		w.text = why
		w.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		w.add_theme_color_override("font_color", Color("#c62828"))
		land_box.add_child(w)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_small_btn("  ⚙️ Öğüt  ", func():
		land_dlg.visible = false
		_mill_start(), why == "", true))
	row.add_child(_small_btn("  Kapat  ", func(): land_dlg.visible = false))
	land_box.add_child(row)
	land_dlg.visible = true

func _mill_start() -> bool:
	if mill_state != "" or level < MILL_LEVEL or int(res.get("cereal", 0)) < MILL_IN:
		return false
	_fish_end()
	mill_state = "game"
	mill_g = {"round": 0, "a": 0.0, "lap": 0.0, "hits": [], "wait": 0.0}
	_mill_new_round()
	_build_mill_ui()
	mill_ui.visible = true
	mill_msg.text = "İbre yeşile gelince tıkla!"
	_mill_layout()
	return true

func _mill_new_round() -> void:
	var rd := int(mill_g.round)
	mill_g.zone = randf() * TAU
	mill_g.zw = maxf(0.22, 0.46 - rd * 0.05)    # yeşil yarı genişlik (radyan)
	mill_g.pw = 0.11                            # altın orta
	mill_g.speed = 2.3 + rd * 0.45
	mill_g.lap = 0.0
	mill_g.a = fmod(float(mill_g.zone) + PI, TAU)   # ibre bölgenin karşısından başlar

## İbre açısına göre sonuç: 2 mükemmel, 1 iyi, 0 ıska.
static func _mill_judge(a: float, zone: float, zw: float, pw: float) -> int:
	var dd := absf(wrapf(a - zone, -PI, PI))
	if dd <= pw:
		return 2
	if dd <= zw:
		return 1
	return 0

func _mill_hit() -> void:
	if mill_state != "game" or float(mill_g.wait) > 0.0:
		return
	var r := _mill_judge(float(mill_g.a), float(mill_g.zone), float(mill_g.zw), float(mill_g.pw))
	_mill_record(r)

func _mill_record(r: int) -> void:
	mill_g.hits.append(r)
	mill_msg.text = ["❌ Iska!", "👍 İyi!", "✨ Mükemmel!"][r]
	if r > 0:
		mill_spin = 2.5 + r
		_sfx("harvest" if r == 2 else "place")
	else:
		_sfx("error")
	mill_g.round = int(mill_g.round) + 1
	mill_g.wait = 0.55
	if int(mill_g.round) >= MILL_ROUNDS:
		mill_g.wait = 0.9

func _update_mill(dt: float) -> void:
	if mill_state != "game":
		return
	if float(mill_g.wait) > 0.0:
		mill_g.wait = float(mill_g.wait) - dt
		if float(mill_g.wait) <= 0.0:
			if int(mill_g.round) >= MILL_ROUNDS:
				var good := 0
				var perfect := 0
				for h in mill_g.hits:
					if int(h) > 0:
						good += 1
					if int(h) == 2:
						perfect += 1
				_mill_done(good, perfect)
				return
			_mill_new_round()
			mill_msg.text = "Tur %d / %d" % [int(mill_g.round) + 1, MILL_ROUNDS]
	else:
		var step := float(mill_g.speed) * dt
		mill_g.a = fmod(float(mill_g.a) + step, TAU)
		mill_g.lap = float(mill_g.lap) + step
		if float(mill_g.lap) > TAU * 2.2:   # iki tur bekledi: ıska say
			_mill_record(0)
	_mill_layout()

func _mill_done(good: int, perfect: int) -> void:
	mill_state = ""
	if mill_ui != null:
		mill_ui.visible = false
	if net_role == "guest":
		rpc_id(1, "net_req", "@mill", "", good, perfect)
		res["cereal"] = maxi(0, int(res.get("cereal", 0)) - MILL_IN)
		res["flour"] = int(res.get("flour", 0)) + good
		_toast("🌬️ Öğütme bitti: +%d 🥖 Un" % good, "level")
		return
	_mill_finish(good, perfect)

## Ev sahibinde: tahılı düş, unu ekle, XP ver.
func _mill_finish(good: int, perfect: int) -> bool:
	good = clampi(good, 0, MILL_ROUNDS)
	perfect = clampi(perfect, 0, good)
	if int(res.get("cereal", 0)) < MILL_IN:
		return false
	res["cereal"] = int(res.get("cereal", 0)) - MILL_IN
	res["flour"] = int(res.get("flour", 0)) + good
	var p := Vector3(MILL_POS.x, 1.5, MILL_POS.z)
	_gain(0, good * 2 + perfect * 2, farmer.position, "🥖")
	if good == MILL_ROUNDS and perfect == MILL_ROUNDS:
		_toast("🌬️ Kusursuz öğütme! +%d 🥖 Un" % good, "level")
	else:
		_toast("🌬️ Öğütme bitti: +%d 🥖 Un  (%d mükemmel)" % [good, perfect], "level")
	_burst(p + Vector3(0, 2.0, 0), "#fff8e1", 18, 3.0)
	net_quest_dirty = true
	hud_dirty = true
	if barn.visible:
		_render_barn()
	return true

func _build_mill_ui() -> void:
	if mill_ui != null:
		return
	mill_ui = _panel(14)
	mill_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(mill_ui)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mill_ui.add_child(v)
	var t := Label.new()
	t.text = "🌬️ Değirmen taşı"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 20)
	v.add_child(t)
	mill_dial = Control.new()
	mill_dial.custom_minimum_size = Vector2(230, 230)
	mill_dial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mill_dial.draw.connect(_draw_mill_dial)
	v.add_child(mill_dial)
	mill_msg = Label.new()
	mill_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mill_msg.add_theme_font_size_override("font_size", 18)
	v.add_child(mill_msg)
	mill_row = Label.new()
	mill_row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mill_row.add_theme_font_size_override("font_size", 22)
	v.add_child(mill_row)
	var h := Label.new()
	h.text = "Tıkla / Boşluk · Esc: vazgeç"
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_font_size_override("font_size", 12)
	h.add_theme_color_override("font_color", Color("#8a7260"))
	v.add_child(h)

func _draw_mill_dial() -> void:
	if mill_g.is_empty():
		return
	var c := mill_dial.size / 2.0
	var r := 88.0
	mill_dial.draw_circle(c, r + 14.0, Color("#bfae98"))
	mill_dial.draw_circle(c, r - 14.0, Color("#9e8e7a"))
	mill_dial.draw_arc(c, r, 0.0, TAU, 72, Color("#e8dcc8"), 20.0)
	var z := float(mill_g.zone)
	mill_dial.draw_arc(c, r, z - float(mill_g.zw), z + float(mill_g.zw), 24, Color("#7cc44e"), 20.0)
	mill_dial.draw_arc(c, r, z - float(mill_g.pw), z + float(mill_g.pw), 12, Color("#f4c430"), 20.0)
	for i in 8:   # taşın oyukları
		var aa := TAU * i / 8.0 + float(mill_g.a) * 0.3
		mill_dial.draw_line(c + Vector2(cos(aa), sin(aa)) * 18.0, c + Vector2(cos(aa), sin(aa)) * (r - 18.0), Color("#8a7a66"), 3.0)
	var a := float(mill_g.a)
	mill_dial.draw_line(c, c + Vector2(cos(a), sin(a)) * (r + 16.0), Color("#4e342e"), 6.0)
	mill_dial.draw_circle(c, 12.0, Color("#5d4037"))

func _mill_layout() -> void:
	var icons := ""
	for i in MILL_ROUNDS:
		if i < mill_g.hits.size():
			icons += ["❌", "🥖", "✨"][int(mill_g.hits[i])] + " "
		else:
			icons += "⚪ "
	mill_row.text = icons
	mill_dial.queue_redraw()
	mill_ui.reset_size()
	var vs := get_viewport().get_visible_rect().size
	mill_ui.position = Vector2((vs.x - mill_ui.size.x) / 2.0, (vs.y - mill_ui.size.y) / 2.0 + 40.0)

# ============================================================ arazi (parseller)
func _build_land_ui() -> void:
	land_dlg = ColorRect.new()
	land_dlg.color = Color(0.12, 0.2, 0.08, 0.35)
	land_dlg.set_anchors_preset(Control.PRESET_FULL_RECT)
	land_dlg.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(land_dlg)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	land_dlg.add_child(cc)
	var p := _panel(22)
	p.custom_minimum_size = Vector2(400, 0)
	cc.add_child(p)
	land_box = VBoxContainer.new()
	land_box.add_theme_constant_override("separation", 10)
	p.add_child(land_box)
	land_dlg.visible = false

func _open_land() -> void:
	shop_open = false
	if net_role == "guest":
		_toast("🗺️ Arazi genişletme çiftlik sahibinde.", "hint")
		return
	for c in land_box.get_children():
		land_box.remove_child(c)
		c.queue_free()
	var nx := _expand_next()
	var t := Label.new()
	t.text = "🗺️ Arazi"
	t.add_theme_font_size_override("font_size", 26)
	land_box.add_child(t)
	var d := Label.new()
	d.text = "Çiftliğin şu an %d×%d kare. Genişletince çit dışarı taşınır, yeni toprak açılır." % [farm_h * 2, farm_h * 2]
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.add_theme_color_override("font_color", Color("#7a5a3a"))
	land_box.add_child(d)
	# küçük harita: dünya, sıradaki kare, şimdiki kare
	var px := 5.0
	var full := (WORLD_MAX + 1 - WORLD_MIN) * px
	var mc := CenterContainer.new()
	var mp := Control.new()
	mp.custom_minimum_size = Vector2(full, full)
	mc.add_child(mp)
	land_box.add_child(mc)
	var sq := func(h: int, col: Color) -> void:
		var cr := ColorRect.new()
		cr.color = col
		cr.position = Vector2(full / 2.0 - h * px, full / 2.0 - h * px)
		cr.size = Vector2(h * 2 * px, h * 2 * px)
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mp.add_child(cr)
	sq.call(WORLD_MAX + 1, Color("#4f7f34"))
	for st in EXPAND:
		if int(st[0]) > farm_h:
			sq.call(int(st[0]), Color("#5d8f3d") if int(st[0]) % 4 == 0 else Color("#56873a"))
	if not nx.is_empty():
		sq.call(int(nx[0]), Color("#ffe082"))
	sq.call(farm_h, Color("#9ccc65"))
	var dot := Label.new()
	dot.text = "🏡"
	dot.position = Vector2(full / 2.0 - 11, full / 2.0 - 14)
	mp.add_child(dot)
	if nx.is_empty():
		var w0 := Label.new()
		w0.text = "🎉 Çiftliğin en büyük boyda: %d×%d." % [farm_h * 2, farm_h * 2]
		land_box.add_child(w0)
		land_box.add_child(_small_btn("  Kapat  ", func(): land_dlg.visible = false, true, true))
		land_dlg.visible = true
		return
	var b := Label.new()
	b.text = "Sıradaki: %d×%d  (sarı alan, +%d kare)\nBedel: %d 🪙\nGerekli seviye: %d   (sen: %d)" % [int(nx[0]) * 2, int(nx[0]) * 2, (int(nx[0]) * 2) * (int(nx[0]) * 2) - (farm_h * 2) * (farm_h * 2), int(nx[1]), int(nx[2]), level]
	land_box.add_child(b)
	var ok := coins >= int(nx[1]) and level >= int(nx[2])
	if not ok:
		var w := Label.new()
		w.text = "⭐ Seviye yetmiyor" if level < int(nx[2]) else "🪙 Altın yetmiyor"
		w.add_theme_color_override("font_color", Color("#c62828"))
		land_box.add_child(w)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_small_btn("  Genişlet  ", func():
		if _expand_farm():
			_open_land(), ok, true))
	row.add_child(_small_btn("  Kapat  ", func(): land_dlg.visible = false))
	land_box.add_child(row)
	land_dlg.visible = true

func _selftest_story(fails: Array) -> void:
	var keep_q = quests
	story_step = 0
	story_have = 0
	var c0 := coins
	_quest_event("clear", "weed", 6)
	if story_step != 1: fails.append("hikâye 1. adım geçmedi")
	if coins < c0 + STORY[0].coins: fails.append("hikâye ödülü yok")
	_quest_event("plant", "carrot", 6)
	if story_step != 1: fails.append("hikâye yanlış olayla ilerledi")
	_fill_quests()
	if not quests.is_empty(): fails.append("hikâye sürerken rastgele görev")
	for i in range(1, STORY.size()):
		var st: Dictionary = STORY[i]
		_quest_event(st.kind, st.arg if st.arg != "" else "x", st.need)
	if _story_on(): fails.append("hikâye bitmedi")
	if quests.size() != QUEST_SLOTS: fails.append("hikâye sonrası görev gelmedi")
	quests = keep_q
	var d := _add_entity({"kind": "debris", "type": "stone", "x": 11, "z": -11})
	if _walkable(11, -11): fails.append("taş yolu kapatmıyor")
	if not _perform({"tool": "remove", "arg": null, "x": 11, "z": -11}): fails.append("taş kaldırılamadı")
	if tiles.has(key(11, -11)): fails.append("taş kaldı")

func _selftest_net(fails: Array) -> void:
	var d := _state_dict()
	var js = JSON.parse_string(JSON.stringify(d))
	if typeof(js) != TYPE_DICTIONARY or js.ents.size() != d.ents.size(): fails.append("durum JSON gidiş-dönüş")
	var plot = null
	for e in entities:
		if e.kind == "plot" and e.crop != null:
			plot = e
			break
	if plot != null:
		var s := _ent_dict(plot)
		s.p = 1.0
		_net_apply_ents([s] + js.ents.filter(func(q): return not (int(q.x) == plot.x and int(q.z) == plot.z)))
		if tiles.get(key(plot.x, plot.z)).progress < 1.0: fails.append("senkron ilerleme uygulanmadı")

func _selftest_gates(fails: Array) -> void:
	if _walkable(farm_h, 0): fails.append("sınır çiti yürünebilir")
	var pth = _find_path(Vector3(5.5, 0, 5.5), Rect2(farm_h + 3, 5, 1, 1), 0.0)
	if pth == null:
		fails.append("çiftlik dışına yol yok")
	else:
		var via_gate := false
		for w in pth:
			if w.z > farm_h - 1 and absf(w.x) < 2.5:
				via_gate = true
		if not via_gate: fails.append("yol kapıdan geçmiyor")
	var gate = tiles.get(key(-3, 4))
	if gate == null or gate.get("type", "") != "gate":
		fails.append("ağıl kapısı yok")
		return
	var keep := farmer.position
	farmer.position = Vector3(-2.0, 0, 4.5)
	for i in 30:
		_update_gates(0.05)
	if gate.get("door") == null or absf(gate.door.rotation.y) < 1.0: fails.append("kapı açılmadı")
	farmer.position = Vector3(5, 0, 8)
	for i in 60:
		_update_gates(0.05)
	if absf(gate.door.rotation.y) > 0.1: fails.append("kapı kapanmadı")
	farmer.position = keep
	_set_tool("seed", true)
	if not shelf_panel.visible: fails.append("tohum penceresi açılmadı")
	_set_tool("hand")
	if shelf_panel.visible: fails.append("el seçilince pencere açık kaldı")

func _free_spot(w: int, d: int) -> Vector2i:
	for z in range(-farm_h, farm_h - d + 1):
		for x in range(-farm_h, farm_h - w + 1):
			if _free_area(x, z, w, d):
				return Vector2i(x, z)
	return Vector2i(999, 999)

func _selftest_build(fails: Array) -> void:
	coins = 10000
	level = 10
	var b0 := _count_buildings("barn")
	var cap0 := _barn_cap()
	var sp := _free_spot(4, 4)
	if sp.x == 999:
		fails.append("ambar için yer yok")
		return
	if not _perform({"x": sp.x, "z": sp.y, "tool": "build", "arg": "barn"}): fails.append("ambar kurma")
	var be = tiles.get(key(sp.x + 3, sp.y + 3))
	if be == null or be.kind != "building" or be.type != "barn": fails.append("ambar 4×4 değil")
	if _count_buildings("barn") != b0 + 1 or _barn_cap() != cap0 + Data.BARN_CAP: fails.append("ambar kapasitesi artmadı")
	if _perform({"x": sp.x + 1, "z": sp.y + 1, "tool": "build", "arg": "silo"}): fails.append("dolu yere bina")
	var ws := _free_spot(1, 1)
	_perform({"x": ws.x, "z": ws.y, "tool": "build", "arg": "well"})
	var ps := Vector2i(ws.x + 1, ws.y)
	if not tiles.has(key(ps.x, ps.y)) and in_farm(ps.x, ps.y):
		_perform({"x": ps.x, "z": ps.y, "tool": "plow", "arg": null})
		var pe = tiles.get(key(ps.x, ps.y))
		if pe == null or not pe.get("wn", false): fails.append("kuyu bonusu")
	# taşı: ambar bir kare kayar (kendi yerine taşabilir), dolu yere gitmez
	if _free_area(sp.x + 4, sp.y, 1, 4):
		var c1 := coins
		if not _perform({"x": sp.x + 1, "z": sp.y, "tool": "move", "arg": "%d,%d" % [sp.x, sp.y]}): fails.append("ambar taşıma")
		var mb = tiles.get(key(sp.x + 4, sp.y))
		if mb == null or mb.type != "barn" or tiles.has(key(sp.x, sp.y)) or coins != c1: fails.append("ambar yeni yerinde değil")
		if not _perform({"x": sp.x, "z": sp.y, "tool": "move", "arg": "%d,%d" % [sp.x + 1, sp.y]}): fails.append("ambarı geri taşıma")
	var wl = tiles.get(key(ws.x, ws.y))
	if wl != null and wl.get("type", "") == "well" and _resolve("move", "%d,%d" % [sp.x, sp.y], ws.x, ws.y) != null: fails.append("dolu yere taşıma")
	var tb = tiles.get(key(sp.x, sp.y))
	var r0: float = tb.rot
	_turn_entity(tb)
	if absf(fmod(tb.rot - r0 + TAU, TAU) - PI / 2.0) > 0.01 or tiles.get(key(sp.x, sp.y)) != tb: fails.append("döndürme")
	hold_at = Vector2(300, 300)
	_open_ctx(tb)
	if ctx_menu == null or not ctx_menu.visible or ctx_box.get_child_count() < 4: fails.append("basılı tut menüsü")
	ctx_menu.visible = false
	var lamp := _free_spot(1, 1)
	if lamp.x != 999:
		var le := _add_entity({"kind": "decor", "type": "lantern", "x": lamp.x, "z": lamp.y})
		_open_ctx(le)
		if not ctx_menu.visible or not str(ctx_box.get_child(0).text).contains(Data.DECOR.lantern.name): fails.append("fener menüsü")
		ctx_menu.visible = false
		var lr: float = le.rot
		_turn_entity(le)
		if absf(fmod(le.rot - lr + TAU, TAU) - PI / 2.0) > 0.01: fails.append("fener döndürme")
		_remove_entity(le)
	# hikâye: kümes önceden kurulduysa adım kendiliğinden geçer
	var ks := story_step
	var kh := story_have
	for i in STORY.size():
		if STORY[i].kind == "buy" and STORY[i].arg == "coop":
			story_step = i
	story_have = 0
	var has_coop := false
	for e in entities:
		if e.kind == "coop":
			has_coop = true
	_story_catchup()
	if has_coop and STORY[story_step].arg == "coop": fails.append("hikâye önceden kurulan kümesi saymadı")
	story_step = ks
	story_have = kh
	# sınır çiti: içeriye konan çite bağlanır
	var fx := -farm_h
	var fz := 0
	if not tiles.has(key(fx, fz)):
		var fe := _add_entity({"kind": "decor", "type": "fence", "x": fx, "z": fz})
		if not _is_fence(fx - 1, fz): fails.append("sınır çiti çit sayılmıyor")
		if not frame_fences.has(Vector2i(fx - 1, fz)): fails.append("sınır çiti parçası yok")
		_remove_entity(fe)
	_show_emote(farmer, 0)
	if emote_fx.is_empty(): fails.append("emote balonu")
	_update_emotes(3.5)
	if not emote_fx.is_empty(): fails.append("emote kaybolmadı")
	_selftest_fish(fails)
	_selftest_mill(fails)
	_selftest_bake(fails)
	var rb := _refund_of(tiles.get(key(sp.x, sp.y)))
	var c2 := coins
	if not _perform({"x": sp.x, "z": sp.y, "tool": "remove", "arg": null}) or _count_buildings("barn") != b0: fails.append("bina kaldırma")
	if rb != Data.BUILDINGS.barn.cost / 2 or coins != c2 + rb: fails.append("yarı fiyat iade")
	var we = tiles.get(key(ws.x, ws.y))
	if we != null:
		_remove_entity(we)
	var pe2 = tiles.get(key(ps.x, ps.y))
	if pe2 != null and pe2.kind == "plot":
		_remove_entity(pe2)

func _selftest_bake(fails: Array) -> void:
	var keep_res := res.duplicate()
	var keep_lv := level
	level = 10
	coins = 10000
	var sp := _free_spot(2, 2)
	if sp.x == 999 or not _perform({"x": sp.x, "z": sp.y, "tool": "build", "arg": "oven"}):
		fails.append("fırın kurma")
	res = {"flour": 1, "egg": 1}
	if _bake_start("pogaca"): fails.append("malzemesiz pişirme")
	res = {"flour": 4, "egg": 2}
	if not _bake_start("pogaca"): fails.append("pişirme başlamadı")
	var r := ""
	for i in 400:   # ısıyı bantta tut
		r = _bake_step(0.05, 1 if float(bake_g.h) < float(bake_g.c) - 0.03 else 0)
		if r != "":
			break
	if r != "done": fails.append("pişirme bitmedi (%s)" % r)
	bake_state = ""
	bake_ui.visible = false
	if not _bake_finish("pogaca", 2) or int(res.flour) != 2 or int(res.egg) != 1 or int(res.pogaca) != 2: fails.append("pişirme sonucu %s" % res)
	res = {"flour": 0}
	if _bake_finish("pogaca", 1): fails.append("eksik malzemeyle pişti")
	var found := false
	for i in 20:
		_new_order()
		for k in order.need:
			if k == "pogaca" or k == "fishbread" or k == "pie":
				found = true
	if not found: fails.append("siparişte fırın ürünü yok")
	var oe = tiles.get(key(sp.x, sp.y))
	if oe != null:
		_remove_entity(oe)
	res = keep_res
	level = keep_lv
	_new_order()

func _selftest_mill(fails: Array) -> void:
	var keep_res := res.duplicate()
	if _mill_judge(1.0, 1.0, 0.4, 0.1) != 2 or _mill_judge(1.3, 1.0, 0.4, 0.1) != 1 or _mill_judge(2.0, 1.0, 0.4, 0.1) != 0: fails.append("değirmen hakemi")
	if _mill_judge(0.05, TAU - 0.05, 0.4, 0.15) != 2: fails.append("değirmen açı sarması")
	if not _near_mill(MILL_POS) or _near_mill(Vector3.ZERO): fails.append("değirmen algılama")
	res = {"cereal": 4}
	if _mill_start(): fails.append("tahılsız öğütme")
	res = {"cereal": 10}
	if not _mill_finish(4, 1) or int(res.cereal) != 4 or int(res.flour) != 4: fails.append("öğütme sonucu %s" % res)
	if _mill_finish(5, 0): fails.append("eksik tahılla öğütme")
	res = {"cereal": 10}
	level = maxi(level, MILL_LEVEL)
	if not _mill_start(): fails.append("öğütme başlamadı")
	for i in MILL_ROUNDS:
		mill_g.a = mill_g.zone
		mill_g.wait = 0.0
		_mill_hit()
	_update_mill(1.0)
	if mill_state != "" or int(res.get("flour", 0)) != MILL_ROUNDS: fails.append("tam öğütme %s" % res)
	res = keep_res

func _selftest_fish(fails: Array) -> void:
	var keep_g := fishgear.duplicate(true)
	var keep_res := res.duplicate()
	fishgear = {"rod": 0, "bait": 0, "bait2": 0, "use2": false, "log": {}}
	coins = 5000
	level = 10
	_start_fishing(Vector3(POND_X, 0, POND_Z))
	if fish_state != "": fails.append("oltasız balık tutuldu")
	if not _fish_buy("rod1") or int(fishgear.rod) != 1: fails.append("olta alma")
	if _fish_buy("rod1"): fails.append("olta iki kez alındı")
	if not _fish_buy("bait") or int(fishgear.bait) != 10: fails.append("yem alma")
	if not _in_lake(Vector3(POND_X, 0, POND_Z)) or _in_lake(Vector3(0, 0, 0)): fails.append("göl algılama")
	if not _near_stall(STALL) or _walkable(floori(STALL.x), floori(STALL.z)): fails.append("tezgâh")
	var counts := {}
	for i in 400:
		var f := _fish_roll(false)
		counts[f.id] = counts.get(f.id, 0) + 1
	if counts.get("kizilkanat", 0) < counts.get("turna", 0): fails.append("balık olasılıkları")
	# mini oyun: alanı balığın üstünde tutunca yakalanır, hiç tutmayınca kaçar
	fish_pick = FISH[1]
	fish_g = {"zx": 0.35, "zv": 0.0, "zw": 0.3, "fx": 0.5, "ftx": 0.5, "ft": 99.0, "p": 0.35, "diff": 0.0, "fill": 0.3}
	var r := ""
	for i in 200:
		r = _fish_game_step(0.05, false)
		fish_g.zx = clampf(float(fish_g.fx) - 0.1, 0.0, 0.7)
		if r != "":
			break
	if r != "catch": fails.append("mini oyun yakalama (%s)" % r)
	fish_g = {"zx": 0.0, "zv": 0.0, "zw": 0.3, "fx": 0.9, "ftx": 0.9, "ft": 99.0, "p": 0.35, "diff": 0.5, "fill": 0.3}
	r = ""
	for i in 400:
		r = _fish_game_step(0.05, false)
		if r != "":
			break
	if r != "escape": fails.append("mini oyun kaçma (%s)" % r)
	res = {}
	var x0 := xp
	_fish_reward("sazan", 2.5)
	if int(res.get("fish", 0)) != 2 or fishgear.log.get("sazan", {}).get("n", 0) != 1: fails.append("balık ödülü")
	_fish_reward("sazan", 1.0)
	if absf(float(fishgear.log.sazan.best) - 2.5) > 0.01 or int(fishgear.log.sazan.n) != 2: fails.append("balık defteri")
	if xp == x0 and level == 10: fails.append("balık XP")
	var sv: Dictionary = _state_dict()
	_load_fishgear(sv.fg)
	if int(fishgear.rod) != 1 or int(fishgear.log.sazan.n) != 2: fails.append("balık kaydı")
	_fish_end()
	fishgear = keep_g
	res = keep_res

func _selftest_parcels(fails: Array) -> void:
	var keep_h := farm_h
	farm_h = FARM_H_START
	if in_farm(8, 0) or in_farm(0, -9): fails.append("kare dışı açık")
	if not in_farm(7, 7) or not in_farm(-8, -8): fails.append("başlangıç karesi kapalı")
	if _resolve("plow", null, 9, -1) != null: fails.append("çiftlik dışına çapa")
	coins = 100000
	level = 1
	if _expand_farm(): fails.append("seviyesiz genişleme")
	level = 30
	var c0 := coins
	var nx := _expand_next()
	if not _expand_farm(): fails.append("genişletme")
	if coins != c0 - int(nx[1]): fails.append("genişleme bedeli")
	if farm_h != 10 or not in_farm(9, -10) or in_farm(10, 0): fails.append("kare büyümedi")
	if _resolve("plow", null, 9, -1) != "plow": fails.append("yeni araziye çapa")
	if int(_expand_next()[1]) <= int(nx[1]): fails.append("ikinci adım pahalanmadı")
	while _expand_farm():
		pass
	if farm_h != WORLD_MAX + 1 or not _expand_next().is_empty(): fails.append("en büyük kare")
	if _farm_h_from_parcels([]) != 12 or _farm_h_from_parcels(["2,0"]) != 20: fails.append("eski kayıt arazisi")
	farm_h = keep_h
	_on_farm_resized()

# ============================================================ çarpışma, yol, kümes testleri
func _selftest_paths(fails: Array) -> void:
	_clear_queue()
	var ring := []
	for x in range(8, 11):
		for z in range(-3, 0):
			if x == 9 and z == -2:
				continue
			ring.append(_add_entity({"kind": "decor", "type": "fence", "x": x, "z": z}))
	farmer.position = Vector3(6.5, 0, -2.5)
	_walk_to(Vector3(9.5, 0, -1.5))
	if move_target != null: fails.append("kapalı ağıla yol bulundu")
	var side = tiles[key(9, -1)]
	_remove_entity(side)
	ring.erase(side)
	ring.append(_add_entity({"kind": "decor", "type": "gate", "x": 9, "z": -1}))
	_walk_to(Vector3(9.5, 0, -1.5))
	for i in 300:
		_update_farmer(0.05)
		if _blocked(farmer.position): fails.append("çitin içinden geçti %s" % farmer.position)
	if farmer.position.distance_to(Vector3(9.5, 0, -1.5)) > 0.1: fails.append("kapıdan girilemedi %s" % farmer.position)
	for f in ring:
		_remove_entity(f)
	# kümes
	coins = 1000
	level = 3
	res = {}
	if not _perform({"x": 2, "z": 6, "tool": "animal", "arg": "coop"}): fails.append("kümes kurma")
	var cp = tiles.get(key(3, 7))
	if cp == null or cp.kind != "coop": fails.append("kümes 2×2 değil")
	var ch := _add_entity({"kind": "animal", "type": "chicken", "x": 5, "z": 6, "t": 0.999, "food": 1.0})
	_simulate(1.0)
	if ch.ready or cp.eggs != 1: fails.append("tavuk kümese yumurtlamadı")
	var c0 := coins
	if not _perform({"x": 3, "z": 7, "tool": "hand", "arg": "wheat"}): fails.append("kümesten toplama")
	if coins != c0 + Data.ANIMALS.chicken.sell or res.get("egg", 0) != 2 or cp.eggs != 0: fails.append("kümes hasadı %d %s" % [coins - c0, res])
	_remove_entity(ch)
	_remove_entity(cp)
	res = {}

# ============================================================ görevler (Aşama 5)
func _owned(kind: String, type: String) -> bool:
	for e in entities:
		if e.kind == kind and e.get("type", "") == type:
			return true
	return false

func _owned_kind(kind: String) -> bool:
	for e in entities:
		if e.kind == kind:
			return true
	return false

## Görev şablonu: ihtiyaç ve ödül seviyeye göre ölçeklenir.
func _make_quest(kind: String, arg: String) -> Dictionary:
	var need := 1
	var val := 1.0
	var text := ""
	var lv := level
	match kind:
		"crop":
			var c = Data.CROPS[arg]
			need = maxi(3, int(round(300.0 / c.time))) + lv
			val = c.sell
			text = "%s %d %s topla" % [c.icon, need, c.name]
		"fruit":
			var t = Data.TREES[arg]
			need = 3 + lv / 2
			val = t.sell
			text = "%s %d kez %s topla" % [t.icon, need, t.name]
		"animal":
			var a = Data.ANIMALS[arg]
			need = 3 + lv / 2
			val = a.sell
			text = "%s %d kez %s topla" % [a.picon, need, a.product]
		"flower":
			need = 4 + lv / 2
			val = 20.0
			text = "🌼 %d çiçek tarhı topla" % need
		"fish":
			need = 3 + lv / 3
			val = 40.0
			text = "🐟 %d kez balık tut" % need
		"plant":
			need = 15 + lv * 2
			val = 6.0
			text = "🌱 %d tohum ek" % need
		"water":
			need = 15 + lv * 2
			val = 4.0
			text = "💧 %d kez sula" % need
		"feed":
			need = 4 + lv / 2
			val = 15.0
			text = "🌾 %d kez hayvan yemle" % need
		"sell":
			need = 30 + lv * 5
			val = 3.0
			text = "💰 Ambardan %d kaynak sat" % need
		"order":
			need = 1 + lv / 4
			val = 150.0
			text = "📋 %d pazar siparişi teslim et" % need
		"tree":
			need = 1 + lv / 5
			val = 100.0
			text = "🌳 %d ağaç dik" % need
		"bake":
			need = 2 + lv / 4
			val = 60.0
			text = "🔥 Fırında %d kez pişir" % need
		"earn":
			need = 300 + lv * 100
			val = 0.3
			text = "🪙 %d altın kazan" % need
	var v := need * val
	return {"kind": kind, "arg": arg, "text": text, "need": need, "have": 0,
		"medals": maxi(1, int(v / 60.0)), "gems": 1 if v < 250.0 else 2, "xp": maxi(5, int(v / 5.0))}

func _quest_candidates() -> Array:
	var out := []
	for k in Data.CROPS:
		if Data.CROPS[k].level <= level:
			out.append(["crop", k])
	for k in Data.TREES:
		if _owned("tree", k):
			out.append(["fruit", k])
	for k in Data.ANIMALS:
		if _owned("animal", k):
			out.append(["animal", k])
	out.append(["flower", ""])
	if _owned_kind("pond"):
		out.append(["fish", ""])
	if _count_buildings("oven") > 0:
		out.append(["bake", ""])
	for k in ["plant", "water", "sell", "order", "earn"]:
		out.append([k, ""])
	if _owned_kind("animal"):
		out.append(["feed", ""])
	if Data.TREES.apple.level <= level:
		out.append(["tree", ""])
	var active := {}
	for q in quests:
		active[q.kind + ":" + q.arg] = true
	return out.filter(func(c): return not active.has(c[0] + ":" + c[1]))

func _random_quest() -> Dictionary:
	var c := _quest_candidates()
	var pick = c[randi() % c.size()]
	return _make_quest(pick[0], pick[1])

func _story_on() -> bool:
	return story_step < STORY.size()

func _fill_quests() -> void:
	if net_role == "guest":   # görevler ev sahibinden gelir (net_quests)
		_render_quests()
		return
	if _story_on():
		quests = []
		_render_quests()
		return
	while quests.size() < QUEST_SLOTS:
		quests.append(_random_quest())
	_render_quests()

## Hikâye adımı bir şeyin var olmasını istiyorsa (ambar, kümes, tavuk, ev) ve o şey zaten varsa adım kendiliğinden geçer.
func _story_catchup() -> void:
	if not _story_on() or net_role == "guest":
		return
	var st: Dictionary = STORY[story_step]
	var have := 0
	match st.kind:
		"build":
			have = _count_buildings(st.arg)
		"buy":
			for e in entities:
				if (st.arg == "coop" and e.kind == "coop") or (st.arg != "coop" and e.kind == "animal" and e.type == st.arg):
					have += 1
		_:
			return
	if have > story_have:
		story_have = mini(have, st.need)
		_story_event(st.kind, st.arg, 0)

func _story_event(kind: String, arg: String, n: int) -> void:
	if not _story_on() or net_role == "guest":
		return
	var st: Dictionary = STORY[story_step]
	if st.kind != kind or (st.arg != "" and st.arg != arg):
		return
	story_have = mini(st.need, story_have + n)
	if story_have < st.need:
		_render_quests()
		return
	story_step += 1
	story_have = 0
	call_deferred("_story_catchup")
	_sfx("level")
	if st.say != "":
		_toast_all("⭐ %s" % st.say, "level")
	_gain(st.coins, st.xp, farmer.position, "⭐")
	if not _story_on():
		gems += 3
		_toast("🎉 Çiftlik yeniden canlandı! Nermin Teyze gurur duyardı.\n+3 💎 · Artık günlük görevler de geliyor.", "level")
		_fill_quests()
	hud_dirty = true
	_render_quests()

func _quest_event(kind: String, arg: String, n: int) -> void:
	if n <= 0 or net_role == "guest":   # çiftliğin görevleri ortak: işi ev sahibi uygular ve sayar
		return
	_story_event(kind, arg, n)
	var done := []
	for i in quests.size():
		var q = quests[i]
		if q.kind == kind and (q.arg == "" or q.arg == arg):
			q.have = mini(q.need, q.have + n)
			if q.have >= q.need:
				done.append(i)
	for i in done:
		var q = quests[i]
		medals += q.medals
		gems += q.gems
		quests[i] = _random_quest()
		_toast_all("📜 Görev tamamlandı: %s\n+%d 🏅  +%d 💎  +%d XP" % [q.text, q.medals, q.gems, q.xp], "level")
		_gain(0, q.xp, farmer.position, "📜")
		_sfx("level")
	hud_dirty = true
	_render_quests()

func _skip_quest(i: int) -> bool:
	if net_role == "guest":
		rpc_id(1, "net_req", "@skip", "", i, 0)
		return true
	var now := Time.get_unix_time_from_system()
	if now - quest_skip_at >= QUEST_SKIP_COOLDOWN:
		quest_skip_at = now
	elif gems >= QUEST_SKIP_GEMS:
		gems -= QUEST_SKIP_GEMS
	else:
		var left := QUEST_SKIP_COOLDOWN - (now - quest_skip_at)
		_toast("⏳ Ücretsiz silme %s sonra (ya da %d 💎)" % [fmt_time(left), QUEST_SKIP_GEMS], "warn")
		return false
	var old = quests[i]
	quests.remove_at(i)
	var nq := _random_quest()
	quests.insert(i, nq)
	if nq.kind == old.kind and nq.arg == old.arg and _quest_candidates().size() > 0:
		quests[i] = _random_quest()
	hud_dirty = true
	_render_quests()
	return true

func _build_quest_ui() -> void:
	quest_panel = _panel(10)
	quest_panel.position = Vector2(12, 84)
	quest_panel.custom_minimum_size = Vector2(290, 0)
	quest_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(quest_panel)
	ui.move_child(quest_panel, help.get_index())
	quest_box = VBoxContainer.new()
	quest_box.add_theme_constant_override("separation", 6)
	quest_panel.add_child(quest_box)

func _render_quests() -> void:
	if net_role == "host":
		net_quest_dirty = true
	if quest_box == null:
		return
	for c in quest_box.get_children():
		quest_box.remove_child(c)
		c.queue_free()
	var head := HBoxContainer.new()
	var t := Label.new()
	t.text = "📜 Görevler"
	t.add_theme_font_size_override("font_size", 17)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var tg := _small_btn(" ▾ " if quest_open else " ▸ ", func():
		quest_open = not quest_open
		_render_quests())
	tg.tooltip_text = "Görevleri aç/kapa  [J]"
	head.add_child(tg)
	quest_box.add_child(head)
	quest_panel.reset_size()
	if not quest_open:
		return
	if _story_on():
		var st: Dictionary = STORY[story_step]
		var sp := PanelContainer.new()
		sp.add_theme_stylebox_override("panel", _sb(Color("#fff4cc"), 10, Color("#f2c94c"), 2, 0))
		var sv := VBoxContainer.new()
		sv.add_theme_constant_override("separation", 4)
		sp.add_child(sv)
		var sh := Label.new()
		sh.text = "⭐ Hikâye · %d / %d" % [story_step + 1, STORY.size()]
		sh.add_theme_font_size_override("font_size", 12)
		sh.add_theme_color_override("font_color", Color("#a0731b"))
		sv.add_child(sh)
		var sl := Label.new()
		sl.text = st.text
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sl.custom_minimum_size = Vector2(250, 0)
		sl.add_theme_font_size_override("font_size", 14)
		sv.add_child(sl)
		var spb := ProgressBar.new()
		spb.show_percentage = false
		spb.custom_minimum_size = Vector2(0, 7)
		spb.max_value = st.need
		spb.value = story_have
		spb.add_theme_stylebox_override("background", _sb(Color("#eadcc6"), 3, Color(0, 0, 0, 0), 0, 0))
		spb.add_theme_stylebox_override("fill", _sb(Color("#f2a900"), 3, Color(0, 0, 0, 0), 0, 0))
		sv.add_child(spb)
		var sr := Label.new()
		sr.text = "%d / %d   ·   ödül: %d 🪙  +%d XP" % [story_have, st.need, st.coins, st.xp]
		sr.add_theme_font_size_override("font_size", 12)
		sr.add_theme_color_override("font_color", Color("#8a7260"))
		sv.add_child(sr)
		quest_box.add_child(sp)
	for i in quests.size():
		var q = quests[i]
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		var top := HBoxContainer.new()
		var l := Label.new()
		l.text = q.text
		l.add_theme_font_size_override("font_size", 14)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(l)
		var cnt := Label.new()
		cnt.text = "%d/%d" % [q.have, q.need]
		cnt.add_theme_font_size_override("font_size", 13)
		cnt.add_theme_color_override("font_color", Color("#8a7260"))
		top.add_child(cnt)
		var ii := i
		var x := _small_btn("✕", func(): _skip_quest(ii))
		x.custom_minimum_size = Vector2(26, 24)
		x.add_theme_font_size_override("font_size", 11)
		x.tooltip_text = "Görevi sil (günde 1 ücretsiz, sonra %d 💎)" % QUEST_SKIP_GEMS
		top.add_child(x)
		row.add_child(top)
		var pb := ProgressBar.new()
		pb.show_percentage = false
		pb.custom_minimum_size = Vector2(0, 6)
		pb.max_value = q.need
		pb.value = q.have
		pb.add_theme_stylebox_override("background", _sb(Color("#eadcc6"), 3, Color(0, 0, 0, 0), 0, 0))
		pb.add_theme_stylebox_override("fill", _sb(Color("#5cbf2f"), 3, Color(0, 0, 0, 0), 0, 0))
		row.add_child(pb)
		var rw := Label.new()
		rw.text = "🏅 %d   💎 %d   +%d XP" % [q.medals, q.gems, q.xp]
		rw.add_theme_font_size_override("font_size", 12)
		rw.add_theme_color_override("font_color", Color("#9a6a00"))
		row.add_child(rw)
		quest_box.add_child(row)
	quest_panel.reset_size()

func _selftest_quests(fails: Array) -> void:
	medals = 0
	gems = 0
	quests = []
	_fill_quests()
	if quests.size() != QUEST_SLOTS: fails.append("görev sayısı %d" % quests.size())
	var keys := {}
	for q in quests:
		keys[q.kind + ":" + q.arg] = true
	if keys.size() != QUEST_SLOTS: fails.append("tekrarlı görev")
	for i in 40:
		var rq := _random_quest()
		if rq.text == "" or rq.need <= 0: fails.append("boş görev %s" % rq)
	quests = [_make_quest("crop", "wheat"), _make_quest("sell", ""), _make_quest("water", ""), _make_quest("earn", "")]
	quests[0].need = 2
	quests[1].need = 5
	var q0 = quests[0]
	_quest_event("crop", "carrot", 1)
	if q0.have != 0: fails.append("yanlış ekin sayıldı")
	_quest_event("crop", "wheat", 1)
	if q0.have != 1: fails.append("görev ilerlemedi")
	var m0 := medals
	_quest_event("crop", "wheat", 1)
	if quests[0] == q0 or medals != m0 + q0.medals or gems != q0.gems: fails.append("görev ödülü")
	if quests.size() != QUEST_SLOTS: fails.append("tamamlanınca görev eksildi")
	res = {"egg": 5}
	var q1 = quests[1]
	_sell("egg", 5)
	if quests[1] == q1: fails.append("satış görevi tamamlanmadı")
	quest_skip_at = 0.0
	gems = 0
	var q2 = quests[2]
	if not _skip_quest(2) or quests[2] == q2: fails.append("ücretsiz silme")
	var q3 = quests[3]
	if _skip_quest(3) or quests[3] != q3: fails.append("bekleme süresi yok sayıldı")
	gems = QUEST_SKIP_GEMS
	if not _skip_quest(3) or gems != 0: fails.append("elmasla silme")
	res = {}

# ============================================================ çiçekler ve gölet (Aşama 4)
func _flower_lv(t: String) -> Dictionary:
	if not flv.has(t):
		flv[t] = {"lv": 1, "n": 0}
	return flv[t]

func _flower_wet_frac(e: Dictionary) -> float:
	return clampf(e.wet_t / Data.FLOWERS[e.type].time, 0.0, 1.0)

func _harvest_flower(e: Dictionary, pos: Vector3) -> void:
	var f = Data.FLOWERS[e.type]
	var frac := _flower_wet_frac(e)
	var fl := _flower_lv(e.type)
	var mult := (1.0 + Data.FLOWER_WET_BONUS * frac) * Data.flower_mult(fl.lv)
	_burst(pos + Vector3(0, 0.4, 0), f.color, 14, 3.5)
	_gain(int(round(f.sell * mult)), int(round(f.xp * (1.0 + Data.FLOWER_WET_BONUS * frac))), pos, f.icon)
	_store(e.type, pos, int(round(frac * 2.0)))
	_quest_event("flower", e.type, 1)
	if frac > 0.95:
		_float_text(pos + Vector3(0, 0.75, 0), "💐 ×%.0f" % (1.0 + Data.FLOWER_WET_BONUS), Color("#ffb3e6"))
	e.ready = false
	e.t = 0.0
	e.wet_t = 0.0
	_refresh(e)
	if fl.lv < Data.FLOWER_MAX_LV:
		fl.n += 1
		if fl.n >= fl.lv * Data.FLOWER_HARVESTS_PER_LV:
			fl.n = 0
			fl.lv += 1
			_toast("%s %s seviye %d! Tüm %s tarhları +%%%d kazanç" % [f.icon, f.name, fl.lv, f.name, int(round((Data.flower_mult(fl.lv) - 1.0) * 100.0))], "level")
			if tool == "garden":
				_render_shelf()

func _selftest_garden(fails: Array) -> void:
	coins = 2000
	level = 6
	res = {}
	flv = {}
	weather = ""
	if not _perform({"x": 10, "z": 11, "tool": "garden", "arg": "daisy"}): fails.append("çiçek dikme")
	var f = tiles[key(10, 11)]
	if not _perform({"x": 10, "z": 11, "tool": "water", "arg": null}): fails.append("çiçek sulama")
	_simulate(Data.FLOWERS.daisy.time)
	if not f.ready: fails.append("çiçek açmadı %.3f" % f.t)
	var c0 := coins
	if not _perform({"x": 10, "z": 11, "tool": "hand", "arg": "wheat"}): fails.append("çiçek hasadı")
	if coins - c0 != 30: fails.append("sulu çiçek kazancı %d" % (coins - c0))
	if res.get("flower", 0) != 4: fails.append("çiçek kaynağı %s" % res)
	if f.ready or f.t != 0.0 or not tiles.has(key(10, 11)): fails.append("çiçek yeniden açmıyor")
	f.water = 0.0
	_simulate(Data.FLOWERS.daisy.time)
	c0 = coins
	_perform({"x": 10, "z": 11, "tool": "hand", "arg": "wheat"})
	if coins - c0 != 10: fails.append("kuru çiçek kazancı %d" % (coins - c0))
	flv.daisy.n = Data.FLOWER_HARVESTS_PER_LV - 1
	f.water = 0.0
	_simulate(Data.FLOWERS.daisy.time)
	_perform({"x": 10, "z": 11, "tool": "hand", "arg": "wheat"})
	if flv.daisy.lv != 2: fails.append("çiçek seviyesi %s" % flv.daisy)
	# gölet
	if _resolve("garden", "pond", 10, 10) != null: fails.append("gölet dolu alana kuruldu")
	if not _perform({"x": 8, "z": 9, "tool": "garden", "arg": "pond"}): fails.append("gölet kurma")
	var pd = tiles.get(key(9, 10))
	if pd == null or pd.kind != "pond": fails.append("gölet 2×2 değil")
	if _resolve("garden", "daisy", 9, 9) != null: fails.append("gölet üstüne çiçek")
	_simulate(Data.POND.time + 0.5)
	if not pd.ready: fails.append("gölet balık üretmedi")
	res = {}
	if not _perform({"x": 9, "z": 10, "tool": "hand", "arg": "wheat"}): fails.append("balık toplama")
	if res.get("fish", 0) != 4: fails.append("balık kaynağı %s" % res)
	if not _perform({"x": 9, "z": 10, "tool": "remove", "arg": null}): fails.append("gölet kaldırma")
	if tiles.has(key(8, 9)) or tiles.has(key(9, 10)): fails.append("gölet kareleri boşalmadı")
	res = {}

# ============================================================ hayvan yemi, ağıl, seviye (Aşama 3)
## Bitişik (4 yön) aynı tür hayvanlar bir ağıldır.
func _pen(e: Dictionary) -> Array:
	var out := [e]
	var seen := {key(e.x, e.z): true}
	var i := 0
	while i < out.size():
		var c = out[i]
		i += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var k := key(c.x + d.x, c.z + d.y)
			if seen.has(k):
				continue
			var n = tiles.get(k)
			if n != null and n.kind == "animal" and n.type == e.type:
				seen[k] = true
				out.append(n)
	return out

## Ağıldaki eksik yem için gereken tahıl.
func _feed_need(e: Dictionary) -> int:
	var need := 0.0
	for a in _pen(e):
		need += Data.ANIMALS[a.type].feed * (1.0 - a.food)
	return ceili(need - 0.001)

func _feed_split(e: Dictionary) -> Vector2i:
	var need := _feed_need(e)
	var from_res := mini(need, res.get("cereal", 0))
	return Vector2i(from_res, (need - from_res) * Data.FEED_COIN)

func _can_feed(e: Dictionary) -> bool:
	return _feed_split(e).y <= coins

func _feed_cost_text(e: Dictionary) -> String:
	var sp := _feed_split(e)
	var parts := []
	if sp.x > 0:
		parts.append("-%d🌾" % sp.x)
	if sp.y > 0:
		parts.append("-%d🪙" % sp.y)
	var n := _pen(e).size()
	return ("(ağıl %d) " % n if n > 1 else "") + " ".join(parts)

func _feed_pen(e: Dictionary) -> void:
	_quest_event("feed", e.type, 1)
	var sp := _feed_split(e)
	if sp.x > 0:
		res.cereal -= sp.x
	if sp.y > 0:
		_spend(sp.y)
	var pos := tile_center(e.x, e.z)
	_float_text(pos, ("-%d 🌾" % sp.x) if sp.x > 0 else ("-%d 🪙" % sp.y), Color("#ffe2a8"))
	for a in _pen(e):
		a.food = 1.0
		a.hop_t = 1.0 + randf() * 0.3
		_update_hungry(a)
		_burst(tile_center(a.x, a.z) + Vector3(0, 0.3, 0), "#f0c75e", 6, 2.0)
	_sfx("plant")
	if barn.visible:
		_render_barn()

func _update_hungry(e: Dictionary) -> void:
	if e.has("hungry_lbl"):
		e.hungry_lbl.visible = e.food <= 0.0 and not e.ready

func _animal_harvested(e: Dictionary, pos: Vector3) -> void:
	if e.lv >= Data.ANIMAL_MAX_LV:
		return
	e.hv += 1
	if e.hv >= e.lv * Data.HARVESTS_PER_LV:
		e.hv = 0
		e.lv += 1
		var a = Data.ANIMALS[e.type]
		_float_text(pos + Vector3(0, 0.7, 0), "⭐ Sv %d" % e.lv, Color("#ffd54f"))
		_toast("%s %s seviye %d oldu! Kazancı +%%%d" % [a.icon, a.name, e.lv, int(round((Data.animal_sell_mult(e.lv) - 1.0) * 100.0))], "level")
		_burst(pos + Vector3(0, 1.0, 0), "#ffd54f", 14, 4.0)

func _selftest_animals(fails: Array) -> void:
	coins = 100
	level = 6
	res = {"cereal": 1}
	var a := _add_entity({"kind": "animal", "type": "chicken", "x": 10, "z": 7, "food": 0.0})
	var b := _add_entity({"kind": "animal", "type": "chicken", "x": 11, "z": 7, "food": 0.0})
	if _pen(a).size() != 2: fails.append("ağıl boyutu %d" % _pen(a).size())
	_simulate(30.0)
	if a.t != 0.0: fails.append("aç hayvan üretti")
	if _resolve("hand", "wheat", 10, 7) != "feed": fails.append("yemle eylemi yok")
	if not _perform({"x": 10, "z": 7, "tool": "hand", "arg": "wheat"}): fails.append("yemleme")
	if a.food != 1.0 or b.food != 1.0: fails.append("ağıl yemi paylaşmadı")
	if res.cereal != 0 or coins != 100 - Data.FEED_COIN: fails.append("yem bedeli %d/%d" % [res.cereal, coins])
	_simulate(Data.ANIMALS.chicken.time)
	if not a.ready: fails.append("yemli hayvan üretmedi")
	if absf(a.food - (1.0 - 1.0 / Data.FEED_CYCLES)) > 0.01: fails.append("yem azalması %.3f" % a.food)
	a.hv = Data.HARVESTS_PER_LV - 1
	if not _perform({"x": 10, "z": 7, "tool": "hand", "arg": "wheat"}): fails.append("hayvan hasadı")
	if a.lv != 2: fails.append("hayvan seviyesi %d" % a.lv)
	a.ready = true
	var c0 := coins
	res = {}
	_perform({"x": 10, "z": 7, "tool": "hand", "arg": "wheat"})
	if coins != c0 + int(round(Data.ANIMALS.chicken.sell * Data.animal_sell_mult(2))): fails.append("seviye bonusu %d" % (coins - c0))
	if res.get("egg", 0) != Data.YIELD.chicken[1] + Data.animal_extra_yield(2): fails.append("seviye yumurta %s" % res)
	res = {}

# ============================================================ mevsim ve hava (Aşama 2)
func _on_season_start() -> void:
	var sn = Data.SEASONS[season]
	var prev := (season + 3) % 4
	var fresh := []
	for k in Data.CROPS:
		var c = Data.CROPS[k]
		if c.seasons.has(season) and not c.seasons.has(prev) and c.level <= level:
			fresh.append(c.icon + " " + c.name)
	var msg := "%s %s geldi!" % [sn.icon, sn.name]
	if fresh.size() > 0:
		msg += "\nEkilebilir: " + ", ".join(fresh)
	_toast(msg, "level")
	if season != 3:
		var n := 0
		for e in entities:
			if e.kind == "tree" and e.age >= 1.0 and not e.has_fruit:
				e.has_fruit = true
				e.fruit_t = 0.0
				_refresh(e)
				n += 1
		if n > 0:
			_toast("🌳 Ağaçlar mevsim meyvesi verdi (%d)" % n)
	if weather != "":
		_end_weather()
	var r := randf() if net_role != "guest" else 2.0
	for wc in Data.WEATHER_CHANCE[season]:
		if r < wc[1]:
			_start_weather(wc[0])
			break
		r -= wc[1]
	_apply_season_visual(loading)
	if shelf_box != null:
		_render_shelf()

## Tarla/tarh üstünde küçük simge: 🧺 hazır, 💧 susuz büyüyor.
func _make_mark(g: Node3D, y: float) -> Label3D:
	var l := Label3D.new()
	l.font = font
	l.font_size = 52
	l.pixel_size = 0.0065
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.outline_size = 10
	l.outline_modulate = Color(0.1, 0.15, 0.25, 0.6)
	l.position.y = y
	l.rotation.y = 0.0
	g.add_child(l)
	return l

func _update_mark(e: Dictionary) -> void:
	if not e.has("mark") or e.mark == null or not is_instance_valid(e.mark):
		return
	var ready := false
	var growing := false
	if e.kind == "plot":
		ready = e.crop != null and e.progress >= 1.0
		growing = e.crop != null and e.progress < 1.0
	elif e.kind == "flower":
		ready = e.ready
		growing = not e.ready
	if ready:
		e.mark.text = "🧺"
		e.mark.modulate = Color.WHITE
		e.mark.visible = true
	elif growing and not _wet(e) and weather != "snow":
		e.mark.text = "💧"
		e.mark.modulate = Color(1, 1, 1, 0.85)
		e.mark.visible = true
	else:
		e.mark.visible = false

func _refresh_marks() -> void:
	for e in entities:
		if e.kind == "plot" or e.kind == "flower":
			_update_mark(e)

func _start_weather(w: String) -> void:
	if not Data.WEATHER.has(w):
		return
	weather = w
	weather_t = randf_range(150.0, 300.0)
	_toast("%s %s" % [Data.WEATHER[w].icon, Data.WEATHER[w].msg], "warn" if w == "drought" else "")
	_refresh_marks()

func _end_weather() -> void:
	if weather != "":
		_toast("🌤️ Hava açıldı")
	weather = ""
	weather_t = 0.0
	_refresh_marks()

func _apply_season_visual(instant: bool) -> void:
	var t = SEASON_TINT[season]
	var col := Color(t[0])
	# MegaKit yaprakları: sonbaharda kızıl, kışın soluk
	var leaf: Color = [Color.WHITE, Color("#fff0b0"), Color("#ffa060"), Color("#e6efe6")][season]
	if instant:
		for m in [ground_mat, grass_mat]:
			m.set_shader_parameter("tint", col)
			m.set_shader_parameter("amt", t[1])
		for lm in Assets.leaf_mats:
			lm.albedo_color = leaf * lm.get_meta("base", Color.WHITE)
		return
	var tw := create_tween().set_parallel()
	for lm in Assets.leaf_mats:
		tw.tween_property(lm, "albedo_color", leaf * lm.get_meta("base", Color.WHITE), 6.0)
	for m in [ground_mat, grass_mat]:
		tw.tween_property(m, "shader_parameter/tint", col, 6.0)
		tw.tween_property(m, "shader_parameter/amt", t[1], 6.0)

func _selftest_seasons(fails: Array) -> void:
	season = 0
	season_t = 0.0
	weather = ""
	coins = 1000
	level = 6
	if not _perform({"x": 9, "z": 3, "tool": "plow", "arg": null}): fails.append("sürme 3")
	if not _perform({"x": 9, "z": 3, "tool": "seed", "arg": "tomato"}): fails.append("ilkbaharda domates")
	var e = tiles[key(9, 3)]
	var b := 1.25 if e.boost else 1.0
	var w_exp := 1.0 - Data.CROPS.tomato.time / 2.0 / Data.WATER_DUR
	_simulate(Data.CROPS.tomato.time / 2.0)
	if absf(e.progress - 0.25 * b) > 0.01: fails.append("susuz büyüme %.3f" % e.progress)
	if not _perform({"x": 9, "z": 3, "tool": "water", "arg": null}): fails.append("sulama 3")
	if _resolve("water", null, 9, 3) != null: fails.append("dolu toprağa tekrar sulama")
	_simulate(Data.CROPS.tomato.time / 2.0)
	if absf(e.progress - 0.75 * b) > 0.01: fails.append("sulu büyüme %.3f" % e.progress)
	if absf(e.water - w_exp) > 0.01: fails.append("su azalması %.3f" % e.water)
	_start_weather("drought")
	_simulate(10.0)
	if absf(e.water - (w_exp - 30.0 / Data.WATER_DUR)) > 0.01: fails.append("kuraklık %.3f" % e.water)
	_start_weather("rain")
	e.water = 0.0
	_simulate(8.0)
	if e.water < 0.99: fails.append("yağmur %.3f" % e.water)
	_start_weather("snow")
	e.water = 0.0
	if _resolve("water", null, 9, 3) != null: fails.append("karda sulama")
	if absf(_grow_rate(e) - 0.6 * b) > 0.001: fails.append("kar hızı")
	_end_weather()
	season = 2
	if not _perform({"x": 8, "z": 3, "tool": "plow", "arg": null}): fails.append("sürme 4")
	if _resolve("seed", "tomato", 8, 3) != null: fails.append("sonbaharda domates ekildi")
	if _resolve("seed", "pumpkin", 8, 3) != "plant": fails.append("sonbaharda balkabağı")
	var tree_e = tiles[key(9, 5)]
	tree_e.has_fruit = false
	tree_e.age = 1.0
	season = 3
	season_t = 1.0 - 0.5 / Data.SEASON_LEN
	var y0 := year
	_simulate(1.0)
	if season != 0 or year != y0 + 1: fails.append("mevsim geçişi %d/%d" % [season, year])
	if not tree_e.has_fruit: fails.append("mevsim meyvesi")
	_end_weather()

# ============================================================ ambar, satış, sipariş (Aşama 1)
func _res_total() -> int:
	var t := 0
	for k in res:
		t += res[k]
	return t

## Hasadın kaynağını ambara koyar; yer yoksa sığdığı kadarını.
func _store(src: String, pos: Vector3, extra := 0) -> void:
	if not Data.YIELD.has(src):
		return
	var r: String = Data.YIELD[src][0]
	var amt: int = Data.YIELD[src][1] + extra
	if _barn_cap() == 0:
		if not loading:
			_toast("📦 Ambarın yok: ürünler saklanamadı. 🏗️ Yapı ile ambar kur.", "warn")
		return
	var add := mini(amt, _barn_cap() - _res_total())
	if add > 0:
		res[r] = res.get(r, 0) + add
		_float_text(pos + Vector3(0.35, -0.15, 0), "+%d %s" % [add, Data.RESOURCES[r].icon], Color("#e6f7ff"))
	if add < amt:
		_toast("📦 Ambar dolu! B ile aç, kaynak sat.", "warn")
	if barn.visible:
		_render_barn()

func _sell(r: String, n: int) -> void:
	n = mini(n, res.get(r, 0))
	if n <= 0:
		return
	if net_role == "guest":   # satışı ev sahibi yapar; para ve ambar eşitlenir
		rpc_id(1, "net_req", "@sell", r, n, 0)
		res[r] -= n
		coins += n * int(Data.RESOURCES[r].price)
		hud_dirty = true
		_sfx("harvest")
		_toast("💰 %d %s satıldı: +%d 🪙" % [n, Data.RESOURCES[r].icon, n * int(Data.RESOURCES[r].price)])
		_render_barn()
		return
	res[r] -= n
	var gain_c: int = n * Data.RESOURCES[r].price
	coins += gain_c
	_quest_event("sell", r, n)
	_quest_event("earn", "", gain_c)
	hud_dirty = true
	_sfx("harvest")
	_toast("💰 %d %s satıldı: +%d 🪙" % [n, Data.RESOURCES[r].icon, gain_c])
	_render_barn()

## Oyuncunun seviyesinde üretebildiği kaynaklardan rastgele bir sipariş.
func _new_order() -> void:
	var avail := []
	for list in [Data.CROPS, Data.TREES, Data.ANIMALS, Data.garden()]:
		for k in list:
			if list[k].level <= level and Data.YIELD.has(k):
				var r: String = Data.YIELD[k][0]
				if not avail.has(r):
					avail.append(r)
	if _count_buildings("oven") > 0:
		for rc in RECIPES:
			if level >= int(rc.level):
				avail.append(rc.id)
	avail.shuffle()
	var need := {}
	var value := 0
	for i in mini(2, avail.size()):
		var n := randi_range(4, 8) + level * 2
		if int(Data.RESOURCES[avail[i]].price) >= 25:   # fırın ürünü: az sayıda
			n = randi_range(1, 3) + level / 5
		need[avail[i]] = n
		value += n * int(Data.RESOURCES[avail[i]].price)
	order = {"need": need, "medals": maxi(1, value / 40), "xp": maxi(5, value / 4), "coins": int(value * 1.5)}

func _can_deliver() -> bool:
	if order.is_empty():
		return false
	for r in order.need:
		if res.get(r, 0) < order.need[r]:
			return false
	return true

func _deliver() -> void:
	if not _can_deliver():
		return
	if net_role == "guest":
		rpc_id(1, "net_req", "@deliver", "", 0, 0)
		for r in order.need:
			res[r] -= order.need[r]
		_toast("📋 Sipariş teslim edildi!", "level")
		_sfx("level")
		order = {}
		_render_barn()
		return
	for r in order.need:
		res[r] -= order.need[r]
	medals += order.medals
	_quest_event("order", "", 1)
	var got: int = order.medals
	_gain(order.coins, order.xp, farmer.position, "🏅")
	_new_order()
	_toast("📋 Sipariş teslim edildi! +%d 🏅" % got, "level")
	hud_dirty = true
	_render_barn()

func _open_barn() -> void:
	if _count_buildings("barn") == 0:
		_toast("📦 Henüz ambarın yok. 🏗️ Yapı aletiyle bir ambar kur.", "hint")
		return
	help.visible = false
	barn.visible = true
	_render_barn()

func _build_barn_ui() -> void:
	barn = ColorRect.new()
	barn.color = Color(0.12, 0.2, 0.08, 0.35)
	barn.set_anchors_preset(Control.PRESET_FULL_RECT)
	barn.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(barn)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	barn.add_child(cc)
	var p := _panel(20)
	p.custom_minimum_size = Vector2(580, 0)
	cc.add_child(p)
	barn_box = VBoxContainer.new()
	barn_box.add_theme_constant_override("separation", 8)
	p.add_child(barn_box)
	barn.visible = false

func _small_btn(text: String, cb: Callable, enabled := true, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 32)
	b.disabled = not enabled
	if primary:
		_btn_styles(b, Color("#6fbf3b"), Color("#7fcf4b"))
		for st in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
			b.add_theme_color_override(st, Color.WHITE)
	else:
		_btn_styles(b, Color("#f3e6cf"), Color("#ead9bb"))
	if not enabled:
		b.modulate = Color(1, 1, 1, 0.5)
	b.pressed.connect(cb)
	return b

func _change_order() -> void:
	if coins < 20:
		return
	coins -= 20
	hud_dirty = true
	_new_order()
	_render_barn()

func _render_barn() -> void:
	for c in barn_box.get_children():
		barn_box.remove_child(c)
		c.queue_free()
	var head := HBoxContainer.new()
	var t := Label.new()
	t.text = "📦 Ambar   %d / %d" % [_res_total(), _barn_cap()]
	t.add_theme_font_size_override("font_size", 24)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(_small_btn("  ✕  ", func(): barn.visible = false))
	barn_box.add_child(head)
	var fill := ProgressBar.new()
	fill.show_percentage = false
	fill.custom_minimum_size = Vector2(0, 8)
	fill.max_value = maxi(1, _barn_cap())
	fill.value = _res_total()
	fill.add_theme_stylebox_override("background", _sb(Color("#eadcc6"), 4, Color(0, 0, 0, 0), 0, 0))
	fill.add_theme_stylebox_override("fill", _sb(Color("#e0a030") if _res_total() > _barn_cap() * 0.85 else Color("#5cbf2f"), 4, Color(0, 0, 0, 0), 0, 0))
	barn_box.add_child(fill)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 6)
	var any := false
	for r in Data.RESOURCES:
		var n: int = res.get(r, 0)
		if n <= 0:
			continue
		any = true
		var info = Data.RESOURCES[r]
		var nm := Label.new()
		nm.text = "%s %s" % [info.icon, info.name]
		nm.custom_minimum_size = Vector2(150, 0)
		grid.add_child(nm)
		var cnt := Label.new()
		cnt.text = "× %d" % n
		cnt.custom_minimum_size = Vector2(60, 0)
		grid.add_child(cnt)
		var pr := Label.new()
		pr.text = "%d🪙/adet" % info.price
		pr.add_theme_color_override("font_color", Color("#8a7260"))
		grid.add_child(pr)
		var rr: String = r
		grid.add_child(_small_btn("Sat 10", func(): _sell(rr, 10)))
		grid.add_child(_small_btn("Tümü (+%d🪙)" % (n * int(info.price)), func(): _sell(rr, 999999), true, true))
	if any:
		barn_box.add_child(grid)
	else:
		var e := Label.new()
		e.text = "Ambar boş. Hasat edince kaynaklar buraya gelir."
		e.add_theme_color_override("font_color", Color("#8a7260"))
		barn_box.add_child(e)

	barn_box.add_child(HSeparator.new())
	var ot := Label.new()
	ot.text = "📋 Pazar Siparişi"
	ot.add_theme_font_size_override("font_size", 19)
	barn_box.add_child(ot)
	var need_parts := []
	for r in order.get("need", {}):
		var have: int = res.get(r, 0)
		var want: int = order.need[r]
		var mark := "✅" if have >= want else "▫️"
		need_parts.append("%s %s %s  %d / %d" % [mark, Data.RESOURCES[r].icon, Data.RESOURCES[r].name, mini(have, want), want])
	var nl := Label.new()
	nl.text = "\n".join(need_parts)
	barn_box.add_child(nl)
	var rw := Label.new()
	rw.text = "Ödül:  🏅 %d   ·   +%d XP   ·   +%d 🪙" % [order.get("medals", 0), order.get("xp", 0), order.get("coins", 0)]
	rw.add_theme_color_override("font_color", Color("#9a6a00"))
	barn_box.add_child(rw)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_small_btn("  Teslim et  ", _deliver, _can_deliver(), true))
	row.add_child(_small_btn("Değiştir (-20🪙)", _change_order, coins >= 20))
	barn_box.add_child(row)
