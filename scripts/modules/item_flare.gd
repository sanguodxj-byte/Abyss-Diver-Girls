extends RefCounted
## 撤离引导金属信号弹罐 (Extraction Smoke Flare Canister)
## 清单编号：P0-SKL-10 | 优先级：P0 | 目标路径：scripts/modules/item_flare.gd
## 替换原仓未更新旧模：scripts/modules/item_flare.gd (L28-32 原完全无 3D 落地实体)
## 标准占地：Vector3(0.34, 0.56, 0.34) | 全曲面已通过 docs/low_poly_model_audit.md 红线校验
## 补全原仓缺失的 3D 落地信号弹罐体：36 段车削钢罐与 8 道纵向防滑加强筋 + 底部加重防倾法兰 + 8 螺栓顶盖与 6 孔排气歧管 + 折弯金属击发保险匙（K.plate）+ 黄铜引信转轴 + 28 段拉环保险销 + 灼热发烟喉口。
## 保留原仓撤离加速与烟雾逻辑，补全高细分落地金属信号弹罐实体（含滚花加强肋、击发匙、拉环与 6 排气孔盖）。

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")
const FX = preload("res://scripts/modules/weapon_fx.gd")

const SMOKE := Color(1.0, 0.62, 0.24)

static func build_canister() -> Node3D:
	var root := Node3D.new()
	root.name = "ExtractionFlareCanister"
	var M_BODY := K.armor(Color("#4d5246"), 0.58)
	var M_BODYSUB := K.armor_sub(Color("#3b4038"), 0.54)
	var M_DARK := K.dark()
	var M_GUNMETAL := K.gunmetal()
	var M_BRASS := K.brass()
	var M_CHROME := A.chrome()
	var M_HAZARD := A.hazard()
	var M_BORE := K.bore_mat()
	var M_ORANGEBAND := A.paint(Color("#b85a22"), 0.16, 0.48, {"wear": 0.52, "panel_scale": 0.0})
	var M_EMBER := A.emit(Color("#ff8a2b"), 2.6)
	var n_1 := K.node(root, Vector3.ZERO, Vector3.ZERO, "WeightedBaseFlange")
	K.cy(n_1, 0.145, 0.045, M_DARK, Vector3(0.0, 0.022, 0.0), Vector3.ZERO, 0.16, 32)
	A.add(n_1, A.torus(0.12, 0.15, 28), M_GUNMETAL, Vector3(0.0, 0.05, 0.0), Vector3.ZERO)
	var n_2 := K.node(n_1, Vector3(0.0, 0.052, 0.0), Vector3.ZERO, "BaseFlangeBolts")
	A.add(n_2, A.cyl(0.008, 0.012, 0.009, 6), M_CHROME, Vector3(0.135, 0.0, 0.0), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_2, A.cyl(0.008, 0.012, 0.009, 6), M_CHROME, Vector3(0.0955, 0.0, 0.0955), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_2, A.cyl(0.008, 0.012, 0.009, 6), M_CHROME, Vector3(0.0, 0.0, 0.135), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_2, A.cyl(0.008, 0.012, 0.009, 6), M_CHROME, Vector3(-0.0955, 0.0, 0.0955), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_2, A.cyl(0.008, 0.012, 0.009, 6), M_CHROME, Vector3(-0.135, 0.0, 0.0), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_2, A.cyl(0.008, 0.012, 0.009, 6), M_CHROME, Vector3(-0.0955, 0.0, -0.0955), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_2, A.cyl(0.008, 0.012, 0.009, 6), M_CHROME, Vector3(0.0, 0.0, -0.135), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_2, A.cyl(0.008, 0.012, 0.009, 6), M_CHROME, Vector3(0.0955, 0.0, -0.0955), Vector3.ZERO, Vector3.ONE, false)
	var n_3 := K.node(root, Vector3.ZERO, Vector3.ZERO, "CanisterBody")
	K.cy(n_3, 0.118, 0.34, M_BODY, Vector3(0.0, 0.22, 0.0), Vector3.ZERO, 0.118, 36)
	K.cy(n_3, 0.121, 0.085, M_ORANGEBAND, Vector3(0.0, 0.3, 0.0), Vector3.ZERO, 0.121, 36)
	K.cy(n_3, 0.122, 0.042, M_HAZARD, Vector3(0.0, 0.11, 0.0), Vector3.ZERO, 0.122, 36)
	A.add(n_3, A.torus(0.114, 0.132, 32), M_DARK, Vector3(0.0, 0.385, 0.0), Vector3.ZERO)
	A.stencil(n_3, "EX-FLARE", Vector3(0.0, 0.21, -0.123), Vector3(0.0, 180.0, 0.0), 0.0032, Color("#dbd6c6"))
	K.bb(n_3, Vector3(0.018, 0.22, 0.016), M_BODYSUB, Vector3(0.118, 0.22, 0.0), Vector3(0.0, 90.0, 0.0), 0.003)
	K.bb(n_3, Vector3(0.018, 0.22, 0.016), M_BODYSUB, Vector3(0.0834, 0.22, 0.0834), Vector3(0.0, 45.0, 0.0), 0.003)
	K.bb(n_3, Vector3(0.018, 0.22, 0.016), M_BODYSUB, Vector3(0.0, 0.22, 0.118), Vector3.ZERO, 0.003)
	K.bb(n_3, Vector3(0.018, 0.22, 0.016), M_BODYSUB, Vector3(-0.0834, 0.22, 0.0834), Vector3(0.0, -45.0, 0.0), 0.003)
	K.bb(n_3, Vector3(0.018, 0.22, 0.016), M_BODYSUB, Vector3(-0.118, 0.22, 0.0), Vector3(0.0, -90.0, 0.0), 0.003)
	K.bb(n_3, Vector3(0.018, 0.22, 0.016), M_BODYSUB, Vector3(-0.0834, 0.22, -0.0834), Vector3(0.0, -135.0, 0.0), 0.003)
	K.bb(n_3, Vector3(0.018, 0.22, 0.016), M_BODYSUB, Vector3(0.0, 0.22, -0.118), Vector3(0.0, -180.0, 0.0), 0.003)
	K.bb(n_3, Vector3(0.018, 0.22, 0.016), M_BODYSUB, Vector3(0.0834, 0.22, -0.0834), Vector3(0.0, -225.0, 0.0), 0.003)
	var n_4 := K.node(root, Vector3.ZERO, Vector3.ZERO, "IgniterCapAndPorts")
	K.cy(n_4, 0.112, 0.052, M_DARK, Vector3(0.0, 0.415, 0.0), Vector3.ZERO, 0.124, 32)
	K.cy(n_4, 0.036, 0.06, M_BRASS, Vector3(0.0, 0.45, 0.0), Vector3.ZERO, 0.036, 24)
	A.add(n_4, A.cyl(0.025, 0.02, 0.025, 20), M_EMBER, Vector3(0.0, 0.482, 0.0), Vector3.ZERO, Vector3.ONE, false)
	K.cy(n_4, 0.024, 0.04, M_GUNMETAL, Vector3(0.0624, 0.425, 0.036), Vector3.ZERO, 0.024, 16)
	A.add(n_4, A.cyl(0.017, 0.044, 0.017, 16), M_BORE, Vector3(0.0624, 0.428, 0.036), Vector3.ZERO, Vector3.ONE, false)
	K.cy(n_4, 0.024, 0.04, M_GUNMETAL, Vector3(0.0, 0.425, 0.072), Vector3.ZERO, 0.024, 16)
	A.add(n_4, A.cyl(0.017, 0.044, 0.017, 16), M_BORE, Vector3(0.0, 0.428, 0.072), Vector3.ZERO, Vector3.ONE, false)
	K.cy(n_4, 0.024, 0.04, M_GUNMETAL, Vector3(-0.0624, 0.425, 0.036), Vector3.ZERO, 0.024, 16)
	A.add(n_4, A.cyl(0.017, 0.044, 0.017, 16), M_BORE, Vector3(-0.0624, 0.428, 0.036), Vector3.ZERO, Vector3.ONE, false)
	K.cy(n_4, 0.024, 0.04, M_GUNMETAL, Vector3(-0.0624, 0.425, -0.036), Vector3.ZERO, 0.024, 16)
	A.add(n_4, A.cyl(0.017, 0.044, 0.017, 16), M_BORE, Vector3(-0.0624, 0.428, -0.036), Vector3.ZERO, Vector3.ONE, false)
	K.cy(n_4, 0.024, 0.04, M_GUNMETAL, Vector3(0.0, 0.425, -0.072), Vector3.ZERO, 0.024, 16)
	A.add(n_4, A.cyl(0.017, 0.044, 0.017, 16), M_BORE, Vector3(0.0, 0.428, -0.072), Vector3.ZERO, Vector3.ONE, false)
	K.cy(n_4, 0.024, 0.04, M_GUNMETAL, Vector3(0.0624, 0.425, -0.036), Vector3.ZERO, 0.024, 16)
	A.add(n_4, A.cyl(0.017, 0.044, 0.017, 16), M_BORE, Vector3(0.0624, 0.428, -0.036), Vector3.ZERO, Vector3.ONE, false)
	var n_5 := K.node(n_4, Vector3(0.0, 0.442, 0.0), Vector3.ZERO, "CapBolts")
	A.add(n_5, A.cyl(0.007, 0.012, 0.0078, 6), M_CHROME, Vector3(0.102, 0.0, 0.0), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_5, A.cyl(0.007, 0.012, 0.0078, 6), M_CHROME, Vector3(0.0721, 0.0, 0.0721), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_5, A.cyl(0.007, 0.012, 0.0078, 6), M_CHROME, Vector3(0.0, 0.0, 0.102), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_5, A.cyl(0.007, 0.012, 0.0078, 6), M_CHROME, Vector3(-0.0721, 0.0, 0.0721), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_5, A.cyl(0.007, 0.012, 0.0078, 6), M_CHROME, Vector3(-0.102, 0.0, 0.0), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_5, A.cyl(0.007, 0.012, 0.0078, 6), M_CHROME, Vector3(-0.0721, 0.0, -0.0721), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_5, A.cyl(0.007, 0.012, 0.0078, 6), M_CHROME, Vector3(0.0, 0.0, -0.102), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_5, A.cyl(0.007, 0.012, 0.0078, 6), M_CHROME, Vector3(0.0721, 0.0, -0.0721), Vector3.ZERO, Vector3.ONE, false)
	var n_6 := K.node(root, Vector3.ZERO, Vector3.ZERO, "SafetySpoonAndPin")
	K.bb(n_6, Vector3(0.058, 0.068, 0.048), M_BRASS, Vector3(0.06, 0.46, 0.0), Vector3.ZERO, 0.004)
	A.add(n_6, A.cyl(0.012, 0.072, 0.012, 16), M_CHROME, Vector3(0.06, 0.47, 0.0), Vector3(90.0, 0.0, 0.0), Vector3.ONE, false)
	K.plate(n_6, [Vector2(-0.04, 0.02), Vector2(0.055, 0.02), Vector2(0.085, -0.02), Vector2(0.095, -0.24), Vector2(0.072, -0.25), Vector2(0.064, -0.04), Vector2(0.042, -0.008), Vector2(-0.04, -0.008)], 0.036, M_GUNMETAL, Vector3(0.055, 0.47, 0.0), Vector3.ZERO, 0.004)
	A.add(n_6, A.torus(0.032, 0.044, 28), M_CHROME, Vector3(0.06, 0.48, -0.068), Vector3(90.0, 0.0, 22.0), Vector3.ONE, false)
	return root

static func use(mech, _id) -> bool:
	var raid = mech.raid
	if raid == null or not is_instance_valid(raid):
		return false
	var zone = raid.extract_target
	if zone == null or not is_instance_valid(zone):
		mech.message.emit(Loc.t("不在撤离区内", "Not inside extraction zone"))
		Audio.play_sfx("use_denied")
		return false
	if zone.has_meta("flare_used"):
		mech.message.emit(Loc.t("这个撤离点已经引导过了", "This extraction zone is already flared"))
		Audio.play_sfx("use_denied")
		return false
	zone.set_meta("flare_used", true)
	var before := float(zone.need)
	zone.need = maxf(1.5, before * 0.55)
	var canister := build_canister()
	canister.position = Vector3(0.35, 0.0, 0.22)
	zone.add_child(canister)
	var tree: SceneTree = raid.get_tree()
	var e = A.emitter(zone, Vector3(0.35, 0.48, 0.22), {"amount": 42, "life": 2.6, "size": 2.4, "tex": A.smoke_tex(), "additive": false, "dir": Vector3.UP, "spread": 22.0,
		"vmin": 2.2, "vmax": 4.5, "gravity": Vector3(0, 0.6, 0), "box": Vector3(0.45, 0.1, 0.45),
		"c0": Color(SMOKE.r, SMOKE.g, SMOKE.b, 0.75), "c1": Color(0.8, 0.45, 0.2, 0.0), "grow0": 0.4, "grow1": 2.4})
	FX.light(raid, zone.global_position + Vector3(0.35, 1.2, 0.22), SMOKE, 3.5, 9.0, 0.6)
	FX.ring(raid, zone.global_position, SMOKE, zone.radius, 0.6)
	var eid: int = e.get_instance_id()
	var cid: int = canister.get_instance_id()
	tree.create_timer(7.0).timeout.connect(func():
		var o = instance_from_id(eid)
		if o != null:
			o.emitting = false
		tree.create_timer(2.8).timeout.connect(func():
			var o2 = instance_from_id(eid)
			if o2 != null:
				o2.queue_free()
			var c2 = instance_from_id(cid)
			if c2 != null:
				c2.queue_free()))
	mech.message.emit(Loc.t("%s：撤离读条 %.1f 到 %.1f 秒" % [zone.title, before, zone.need], "%s: extraction timer %.1f -> %.1fs" % [zone.title, before, zone.need]))
	Audio.play_sfx("flare_ignite", zone.global_position)
	return true
