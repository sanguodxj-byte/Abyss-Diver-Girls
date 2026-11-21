extends Node3D
## 四足跃迁战术阻拦网 (Tactical Anchor Snare Web)
## 清单编号：P0-SKL-03 | 优先级：P0 | 目标路径：scripts/modules/slow_web.gd
## 替换原仓未更新旧模：scripts/modules/slow_web.gd (L34-39 原 4/5 边硬棒网丝)
## 标准占地：Vector3(5.2, 0.62, 5.2) | 全曲面已通过 docs/low_poly_model_audit.md 红线校验
## 彻底淘汰原 4/5 边折线硬棒：中心 36 段装甲网囊抛射母罐（6 片弹开瓣盖 + 12 螺栓法兰环 + 6 具气动抛射口 + 警示箍）+ 周边 8 根带倒钩与拉环的爆破地桩 + 24 条 seg=14/sub=10 平滑悬链线高粘纤维钢缆与树脂张紧节点。
## 保留原仓范围减速逻辑，将 4/5 边硬棒网丝升级为抛射母罐 + 8 锚钉地桩 + seg=14 悬链线阻滞网。

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")
const FX = preload("res://scripts/modules/weapon_fx.gd")
const Status = preload("res://scripts/modules/status.gd")

var raid
var radius := 4.2
var life := 4.5
var factor := 0.35
var _tick := 0.0

func setup(r, rad: float, dur: float) -> void:
	raid = r
	add_to_group("coop_devices")
	set_meta("coop_device", "web")
	radius = rad
	life = dur

static func build_model() -> Node3D:
	var root := Node3D.new()
	root.name = "TacticalSlowWeb"
	var M_BODY := K.armor(Color("#42494a"), 0.54)
	var M_BODYSUB := K.armor_sub(Color("#33383a"), 0.56)
	var M_DARK := K.dark()
	var M_GUNMETAL := K.gunmetal()
	var M_BRASS := K.brass()
	var M_CHROME := A.chrome()
	var M_HAZARD := A.hazard()
	var M_WEBGLOW := A.emit(Color("#64e8dc"), 1.7)
	var M_WEBRESIN := A.paint(Color("#3a7a74"), 0.14, 0.26, {"wear": 0.2, "panel_scale": 0.0})
	var n_1 := K.node(root, Vector3.ZERO, Vector3.ZERO, "CentralWebMortar")
	K.cy(n_1, 0.44, 0.08, M_DARK, Vector3(0.0, 0.04, 0.0), Vector3.ZERO, 0.48, 36)
	K.cy(n_1, 0.36, 0.26, M_BODY, Vector3(0.0, 0.19, 0.0), Vector3.ZERO, 0.39, 36)
	K.cy(n_1, 0.38, 0.06, M_HAZARD, Vector3(0.0, 0.14, 0.0), Vector3.ZERO, 0.38, 36)
	A.add(n_1, A.torus(0.3, 0.37, 32), M_GUNMETAL, Vector3(0.0, 0.34, 0.0), Vector3.ZERO)
	A.add(n_1, A.cyl(0.22, 0.16, 0.22, 28), M_WEBGLOW, Vector3(0.0, 0.34, 0.0), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_1, A.sphere(0.18, 0.14, 32), M_WEBRESIN, Vector3(0.0, 0.43, 0.0), Vector3.ZERO, Vector3.ONE, false)
	A.stencil(n_1, "WEB-09", Vector3(0.0, 0.24, -0.378), Vector3(0.0, 180.0, 0.0), 0.005, Color("#cbc5b4"))
	K.plate(n_1, [Vector2(-0.08, 0.0), Vector2(0.08, 0.0), Vector2(0.12, 0.24), Vector2(0.0, 0.3), Vector2(-0.12, 0.24)], 0.026, M_BODY, Vector3(0.3, 0.36, 0.0), Vector3(62.0, 90.0, 0.0), 0.005)
	K.cy(n_1, 0.036, 0.16, M_GUNMETAL, Vector3(0.31, 0.24, 0.0), Vector3(74.0, 90.0, 0.0), 0.044, 16)
	K.plate(n_1, [Vector2(-0.08, 0.0), Vector2(0.08, 0.0), Vector2(0.12, 0.24), Vector2(0.0, 0.3), Vector2(-0.12, 0.24)], 0.026, M_BODY, Vector3(0.15, 0.36, 0.2598), Vector3(62.0, 30.0, 0.0), 0.005)
	K.cy(n_1, 0.036, 0.16, M_GUNMETAL, Vector3(0.155, 0.24, 0.2685), Vector3(74.0, 30.0, 0.0), 0.044, 16)
	K.plate(n_1, [Vector2(-0.08, 0.0), Vector2(0.08, 0.0), Vector2(0.12, 0.24), Vector2(0.0, 0.3), Vector2(-0.12, 0.24)], 0.026, M_BODY, Vector3(-0.15, 0.36, 0.2598), Vector3(62.0, -30.0, 0.0), 0.005)
	K.cy(n_1, 0.036, 0.16, M_GUNMETAL, Vector3(-0.155, 0.24, 0.2685), Vector3(74.0, -30.0, 0.0), 0.044, 16)
	K.plate(n_1, [Vector2(-0.08, 0.0), Vector2(0.08, 0.0), Vector2(0.12, 0.24), Vector2(0.0, 0.3), Vector2(-0.12, 0.24)], 0.026, M_BODY, Vector3(-0.3, 0.36, 0.0), Vector3(62.0, -90.0, 0.0), 0.005)
	K.cy(n_1, 0.036, 0.16, M_GUNMETAL, Vector3(-0.31, 0.24, 0.0), Vector3(74.0, -90.0, 0.0), 0.044, 16)
	K.plate(n_1, [Vector2(-0.08, 0.0), Vector2(0.08, 0.0), Vector2(0.12, 0.24), Vector2(0.0, 0.3), Vector2(-0.12, 0.24)], 0.026, M_BODY, Vector3(-0.15, 0.36, -0.2598), Vector3(62.0, -150.0, 0.0), 0.005)
	K.cy(n_1, 0.036, 0.16, M_GUNMETAL, Vector3(-0.155, 0.24, -0.2685), Vector3(74.0, -150.0, 0.0), 0.044, 16)
	K.plate(n_1, [Vector2(-0.08, 0.0), Vector2(0.08, 0.0), Vector2(0.12, 0.24), Vector2(0.0, 0.3), Vector2(-0.12, 0.24)], 0.026, M_BODY, Vector3(0.15, 0.36, -0.2598), Vector3(62.0, -210.0, 0.0), 0.005)
	K.cy(n_1, 0.036, 0.16, M_GUNMETAL, Vector3(0.155, 0.24, -0.2685), Vector3(74.0, -210.0, 0.0), 0.044, 16)
	var n_2 := K.node(n_1, Vector3(0.0, 0.355, 0.0), Vector3.ZERO, "MortarFlangeBolts")
	A.add(n_2, A.cyl(0.014, 0.018, 0.0157, 6), M_CHROME, Vector3(0.335, 0.0, 0.0), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_2, A.cyl(0.014, 0.018, 0.0157, 6), M_CHROME, Vector3(0.2901, 0.0, 0.1675), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_2, A.cyl(0.014, 0.018, 0.0157, 6), M_CHROME, Vector3(0.1675, 0.0, 0.2901), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_2, A.cyl(0.014, 0.018, 0.0157, 6), M_CHROME, Vector3(0.0, 0.0, 0.335), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_2, A.cyl(0.014, 0.018, 0.0157, 6), M_CHROME, Vector3(-0.1675, 0.0, 0.2901), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_2, A.cyl(0.014, 0.018, 0.0157, 6), M_CHROME, Vector3(-0.2901, 0.0, 0.1675), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_2, A.cyl(0.014, 0.018, 0.0157, 6), M_CHROME, Vector3(-0.335, 0.0, 0.0), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_2, A.cyl(0.014, 0.018, 0.0157, 6), M_CHROME, Vector3(-0.2901, 0.0, -0.1675), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_2, A.cyl(0.014, 0.018, 0.0157, 6), M_CHROME, Vector3(-0.1675, 0.0, -0.2901), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_2, A.cyl(0.014, 0.018, 0.0157, 6), M_CHROME, Vector3(0.0, 0.0, -0.335), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_2, A.cyl(0.014, 0.018, 0.0157, 6), M_CHROME, Vector3(0.1675, 0.0, -0.2901), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_2, A.cyl(0.014, 0.018, 0.0157, 6), M_CHROME, Vector3(0.2901, 0.0, -0.1675), Vector3.ZERO, Vector3.ONE, false)
	var n_3 := K.node(root, Vector3.ZERO, Vector3.ZERO, "PerimeterAnchorStakes")
	var n_4 := K.node(n_3, Vector3(2.3301, 0.0, 0.7571), Vector3(0.0, 72.0, 0.0), "AnchorStake_1")
	K.cy(n_4, 0.055, 0.44, M_DARK, Vector3(0.0, 0.16, 0.0), Vector3(16.0, 0.0, 0.0), 0.018, 16)
	K.cy(n_4, 0.092, 0.04, M_BODYSUB, Vector3(0.0, 0.02, 0.0), Vector3.ZERO, 0.105, 24)
	A.add(n_4, A.torus(0.052, 0.082, 24), M_BRASS, Vector3(0.0, 0.3, 0.04), Vector3(16.0, 0.0, 0.0), Vector3.ONE, false)
	A.add(n_4, A.cyl(0.044, 0.05, 0.044, 16), M_WEBGLOW, Vector3(0.0, 0.37, 0.06), Vector3(16.0, 0.0, 0.0), Vector3.ONE, false)
	var n_5 := K.node(n_3, Vector3(1.1123, 0.0, 2.183), Vector3(0.0, 27.0, 0.0), "AnchorStake_2")
	K.cy(n_5, 0.055, 0.44, M_DARK, Vector3(0.0, 0.16, 0.0), Vector3(16.0, 0.0, 0.0), 0.018, 16)
	K.cy(n_5, 0.092, 0.04, M_BODYSUB, Vector3(0.0, 0.02, 0.0), Vector3.ZERO, 0.105, 24)
	A.add(n_5, A.torus(0.052, 0.082, 24), M_BRASS, Vector3(0.0, 0.3, 0.04), Vector3(16.0, 0.0, 0.0), Vector3.ONE, false)
	A.add(n_5, A.cyl(0.044, 0.05, 0.044, 16), M_WEBGLOW, Vector3(0.0, 0.37, 0.06), Vector3(16.0, 0.0, 0.0), Vector3.ONE, false)
	var n_6 := K.node(n_3, Vector3(-0.7571, 0.0, 2.3301), Vector3(0.0, -18.0, 0.0), "AnchorStake_3")
	K.cy(n_6, 0.055, 0.44, M_DARK, Vector3(0.0, 0.16, 0.0), Vector3(16.0, 0.0, 0.0), 0.018, 16)
	K.cy(n_6, 0.092, 0.04, M_BODYSUB, Vector3(0.0, 0.02, 0.0), Vector3.ZERO, 0.105, 24)
	A.add(n_6, A.torus(0.052, 0.082, 24), M_BRASS, Vector3(0.0, 0.3, 0.04), Vector3(16.0, 0.0, 0.0), Vector3.ONE, false)
	A.add(n_6, A.cyl(0.044, 0.05, 0.044, 16), M_WEBGLOW, Vector3(0.0, 0.37, 0.06), Vector3(16.0, 0.0, 0.0), Vector3.ONE, false)
	var n_7 := K.node(n_3, Vector3(-2.183, 0.0, 1.1123), Vector3(0.0, -63.0, 0.0), "AnchorStake_4")
	K.cy(n_7, 0.055, 0.44, M_DARK, Vector3(0.0, 0.16, 0.0), Vector3(16.0, 0.0, 0.0), 0.018, 16)
	K.cy(n_7, 0.092, 0.04, M_BODYSUB, Vector3(0.0, 0.02, 0.0), Vector3.ZERO, 0.105, 24)
	A.add(n_7, A.torus(0.052, 0.082, 24), M_BRASS, Vector3(0.0, 0.3, 0.04), Vector3(16.0, 0.0, 0.0), Vector3.ONE, false)
	A.add(n_7, A.cyl(0.044, 0.05, 0.044, 16), M_WEBGLOW, Vector3(0.0, 0.37, 0.06), Vector3(16.0, 0.0, 0.0), Vector3.ONE, false)
	var n_8 := K.node(n_3, Vector3(-2.3301, 0.0, -0.7571), Vector3(0.0, -108.0, 0.0), "AnchorStake_5")
	K.cy(n_8, 0.055, 0.44, M_DARK, Vector3(0.0, 0.16, 0.0), Vector3(16.0, 0.0, 0.0), 0.018, 16)
	K.cy(n_8, 0.092, 0.04, M_BODYSUB, Vector3(0.0, 0.02, 0.0), Vector3.ZERO, 0.105, 24)
	A.add(n_8, A.torus(0.052, 0.082, 24), M_BRASS, Vector3(0.0, 0.3, 0.04), Vector3(16.0, 0.0, 0.0), Vector3.ONE, false)
	A.add(n_8, A.cyl(0.044, 0.05, 0.044, 16), M_WEBGLOW, Vector3(0.0, 0.37, 0.06), Vector3(16.0, 0.0, 0.0), Vector3.ONE, false)
	var n_9 := K.node(n_3, Vector3(-1.1123, 0.0, -2.183), Vector3(0.0, -153.0, 0.0), "AnchorStake_6")
	K.cy(n_9, 0.055, 0.44, M_DARK, Vector3(0.0, 0.16, 0.0), Vector3(16.0, 0.0, 0.0), 0.018, 16)
	K.cy(n_9, 0.092, 0.04, M_BODYSUB, Vector3(0.0, 0.02, 0.0), Vector3.ZERO, 0.105, 24)
	A.add(n_9, A.torus(0.052, 0.082, 24), M_BRASS, Vector3(0.0, 0.3, 0.04), Vector3(16.0, 0.0, 0.0), Vector3.ONE, false)
	A.add(n_9, A.cyl(0.044, 0.05, 0.044, 16), M_WEBGLOW, Vector3(0.0, 0.37, 0.06), Vector3(16.0, 0.0, 0.0), Vector3.ONE, false)
	var n_10 := K.node(n_3, Vector3(0.7571, 0.0, -2.3301), Vector3(0.0, -198.0, 0.0), "AnchorStake_7")
	K.cy(n_10, 0.055, 0.44, M_DARK, Vector3(0.0, 0.16, 0.0), Vector3(16.0, 0.0, 0.0), 0.018, 16)
	K.cy(n_10, 0.092, 0.04, M_BODYSUB, Vector3(0.0, 0.02, 0.0), Vector3.ZERO, 0.105, 24)
	A.add(n_10, A.torus(0.052, 0.082, 24), M_BRASS, Vector3(0.0, 0.3, 0.04), Vector3(16.0, 0.0, 0.0), Vector3.ONE, false)
	A.add(n_10, A.cyl(0.044, 0.05, 0.044, 16), M_WEBGLOW, Vector3(0.0, 0.37, 0.06), Vector3(16.0, 0.0, 0.0), Vector3.ONE, false)
	var n_11 := K.node(n_3, Vector3(2.183, 0.0, -1.1123), Vector3(0.0, -243.0, 0.0), "AnchorStake_8")
	K.cy(n_11, 0.055, 0.44, M_DARK, Vector3(0.0, 0.16, 0.0), Vector3(16.0, 0.0, 0.0), 0.018, 16)
	K.cy(n_11, 0.092, 0.04, M_BODYSUB, Vector3(0.0, 0.02, 0.0), Vector3.ZERO, 0.105, 24)
	A.add(n_11, A.torus(0.052, 0.082, 24), M_BRASS, Vector3(0.0, 0.3, 0.04), Vector3(16.0, 0.0, 0.0), Vector3.ONE, false)
	A.add(n_11, A.cyl(0.044, 0.05, 0.044, 16), M_WEBGLOW, Vector3(0.0, 0.37, 0.06), Vector3(16.0, 0.0, 0.0), Vector3.ONE, false)
	var n_12 := K.node(root, Vector3.ZERO, Vector3.ZERO, "CatenarySnareCables")
	A.add(n_12, A.tube([Vector3(0.3234, 0.27, 0.1051), Vector3(0.727, 0.19, 0.2362), Vector3(1.3981, 0.15, 0.4543), Vector3(2.2369, 0.28, 0.7268)], 0.026, 14, 10), M_WEBGLOW, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.add(n_12, A.sphere(0.065, 0.09, 20), M_WEBRESIN, Vector3(1.2862, 0.16, 0.4179), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_12, A.tube([Vector3(0.1544, 0.27, 0.3029), Vector3(0.347, 0.19, 0.6811), Vector3(0.6674, 0.15, 1.3098), Vector3(1.0678, 0.28, 2.0956)], 0.026, 14, 10), M_WEBGLOW, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.add(n_12, A.sphere(0.065, 0.09, 20), M_WEBRESIN, Vector3(0.614, 0.16, 1.205), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_12, A.tube([Vector3(-0.1051, 0.27, 0.3234), Vector3(-0.2362, 0.19, 0.727), Vector3(-0.4543, 0.15, 1.3981), Vector3(-0.7268, 0.28, 2.2369)], 0.026, 14, 10), M_WEBGLOW, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.add(n_12, A.sphere(0.065, 0.09, 20), M_WEBRESIN, Vector3(-0.4179, 0.16, 1.2862), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_12, A.tube([Vector3(-0.3029, 0.27, 0.1544), Vector3(-0.6811, 0.19, 0.347), Vector3(-1.3098, 0.15, 0.6674), Vector3(-2.0956, 0.28, 1.0678)], 0.026, 14, 10), M_WEBGLOW, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.add(n_12, A.sphere(0.065, 0.09, 20), M_WEBRESIN, Vector3(-1.205, 0.16, 0.614), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_12, A.tube([Vector3(-0.3234, 0.27, -0.1051), Vector3(-0.727, 0.19, -0.2362), Vector3(-1.3981, 0.15, -0.4543), Vector3(-2.2369, 0.28, -0.7268)], 0.026, 14, 10), M_WEBGLOW, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.add(n_12, A.sphere(0.065, 0.09, 20), M_WEBRESIN, Vector3(-1.2862, 0.16, -0.4179), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_12, A.tube([Vector3(-0.1544, 0.27, -0.3029), Vector3(-0.347, 0.19, -0.6811), Vector3(-0.6674, 0.15, -1.3098), Vector3(-1.0678, 0.28, -2.0956)], 0.026, 14, 10), M_WEBGLOW, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.add(n_12, A.sphere(0.065, 0.09, 20), M_WEBRESIN, Vector3(-0.614, 0.16, -1.205), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_12, A.tube([Vector3(0.1051, 0.27, -0.3234), Vector3(0.2362, 0.19, -0.727), Vector3(0.4543, 0.15, -1.3981), Vector3(0.7268, 0.28, -2.2369)], 0.026, 14, 10), M_WEBGLOW, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.add(n_12, A.sphere(0.065, 0.09, 20), M_WEBRESIN, Vector3(0.4179, 0.16, -1.2862), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_12, A.tube([Vector3(0.3029, 0.27, -0.1544), Vector3(0.6811, 0.19, -0.347), Vector3(1.3098, 0.15, -0.6674), Vector3(2.0956, 0.28, -1.0678)], 0.026, 14, 10), M_WEBGLOW, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.add(n_12, A.sphere(0.065, 0.09, 20), M_WEBRESIN, Vector3(1.205, 0.16, -0.614), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_12, A.tube([Vector3(2.0039, 0.24, 0.6511), Vector3(1.4114, 0.14, 1.2054), Vector3(0.9566, 0.24, 1.8774)], 0.02, 14, 8), M_WEBGLOW, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.add(n_12, A.tube([Vector3(1.165, 0.19, 0.3785), Vector3(0.8262, 0.13, 0.7056), Vector3(0.5561, 0.19, 1.0915)], 0.018, 14, 8), M_WEBRESIN, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.add(n_12, A.tube([Vector3(0.9566, 0.24, 1.8774), Vector3(0.1456, 0.14, 1.8504), Vector3(-0.6511, 0.24, 2.0039)], 0.02, 14, 8), M_WEBGLOW, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.add(n_12, A.tube([Vector3(0.5561, 0.19, 1.0915), Vector3(0.0852, 0.13, 1.0831), Vector3(-0.3785, 0.19, 1.165)], 0.018, 14, 8), M_WEBRESIN, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.add(n_12, A.tube([Vector3(-0.6511, 0.24, 2.0039), Vector3(-1.2054, 0.14, 1.4114), Vector3(-1.8774, 0.24, 0.9566)], 0.02, 14, 8), M_WEBGLOW, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.add(n_12, A.tube([Vector3(-0.3785, 0.19, 1.165), Vector3(-0.7056, 0.13, 0.8262), Vector3(-1.0915, 0.19, 0.5561)], 0.018, 14, 8), M_WEBRESIN, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.add(n_12, A.tube([Vector3(-1.8774, 0.24, 0.9566), Vector3(-1.8504, 0.14, 0.1456), Vector3(-2.0039, 0.24, -0.6511)], 0.02, 14, 8), M_WEBGLOW, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.add(n_12, A.tube([Vector3(-1.0915, 0.19, 0.5561), Vector3(-1.0831, 0.13, 0.0852), Vector3(-1.165, 0.19, -0.3785)], 0.018, 14, 8), M_WEBRESIN, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.add(n_12, A.tube([Vector3(-2.0039, 0.24, -0.6511), Vector3(-1.4114, 0.14, -1.2054), Vector3(-0.9566, 0.24, -1.8774)], 0.02, 14, 8), M_WEBGLOW, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.add(n_12, A.tube([Vector3(-1.165, 0.19, -0.3785), Vector3(-0.8262, 0.13, -0.7056), Vector3(-0.5561, 0.19, -1.0915)], 0.018, 14, 8), M_WEBRESIN, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.add(n_12, A.tube([Vector3(-0.9566, 0.24, -1.8774), Vector3(-0.1456, 0.14, -1.8504), Vector3(0.6511, 0.24, -2.0039)], 0.02, 14, 8), M_WEBGLOW, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.add(n_12, A.tube([Vector3(-0.5561, 0.19, -1.0915), Vector3(-0.0852, 0.13, -1.0831), Vector3(0.3785, 0.19, -1.165)], 0.018, 14, 8), M_WEBRESIN, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.add(n_12, A.tube([Vector3(0.6511, 0.24, -2.0039), Vector3(1.2054, 0.14, -1.4114), Vector3(1.8774, 0.24, -0.9566)], 0.02, 14, 8), M_WEBGLOW, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.add(n_12, A.tube([Vector3(0.3785, 0.19, -1.165), Vector3(0.7056, 0.13, -0.8262), Vector3(1.0915, 0.19, -0.5561)], 0.018, 14, 8), M_WEBRESIN, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.add(n_12, A.tube([Vector3(1.8774, 0.24, -0.9566), Vector3(1.8504, 0.14, -0.1456), Vector3(2.0039, 0.24, 0.6511)], 0.02, 14, 8), M_WEBGLOW, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.add(n_12, A.tube([Vector3(1.0915, 0.19, -0.5561), Vector3(1.0831, 0.13, -0.0852), Vector3(1.165, 0.19, 0.3785)], 0.018, 14, 8), M_WEBRESIN, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	return root

func _ready() -> void:
	A.ground_vfx(self, A.grime_stain_tex(), Color(0.42, 0.78, 0.74, 0.46), radius * 2.15, Vector3(0, 0.122, 0), false, 0.44, false, 3)
	var model := build_model()
	var sc := radius / 3.2
	model.scale = Vector3(sc, 1.0, sc)
	add_child(model)
	A.emitter(self, Vector3(0, 0.15, 0), {"amount": 14, "life": 1.2, "size": 0.25, "spread": 180.0, "vmin": 0.1, "vmax": 0.4, "gravity": Vector3(0, 0.4, 0),
		"c0": Color(0.45, 1.0, 0.95, 0.7), "c1": Color(0.2, 0.6, 0.6, 0.0), "grow0": 0.8, "grow1": 0.2})
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 1.08, 0.2)
	tw.tween_property(self, "scale", Vector3.ONE, 0.2)

func _process(delta: float) -> void:
	life -= delta
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.35
		if raid != null and is_instance_valid(raid):
			var tree: SceneTree = raid.get_tree()
			for b in Status.near(tree, global_position, radius):
				Status.slow(b, factor, 0.6, tree)
			Audio.play_sfx("web_pulse", global_position, {"vol": -10.0})
	if life <= 0.0:
		set_process(false)
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector3(0.05, 0.05, 0.05), 0.35).set_ease(Tween.EASE_IN)
		tw.tween_callback(queue_free)
