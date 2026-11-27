class_name Town
## Çiftliğin güneyindeki köy: ana yol, iki cadde, evler, ahırlar, sokak lambaları, ağaçlar.
## Modeller (ilkhom23 "Low Poly Farm Set 02") lisans gereği repoda yok; yoksa köy kurulmaz, yollar kalır.

const DIR := "res://assets/farm02/town/"
const VEH := "res://assets/vehicles/"   # araçlar ve sokak lambaları (CGTrader ücretsiz, repoda yok)
const SIDE_X := 38.5                      # caddeleri bağlayan yan yollar (x = ±)
const NAME := "Yeşilköy"
## Köyün düzlenen alanı (x, z, genişlik, derinlik)
const RECT := Rect2(-56, 38, 112, 58)
const STREETS := [56.0, 80.0]     # doğu–batı caddeleri (z)
const STREET_HALF := 41.0          # caddelerin yarı uzunluğu (x)
const PLAZA := Vector2(0, 56)       # kavşak meydanı
const PLAZA_R := 5.5
const RING_OUT := 9.5                # göbek çevresindeki dönel kavşağın dış kenarı
const RING_C := 6.5                  # dönel kavşakta araç yolunun orta çizgisi (şerit = +1 dışarı)
## Otoparklar: köy girişinde, pazar yerine yürüme mesafesinde (x, z, en, boy).
const LOTS := [Rect2(5.0, 38.5, 10.0, 9.0), Rect2(-15.0, 38.5, 10.0, 9.0)]
const BAY_W := 2.0
const BAY_L := 3.6
const ASPHALT := "#8d8782"
const WALK_COL := "#d9cbab"
const HOUSES := ["house_01", "house_02", "house_05", "house_06", "house_07", "house_11", "house_12", "house_13",
	"house_03", "house_04", "house_08", "house_09", "house_10", "house_14", "house_15", "house_16"]
const TREES := ["tree_01", "tree_02", "tree_03", "tree_05", "tree_06", "tree_07", "tree_10"]
## Modelin ön yüzünün yerel yönü için ek dönüş (ön yüz +z kabul edilir).
const FRONT := {"house": 0.0, "farmbuilding": 0.0, "farmstractures": 0.0}

static var blocks := {}        # Vector2i → true: yürünemeyen kareler
static var movers := []        # tur atan arabalar: {node, pts, len, s, speed, v}
static var _vmats := {}
static var walkers := []       # yürüyen köylüler: {node, ap, pts, len, loop, s, dir, speed, pause}
static var _npc_scene: PackedScene = null
static var _npc_mats := {}
static var _npc_scale := 0.0
static var folk := {}          # isimli köylü id → düğüm
static var _bubbles := []      # [Label3D, kalan süre]
static var _font: Font = null

## Yeşilköy'ün isimli sakinleri (meydanda ve ev önlerinde sohbet edenler, ikişer ikişer).
const TOWNSFOLK := [
	{"id": "kemal", "name": "Postacı Kemal", "icon": "✉️", "likes": ["egg", "cereal"],
		"lines": ["Mektup var, mektup! Bugün sana yok ama.", "Bu köyün her kapısını bilirim.", "Otobüs yine geç kaldı, şaşırdık mı?"]},
	{"id": "ayse", "name": "Terzi Ayşe", "icon": "🧵", "likes": ["wool", "flower"],
		"lines": ["Şu şapka sana çok yakışmış!", "Yeni kumaşlar geldi, bir ara uğra.", "İğne iplik, bir de iyi yün: başka bir şey istemem."]},
	{"id": "fatma", "name": "Sütçü Fatma", "icon": "🥛", "likes": ["milk", "veg"],
		"lines": ["Sabah dörtte kalkarım, inekler beklemez.", "Taze süt her derde deva!", "Senin ineklerin de nazlı mı?"]},
	{"id": "mehmet", "name": "Demirci Mehmet", "icon": "⚒️", "likes": ["cereal", "nut"],
		"lines": ["Örs başında bütün gün, kollarım demir gibi.", "Çapanın ağzı mı köreldi? Getir bileyleyeyim.", "Atlarım tahıla bayılır."]},
	{"id": "elif", "name": "Öğretmen Elif", "icon": "📚", "likes": ["flower", "fruit"],
		"lines": ["Bugün çocuklara tohumların nasıl filizlendiğini anlattım.", "Okuma yazma bilmeyen kalmasın bu köyde.", "Sınıfa bir saksı çiçek ne güzel olurdu."]},
	{"id": "selin", "name": "Doktor Selin", "icon": "🩺", "likes": ["fruit", "mushroom"],
		"lines": ["Bol su iç, güneşte çok kalma!", "Günde bir elma doktoru uzak tutar derler... bana da iş kalmıyor.", "Köy sağlıklı, ben mutluyum."]},
	{"id": "ali", "name": "Marangoz Ali", "icon": "🪚", "likes": ["nut", "veg"],
		"lines": ["Ölç bin kere, kes bir kere.", "Çitin mi kırıldı? Tahtası bende.", "Ceviz ağacından iyi masa olur."]},
	{"id": "yusuf", "name": "Bekçi Yusuf", "icon": "🔦", "likes": ["pogaca", "fish"],
		"lines": ["Geceleri köy bana emanet.", "Dün gece bir tilki gördüm, tavuklarına dikkat!", "Lambalar yanınca köy bir başka güzel."]},
]
const WALKER_LINES := ["Günaydın komşu!", "Pazara mı gidiyorsun?", "Hava bugün ne güzel!", "Senin çiftliğin buradan görünüyor mu?",
	"Fırıncı Zeynep'in poğaçaları bir harika.", "Otobüs kaçta geliyordu?", "Selam! Acelem var, sonra konuşalım.", "Bu yıl hasat bereketli olacak.",
	"Meydandaki ağaç benim dedemden yaşlı.", "Akşam şenlik var mıydı?"]

## Köy işleri zinciri: "to" varsa o köylüyle konuşmak, "r"/"n" varsa ambardan teslim etmek.
## pay: [altın, XP, elmas, çantaya hediye]
const TQUESTS := [
	{"giver": "kemal", "to": "ayse", "ask": "Yeşilköy'e hoş geldin! Ben postacı Kemal. Terzi Ayşe yeni komşuyu çok merak ediyor, git bir selam ver.",
		"done": "Demek yeni çiftçi sensin! Kemal hep senden bahsediyor.", "pay": [30, 10, 0, ""]},
	{"giver": "ayse", "r": "wool", "n": 3, "ask": "Kışlık elbise dikiyorum ama yünüm bitti. 3 yün getirir misin?",
		"done": "Ne yumuşak yün bu! Sana bir atkı örerim.", "pay": [80, 20, 0, ""]},
	{"giver": "ayse", "to": "fatma", "ask": "Sütçü Fatma çiftliğini görmek istiyordu. Meydanın doğusunda, evlerin önünde bulursun onu.",
		"done": "Ayşe mi gönderdi? Gel bakalım, konuşacaklarımız var.", "pay": [30, 10, 0, ""]},
	{"giver": "fatma", "r": "milk", "n": 3, "ask": "İneklerim hasta, köye süt yetmiyor. 3 süt getirebilir misin?",
		"done": "Çocuklar bugün de süt içecek, sağ ol! Al şu bankı, bahçene koy.", "pay": [100, 25, 2, "decor:bench"]},
	{"giver": "mehmet", "r": "cereal", "n": 10, "ask": "Demirhanenin atları aç kaldı. 10 tahıl getirir misin? Parasını fazlasıyla veririm.",
		"done": "Atlar bayram etti!", "pay": [60, 20, 0, ""]},
	{"giver": "elif", "r": "flower", "n": 5, "ask": "Sınıfı süslemek istiyorum. 5 çiçek getirir misin?",
		"done": "Çocuklar bayılacak, teşekkürler!", "pay": [70, 20, 0, ""]},
	{"giver": "elif", "to": "selin", "ask": "Öğrencilerimden biri hasta. Doktor Selin'e haber verir misin? Batıdaki arka caddede olur.",
		"done": "Hemen bakarım, haber verdiğin iyi oldu.", "pay": [40, 12, 0, ""]},
	{"giver": "selin", "r": "fruit", "n": 6, "ask": "Hastalara taze meyve iyi gelir. 6 meyve getirebilir misin?",
		"done": "Şifa olsun! Bu lamba yolunu aydınlatsın.", "pay": [90, 25, 2, "decor:lamppost"]},
	{"giver": "ali", "r": "nut", "n": 5, "ask": "Yeni bir dolap yapıyorum, cilası için ceviz lazım. 5 ceviz getirir misin?",
		"done": "Bu cilayla dolap pırıl pırıl olacak.", "pay": [80, 22, 0, ""]},
	{"giver": "yusuf", "r": "pogaca", "n": 2, "ask": "Gece nöbeti uzun sürüyor. 2 poğaça getirsen dua ederim.",
		"done": "Mis gibi! Bu gece köy emin ellerde.", "pay": [120, 28, 0, ""]},
	{"giver": "kemal", "r": "egg", "n": 8, "ask": "Köy şenliği yaklaşıyor! Kek için 8 yumurta lazım.",
		"done": "Şenlik hazırlığı tamam sayılır!", "pay": [90, 25, 0, ""]},
	{"giver": "kemal", "r": "pie", "n": 1, "ask": "Şenliğin baş tatlısı senin turtan olsun. 1 turta getirir misin?",
		"done": "Bütün köy seni konuşuyor, artık Yeşilköy'ün gözdesisin! Bu tezgâh da şenlikten hatıra.", "pay": [300, 60, 5, "decor:market"]},
]

static func folk_def(id: String) -> Dictionary:
	for f in TOWNSFOLK:
		if f.id == id:
			return f
	return {}

## Tıklanan noktadaki köylü: isimliyse id, yürüyen köylüyse "~sıra", yoksa "".
static func pick(p: Vector3) -> String:
	for id in folk:
		var n: Node3D = folk[id]
		if is_instance_valid(n) and Vector2(p.x - n.position.x, p.z - n.position.z).length() < 1.0:
			return id
	for i in walkers.size():
		var n: Node3D = walkers[i].node
		if is_instance_valid(n) and Vector2(p.x - n.position.x, p.z - n.position.z).length() < 1.0:
			return "~%d" % i
	return ""

static func node_of(id: String) -> Node3D:
	if id.begins_with("~"):
		var i := int(id.substr(1))
		return walkers[i].node if i >= 0 and i < walkers.size() else null
	return folk.get(id)

## Köylünün başının üstünde konuşma balonu.
static func say(id: String, text: String, look := Vector3.INF) -> void:
	var n := node_of(id)
	if n == null or not is_instance_valid(n):
		return
	var l: Label3D = n.get_node_or_null("Say")
	if l == null:
		l = Label3D.new()
		l.name = "Say"
		l.font = _font
		l.font_size = 40
		l.outline_size = 10
		l.outline_modulate = Color(0, 0, 0, 0.65)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.width = 420.0
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.pixel_size = 0.006 / maxf(_npc_scale, 0.001)
		l.position = Vector3(0, (NPC_H + 1.0) / maxf(_npc_scale, 0.001), 0)
		n.add_child(l)
	l.text = "💬 " + text
	l.visible = true
	for b in _bubbles:
		if b[0] == l:
			_bubbles.erase(b)
			break
	_bubbles.append([l, 5.0])
	if id.begins_with("~"):
		var w: Dictionary = walkers[int(id.substr(1))]
		w.pause = maxf(float(w.pause), 5.0)
		if look != Vector3.INF:
			w["look"] = Vector2(look.x, look.z)
	elif look != Vector3.INF:
		n.rotation.y = atan2(look.x - n.position.x, look.z - n.position.z)

## Görev işareti: yalnızca `id` köylüsünün başında ❗.
static func mark(id: String) -> void:
	for k in folk:
		var n: Node3D = folk[k]
		if not is_instance_valid(n):
			continue
		var ex: Label3D = n.get_node_or_null("Ex")
		if ex == null:
			if k != id:
				continue
			ex = Label3D.new()
			ex.name = "Ex"
			ex.font = _font
			ex.text = "❗"
			ex.font_size = 80
			ex.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			ex.pixel_size = 0.006 / maxf(_npc_scale, 0.001)
			ex.position = Vector3(0, (NPC_H + 0.6) / maxf(_npc_scale, 0.001), 0)
			n.add_child(ex)
		ex.visible = k == id
static var _meshes := {}

## Köy alanına yakınlık: içeride 1, 8 m dışarıda 0.
static func mask(x: float, z: float) -> float:
	var dx := maxf(maxf(RECT.position.x - x, x - RECT.end.x), 0.0)
	var dz := maxf(maxf(RECT.position.y - z, z - RECT.end.y), 0.0)
	return 1.0 - smoothstep(0.0, 8.0, Vector2(dx, dz).length())

static func on_road(x: float, z: float) -> bool:
	if z > 36.0 and z < RECT.end.y and absf(x) < 3.6:
		return true
	for sz in STREETS:
		if absf(z - sz) < 3.4 and absf(x) < STREET_HALF:
			return true
	if absf(absf(x) - SIDE_X) < 3.4 and z > STREETS[0] - 3.4 and z < STREETS[1] + 3.4:
		return true
	for l in LOTS:
		if (l as Rect2).grow(0.6).has_point(Vector2(x, z)):
			return true
	return Vector2(x, z).distance_to(PLAZA) < RING_OUT + 1.2

static func available() -> bool:
	return Assets.enabled and ResourceLoader.exists(DIR + "house_07.res")

static func _mesh(file: String) -> Mesh:
	if not _meshes.has(file):
		var p := DIR + file + ".res"
		_meshes[file] = load(p) if ResourceLoader.exists(p) else null
	return _meshes[file]

static func _family(file: String) -> String:
	return file.substr(0, file.rfind("_"))

## En büyük yatay boyutu `width` metre olacak ölçek.
static func _fit(file: String, width: float) -> float:
	var m := _mesh(file)
	if m == null:
		return 1.0
	var sz := m.get_aabb().size
	return width / maxf(sz.x, sz.z)

## Modeli yerleştirir; `face` ön yüzün bakacağı yön. block: tabanı yürünemez yapar.
static func _put(g: Node, root: Node3D, file: String, x: float, z: float, face: float, s: float, block := true, vis := 160.0, shadow := true) -> MeshInstance3D:
	var m := _mesh(file)
	if m == null:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = Visuals.f2_mat()
	mi.position = Vector3(x, g.height_at(x, z) - 0.04, z)
	mi.rotation.y = face + FRONT.get(_family(file), 0.0)
	mi.scale = Vector3.ONE * s
	mi.visibility_range_end = vis
	mi.visibility_range_end_margin = 10.0
	mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var ab := m.get_aabb()
	if file.begins_with("tree_") and ab.position.y > 0.3:
		# Set 02'nin bazı ağaçları yalnızca taç: havada kalmasın diye gövde ekle
		var tr := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		var h := ab.position.y + 0.45
		cm.top_radius = 0.13
		cm.bottom_radius = 0.2
		cm.height = h
		cm.radial_segments = 7
		cm.rings = 1
		tr.mesh = cm
		tr.material_override = Visuals.bark_mat()
		tr.position = Vector3(ab.get_center().x, h / 2.0, ab.get_center().z)
		tr.visibility_range_end = vis
		mi.add_child(tr)
	if block:
		var a := m.get_aabb()
		var hx := a.size.x * s / 2.0 - 0.35
		var hz := a.size.z * s / 2.0 - 0.35
		var cx := (a.position.x + a.size.x / 2.0) * s
		var cz := (a.position.z + a.size.z / 2.0) * s
		var r := Vector2(hx, hz).length() + absf(cx) + absf(cz) + 1.0
		var inv := Basis(Vector3.UP, mi.rotation.y).inverse()
		for ix in range(floori(x - r), ceili(x + r)):
			for iz in range(floori(z - r), ceili(z + r)):
				var lp := inv * Vector3(ix + 0.5 - x, 0, iz + 0.5 - z)
				if absf(lp.x - cx) <= hx and absf(lp.z - cz) <= hz:
					blocks[Vector2i(ix, iz)] = true
	return mi

static func _vm(key: String, col: Color, metal := 0.0) -> StandardMaterial3D:
	if not _vmats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.roughness = 0.45 if metal > 0.0 else 0.85
		m.metallic = metal
		_vmats[key] = m
	return _vmats[key]

## Araç ya da lamba: yüzey adına göre boyanır (modeller dokusuz gelir). Lamba camı ve farlar gece parlar.
static func vehicle(file: String, paint: Color) -> MeshInstance3D:
	var p := VEH + file + ".res"
	if not _meshes.has(p):
		_meshes[p] = load(p) if Assets.enabled and ResourceLoader.exists(p) else null
	var m: Mesh = _meshes[p]
	if m == null:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = m
	for i in m.get_surface_count():
		var mat: Material
		match m.surface_get_name(i):
			"CarPaint": mat = _vm("paint" + paint.to_html(), paint, 0.15)
			"CarWindows": mat = _vm("glass", Color("#33475b"), 0.3)
			"CarRubber": mat = _vm("rubber", Color("#26262a"))
			"CarLamps", "White": mat = Models.glow()
			"Black": mat = _vm("pole", Color("#34373d"), 0.4)
			_: mat = _vm("grey", Color("#8a929c"), 0.3)
		mi.set_surface_override_material(i, mat)
	mi.visibility_range_end = 130.0
	mi.visibility_range_end_margin = 10.0
	mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	return mi

const PAINTS := ["#d94b3d", "#3d7dd9", "#f2c14e", "#4caf6a", "#f5f2ea", "#7e57c2", "#ff8a3d", "#5b6670"]
const CAR_SCALE := 0.62

## Park etmiş araç: uzun ekseni yol boyunca.
static func _park(g: Node, root: Node3D, file: String, paint: String, x: float, z: float, along_x: bool, flip := false) -> void:
	var v := vehicle(file, Color(paint))
	if v == null:
		return
	v.scale = Vector3.ONE * CAR_SCALE
	v.position = Vector3(x, g.height_at(x, z), z)
	v.rotation.y = (0.0 if along_x else PI / 2.0) + (PI if flip else 0.0)
	root.add_child(v)
	var a := v.mesh.get_aabb()
	var hl := a.size.x * CAR_SCALE / 2.0
	var hw := a.size.z * CAR_SCALE / 2.0
	var ex := hl if along_x else hw
	var ez := hw if along_x else hl
	for ix in range(floori(x - ex + 0.3), ceili(x + ex - 0.3)):
		for iz in range(floori(z - ez + 0.3), ceili(z + ez - 0.3)):
			blocks[Vector2i(ix, iz)] = true

## Tur atan araba: kapalı yol çizgisi boyunca, sağ şeritte.
static func _drive(root: Node3D, file: String, paint: String, center: Array, phase: float, speed: float) -> void:
	var v := vehicle(file, Color(paint))
	if v == null:
		return
	v.scale = Vector3.ONE * CAR_SCALE
	var n := center.size()
	var pts := []
	for i in n:   # şerit: her köşeyi iki komşu kenarın normaline göre kaydır
		var a: Vector2 = center[(i - 1 + n) % n]
		var b: Vector2 = center[i]
		var c: Vector2 = center[(i + 1) % n]
		var n1 := (b - a).normalized().orthogonal()
		var n2 := (c - b).normalized().orthogonal()
		pts.append(b - (n1 + n2).normalized() * 1.0)
	var tot := 0.0
	for i in n:
		tot += (pts[(i + 1) % n] as Vector2).distance_to(pts[i])
	root.add_child(v)
	movers.append({"node": v, "pts": pts, "len": tot, "s": phase * tot, "speed": speed, "v": speed, "id": movers.size(), "dir": Vector2.ZERO})

static func _at(pts: Array, s: float) -> Array:
	var n := pts.size()
	for i in n:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % n]
		var l := a.distance_to(b)
		if s <= l:
			return [a.lerp(b, s / maxf(l, 0.001)), (b - a).normalized()]
		s -= l
	return [pts[0], ((pts[1] as Vector2) - (pts[0] as Vector2)).normalized()]

# ---------------------------------------------------------------- köylüler
const NPC := "res://assets/npc/"
const NPC_SKINS := ["Blue", "Brown", "Green", "Yellow"]
const NPC_H := 1.45       # köylü boyu (m): çiftçiden biraz uzun
const WALK := "metarig|Walk"
const IDLE := "metarig|Idle"

static func npc_available() -> bool:
	return Assets.enabled and ResourceLoader.exists(NPC + "Peasant_Nolant.fbx")

## Bir köylü: rastgele kıyafet, döngülü yürüme/bekleme animasyonu.
static func _npc(root: Node3D, skin: int) -> Array:
	if _npc_scene == null:
		_npc_scene = load(NPC + "Peasant_Nolant.fbx")
	var n: Node3D = _npc_scene.instantiate()
	root.add_child(n)
	var key: String = NPC_SKINS[skin % NPC_SKINS.size()]
	if not _npc_mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = load(NPC + "Peasant_Nolant_%s.png" % key)
		m.roughness = 0.9
		_npc_mats[key] = m
	var box := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = _npc_mats[key]
		(mi as MeshInstance3D).visibility_range_end = 90.0
		var b: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		box = b if first else box.merge(b)
		first = false
	if _npc_scale <= 0.0:
		_npc_scale = NPC_H / maxf(box.size.y, 0.01)
	n.scale = Vector3.ONE * _npc_scale
	var aps := n.find_children("*", "AnimationPlayer", true, false)
	var ap: AnimationPlayer = aps[0] if aps.size() > 0 else null
	if ap != null:
		for a in [WALK, IDLE]:
			if ap.has_animation(a):
				ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	return [n, ap]

static func _at_open(pts: Array, s: float) -> Array:
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var l := a.distance_to(b)
		if s <= l or i == pts.size() - 2:
			return [a.lerp(b, clampf(s / maxf(l, 0.001), 0.0, 1.0)), (b - a).normalized()]
		s -= l
	return [pts[0], Vector2.DOWN]

static func _poly_len(pts: Array, loop: bool) -> float:
	var t := 0.0
	var n := pts.size()
	for i in (n if loop else n - 1):
		t += (pts[i] as Vector2).distance_to(pts[(i + 1) % n])
	return t

## Yürüyen köylü: açık yolda gidip gelir, kapalı yolda tur atar.
static func _walker(root: Node3D, r: RandomNumberGenerator, pts: Array, loop: bool) -> void:
	var made := _npc(root, r.randi())
	var tot := _poly_len(pts, loop)
	walkers.append({"node": made[0], "ap": made[1], "pts": pts, "len": tot, "loop": loop, "s": r.randf() * tot,
		"dir": 1.0 if r.randf() < 0.5 else -1.0, "speed": r.randf_range(0.85, 1.25), "pause": r.randf_range(0.0, 2.0), "rest": false})

## Duran köylü: meydanda ya da evlerin önünde sohbet eder.
static func _stander(g: Node, root: Node3D, r: RandomNumberGenerator, x: float, z: float, face: Vector2, id: String) -> void:
	var made := _npc(root, r.randi())
	var n: Node3D = made[0]
	if id != "":
		folk[id] = n
		var nl := Label3D.new()   # isim etiketi
		var fd := folk_def(id)
		nl.text = "%s %s" % [fd.icon, fd.name]
		nl.font = g.font
		nl.font_size = 34
		nl.outline_size = 10
		nl.outline_modulate = Color(0, 0, 0, 0.6)
		nl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		nl.pixel_size = 0.006 / maxf(_npc_scale, 0.001)
		nl.position = Vector3(0, (NPC_H + 0.15) / maxf(_npc_scale, 0.001), 0)
		nl.visibility_range_end = 40.0
		n.add_child(nl)
	n.position = Vector3(x, g.height_at(x, z), z)
	n.rotation.y = atan2(face.x - x, face.y - z)
	blocks[Vector2i(floori(x), floori(z))] = true
	if made[1] != null:
		(made[1] as AnimationPlayer).play(IDLE)
		(made[1] as AnimationPlayer).seek(r.randf() * 2.5, true)

static func _people(g: Node, root: Node3D) -> void:
	walkers.clear()
	folk.clear()
	_font = g.font
	_bubbles.clear()
	if not npc_available():
		return
	var r := RandomNumberGenerator.new()
	r.seed = 77
	var e := 2.85   # kaldırımın ortası (arabaların şeridinden uzak)
	var ro := RING_OUT + 0.6
	var routes := [
		[[Vector2(e, 38), Vector2(e, PLAZA.y - ro)], 1],
		[[Vector2(-e, 38), Vector2(-e, PLAZA.y - ro)], 1],
		[[Vector2(e, PLAZA.y + ro), Vector2(e, 92)], 2],
		[[Vector2(-e, PLAZA.y + ro), Vector2(-e, 92)], 2],
		[[Vector2(ro, STREETS[0] - e), Vector2(37, STREETS[0] - e)], 1],
		[[Vector2(-ro, STREETS[0] + e), Vector2(-37, STREETS[0] + e)], 1],
		[[Vector2(ro, STREETS[0] + e), Vector2(30, STREETS[0] + e)], 1],
		[[Vector2(-4, STREETS[1] - e), Vector2(-37, STREETS[1] - e)], 1],
		[[Vector2(4, STREETS[1] + e), Vector2(37, STREETS[1] + e)], 1],
	]
	for rt in routes:
		for k in rt[1]:
			_walker(root, r, rt[0], false)
	# meydanın çevresinde tur (banklarla plaza kenarı arasından)
	var ring := []
	for i in 16:
		var a := i * TAU / 16.0
		ring.append(PLAZA + Vector2(cos(a), sin(a)) * 4.75)
	for k in 2:
		_walker(root, r, ring, true)
	# sohbet edenler: meydanda ve evlerin önünde ikişer
	var spots := [[Vector2(-12.4, 51.0), Vector2(-10.6, 51.0)], [Vector2(12.6, 60.4), Vector2(12.6, 62.2)], [Vector2(-25.8, 76.6), Vector2(-24.0, 76.0)], [Vector2(8.4, 49.3), Vector2(10.2, 49.7)]]
	var fi := 0
	for sp in spots:
		var a: Vector2 = sp[0]
		var b: Vector2 = sp[1]
		_stander(g, root, r, a.x, a.y, b, TOWNSFOLK[fi].id)
		_stander(g, root, r, b.x, b.y, a, TOWNSFOLK[fi + 1].id)
		fi += 2

## Köylüleri yürütür: ara sıra durup soluklanır, çiftçi önündeyse bekler.
static func _tick_people(dt: float, who: Array) -> void:
	for b in _bubbles.duplicate():
		b[1] -= dt
		if b[1] <= 0.0 or not is_instance_valid(b[0]):
			if is_instance_valid(b[0]):
				(b[0] as Label3D).visible = false
			_bubbles.erase(b)
	for w in walkers:
		var node: Node3D = w.node
		if not is_instance_valid(node):
			continue
		var ap: AnimationPlayer = w.ap
		var pos: Array = _at(w.pts, w.s) if w.loop else _at_open(w.pts, w.s)
		var d: Vector2 = pos[1] * float(w.dir)
		var blocked := false
		for p in who:
			if Vector2(p.x, p.z).distance_to(pos[0] + d * 1.0) < 0.9:
				blocked = true
		if w.pause > 0.0 or blocked:
			w.pause = maxf(0.0, w.pause - dt)
			if ap != null and ap.current_animation != IDLE:
				ap.play(IDLE, 0.25)
		else:
			if ap != null and ap.current_animation != WALK:
				ap.play(WALK, 0.25)
				ap.speed_scale = w.speed / 1.05
			w.s += float(w.dir) * float(w.speed) * dt
			if w.loop:
				w.s = fposmod(w.s, w.len)
			elif w.s >= w.len or w.s <= 0.0:   # yolun sonu: dönüp bir süre bekle
				w.s = clampf(w.s, 0.0, w.len)
				w.dir = -float(w.dir)
				w.pause = randf_range(2.0, 6.0)
			elif randf() < dt * 0.03:
				w.pause = randf_range(2.0, 5.0)
		pos = _at(w.pts, w.s) if w.loop else _at_open(w.pts, w.s)
		d = pos[1] * float(w.dir)
		if w.pause > 0.0 and w.has("look"):   # konuşurken çiftçiye döner
			d = (w.look as Vector2) - (pos[0] as Vector2)
		elif w.has("look"):
			w.erase("look")
		node.position = Vector3(pos[0].x, 0.0, pos[0].y)
		node.rotation.y = lerp_angle(node.rotation.y, atan2(d.x, d.y), minf(1.0, dt * 6.0))

## Arabaları sürer; önünde çiftçi ya da başka araba varsa yavaşlayıp durur.
static func tick(dt: float, who: Array) -> void:
	_tick_people(dt, who)
	for m in movers:
		var node: MeshInstance3D = m.node
		if not is_instance_valid(node):
			continue
		var cur: Array = _at(m.pts, m.s)
		var ahead: Vector2 = cur[0] + cur[1] * 3.2
		var want: float = m.speed
		for p in who:
			if Vector2(p.x, p.z).distance_to(ahead) < 2.6:
				want = 0.0
		for o in movers:
			if o == m or not is_instance_valid(o.node):
				continue
			var op := Vector2(o.node.position.x, o.node.position.z)
			if op.distance_to(ahead) > 2.4 and op.distance_to(cur[0] + cur[1] * 1.6) > 1.8:
				continue
			var od: Vector2 = o.get("dir", Vector2.ZERO)
			# aynı yöne giden öndekini izle; kesişmede sırası önce olana yol ver (karşılıklı bekleme olmaz)
			if od.dot(cur[1]) > 0.5 or int(o.id) < int(m.id):
				want = 0.0
		m.v = move_toward(m.v, want, dt * 6.0)
		m.s = fmod(m.s + m.v * dt, m.len)
		var now: Array = _at(m.pts, m.s)
		m.dir = now[1]
		node.position = Vector3(now[0].x, 0.0, now[0].y)
		var target := atan2(-now[1].y, now[1].x) + PI   # modellerin burnu -x yönünde
		node.rotation.y = lerp_angle(node.rotation.y, target, minf(1.0, dt * 8.0))

## Yollar: asfalt şeritler, kesik orta çizgi, iki yanda kaldırım, meydanda dönel kavşak, girişte otoparklar.
static func _roads(root: Node3D) -> void:
	var asphalt := StandardMaterial3D.new()
	asphalt.albedo_color = Color(ASPHALT)
	asphalt.roughness = 0.95
	var walk := StandardMaterial3D.new()
	walk.albedo_color = Color(WALK_COL)
	walk.roughness = 1.0
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color("#f4f1e8")
	paint.roughness = 0.9
	var box := func(cx: float, cz: float, w: float, d: float, y: float, h: float, mat: Material) -> void:
		if w <= 0.05 or d <= 0.05:
			return
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(w, h, d)
		mi.mesh = bm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(cx, y - h / 2.0, cz)
		root.add_child(mi)
	# x boyunca [x0, x1] aralığını kesişme boşluklarıyla parçalara ayır
	var spans := func(x0: float, x1: float, gaps: Array) -> Array:
		var out := [[x0, x1]]
		for gp in gaps:
			var nx := []
			for sp in out:
				if gp[1] <= sp[0] or gp[0] >= sp[1]:
					nx.append(sp)
				else:
					if gp[0] > sp[0]:
						nx.append([sp[0], gp[0]])
					if gp[1] < sp[1]:
						nx.append([gp[1], sp[1]])
			out = nx
		return out
	var road_top := 0.035
	# ana yol (çiftlikten köyün kuzey ucuna)
	box.call(0.0, (37.0 + RECT.end.y) / 2.0, 4.4, RECT.end.y - 37.0, road_top, 0.05, asphalt)
	for sz in STREETS:
		box.call(0.0, sz, STREET_HALF * 2.0, 4.0, road_top + 0.002, 0.05, asphalt)
	for sx in [-1.0, 1.0]:
		box.call(sx * SIDE_X, (STREETS[0] + STREETS[1]) / 2.0, 4.0, STREETS[1] - STREETS[0] + 4.0, road_top + 0.001, 0.05, asphalt)
	# dönel kavşak: halka asfalt + çimenli göbek (meydan)
	var ring := MeshInstance3D.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 48
	for i in segs:
		var a0 := i * TAU / segs
		var a1 := (i + 1) * TAU / segs
		var p0 := Vector3(cos(a0) * (PLAZA_R - 0.2), 0, sin(a0) * (PLAZA_R - 0.2))
		var p1 := Vector3(cos(a1) * (PLAZA_R - 0.2), 0, sin(a1) * (PLAZA_R - 0.2))
		var q0 := Vector3(cos(a0) * RING_OUT, 0, sin(a0) * RING_OUT)
		var q1 := Vector3(cos(a1) * RING_OUT, 0, sin(a1) * RING_OUT)
		st.set_normal(Vector3.UP)
		for v in [p0, q0, q1, p0, q1, p1]:
			st.add_vertex(v)
	ring.mesh = st.commit()
	ring.material_override = asphalt
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = Vector3(PLAZA.x, road_top + 0.004, PLAZA.y)
	root.add_child(ring)
	var pl := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = PLAZA_R
	cm.bottom_radius = PLAZA_R + 0.1
	cm.height = 0.08
	cm.radial_segments = 40
	pl.mesh = cm
	var pm := walk.duplicate()
	pm.albedo_color = Color("#d6b47e")
	pl.material_override = pm
	pl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pl.position = Vector3(PLAZA.x, 0.04, PLAZA.y)
	root.add_child(pl)
	# kesik orta çizgiler (kesişme ve kavşak içinde yok)
	var dash := func(x0: float, x1: float, z: float, along_x: bool, gaps: Array) -> void:
		for sp in spans.call(x0, x1, gaps):
			var t: float = sp[0] + 1.0
			while t + 1.2 < sp[1] - 0.5:
				if along_x:
					box.call(t + 0.6, z, 1.2, 0.14, road_top + 0.012, 0.01, paint)
				else:
					box.call(z, t + 0.6, 0.14, 1.2, road_top + 0.012, 0.01, paint)
				t += 3.0
	for sz in STREETS:
		var gaps := [[-SIDE_X - 3.0, -SIDE_X + 3.0], [SIDE_X - 3.0, SIDE_X + 3.0], [-3.0, 3.0]]
		if absf(sz - PLAZA.y) < 1.0:
			gaps.append([-RING_OUT - 0.5, RING_OUT + 0.5])
		dash.call(-STREET_HALF, STREET_HALF, sz, true, gaps)
	var mgaps := [[PLAZA.y - RING_OUT - 0.5, PLAZA.y + RING_OUT + 0.5]]
	for sz in STREETS:
		mgaps.append([sz - 3.0, sz + 3.0])
	dash.call(37.0, RECT.end.y, 0.0, false, mgaps)
	for sx in [-1.0, 1.0]:
		dash.call(STREETS[0] + 2.0, STREETS[1] - 2.0, sx * SIDE_X, false, [])
	# kaldırımlar (yolların iki yanında 1.3 m, kesişmelerde ara)
	var kw := 1.3
	var ky := 0.07
	for sz in STREETS:
		var gaps := [[-SIDE_X - 2.0 - kw, -SIDE_X + 2.0 + kw], [SIDE_X - 2.0 - kw, SIDE_X + 2.0 + kw], [-2.2 - kw, 2.2 + kw]]
		if absf(sz - PLAZA.y) < 1.0:
			gaps.append([-RING_OUT - 0.4, RING_OUT + 0.4])
		for side in [-1.0, 1.0]:
			var g2 := gaps.duplicate()
			for sp in spans.call(-STREET_HALF, STREET_HALF, g2):
				box.call((sp[0] + sp[1]) / 2.0, sz + side * (2.0 + kw / 2.0), sp[1] - sp[0], kw, ky, 0.08, walk)
	var zg := [[PLAZA.y - RING_OUT - 0.4, PLAZA.y + RING_OUT + 0.4]]
	for sz in STREETS:
		zg.append([sz - 2.0 - kw, sz + 2.0 + kw])
	for side in [-1.0, 1.0]:
		for sp in spans.call(37.0, RECT.end.y, zg):
			box.call(side * (2.2 + kw / 2.0), (sp[0] + sp[1]) / 2.0, kw, sp[1] - sp[0], ky, 0.08, walk)
	for sx in [-1.0, 1.0]:
		for side in [-1.0, 1.0]:
			box.call(sx * SIDE_X + side * (2.0 + kw / 2.0), (STREETS[0] + STREETS[1]) / 2.0, kw, STREETS[1] - STREETS[0] - 4.0 - 2.0 * kw, ky, 0.08, walk)
	# otoparklar: asfalt zemin, beyaz park yeri çizgileri
	for l in LOTS:
		var lr: Rect2 = l
		box.call(lr.get_center().x, lr.get_center().y, lr.size.x, lr.size.y, road_top + 0.003, 0.05, asphalt)
		var nb := int(lr.size.x / BAY_W)
		for row in [0, 1]:
			var z0 := lr.position.y if row == 0 else lr.end.y - BAY_L
			for k in nb + 1:
				box.call(lr.position.x + k * BAY_W, z0 + BAY_L / 2.0, 0.1, BAY_L, road_top + 0.012, 0.01, paint)
			box.call(lr.get_center().x, z0 + (BAY_L if row == 0 else 0.0), lr.size.x, 0.1, road_top + 0.012, 0.01, paint)
		# büyük P levhası (yola bakar)
		var px := lr.position.x + 0.4 if lr.position.x > 0.0 else lr.end.x - 0.4
		var pz := lr.position.y - 0.5
		box.call(px, pz, 0.12, 0.12, 2.4, 2.4, _vm("pole", Color("#34373d"), 0.4))
		box.call(px, pz, 0.9, 0.12, 2.9, 0.9, _vm("psign", Color("#2f6fd0")))
		var lb := Label3D.new()
		lb.text = "P"
		lb.font_size = 96
		lb.pixel_size = 0.006
		lb.outline_size = 0
		lb.position = Vector3(px, 2.45, pz - 0.08)
		lb.double_sided = true
		root.add_child(lb)

## Bir otoparkın i. park yeri (sıra 0: güney, 1: kuzey) — merkez.
static func bay(lot: int, row: int, i: int) -> Vector2:
	var lr: Rect2 = LOTS[lot]
	var z := lr.position.y + BAY_L / 2.0 if row == 0 else lr.end.y - BAY_L / 2.0
	return Vector2(lr.position.x + BAY_W * (i + 0.5), z)

## Dönel kavşaklı tur yolu: göbeğe kuzeyden (+z) girip `exit_a` açısında çıkar, saat yönünde (yukarıdan bakınca) döner.
static func _ring_arc(from_a: float, to_a: float) -> Array:
	var pts := []
	var a := from_a
	while a > to_a + 0.01:
		pts.append(PLAZA + Vector2(cos(a), sin(a)) * RING_C)
		a -= deg_to_rad(15.0)
	pts.append(PLAZA + Vector2(cos(to_a), sin(to_a)) * RING_C)
	return pts

## Yönü (dx, dz) olan bakışın y-dönüşü.
static func _yaw(dx: float, dz: float) -> float:
	return atan2(dx, dz)

## Köyü kurar; gece yanacak lambaların konumlarını döndürür ({x, z, type}).
static func build(g: Node) -> Array:
	blocks.clear()
	var lamps := []
	var root := Node3D.new()
	root.name = "Town"
	g.add_child(root)
	_roads(root)
	if not available():
		return lamps
	var r := RandomNumberGenerator.new()
	r.seed = 2024
	var hi := 0
	var side_props := ["barrel_a001", "barrel_b001", "cratebox_a001", "cratebox_b001", "cart_b001", "cart_c001", "milktank_a002", "bucket_a001", "bench_d001"]
	# cadde evleri: kuzey sırası güneye, güney sırası kuzeye bakar
	for sz in STREETS:
		for row in [-1.0, 1.0]:
			for hx in [-31.0, -18.0, 18.0, 31.0]:
				var file: String = HOUSES[hi % HOUSES.size()]
				hi += 1
				var z: float = sz + row * 7.6
				_put(g, root, file, hx, z, _yaw(0, -row), _fit(file, 8.6))
				# evin yanında birkaç eşya
				var px: float = hx + (5.6 if (r.randf() < 0.5 and absf(hx) < 25.0) else -5.6 * signf(hx) if absf(hx) > 25.0 else -5.6)
				for k in r.randi_range(1, 2):
					var pf: String = side_props[r.randi() % side_props.size()]
					_put(g, root, pf, px + r.randf_range(-0.6, 0.6), z + r.randf_range(-2.5, 2.5) - row * 1.0, r.randf() * TAU, 0.85, true, 110.0, false)
				# bahçe ağacı
				var tf: String = TREES[r.randi() % TREES.size()]
				_put(g, root, tf, hx + r.randf_range(-3.0, 3.0), z + row * 6.4, r.randf() * TAU, r.randf_range(0.75, 1.0), true, 140.0)
	# köy girişi: ana yolun iki yanında otoparklar (_roads içinde çizilir)
	# köy uçlarında ahırlar, silolar, barakalar
	for sx in [-1.0, 1.0]:
		_put(g, root, "farmbuilding_0%d" % (1 if sx < 0 else 2), sx * 49.0, 50.0, _yaw(-sx, 0), _fit("farmbuilding_01", 11.0))
		_put(g, root, "farmbuilding_0%d" % (4 if sx < 0 else 3), sx * 49.0, 84.0, _yaw(-sx, 0), _fit("farmbuilding_04", 11.0))
		_put(g, root, "farmstractures_2%d" % (1 if sx < 0 else 3), sx * 53.0, 61.0, 0.0, 0.62)
		_put(g, root, "farmstractures_22", sx * 53.0, 65.0, 0.0, 0.62)
		_put(g, root, "farmstractures_1%d" % (1 if sx < 0 else 3), sx * 45.5, 66.5, _yaw(-sx, 0), _fit("farmstractures_11", 6.5))
		_put(g, root, "farmstractures_0%d" % (2 if sx < 0 else 3), sx * 47.0, 74.0, _yaw(-sx, 0), _fit("farmstractures_02", 4.0))
		_put(g, root, "car_0%d" % (7 if sx < 0 else 9), sx * 42.0, 58.6 if sx < 0 else 77.4, _yaw(1, 0), 0.9, true, 90.0)
	# meydan: ortada büyük ağaç, çevresinde banklar
	_put(g, root, "tree_02", PLAZA.x, PLAZA.y, 0.3, 1.25)
	for i in 4:
		var a := PI / 4.0 + i * PI / 2.0
		var bx := PLAZA.x + cos(a) * 3.6
		var bz := PLAZA.y + sin(a) * 3.6
		_put(g, root, "bench_a001", bx, bz, _yaw(PLAZA.x - bx, PLAZA.y - bz), 0.85, true, 110.0, false)
	_put(g, root, "bonfire_a001", -9.0, 50.5, 0.0, 0.9, true, 110.0, false)
	_put(g, root, "table_a001", 11.5, 50.6, 0.4, 0.85, true, 110.0, false)
	_put(g, root, "chair_a001", 12.5, 51.1, 2.0, 0.85, false, 90.0, false)
	_put(g, root, "rocks_01", -52.0, 92.0, 0.6, 1.0)
	_put(g, root, "rocks_04", 53.0, 42.0, 2.1, 0.9)
	# sokak lambaları: ana yol ve caddeler
	var lamp := func(x: float, z: float, fx: float, fz: float, kind: String) -> void:
		var v := vehicle(kind, Color.WHITE)
		if v != null:   # kolu (+x) yola uzanır
			v.scale = Vector3.ONE * 0.85
			v.position = Vector3(x, g.height_at(x, z), z)
			v.rotation.y = atan2(-fz, fx)
			v.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(v)
			blocks[Vector2i(floori(x), floori(z))] = true
		elif _put(g, root, "streetlight_a001", x, z, _yaw(fx, fz), 1.5, true, 130.0, false) == null:
			return
		lamps.append({"x": x - 0.5, "z": z - 0.5, "type": "townlamp"})
	var zl := 40.0
	while zl < 94.0:
		var sx := -1.0 if int(zl) % 24 < 12 else 1.0
		if absf(zl - PLAZA.y) > RING_OUT + 1.0 and absf(zl - STREETS[1]) > 3.5:
			lamp.call(sx * 2.9, zl, -sx, 0.0, "lamp_1")
		zl += 12.0
	for sz in STREETS:
		for lx in [-34.0, -24.5, -11.0, 11.0, 24.5, 34.0]:
			var sgn := 1.0 if int(lx) % 2 == 0 else -1.0
			lamp.call(lx, sz + sgn * 2.8, 0.0, -sgn, "lamp_3")
	for sx in [-1.0, 1.0]:   # göbeğin kısa direkli lambaları
		lamp.call(PLAZA.x + sx * 4.7, PLAZA.y, sx, 0.0, "lamp_4")
	# park etmiş araçlar, durakta otobüs, ahırların önünde kamyonlar
	# otoparklardaki araçlar (bazı yerler boş)
	var lot_cars := [["car_1", PAINTS[0]], ["car_3", PAINTS[1]], ["car_5", PAINTS[4]], ["car_2", PAINTS[2]], ["policecar", "#22397a"],
		["car_6", PAINTS[5]], ["car_4", PAINTS[3]], ["car_1", PAINTS[7]], ["car_3", PAINTS[6]]]
	var ci := 0
	for lot in LOTS.size():
		for row in [0, 1]:
			for k in int((LOTS[lot] as Rect2).size.x / BAY_W):
				if r.randf() < 0.45 or ci >= lot_cars.size():
					continue
				var bp := bay(lot, row, k)
				_park(g, root, lot_cars[ci][0], lot_cars[ci][1], bp.x, bp.y, false, row == 1)
				ci += 1
	_park(g, root, "bus", "#f2b632", -19.0, 41.0, true)   # durakta otobüs, otoparkın yanında
	_park(g, root, "truck_1", "#c0392b", -42.0, 46.0, false)
	_park(g, root, "truck_2", "#2e7d5b", 42.0, 89.0, false, true)
	# tur atan arabalar: iki tek yönlü halka; ikisi de ana yoldan güneye inip dönel kavşaktan geçer
	movers.clear()
	var top := PI / 2.0   # göbeğin kuzeyi (+z)
	var east := [Vector2(0, STREETS[1])]
	east.append_array(_ring_arc(top, 0.0))
	east.append_array([Vector2(SIDE_X, STREETS[0]), Vector2(SIDE_X, STREETS[1])])
	var west := [Vector2(0, STREETS[1])]
	west.append_array(_ring_arc(top, -PI))
	west.append_array([Vector2(-SIDE_X, STREETS[0]), Vector2(-SIDE_X, STREETS[1])])
	_drive(root, "car_4", PAINTS[6], east, 0.0, 4.2)
	_drive(root, "car_2", PAINTS[1], east, 0.5, 3.8)
	_drive(root, "car_6", PAINTS[0], west, 0.2, 4.0)
	_drive(root, "car_1", PAINTS[3], west, 0.7, 4.4)
	_people(g, root)
	# yol kenarı ağaçları ve köy çevresi
	for i in 70:
		var x := r.randf_range(RECT.position.x + 1.0, RECT.end.x - 1.0)
		var z := r.randf_range(RECT.position.y + 1.0, RECT.end.y - 1.0)
		if on_road(x, z) or absf(x) < 4.5 or Vector2(x - (-8.0), z - 31.0).length() < 10.0:
			continue
		var c := Vector2i(floori(x), floori(z))
		var clear := true
		for dx in range(-3, 4):
			for dz in range(-3, 4):
				if blocks.has(c + Vector2i(dx, dz)):
					clear = false
		var near_road := false
		for sz in STREETS:
			if absf(z - sz) < 3.4:
				near_road = true
		if not clear or near_road:
			continue
		_put(g, root, TREES[r.randi() % TREES.size()], x, z, r.randf() * TAU, r.randf_range(0.7, 1.05), true, 140.0)
	# köy tabelası
	_put(g, root, "streetsign_a001", 3.4, 39.0, _yaw(0, -1), 1.2, true, 110.0, false)
	var sg := Label3D.new()
	sg.font = g.font
	sg.text = "🏘️ " + NAME.to_upper()
	sg.font_size = 64
	sg.pixel_size = 0.007
	sg.outline_size = 10
	sg.outline_modulate = Color(0.2, 0.12, 0.05, 0.8)
	sg.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sg.position = Vector3(3.4, g.height_at(3.4, 39.0) + 3.6, 39.0)
	root.add_child(sg)
	return lamps
