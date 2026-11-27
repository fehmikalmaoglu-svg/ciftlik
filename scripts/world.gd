class_name World
extends RefCounted
## Sonsuz keşif dünyası: kayda özel tohumla biyomlar, oyuncunun çevresinde 50 m'lik karolar
## halinde akan zemin, göller ve MultiMesh doğa. Başlangıç bölgesi (±CORE) elle yapılmıştır:
## zeminini ve süslerini game.gd kurar, burada yalnızca dışarısı üretilir.

const TILE := 50.0
const CORE := 100.0
const WATER_Y := -0.35
## Uzaklığa göre ayrıntı: halka ≤ LOD_RING[i] ise SEGS[i] bölmeli zemin.
const SEGS := [25, 10, 5]
const LOD_RING := [1, 3]
const BIOMES := ["Ilıman çayırlar", "Orman kıyısı", "Göl vadisi", "Güneşli ova", "Yüksek yayla", "Karlı kuzey"]
const B_COL := [Color("#69b443"), Color("#4f9a3c"), Color("#74c35b"), Color("#c9bd68"), Color("#8eab5c"), Color("#eef2f6")]
const C_SAND := Color("#e3d28f")
const C_BED := Color("#b5a777")
const C_ROCK := Color("#8f8c80")
const C_SNOW := Color("#f3f6f9")
const MK := "res://assets/megakit/"
const NAT := "res://assets/nature/"
const CZ := "res://assets/cozy/"
## Biyom başına doğa: [dosya, ağırlık, boy_min, boy_max, tür]. Tür: 0 süs, 1 yuvarlak ağaç,
## 2 çam, 3 engel (kaya/kütük), 4 karlı çam. Ağaç ve engeller bulunduğu hücreyi kapatır.
const FLORA := [
	[[CZ + "Nat_01_OakRound.glb", 4, 4.0, 6.5, 1], [CZ + "Nat_03_Birch.glb", 2, 4.5, 7.0, 1], [MK + "CommonTree_3.gltf", 2, 4.5, 7.0, 1],
		[MK + "CommonTree_5.gltf", 2, 4.5, 7.5, 1], [MK + "Bush_Common.gltf", 6, 0.8, 1.4, 0], [MK + "Bush_Common_Flowers.gltf", 4, 0.8, 1.3, 0],
		[MK + "Flower_3_Group.gltf", 8, 0.35, 0.6, 0], [MK + "Flower_4_Single.gltf", 8, 0.35, 0.6, 0], [CZ + "Nat_30_Daisy.glb", 6, 0.3, 0.5, 0],
		[MK + "Grass_Common_Short.gltf", 22, 0.3, 0.5, 0], [MK + "Grass_Wispy_Tall.gltf", 10, 0.5, 0.8, 0],
		[MK + "Rock_Medium_1.gltf", 2, 0.7, 1.3, 3], [MK + "Pebble_Round_1.gltf", 3, 0.2, 0.4, 0]],
	[[CZ + "Nat_03_Birch.glb", 10, 5.0, 8.0, 1], [CZ + "Nat_01_OakRound.glb", 8, 4.5, 7.5, 1], [MK + "Pine_5.gltf", 8, 6.0, 10.0, 2],
		[MK + "CommonTree_5.gltf", 4, 5.0, 9.0, 1], [MK + "Pine_4.gltf", 3, 6.0, 10.0, 2], [MK + "CommonTree_3.gltf", 3, 5.0, 8.5, 1],
		[MK + "Fern_1.gltf", 12, 0.7, 1.1, 0], [MK + "Mushroom_Common.gltf", 5, 0.25, 0.45, 0], [CZ + "Nat_42_MushroomGroup.glb", 3, 0.3, 0.5, 0],
		[CZ + "Nat_47_LogLying.glb", 2, 0.5, 0.7, 3], [CZ + "Nat_50_StumpRoots.glb", 2, 0.5, 0.8, 3], [MK + "Grass_Common_Tall.gltf", 12, 0.4, 0.7, 0],
		[MK + "Bush_Common.gltf", 6, 0.9, 1.5, 0]],
	[[CZ + "Nat_03_Birch.glb", 2, 4.5, 7.0, 1], [CZ + "Nat_10_CherryBlossom.glb", 3, 4.0, 6.0, 1], [MK + "Grass_Wispy_Tall.gltf", 20, 0.6, 1.0, 0],
		[CZ + "Nat_37_TallGrass.glb", 10, 0.6, 1.0, 0], [MK + "Flower_3_Single.gltf", 10, 0.3, 0.5, 0], [MK + "Flower_4_Single.gltf", 10, 0.3, 0.5, 0],
		[MK + "Bush_Common_Flowers.gltf", 5, 0.8, 1.3, 0], [MK + "Clover_1.gltf", 10, 0.15, 0.3, 0], [MK + "Pebble_Round_3.gltf", 4, 0.2, 0.4, 0]],
	[[CZ + "Nat_33_Sunflower.glb", 10, 1.3, 1.9, 0], [MK + "Grass_Wispy_Short.gltf", 20, 0.3, 0.5, 0], [MK + "Grass_Wispy_Tall.gltf", 15, 0.5, 0.8, 0],
		[CZ + "Nat_37_TallGrass.glb", 10, 0.5, 0.9, 0], [MK + "Flower_3_Single.gltf", 8, 0.3, 0.5, 0], [CZ + "Nat_01_OakRound.glb", 3, 3.5, 5.5, 1],
		[MK + "Pebble_Round_1.gltf", 3, 0.3, 0.6, 0], [MK + "Plant_7.gltf", 5, 0.4, 0.7, 0]],
	[[MK + "Pine_5.gltf", 10, 6.0, 10.0, 2], [MK + "Pine_4.gltf", 4, 6.0, 10.0, 2], [MK + "Rock_Medium_2.gltf", 3, 0.8, 1.8, 3],
		[MK + "Rock_Medium_3.gltf", 3, 0.8, 1.8, 3], [CZ + "Nat_22_RockLarge.glb", 1.5, 1.2, 2.4, 3], [CZ + "Nat_24_RockTall.glb", 1, 1.6, 3.0, 3],
		[CZ + "Nat_32_Lavender.glb", 10, 0.4, 0.7, 0], [MK + "Grass_Common_Short.gltf", 20, 0.3, 0.5, 0], [MK + "Fern_1.gltf", 4, 0.6, 1.0, 0],
		[CZ + "Nat_28_RockMossy.glb", 3, 0.6, 1.2, 3]],
	[[CZ + "Nat_07_Spruce.glb", 12, 5.0, 9.0, 4], [MK + "Pine_5.gltf", 4, 5.0, 8.0, 4],
		[CZ + "Win_44_SnowPileC.glb", 6, 0.4, 0.8, 0], [MK + "Rock_Medium_1.gltf", 3, 0.6, 1.4, 3], [CZ + "Win_29_Snowman.glb", 0.15, 1.3, 1.6, 3],
		[MK + "Pebble_Round_2.gltf", 2, 0.2, 0.4, 0]],
]
## Karo başına (50×50 m) biyomun doğa yoğunluğu; aday nokta sayısı CAND.
const FLORA_N := [150, 210, 170, 170, 150, 120]
const CAND := 260
## Gerçek ağaç modelleri bu uzaklığa kadar (karo merkezine göre); ötesi ucuz biçim.
const NEAR_TREES := 55.0

static var seed := 0
static var _n := {}
static var _wcache := {}
static var root: Node3D
static var ground_mat: Material
static var water_mat: Material
static var tiles := {}          # Vector2i → {lod, node, block: Dictionary, walk: PackedByteArray}
static var radius := 6
static var _center := Vector2i(99999, 99999)
static var _queue: Array = []
static var _models := {}        # dosya → [[mesh, xf], ...] (boy 1 m'ye göre)
static var _far: Array = []     # uzak ağaç biçimleri: yuvarlak, çam, karlı çam
static var _cum := []           # biyom başına birikimli ağırlıklar
## Oyuncunun kullandığı hücreler: true dönerse oraya doğa konmaz.
static var exclude := Callable()
## Oyuncunun parselleri (game.gd ile aynı ızgara): içi düzleşir (y=0), kenarı 5 m'de yumuşar.
const PARCEL_O := -20
const PARCEL_S := 8
static var _flat := {}

static func set_land(land: Dictionary) -> void:
	_flat = land.duplicate()
	if not _n.is_empty():
		var nz := _n.duplicate()
		nz.flat = _flat
		_n = nz   # iş parçacıkları eski takımı tutar; yenisi ayrı sözlük

## Bir alanın karolarını hemen yeniden kurar (parsel alındı: düzleşme ve doğa temizliği).
static func refresh(rect: Rect2) -> void:
	var r := rect.grow(6.0)
	for k in tiles.keys():
		var t: Dictionary = tiles[k]
		if Rect2(k.x * TILE, k.y * TILE, TILE, TILE).intersects(r):
			_apply(_job(k, t.lod, seed, _n))

static func _flat_f(x: float, z: float, fl: Dictionary) -> float:
	var px := floori((x - PARCEL_O) / PARCEL_S)
	var pz := floori((z - PARCEL_O) / PARCEL_S)
	var best := 0.0
	for dz in 3:
		for dx in 3:
			var pc := Vector2i(px + dx - 1, pz + dz - 1)
			if fl.has(pc):
				var x0 := PARCEL_O + pc.x * PARCEL_S
				var z0 := PARCEL_O + pc.y * PARCEL_S
				var d := Vector2(maxf(maxf(x0 - x, x - x0 - PARCEL_S), 0.0), maxf(maxf(z0 - z, z - z0 - PARCEL_S), 0.0)).length()
				best = maxf(best, 1.0 - smoothstep(0.0, 5.0, d))
	return best

static func setup(g: Node3D, s: int, gmat: Material, wmat: Material) -> void:
	ground_mat = gmat
	water_mat = wmat
	if root == null or not is_instance_valid(root):
		root = Node3D.new()
		root.name = "World"
		g.add_child(root)
	_reseed(s)
	if _far.is_empty():
		_far = [_far_tree(false, Color("#4f9a3e")), _far_tree(true, Color("#2f6d3a")), _far_tree(true, Color("#dfe9ee"))]
	if _cum.is_empty():
		for list in FLORA:
			var c := []
			var t := 0.0
			for e in list:
				t += float(e[1])
				c.append(t)
			_cum.append(c)

static func _reseed(s: int) -> void:
	seed = s
	_wcache.clear()
	var mk := func(k: int, f: float, oct: int) -> FastNoiseLite:
		var n := FastNoiseLite.new()
		n.seed = s * 31 + k * 1013
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = f
		n.fractal_type = FastNoiseLite.FRACTAL_FBM if oct > 1 else FastNoiseLite.FRACTAL_NONE
		n.fractal_octaves = oct
		return n
	_n = {"flat": _flat, "t": mk.call(1, 1.0 / 900.0, 2), "m": mk.call(2, 1.0 / 750.0, 2), "e": mk.call(3, 1.0 / 650.0, 2),
		"f": mk.call(4, 1.0 / 320.0, 2), "h": mk.call(5, 1.0 / 170.0, 3), "r": mk.call(6, 1.0 / 260.0, 2), "l": mk.call(7, 1.0 / 110.0, 2)}

## Tohum değişti (başka kariyer, misafir): bütün karoları yeniden kur.
static func reset(s: int) -> void:
	if s == seed:
		return
	_reseed(s)
	for k in tiles.keys():
		_drop(k)
	_center = Vector2i(99999, 99999)

# ---------------------------------------------------------------- biyomlar ve yükseklik
static func _lay(w: Array, i: int, a: float) -> void:
	if a <= 0.0:
		return
	for k in 6:
		w[k] *= 1.0 - a
	w[i] += a

## Bir noktadaki biyom ağırlıkları (toplamı 1). Başlangıç çevresi hep ılıman çayırdır.
## nz: gürültü takımı (iş parçacıkları kendi kopyasını taşır).
static func _weights_raw(x: float, z: float, nz: Dictionary) -> Array:
	var w := [1.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	var away := smoothstep(240.0, 460.0, Vector2(x, z).length())
	if away <= 0.0:
		return w
	var t: float = nz.t.get_noise_2d(x, z) + clampf(z / 2500.0, -0.35, 0.35)   # kuzey (-z) serin, güney sıcak
	var m: float = nz.m.get_noise_2d(x, z)
	var e: float = nz.e.get_noise_2d(x, z)
	var f: float = nz.f.get_noise_2d(x, z)
	_lay(w, 1, smoothstep(0.02, 0.16, f) * away)
	_lay(w, 2, smoothstep(0.16, 0.3, m) * away)
	_lay(w, 3, smoothstep(0.14, 0.28, t) * smoothstep(0.08, -0.06, m) * away)
	_lay(w, 4, smoothstep(0.2, 0.34, e) * away)
	_lay(w, 5, smoothstep(-0.16, -0.3, t) * away)
	return w

static func _bilerp(a: Array, b: Array, c: Array, d: Array, fx: float, fz: float) -> Array:
	var w := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	for k in 6:
		w[k] = lerpf(lerpf(a[k], b[k], fx), lerpf(c[k], d[k], fx), fz)
	return w

## 10 m ızgarada önbellekli ağırlıklar, arası doğrusal: karo sınırları birebir örtüşür.
static func weights(x: float, z: float) -> Array:
	var gx := x / 10.0
	var gz := z / 10.0
	var ix := floori(gx)
	var iz := floori(gz)
	return _bilerp(_wl(ix, iz), _wl(ix + 1, iz), _wl(ix, iz + 1), _wl(ix + 1, iz + 1), gx - ix, gz - iz)

static func _wl(ix: int, iz: int) -> Array:
	if _n.is_empty():
		_reseed(maxi(seed, 1))
	var key := Vector2i(ix, iz)
	var w = _wcache.get(key)
	if w == null:
		if _wcache.size() > 60000:
			_wcache.clear()
		w = _weights_raw(ix * 10.0, iz * 10.0, _n)
		_wcache[key] = w
	return w

## Karonun kendi 6×6 ağırlık ızgarası (iş parçacığında, ortak önbelleğe dokunmadan).
static func _lattice(x0: float, z0: float, nz: Dictionary) -> Array:
	var lat := []
	for j in 6:
		for i in 6:
			lat.append(_weights_raw(x0 + i * 10.0, z0 + j * 10.0, nz))
	return lat

static func _wlat(lat: Array, x0: float, z0: float, x: float, z: float) -> Array:
	var gx := clampf((x - x0) / 10.0, 0.0, 4.9999)
	var gz := clampf((z - z0) / 10.0, 0.0, 4.9999)
	var ix := int(gx)
	var iz := int(gz)
	var b := iz * 6 + ix
	return _bilerp(lat[b], lat[b + 1], lat[b + 6], lat[b + 7], gx - ix, gz - iz)

## Baskın biyomun sırası.
static func biome(x: float, z: float) -> int:
	var w := weights(x, z)
	var best := 0
	for k in 6:
		if w[k] > w[best]:
			best = k
	return best

static func h(x: float, z: float) -> float:
	var w := weights(x, z)
	return h_w(x, z, w, _n)

static func h_w(x: float, z: float, w: Array, nz: Dictionary) -> float:
	var n: float = nz.h.get_noise_2d(x, z)
	var hp := maxf(0.0, n + 0.1)
	var y: float = w[0] * hp * 6.0 + w[1] * (hp * 8.0 + 0.3) + w[2] * (n * 5.0 + 0.3) + w[3] * (n * 1.5 + 0.5) + w[5] * (hp * 10.0 + 1.0)
	if w[4] > 0.001:
		var r: float = 1.0 - absf(nz.r.get_noise_2d(x, z))
		y += w[4] * (4.0 + r * r * 26.0 + n * 6.0)
	# küçük göller (başlangıç çevresinde yok; ovada, yaylada ve karda seyrek)
	var away := smoothstep(130.0, 220.0, Vector2(x, z).length())
	if away > 0.0:
		var l: float = nz.l.get_noise_2d(x, z)
		var thr: float = 0.42 - 0.3 * w[2] + 0.2 * (w[3] + w[4] + w[5])
		y = lerpf(y, -1.4, smoothstep(thr, thr + 0.12, l) * away)
	var fl: Dictionary = nz.get("flat", {})
	if not fl.is_empty():
		var ff := _flat_f(x, z, fl)
		if ff > 0.0:
			y = lerpf(y, 0.0, ff)
	return y

static func _color(w: Array, y: float, slope: float) -> Color:
	var c := Color(0, 0, 0, 0)
	for k in 6:
		c += B_COL[k] * float(w[k])
	c = c.lerp(C_ROCK, clampf(slope * 2.4 - 0.6, 0.0, 1.0) * (1.0 - float(w[5]) * 0.6))
	c = c.lerp(C_SNOW, smoothstep(21.0, 27.0, y + slope * 4.0))
	if y < WATER_Y + 0.3:
		c = c.lerp(C_SAND, smoothstep(WATER_Y + 0.3, WATER_Y + 0.05, y))
		c = c.lerp(C_BED, smoothstep(WATER_Y - 0.1, WATER_Y - 0.5, y))
	c.a = 1.0
	return c

## Göl suyu ya da ağaç/kaya: yürünemez. Yüklenmemiş karo da kapalı sayılır.
static func walkable(x: int, z: int) -> bool:
	var k := Vector2i(floori(x / TILE), floori(z / TILE))
	var t = tiles.get(k)
	if t == null:
		return false
	if t.block.has(Vector2i(x, z)):
		return false
	var walk: PackedByteArray = t.walk
	if walk.is_empty():
		walk = _walk_grid(k.x * TILE, k.y * TILE, _lattice(k.x * TILE, k.y * TILE, _n), _n)
		t.walk = walk
	return walk[(z - int(k.y * TILE)) * 50 + (x - int(k.x * TILE))] == 1

static func _walk_grid(x0: float, z0: float, lat: Array, nz: Dictionary) -> PackedByteArray:
	var walk := PackedByteArray()
	walk.resize(2500)
	for j in 50:
		for i in 50:
			var x := x0 + i + 0.5
			var z := z0 + j + 0.5
			walk[j * 50 + i] = 1 if h_w(x, z, _wlat(lat, x0, z0, x, z), nz) > WATER_Y + 0.12 else 0
	return walk

# ---------------------------------------------------------------- akış
static var _jobs := {}          # Vector2i → görev kimliği
static var _done: Array = []
static var _mutex := Mutex.new()
const MAX_JOBS := 3

static func _ring(k: Vector2i) -> int:
	return maxi(absi(k.x - _center.x), absi(k.y - _center.y))

static func _lod_for(ring: int) -> int:
	return 0 if ring <= LOD_RING[0] else 1 if ring <= LOD_RING[1] else 2

static func _want(k: Vector2i, lod: int) -> bool:
	var t = tiles.get(k)
	return t == null or t.lod != lod or t.seed != seed

## Her kare çağrılır: merkez karo değişince ister/bırakır; karoları arka planda hesaplatır,
## bitenleri sahneye koyar. sync: hepsini hemen bu karede kur (yükleme, ışınlanma, sınama).
static func update(p: Vector3, sync := false) -> void:
	if root == null:
		return
	var c := Vector2i(floori(p.x / TILE), floori(p.z / TILE))
	if c != _center:
		var jump := maxi(absi(c.x - _center.x), absi(c.y - _center.y)) > 2
		_center = c
		for k in tiles.keys():
			if _ring(k) > radius + 1:
				_drop(k)
		_queue.clear()
		for dz in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var k := c + Vector2i(dx, dz)
				if _want(k, _lod_for(_ring(k))):
					_queue.append(k)
		_queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _ring(a) < _ring(b))
		if jump:   # uzağa ışınlandı: yakın halka hemen
			while not _queue.is_empty() and _ring(_queue[0]) <= LOD_RING[0]:
				var k0: Vector2i = _queue.pop_front()
				_apply(_job(k0, _lod_for(_ring(k0)), seed, _n))
	if sync:
		while not _queue.is_empty():
			var k1: Vector2i = _queue.pop_front()
			_apply(_job(k1, _lod_for(_ring(k1)), seed, _n))
	# bitenler
	_mutex.lock()
	var done := _done
	_done = []
	_mutex.unlock()
	var t0 := Time.get_ticks_usec()
	for di in done.size():
		if not sync and Time.get_ticks_usec() - t0 > 3000:   # kare bütçesi: kalanı sonraki kareye
			_mutex.lock()
			_done = done.slice(di) + _done
			_mutex.unlock()
			break
		var r: Dictionary = done[di]
		var k: Vector2i = r.k
		if _jobs.has(k):
			WorkerThreadPool.wait_for_task_completion(_jobs[k])
			_jobs.erase(k)
		if r.seed != seed or _ring(k) > radius + 1:
			continue
		var lod := _lod_for(_ring(k))
		if r.lod != lod:
			if _want(k, lod) and not _queue.has(k):
				_queue.push_front(k)
			continue
		if _want(k, lod):
			_apply(r)
	# yenileri arka plana
	while _jobs.size() < MAX_JOBS and not _queue.is_empty():
		var k: Vector2i = _queue.pop_front()
		if _jobs.has(k):
			continue
		var lod := _lod_for(_ring(k))
		if not _want(k, lod):
			continue
		_jobs[k] = WorkerThreadPool.add_task(_run.bind(k, lod, seed, _n), false, "karo")

static func _run(k: Vector2i, lod: int, sd: int, nz: Dictionary) -> void:
	var r := _job(k, lod, sd, nz)
	_mutex.lock()
	_done.append(r)
	_mutex.unlock()

## Bekleyen iş (sınama ve ekran görüntüsü için).
static func pending() -> int:
	return _queue.size() + _jobs.size()

static func _drop(k: Vector2i) -> void:
	var t = tiles.get(k)
	if t != null and is_instance_valid(t.node):
		t.node.queue_free()
	tiles.erase(k)

static func _in_core(x: float, z: float) -> bool:
	return absf(x) < CORE and absf(z) < CORE

## Karonun bütün verisi; sahneye dokunmaz, iş parçacığında çalışabilir.
static func _job(k: Vector2i, lod: int, sd: int, nz: Dictionary) -> Dictionary:
	var x0 := k.x * TILE
	var z0 := k.y * TILE
	var lat := _lattice(x0, z0, nz)
	var r := {"k": k, "lod": lod, "seed": sd, "low": 999.0}
	var inside := x0 >= -CORE and x0 + TILE <= CORE and z0 >= -CORE and z0 + TILE <= CORE
	if not inside:
		_job_ground(r, x0, z0, SEGS[lod], lat, nz)
	_job_scatter(r, k, lod, sd, lat, nz)
	if lod <= 1:
		r.walk = _walk_grid(x0, z0, lat, nz)
	return r

## Zemin: düz gölgeli üçgenler, biyom rengi; kenarda ayrıntı farkını örten etek.
static func _job_ground(r: Dictionary, x0: float, z0: float, seg: int, lat: Array, nz: Dictionary) -> void:
	var n := seg + 1
	var step := TILE / seg
	var hs := PackedFloat32Array()
	hs.resize(n * n)
	var ws := []
	ws.resize(n * n)
	var low := 999.0
	for j in n:
		for i in n:
			var x := x0 + i * step
			var z := z0 + j * step
			var w := _wlat(lat, x0, z0, x, z)
			var y := h_w(x, z, w, nz)
			hs[j * n + i] = y
			ws[j * n + i] = w
			low = minf(low, y)
	var vs := PackedVector3Array()
	var ns := PackedVector3Array()
	var cs := PackedColorArray()
	var cnt := seg * seg * 6 + 4 * seg * 6
	vs.resize(cnt)
	ns.resize(cnt)
	cs.resize(cnt)
	var o := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(int(x0), int(z0), 5))
	for j in seg:
		for i in seg:
			var ia := j * n + i
			var a := Vector3(x0 + i * step, hs[ia], z0 + j * step)
			var b := Vector3(a.x + step, hs[ia + 1], a.z)
			var c := Vector3(a.x, hs[ia + n], a.z + step)
			var d := Vector3(a.x + step, hs[ia + n + 1], a.z + step)
			for tri in 2:
				var p0 := a if tri == 0 else b
				var p1 := b if tri == 0 else d
				var nrm := (p1 - p0).cross(c - p0).normalized()
				if nrm.y < 0.0:
					nrm = -nrm
				var col := _color(ws[ia if tri == 0 else ia + n + 1], (p0.y + p1.y + c.y) / 3.0, 1.0 - nrm.y)
				var v := rng.randf() * 0.06 - 0.03
				col = col.lightened(v) if v > 0.0 else col.darkened(-v)
				vs[o] = p0
				vs[o + 1] = p1
				vs[o + 2] = c
				for q in 3:
					ns[o + q] = nrm
					cs[o + q] = col
				o += 3
	# etek: dört kenar boyunca 2 m aşağı sarkan şerit
	var down := Vector3(0, 2.0, 0)
	for e in [[0, 1], [n * (n - 1), 1], [0, n], [n - 1, n]]:
		for s in seg:
			var i0: int = e[0] + s * e[1]
			var i1: int = i0 + e[1]
			var pa := Vector3(x0 + (i0 % n) * step, hs[i0], z0 + (i0 / n) * step)
			var pb := Vector3(x0 + (i1 % n) * step, hs[i1], z0 + (i1 / n) * step)
			var col := _color(ws[i0], pa.y, 0.0)
			var quad := [pa, pb, pa - down, pb, pb - down, pa - down]
			for q in 6:
				vs[o] = quad[q]
				ns[o] = Vector3.UP
				cs[o] = col
				o += 1
	r.vs = vs
	r.ns = ns
	r.cs = cs
	r.low = low

## Doğa: aynı tohumdan her ayrıntı düzeyinde aynı noktalar. Yakında gerçek modeller,
## uzakta ağaçlar ucuz biçimlerle; engeller her düzeyde kaydedilir.
static func _job_scatter(r: Dictionary, k: Vector2i, lod: int, sd: int, lat: Array, nz: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(k.x, k.y, sd * 7 + 3))
	var x0 := k.x * TILE
	var z0 := k.y * TILE
	var near := {}     # dosya → [[Basis, Vector3, tür, hücre]]
	var far := [[], [], []]   # [Transform3D, hücre]
	var block := {}
	for i in CAND:
		var x := x0 + rng.randf() * TILE
		var z := z0 + rng.randf() * TILE
		var u1 := rng.randf()
		var u2 := rng.randf()
		var u3 := rng.randf()
		var u4 := rng.randf()
		var yaw := rng.randf() * TAU
		if _in_core(x, z):
			continue
		var w := _wlat(lat, x0, z0, x, z)
		var b := 5
		var acc := 0.0
		for q in 6:
			acc += float(w[q])
			if u1 <= acc:
				b = q
				break
		if u2 > float(FLORA_N[b]) / CAND:
			continue
		var cum: Array = _cum[b]
		var pick := u3 * float(cum[cum.size() - 1])
		var ei := 0
		while ei < cum.size() - 1 and pick > float(cum[ei]):
			ei += 1
		var e: Array = FLORA[b][ei]
		var kind: int = e[4]
		var cell := Vector2i(floori(x), floori(z))
		if lod > 0 and kind == 0:
			continue
		var y := h_w(x, z, w, nz)
		if y < WATER_Y + 0.15:
			continue
		if kind > 0:
			if block.has(cell):
				continue
			block[cell] = true
		if lod > 0 and kind == 3:
			continue
		var tall := lerpf(float(e[2]), float(e[3]), u4)
		if lod > 0:
			if lod == 2 and u4 > 0.4:   # en uzakta seyrek ama iri
				continue
			var sc := tall / 2.3 * (1.25 if lod == 2 else 1.0)
			far[0 if kind == 1 else 2 if kind == 4 else 1].append([Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * sc), Vector3(x, y - 0.3, z)), cell])
			continue
		if kind != 3:   # yakın karoda da uzak biçimi: kameradan 75 m ötede gerçek modelin yerine
			far[0 if kind == 1 else 2 if kind == 4 else 1].append([Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * tall / 2.3), Vector3(x, y - 0.3, z)), cell])
		var nk: String = e[0] + "|" + str(int((x - x0) / 25.0) + 2 * int((z - z0) / 25.0))   # çeyrek karo: ince görünürlük
		if not near.has(nk):
			near[nk] = []
		near[nk].append([Basis(Vector3.UP, yaw).scaled(Vector3.ONE * tall), Vector3(x, y - 0.05, z), kind, cell])
	r.near = near
	r.far = far
	r.block = block

## Hazır veriyi sahneye koyar (ana iş parçacığı). Oyuncunun hücrelerine doğa konmaz.
static func _apply(r: Dictionary) -> void:
	var k: Vector2i = r.k
	var x0 := k.x * TILE
	var z0 := k.y * TILE
	var old = tiles.get(k)
	var node := Node3D.new()
	node.name = "T%d_%d" % [k.x, k.y]
	if r.has("vs"):
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = r.vs
		arr[Mesh.ARRAY_NORMAL] = r.ns
		arr[Mesh.ARRAY_COLOR] = r.cs
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.material_override = ground_mat
		if r.lod > 0:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mi)
		if float(r.low) < WATER_Y:
			var wm := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = Vector2(TILE, TILE)
			wm.mesh = pm
			wm.material_override = water_mat
			wm.position = Vector3(x0 + TILE / 2.0, WATER_Y, z0 + TILE / 2.0)
			wm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.add_child(wm)
	var ex := exclude.is_valid()
	var block: Dictionary = r.block
	if ex:
		for cell in block.keys():
			if exclude.call(cell.x, cell.y):
				block.erase(cell)
	for f in r.near:
		var parts := _model(f.get_slice("|", 0))
		var list: Array = r.near[f]
		if ex:
			list = list.filter(func(it: Array) -> bool: return not exclude.call(it[3].x, it[3].y))
		if parts.is_empty() or list.is_empty():
			continue
		var kind: int = list[0][2]
		for part in parts:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = part[0]
			mm.instance_count = list.size()
			var pxf: Transform3D = part[1]
			for i in list.size():
				mm.set_instance_transform(i, Transform3D(list[i][0], list[i][1]) * pxf)
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			if kind == 0:
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mmi.visibility_range_end = 80.0
			elif kind != 3:
				mmi.visibility_range_end = NEAR_TREES
				mmi.visibility_range_end_margin = 8.0
				mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			node.add_child(mmi)
	for si in 3:
		var list: Array = r.far[si]
		if ex:
			list = list.filter(func(it: Array) -> bool: return not exclude.call(it[1].x, it[1].y))
		if list.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _far[si]
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i][0])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = ground_mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if r.lod == 0:
			mmi.visibility_range_begin = NEAR_TREES
			mmi.visibility_range_begin_margin = 8.0
		node.add_child(mmi)
	root.add_child(node)
	if old != null and is_instance_valid(old.node):
		old.node.queue_free()
	var walk: PackedByteArray = r.get("walk", PackedByteArray())
	if walk.is_empty() and old != null and old.seed == r.seed:
		walk = old.walk
	tiles[k] = {"lod": r.lod, "seed": r.seed, "node": node, "block": block, "walk": walk}

## Modelin örgüleri, malzemeleri gömülü ve 1 m boya göre ölçekli (taban y=0).
static func _model(path: String) -> Array:
	if _models.has(path):
		return _models[path]
	var parts := []
	var n: Node3D = Assets.inst(path) if Assets.exists(path) else null
	if n != null:
		var box := AABB()
		var first := true
		var found := []
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var m: MeshInstance3D = mi
			if m.mesh == null:
				continue
			var xf := Transform3D()
			var p: Node = m
			while p != null and p != n:
				xf = (p as Node3D).transform * xf
				p = p.get_parent()
			var mesh: Mesh = m.mesh.duplicate()
			if mesh is ArrayMesh:
				for s in mesh.get_surface_count():
					var mat := m.get_surface_override_material(s)
					if mat == null:
						mat = m.mesh.surface_get_material(s)
					(mesh as ArrayMesh).surface_set_material(s, mat)
			var bb := xf * m.get_aabb()
			box = bb if first else box.merge(bb)
			first = false
			found.append([mesh, xf])
		var s := 1.0 / maxf(box.size.y, 0.01)
		var base := Transform3D(Basis.from_scale(Vector3.ONE * s), Vector3(-(box.position.x + box.size.x / 2.0) * s, -box.position.y * s, -(box.position.z + box.size.z / 2.0) * s))
		for f in found:
			parts.append([f[0], base * f[1]])
		n.free()
	_models[path] = parts
	return parts

## Uzak ağaç: birkaç üçgenlik, köşe renkli (zemin malzemesiyle çizilir), boyu ~2.3.
static func _far_tree(pine: bool, col: Color) -> ArrayMesh:
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
	var add := func(a: Vector3, b: Vector3, c: Vector3, cl: Color) -> void:
		var nrm := (b - a).cross(c - a).normalized()
		if nrm.y < 0.0:
			nrm = -nrm
		for p in [a, b, c]:
			st.set_color(cl)
			st.set_normal(nrm)
			st.add_vertex(p)
	var tb: Array = ring.call(0.12, 0.0)
	var tt: Array = ring.call(0.1, 0.6)
	for i in n:
		var j := (i + 1) % n
		add.call(tb[i], tt[i], tb[j], trunk)
		add.call(tb[j], tt[i], tt[j], trunk)
	if pine:
		for lay in [[0.75, 0.5, 1.6, col], [0.55, 1.3, 2.3, col.lightened(0.1)]]:
			var base: Array = ring.call(lay[0], lay[1])
			var tip := Vector3(0, lay[2], 0)
			for i in n:
				var j := (i + 1) % n
				add.call(base[i], tip, base[j], lay[3])
				add.call(base[j], Vector3(0, lay[1], 0), base[i], (lay[3] as Color).darkened(0.2))
	else:
		var mid: Array = ring.call(0.8, 1.25)
		var top := Vector3(0, 2.0, 0)
		var bot := Vector3(0, 0.55, 0)
		for i in n:
			var j := (i + 1) % n
			add.call(mid[i], top, mid[j], col)
			add.call(mid[j], bot, mid[i], col.darkened(0.25))
	return st.commit()

static func set_radius(r: int) -> void:
	if r != radius:
		radius = r
		_center = Vector2i(99999, 99999)
