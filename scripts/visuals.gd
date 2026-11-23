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
	"cow": ["Cow.fbx", 0.1, "Armature|Idle", "Armature|WalkSlow"],
	"pig": ["Pig.fbx", 0.085, "Armature|Idle", ""],
	"sheep": ["Sheep.fbx", 0.13, "Armature|Idle", ""],
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
			return n
	return Models.animal(type)

static func decor(type: String, conn: Dictionary) -> Node3D:
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
