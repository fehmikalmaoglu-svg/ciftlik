class_name Visuals
extends RefCounted
## Oyun nesnelerinin görselleri: önce CC0 model (Assets), yoksa prosedürel model (Models).

const C := "res://assets/crops/"
const N := "res://assets/nature/"
const A := "res://assets/animals/"

# ekin: [dosya öneki, ölçek, kare başına bitki sayısı]
const CROP_ASSET := {
	"wheat": ["Wheat", 0.85, 9], "carrot": ["Carrot", 0.6, 4], "tomato": ["Tomato", 0.62, 2],
	"corn": ["Corn", 0.62, 2], "pumpkin": ["Pumpkin", 0.75, 1],
}
const SPOTS := {
	1: [[0.0, 0.0]],
	2: [[-0.2, -0.18], [0.2, 0.18]],
	4: [[-0.22, -0.22], [0.22, -0.22], [-0.22, 0.22], [0.22, 0.22]],
	9: [[-0.28, -0.28], [-0.28, 0.0], [-0.28, 0.28], [0.0, -0.28], [0.0, 0.0], [0.0, 0.28], [0.28, -0.28], [0.28, 0.0], [0.28, 0.28]],
}
const TREE_ASSET := {"apple": "Apple", "orange": "Orange"}
# hayvan: [dosya, ölçek, bekleme animasyonu, yürüme animasyonu]
const ANIMAL_ASSET := {
	"cow": ["Cow.fbx", 0.165, "Armature|Idle", "Armature|WalkSlow"],
	"pig": ["Pig.fbx", 0.115, "Armature|Idle", ""],
	"sheep": ["Sheep.fbx", 0.17, "Armature|Idle", ""],
}

static func crop(type: String, stage: int) -> Node3D:
	if CROP_ASSET.has(type):
		var cfg: Array = CROP_ASSET[type]
		var path := "%s%s_%d.fbx" % [C, cfg[0], stage + 1]
		if Assets.exists(path):
			var g := Node3D.new()
			g.position.y = 0.1
			var spots: Array = SPOTS[cfg[2]]
			for i in spots.size():
				var p = spots[i]
				g.add_child(Assets.inst(path, cfg[1], i * 1.7, Vector3(p[0], 0, p[1])))
			return g
	return Models.crop(type, stage)

static func tree(type: String, grown: bool, fruit: bool) -> Node3D:
	if TREE_ASSET.has(type):
		var pre: String = C + TREE_ASSET[type]
		var path: String = pre + ("_4.fbx" if fruit else "_Harvested.fbx") if grown else pre + "_3.fbx"
		var n := Assets.inst(path, 0.6 if grown else 0.45)
		if n != null:
			return n
	return Models.tree(type, grown, fruit)

## Hayvan modeli; animasyonlu ise "anim" meta'sında AnimationPlayer, "walk"/"idle" adlarıyla.
static func animal(type: String) -> Node3D:
	if ANIMAL_ASSET.has(type):
		var cfg: Array = ANIMAL_ASSET[type]
		var n := Assets.inst(A + cfg[0], cfg[1])
		if n != null:
			var ap := Assets.anim_player(n)
			if ap != null:
				for an in [cfg[2], cfg[3]]:
					if an != "" and ap.has_animation(an):
						ap.get_animation(an).loop_mode = Animation.LOOP_LINEAR
				if ap.has_animation(cfg[2]):
					ap.play(cfg[2])
					ap.seek(randf() * 2.0)
				n.set_meta("anim", ap)
				n.set_meta("idle", cfg[2])
				n.set_meta("walk", cfg[3] if cfg[3] != "" and ap.has_animation(cfg[3]) else "")
				if str(n.get_meta("walk")) == "":
					# kendi yürüyüşü yok: ineğin yürüyüşünü bu iskelete uyarla (aynı kemik adları)
					var sks := n.find_children("*", "Skeleton3D", true, false)
					var lib := _walk_lib(type, sks[0]) if sks.size() > 0 else null
					if lib != null:
						if not ap.has_animation_library("ret"):
							ap.add_animation_library("ret", lib)
						n.set_meta("walk", "ret/Walk")
			return n
	var m := Models.animal(type)
	m.scale *= 1.25
	return m

## İnek yürüyüşünü başka bir dörtayaklı iskelete aktarır. Her kemik için dinlenme pozuna göre fark alınır:
## dönüş = hedef_dinlenme × (inek_dinlenme⁻¹ × inek_poz); konum farkı gövde yüksekliği oranıyla ölçeklenir.
static var _retarget := {}
const STRIDE := 0.8
static func _walk_lib(type: String, sk: Skeleton3D) -> AnimationLibrary:
	if _retarget.has(type):
		return _retarget[type]
	var lib: AnimationLibrary = null
	var cow := Assets.inst(A + "Cow.fbx", 1.0)
	if cow != null:
		var cap := Assets.anim_player(cow)
		var cs := cow.find_children("*", "Skeleton3D", true, false)
		if cap != null and cs.size() > 0 and cap.has_animation("Armature|WalkSlow"):
			var csk: Skeleton3D = cs[0]
			var src := cap.get_animation("Armature|WalkSlow")
			var ratio := _body_h(sk) / maxf(_body_h(csk), 0.001)
			var a := Animation.new()
			a.length = src.length
			a.loop_mode = Animation.LOOP_LINEAR
			for t in src.get_track_count():
				var path := src.track_get_path(t)
				var bone := path.get_concatenated_subnames()
				var ci := csk.find_bone(bone)
				var ti := sk.find_bone(bone)
				var typ := src.track_get_type(t)
				if ci < 0 or ti < 0 or not typ in [Animation.TYPE_ROTATION_3D, Animation.TYPE_POSITION_3D]:
					continue
				var nt := a.add_track(typ)
				a.track_set_path(nt, path)
				a.track_set_interpolation_type(nt, src.track_get_interpolation_type(t))
				var cr := csk.get_bone_rest(ci)
				var tr := sk.get_bone_rest(ti)
				for k in src.track_get_key_count(t):
					var time := src.track_get_key_time(t, k)
					var v = src.track_get_key_value(t, k)
					if typ == Animation.TYPE_ROTATION_3D:
						var d: Quaternion = cr.basis.get_rotation_quaternion().inverse() * Quaternion(v)
						d = Quaternion.IDENTITY.slerp(d, STRIDE)   # kısa bacakta biraz daha kısa adım
						a.rotation_track_insert_key(nt, time, (tr.basis.get_rotation_quaternion() * d).normalized())
					else:
						a.position_track_insert_key(nt, time, tr.origin + (Vector3(v) - cr.origin) * ratio)
			lib = AnimationLibrary.new()
			lib.add_animation("Walk", a)
		cow.free()
	_retarget[type] = lib
	return lib

## Ön bacak boyu (omuzdan toynağa): adım uzunluğu bununla orantılı olmalı.
static func _body_h(sk: Skeleton3D) -> float:
	var top := sk.find_bone("FrontUpLeg.L")
	var end := sk.find_bone("FrontLowLeg.L_end")
	if top < 0 or end < 0:
		return 1.0
	return sk.get_bone_global_rest(top).origin.distance_to(sk.get_bone_global_rest(end).origin)

## Köy/doğa süsleri: tür → [[dosya, ölçek, x, z, dönüş], ...]. Dosyalar repoda yok (lisans):
## yalnızca yerel derlemede bulunur; eksikse COZY_FALLBACK'teki prosedürel modele düşülür.
const CZ := "res://assets/cozy/"
const COZY := {
	"tallgrass": [["Nat_37_TallGrass.glb", 1.15, 0.0, 0.0, 0.0]],
	"fern": [["Nat_17_FernLarge.glb", 0.62, 0.0, 0.0, 0.0]],
	"wildflowers": [["Nat_31_Tulip.glb", 1.9, -0.22, -0.18, 0.0], ["Nat_30_Daisy.glb", 2.3, 0.2, -0.22, 1.0], ["Nat_32_Lavender.glb", 1.8, -0.15, 0.22, 2.0],
		["Nat_31_Tulip.glb", 1.7, 0.24, 0.16, 3.0], ["Nat_30_Daisy.glb", 2.1, 0.0, 0.02, 4.0], ["Nat_35_GrassTuftA.glb", 0.9, 0.05, 0.05, 0.5]],
	"mushrooms": [["Nat_42_MushroomGroup.glb", 1.3, -0.08, -0.05, 0.0], ["Nat_40_FlyAgaric.glb", 1.4, 0.24, 0.2, 0.7]],
	"mossrock": [["Nat_28_RockMossy.glb", 0.55, 0.0, 0.0, 0.0]],
	"sunflowers": [["Nat_33_Sunflower.glb", 1.5, -0.2, -0.15, 0.0], ["Nat_33_Sunflower.glb", 1.3, 0.22, -0.1, 0.4], ["Nat_33_Sunflower.glb", 1.6, 0.0, 0.22, -0.3]],
	"berrybush": [["Nat_15_BushBerries.glb", 0.6, 0.0, 0.0, 0.0]],
	"stump": [["Nat_50_StumpRoots.glb", 0.52, 0.0, 0.0, 0.0]],
	"barrels": [["Vil_38_BarrelsA.glb", 0.66, 0.0, 0.0, 0.0]],
	"crates": [["Vil_40_CratesA.glb", 0.68, 0.0, 0.0, 0.0]],
	"bench": [["Vil_20_BenchA.glb", 0.5, 0.0, 0.0, 0.0]],
	"logstack": [["Nat_48_LogStack.glb", 0.6, 0.0, 0.0, 0.0]],
	"lamppost": [["Vil_15_LampPost.glb", 0.55, 0.0, 0.0, 0.0]],
	"cart": [["Vil_36_Cart.glb", 0.29, -0.45, 0.0, 0.0]],
	"birch": [["Nat_03_Birch.glb", 0.3, 0.0, 0.0, 0.0]],
	"xmastree": [["Win_31_TreeSmallA.glb", 0.6, 0.0, 0.0, 0.0]],
	"giftstack": [["Win_38_GiftStack.glb", 0.62, 0.0, 0.0, 0.0]],
	"sled": [["Win_35_Sled.glb", 0.48, -0.2, 0.0, 0.0]],
	"candycane": [["Win_41_CandyCanePost.glb", 0.7, 0.0, 0.0, 0.0]],
	"market": [["Vil_09_MarketStallA.glb", 0.36, 0.0, 0.0, 0.0]],
	"cherry": [["Nat_10_CherryBlossom.glb", 0.3, 0.0, 0.0, 0.0]],
}
const COZY_FALLBACK := {"tallgrass": "bush", "fern": "bush", "wildflowers": "flowers", "mushrooms": "rock", "mossrock": "rock",
	"sunflowers": "flowers", "berrybush": "bush", "stump": "hay", "barrels": "hay", "crates": "hay", "bench": "hay",
	"logstack": "hay", "lamppost": "lantern", "cart": "hay", "birch": "bush", "xmastree": "bush", "giftstack": "hay",
	"sled": "hay", "candycane": "lantern", "market": "hay", "cherry": "bush"}

static func cozy(type: String) -> Node3D:
	var parts: Array = COZY[type]
	var g: Node3D = null
	for p in parts:
		var n := Assets.inst(CZ + p[0], p[1], p[4], Vector3(p[2], 0, p[3]))
		if n == null:
			if g != null:
				g.free()
			return null
		if g == null:
			g = Node3D.new()
		g.add_child(n)
	return g

static func decor(type: String, conn: Dictionary) -> Node3D:
	if COZY.has(type):
		var cz := cozy(type)
		return cz if cz != null else Models.decor(COZY_FALLBACK[type], conn)
	match type:
		"rock":
			var n := Assets.inst(N + "rock_largeA.glb", 0.9)
			if n != null:
				var s := Assets.inst(N + "rock_smallC.glb", 1.0, 0.8, Vector3(0.3, 0, 0.25))
				if s != null:
					n.add_child(s)
				return n
		"bush":
			var n := Assets.inst(N + "plant_bushDetailed.glb", 1.5)
			if n != null:
				return n
	return Models.decor(type, conn)

const MK := "res://assets/megakit/"
const ROUND_TREES := ["CommonTree_1.gltf", "CommonTree_2.gltf", "CommonTree_3.gltf", "CommonTree_4.gltf", "CommonTree_5.gltf"]
const PINES := ["Pine_1.gltf", "Pine_2.gltf", "Pine_3.gltf", "Pine_4.gltf", "Pine_5.gltf"]
const ROCKS := ["Rock_Medium_1.gltf", "Rock_Medium_2.gltf", "Rock_Medium_3.gltf"]

## Çevre süsü: kind 0 = çam, 1 = yuvarlak ağaç, 2 = kaya. r = 0..1 rastgele.
static func scenery(kind: int, s: float, r: float) -> Node3D:
	var list: Array = PINES if kind == 0 else ROUND_TREES if kind == 1 else ROCKS
	var path: String = MK + list[int(r * list.size()) % list.size()]
	var scale := s * (0.4 if kind == 0 else 0.42 if kind == 1 else 0.3)
	var n := Assets.inst(path, scale)
	if n != null:
		return n
	if kind == 0:
		return Models.pine(s)
	if kind == 1:
		return Models.round_tree(s)
	return Models.decor("rock")
