extends Node3D
## 战术声波诱饵信标 (Tactical Sonic Decoy Beacon)
## 清单编号：P0-SKL-02 | 优先级：P0 | 目标路径：scripts/modules/decoy_beacon.gd
## 替换原仓未更新旧模：scripts/modules/decoy_beacon.gd (L27-38 原 6 图元简拼 + 6 边天线)
## 标准占地：Vector3(1.14, 2.08, 1.14) | 全曲面已通过 docs/low_poly_model_audit.md 红线校验
## 彻底重制原 6 图元简陋诱饵：3 组五件套液压折叠三脚架与防滑泥脚垫 + IP67 防水声学主机箱（双侧百叶散热窗/电量槽/防撞护框/警示条）+ 36 段多级指数扩音号角与黄铜相位锥 + 16 段弹簧鞭状天线 + 护笼频闪警示灯（保留原仓完整声波诱敌与自爆逻辑）。
## 保留原仓完整声波诱敌、受击火花与自爆逻辑，彻底重制高精度三脚液压声波诱饵台与号角阵列。

const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")
const FX = preload("res://scripts/modules/weapon_fx.gd")

const LURE := Color(1.0, 0.72, 0.22)

var raid
var life := 12.0
var hp := 70.0
var dead := false
var radius := 26.0
var _pulse_t := 0.0
var _lured: Array = []
var _lamp: Node3D

func setup(r) -> void:
	raid = r
	add_to_group("coop_devices")
	set_meta("coop_device", "decoy")

static func build_model() -> Node3D:
	var root := Node3D.new()
	root.name = "SonicDecoyBeacon"
	var M_BODY := K.armor(Color("#58513d"), 0.56)
	var M_BODYSUB := K.armor_sub(Color("#464134"), 0.52)
	var M_DARK := K.dark()
	var M_GUNMETAL := K.gunmetal()
	var M_BRASS := K.brass()
	var M_CHROME := A.chrome()
	var M_RUBBER := A.rubber()
	var M_HAZARD := A.hazard()
	var M_BORE := K.bore_mat()
	var M_CANOPY := K.canopy(Color("#3b4a32"), 0.14)
	var M_LURE := A.emit(Color("#ffb838"), 2.5)
	var n_1 := K.node(root, Vector3.ZERO, Vector3.ZERO, "TripodBase")
	K.cy(n_1, 0.16, 0.12, M_DARK, Vector3(0.0, 0.72, 0.0), Vector3.ZERO, 0.18, 28)
	K.cy(n_1, 0.11, 0.48, M_GUNMETAL, Vector3(0.0, 0.44, 0.0), Vector3.ZERO, 0.11, 24)
	K.cy(n_1, 0.14, 0.06, M_DARK, Vector3(0.0, 0.22, 0.0), Vector3.ZERO, 0.14, 24)
	var n_2 := K.node(n_1, Vector3(0.2944, 0.0, 0.17), Vector3(0.0, 60.0, 0.0), "HydraulicTripodLeg_1")
	K.cy(n_2, 0.095, 0.045, M_DARK, Vector3(0.0, 0.022, 0.21), Vector3.ZERO, 0.125, 24)
	K.cy(n_2, 0.032, 0.09, M_GUNMETAL, Vector3(0.0, -0.02, 0.24), Vector3.ZERO, 0.01, 16)
	K.cy(n_2, 0.022, 0.34, M_GUNMETAL, Vector3(0.0, 0.22, -0.04), Vector3(90.0, 0.0, 0.0), 0.022, 16)
	K.bb(n_2, Vector3(0.075, 0.075, 0.08), M_BODYSUB, Vector3(0.0, 0.07, 0.18), Vector3.ZERO, 0.005)
	var n_3 := K.node(n_2, Vector3(0.0, 0.42, 0.02), Vector3(-64.0, 0.0, 0.0), "LegPiston_1")
	K.cy(n_3, 0.042, 0.4212, M_GUNMETAL, Vector3(0.0, 0.0, 0.156), Vector3(90.0, 0.0, 0.0), 0.042, 16)
	K.cy(n_3, 0.0487, 0.032, M_BRASS, Vector3(0.0, 0.0, -0.0624), Vector3(90.0, 0.0, 0.0), 0.0487, 16)
	K.cy(n_3, 0.0235, 0.7176, M_CHROME, Vector3(0.0, 0.0, -0.0156), Vector3(90.0, 0.0, 0.0), 0.0235, 16)
	K.bb(n_3, Vector3(0.0693, 0.0567, 0.0609), M_DARK, Vector3(0.0, 0.0, -0.3744), Vector3.ZERO, 0.006)
	K.bb(n_3, Vector3(0.0693, 0.0567, 0.0609), M_DARK, Vector3(0.0, 0.0, 0.3744), Vector3.ZERO, 0.006)
	A.add(n_3, A.cyl(0.0169, 0.0859, 0.0169, 16), M_CHROME, Vector3(0.0, 0.0, -0.3744), Vector3(0.0, 0.0, 90.0), Vector3.ONE, false)
	A.add(n_3, A.cyl(0.0169, 0.0859, 0.0169, 16), M_CHROME, Vector3(0.0, 0.0, 0.3744), Vector3(0.0, 0.0, 90.0), Vector3.ONE, false)
	var n_4 := K.node(n_1, Vector3(-0.2944, 0.0, 0.17), Vector3(0.0, -60.0, 0.0), "HydraulicTripodLeg_2")
	K.cy(n_4, 0.095, 0.045, M_DARK, Vector3(0.0, 0.022, 0.21), Vector3.ZERO, 0.125, 24)
	K.cy(n_4, 0.032, 0.09, M_GUNMETAL, Vector3(0.0, -0.02, 0.24), Vector3.ZERO, 0.01, 16)
	K.cy(n_4, 0.022, 0.34, M_GUNMETAL, Vector3(0.0, 0.22, -0.04), Vector3(90.0, 0.0, 0.0), 0.022, 16)
	K.bb(n_4, Vector3(0.075, 0.075, 0.08), M_BODYSUB, Vector3(0.0, 0.07, 0.18), Vector3.ZERO, 0.005)
	var n_5 := K.node(n_4, Vector3(0.0, 0.42, 0.02), Vector3(-64.0, 0.0, 0.0), "LegPiston_2")
	K.cy(n_5, 0.042, 0.4212, M_GUNMETAL, Vector3(0.0, 0.0, 0.156), Vector3(90.0, 0.0, 0.0), 0.042, 16)
	K.cy(n_5, 0.0487, 0.032, M_BRASS, Vector3(0.0, 0.0, -0.0624), Vector3(90.0, 0.0, 0.0), 0.0487, 16)
	K.cy(n_5, 0.0235, 0.7176, M_CHROME, Vector3(0.0, 0.0, -0.0156), Vector3(90.0, 0.0, 0.0), 0.0235, 16)
	K.bb(n_5, Vector3(0.0693, 0.0567, 0.0609), M_DARK, Vector3(0.0, 0.0, -0.3744), Vector3.ZERO, 0.006)
	K.bb(n_5, Vector3(0.0693, 0.0567, 0.0609), M_DARK, Vector3(0.0, 0.0, 0.3744), Vector3.ZERO, 0.006)
	A.add(n_5, A.cyl(0.0169, 0.0859, 0.0169, 16), M_CHROME, Vector3(0.0, 0.0, -0.3744), Vector3(0.0, 0.0, 90.0), Vector3.ONE, false)
	A.add(n_5, A.cyl(0.0169, 0.0859, 0.0169, 16), M_CHROME, Vector3(0.0, 0.0, 0.3744), Vector3(0.0, 0.0, 90.0), Vector3.ONE, false)
	var n_6 := K.node(n_1, Vector3(0.0, 0.0, -0.34), Vector3(0.0, -180.0, 0.0), "HydraulicTripodLeg_3")
	K.cy(n_6, 0.095, 0.045, M_DARK, Vector3(0.0, 0.022, 0.21), Vector3.ZERO, 0.125, 24)
	K.cy(n_6, 0.032, 0.09, M_GUNMETAL, Vector3(0.0, -0.02, 0.24), Vector3.ZERO, 0.01, 16)
	K.cy(n_6, 0.022, 0.34, M_GUNMETAL, Vector3(0.0, 0.22, -0.04), Vector3(90.0, 0.0, 0.0), 0.022, 16)
	K.bb(n_6, Vector3(0.075, 0.075, 0.08), M_BODYSUB, Vector3(0.0, 0.07, 0.18), Vector3.ZERO, 0.005)
	var n_7 := K.node(n_6, Vector3(0.0, 0.42, 0.02), Vector3(-64.0, 0.0, 0.0), "LegPiston_3")
	K.cy(n_7, 0.042, 0.4212, M_GUNMETAL, Vector3(0.0, 0.0, 0.156), Vector3(90.0, 0.0, 0.0), 0.042, 16)
	K.cy(n_7, 0.0487, 0.032, M_BRASS, Vector3(0.0, 0.0, -0.0624), Vector3(90.0, 0.0, 0.0), 0.0487, 16)
	K.cy(n_7, 0.0235, 0.7176, M_CHROME, Vector3(0.0, 0.0, -0.0156), Vector3(90.0, 0.0, 0.0), 0.0235, 16)
	K.bb(n_7, Vector3(0.0693, 0.0567, 0.0609), M_DARK, Vector3(0.0, 0.0, -0.3744), Vector3.ZERO, 0.006)
	K.bb(n_7, Vector3(0.0693, 0.0567, 0.0609), M_DARK, Vector3(0.0, 0.0, 0.3744), Vector3.ZERO, 0.006)
	A.add(n_7, A.cyl(0.0169, 0.0859, 0.0169, 16), M_CHROME, Vector3(0.0, 0.0, -0.3744), Vector3(0.0, 0.0, 90.0), Vector3.ONE, false)
	A.add(n_7, A.cyl(0.0169, 0.0859, 0.0169, 16), M_CHROME, Vector3(0.0, 0.0, 0.3744), Vector3(0.0, 0.0, 90.0), Vector3.ONE, false)
	var n_8 := K.node(n_1, Vector3(0.0, 0.78, 0.0), Vector3.ZERO, "HubRingBolts")
	A.add(n_8, A.cyl(0.011, 0.016, 0.0123, 6), M_CHROME, Vector3(0.135, 0.0, 0.0), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_8, A.cyl(0.011, 0.016, 0.0123, 6), M_CHROME, Vector3(0.0955, 0.0, 0.0955), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_8, A.cyl(0.011, 0.016, 0.0123, 6), M_CHROME, Vector3(0.0, 0.0, 0.135), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_8, A.cyl(0.011, 0.016, 0.0123, 6), M_CHROME, Vector3(-0.0955, 0.0, 0.0955), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_8, A.cyl(0.011, 0.016, 0.0123, 6), M_CHROME, Vector3(-0.135, 0.0, 0.0), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_8, A.cyl(0.011, 0.016, 0.0123, 6), M_CHROME, Vector3(-0.0955, 0.0, -0.0955), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_8, A.cyl(0.011, 0.016, 0.0123, 6), M_CHROME, Vector3(0.0, 0.0, -0.135), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_8, A.cyl(0.011, 0.016, 0.0123, 6), M_CHROME, Vector3(0.0955, 0.0, -0.0955), Vector3.ZERO, Vector3.ONE, false)
	var n_9 := K.node(root, Vector3.ZERO, Vector3.ZERO, "AcousticControlBox")
	K.bb(n_9, Vector3(0.46, 0.34, 0.44), M_BODY, Vector3(0.0, 0.94, 0.0), Vector3.ZERO, 0.018)
	K.bb(n_9, Vector3(0.48, 0.075, 0.46), M_HAZARD, Vector3(0.0, 0.8, 0.0), Vector3.ZERO, 0.008)
	K.bb(n_9, Vector3(0.055, 0.38, 0.055), M_DARK, Vector3(-0.23, 0.94, -0.22), Vector3.ZERO, 0.006)
	K.bb(n_9, Vector3(0.055, 0.38, 0.055), M_DARK, Vector3(0.23, 0.94, -0.22), Vector3.ZERO, 0.006)
	K.bb(n_9, Vector3(0.055, 0.38, 0.055), M_DARK, Vector3(-0.23, 0.94, 0.22), Vector3.ZERO, 0.006)
	K.bb(n_9, Vector3(0.055, 0.38, 0.055), M_DARK, Vector3(0.23, 0.94, 0.22), Vector3.ZERO, 0.006)
	K.bb(n_9, Vector3(0.26, 0.12, 0.03), M_DARK, Vector3(0.0, 0.99, -0.224), Vector3.ZERO, 0.004)
	A.add(n_9, A.bevel_box(Vector3(0.22, 0.08, 0.014), 0.002), M_CANOPY, Vector3(0.0, 0.99, -0.234), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_9, A.bevel_box(Vector3(0.16, 0.018, 0.012), 0.002), M_LURE, Vector3(0.0, 0.99, -0.242), Vector3.ZERO, Vector3.ONE, false)
	K.bb(n_9, Vector3(0.1, 0.22, 0.22), M_BODYSUB, Vector3(0.27, 0.94, 0.0), Vector3.ZERO, 0.008)
	A.add(n_9, A.tube([Vector3(0.24, 1.05, 0.06), Vector3(0.29, 1.13, 0.08), Vector3(0.2, 1.22, 0.03)], 0.016, 14, 8), M_RUBBER, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.stencil(n_9, "SONIC-3", Vector3(0.0, 0.89, -0.225), Vector3(0.0, 180.0, 0.0), 0.005, Color("#d0cab8"))
	A.add(n_9, A.cyl(0.01, 0.014, 0.0115, 6), M_CHROME, Vector3(-0.18, 1.08, -0.224), Vector3(90.0, 0.0, 0.0), Vector3.ONE, false)
	A.add(n_9, A.cyl(0.01, 0.014, 0.0115, 6), M_CHROME, Vector3(-0.09, 1.08, -0.224), Vector3(90.0, 0.0, 0.0), Vector3.ONE, false)
	A.add(n_9, A.cyl(0.01, 0.014, 0.0115, 6), M_CHROME, Vector3(0.0, 1.08, -0.224), Vector3(90.0, 0.0, 0.0), Vector3.ONE, false)
	A.add(n_9, A.cyl(0.01, 0.014, 0.0115, 6), M_CHROME, Vector3(0.09, 1.08, -0.224), Vector3(90.0, 0.0, 0.0), Vector3.ONE, false)
	A.add(n_9, A.cyl(0.01, 0.014, 0.0115, 6), M_CHROME, Vector3(0.18, 1.08, -0.224), Vector3(90.0, 0.0, 0.0), Vector3.ONE, false)
	var n_10 := K.node(n_9, Vector3(-0.235, 0.95, 0.0), Vector3(0.0, -90.0, 0.0), "LeftAmpVent")
	K.bb(n_10, Vector3(0.26, 0.19, 0.036), M_DARK, Vector3(0.0, 0.0, -0.006), Vector3.ZERO, 0.006)
	A.add(n_10, A.bevel_box(Vector3(0.2366, 0.1672, 0.024), 0.004), M_BORE, Vector3(0.0, 0.0, -0.024), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_10, A.bevel_box(Vector3(0.2262, 0.014, 0.032), 0.004), M_GUNMETAL, Vector3(0.0, -0.0593, -0.036), Vector3(-28.0, 0.0, 0.0), Vector3.ONE, false)
	A.add(n_10, A.bevel_box(Vector3(0.2262, 0.014, 0.032), 0.004), M_GUNMETAL, Vector3(0.0, -0.0296, -0.036), Vector3(-28.0, 0.0, 0.0), Vector3.ONE, false)
	A.add(n_10, A.bevel_box(Vector3(0.2262, 0.014, 0.032), 0.004), M_GUNMETAL, Vector3(0.0, 0.0, -0.036), Vector3(-28.0, 0.0, 0.0), Vector3.ONE, false)
	A.add(n_10, A.bevel_box(Vector3(0.2262, 0.014, 0.032), 0.004), M_GUNMETAL, Vector3(0.0, 0.0296, -0.036), Vector3(-28.0, 0.0, 0.0), Vector3.ONE, false)
	A.add(n_10, A.bevel_box(Vector3(0.2262, 0.014, 0.032), 0.004), M_GUNMETAL, Vector3(0.0, 0.0593, -0.036), Vector3(-28.0, 0.0, 0.0), Vector3.ONE, false)
	var n_11 := K.node(n_9, Vector3(0.0, 0.95, 0.225), Vector3(0.0, 180.0, 0.0), "RearAmpVent")
	K.bb(n_11, Vector3(0.3, 0.19, 0.036), M_DARK, Vector3(0.0, 0.0, -0.006), Vector3.ZERO, 0.006)
	A.add(n_11, A.bevel_box(Vector3(0.273, 0.1672, 0.024), 0.004), M_BORE, Vector3(0.0, 0.0, -0.024), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_11, A.bevel_box(Vector3(0.261, 0.014, 0.032), 0.004), M_GUNMETAL, Vector3(0.0, -0.0593, -0.036), Vector3(-28.0, 0.0, 0.0), Vector3.ONE, false)
	A.add(n_11, A.bevel_box(Vector3(0.261, 0.014, 0.032), 0.004), M_GUNMETAL, Vector3(0.0, -0.0296, -0.036), Vector3(-28.0, 0.0, 0.0), Vector3.ONE, false)
	A.add(n_11, A.bevel_box(Vector3(0.261, 0.014, 0.032), 0.004), M_GUNMETAL, Vector3(0.0, 0.0, -0.036), Vector3(-28.0, 0.0, 0.0), Vector3.ONE, false)
	A.add(n_11, A.bevel_box(Vector3(0.261, 0.014, 0.032), 0.004), M_GUNMETAL, Vector3(0.0, 0.0296, -0.036), Vector3(-28.0, 0.0, 0.0), Vector3.ONE, false)
	A.add(n_11, A.bevel_box(Vector3(0.261, 0.014, 0.032), 0.004), M_GUNMETAL, Vector3(0.0, 0.0593, -0.036), Vector3(-28.0, 0.0, 0.0), Vector3.ONE, false)
	var n_12 := K.node(root, Vector3.ZERO, Vector3.ZERO, "AcousticHornArray")
	K.cy(n_12, 0.16, 0.14, M_DARK, Vector3(0.0, 1.15, 0.0), Vector3.ZERO, 0.19, 28)
	K.cy(n_12, 0.28, 0.16, M_BODYSUB, Vector3(0.0, 1.29, 0.0), Vector3.ZERO, 0.16, 36)
	K.cy(n_12, 0.44, 0.2, M_BODY, Vector3(0.0, 1.46, 0.0), Vector3.ZERO, 0.28, 36)
	A.add(n_12, A.torus(0.415, 0.465, 36), M_DARK, Vector3(0.0, 1.56, 0.0), Vector3.ZERO)
	K.cy(n_12, 0.45, 0.055, M_HAZARD, Vector3(0.0, 1.5, 0.0), Vector3.ZERO, 0.425, 36)
	A.add(n_12, A.cyl(0.38, 0.14, 0.15, 32), M_BORE, Vector3(0.0, 1.48, 0.0), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_12, A.sphere(0.11, 0.2, 24), M_BRASS, Vector3(0.0, 1.47, 0.0), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_12, A.torus(0.19, 0.215, 28), M_GUNMETAL, Vector3(0.0, 1.53, 0.0), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_12, A.torus(0.3, 0.325, 32), M_GUNMETAL, Vector3(0.0, 1.55, 0.0), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_12, A.bevel_box(Vector3(0.028, 0.028, 0.42), 0.004), M_DARK, Vector3(0.21, 1.55, 0.0), Vector3(0.0, 90.0, 0.0), Vector3.ONE, false)
	A.add(n_12, A.bevel_box(Vector3(0.028, 0.028, 0.42), 0.004), M_DARK, Vector3(0.0, 1.55, 0.21), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_12, A.bevel_box(Vector3(0.028, 0.028, 0.42), 0.004), M_DARK, Vector3(-0.21, 1.55, 0.0), Vector3(0.0, -90.0, 0.0), Vector3.ONE, false)
	A.add(n_12, A.bevel_box(Vector3(0.028, 0.028, 0.42), 0.004), M_DARK, Vector3(0.0, 1.55, -0.21), Vector3(0.0, -180.0, 0.0), Vector3.ONE, false)
	var n_13 := K.node(root, Vector3.ZERO, Vector3.ZERO, "AntennaAndStrobe")
	K.bb(n_13, Vector3(0.24, 0.05, 0.08), M_DARK, Vector3(0.26, 1.06, -0.06), Vector3.ZERO, 0.005)
	K.cy(n_13, 0.028, 0.08, M_BRASS, Vector3(0.35, 1.12, -0.06), Vector3.ZERO, 0.028, 16)
	K.cy(n_13, 0.012, 0.88, M_GUNMETAL, Vector3(0.35, 1.59, -0.06), Vector3.ZERO, 0.018, 16)
	A.add(n_13, A.sphere(0.022, -1.0, 20), M_LURE, Vector3(0.35, 2.04, -0.06), Vector3.ZERO, Vector3.ONE, false)
	K.bb(n_13, Vector3(0.22, 0.045, 0.07), M_DARK, Vector3(-0.25, 1.06, 0.04), Vector3.ZERO, 0.005)
	K.cy(n_13, 0.014, 0.62, M_GUNMETAL, Vector3(-0.33, 1.38, 0.04), Vector3.ZERO, 0.02, 16)
	var n_14 := K.node(n_13, Vector3(-0.33, 1.72, 0.04), Vector3.ZERO, "StrobeBeacon")
	K.cy(n_14, 0.068, 0.055, M_DARK, Vector3(0.0, -0.04, 0.0), Vector3.ZERO, 0.078, 24)
	A.add(n_14, A.cyl(0.054, 0.11, 0.054, 24), M_LURE, Vector3(0.0, 0.04, 0.0), Vector3.ZERO, Vector3.ONE, false)
	K.cy(n_14, 0.062, 0.026, M_DARK, Vector3(0.0, 0.105, 0.0), Vector3.ZERO, 0.062, 24)
	var n_15 := K.node(n_14, Vector3(0.0, 0.04, 0.0), Vector3.ZERO, "StrobeCage")
	A.add(n_15, A.torus(0.06, 0.092, 24), M_DARK, Vector3(0.0, -0.054, 0.0), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_15, A.torus(0.06, 0.092, 24), M_DARK, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	A.add(n_15, A.torus(0.06, 0.092, 24), M_DARK, Vector3(0.0, 0.054, 0.0), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_15, A.cyl(0.012, 0.1152, 0.012, 16), M_DARK, Vector3(0.0537, 0.0, 0.0537), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_15, A.cyl(0.012, 0.1152, 0.012, 16), M_DARK, Vector3(-0.0537, 0.0, 0.0537), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_15, A.cyl(0.012, 0.1152, 0.012, 16), M_DARK, Vector3(-0.0537, 0.0, -0.0537), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_15, A.cyl(0.012, 0.1152, 0.012, 16), M_DARK, Vector3(0.0537, 0.0, -0.0537), Vector3.ZERO, Vector3.ONE, false)
	var n_16 := K.node(n_13, Vector3(0.0, 1.06, -0.23), Vector3(-90.0, 0.0, 0.0), "AcousticSensor")
	K.cy(n_16, 0.0497, 0.0342, M_DARK, Vector3.ZERO, Vector3.ZERO, 0.0533, 16)
	A.add(n_16, A.torus(0.0331, 0.0482, 24), M_GUNMETAL, Vector3(0.0, 0.0158, 0.0), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_16, A.cyl(0.0367, 0.0079, 0.0367, 16), M_BORE, Vector3(0.0, 0.0126, 0.0), Vector3.ZERO, Vector3.ONE, false)
	A.add(n_16, A.sphere(0.0331, 0.0223, 20), M_LURE, Vector3(0.0, 0.0122, 0.0), Vector3.ZERO, Vector3.ONE, false)
	return root

func _ready() -> void:
	add_to_group("decoy")
	var model := build_model()
	add_child(model)
	_lamp = model.find_child("StrobeBeacon", true, false)
	A.add(self, A.quad(3.6, 3.6), A.extract_pad_mat(Color(LURE.r * 0.9, LURE.g * 0.9, LURE.b * 0.9, 0.52), 0.44, 3), Vector3(0, 0.118, 0), Vector3.ZERO, Vector3.ONE, false)
	A.emitter(self, Vector3(0, 1.15, 0), {"amount": 10, "life": 1.4, "size": 0.3, "spread": 60.0, "vmin": 0.4, "vmax": 1.2, "gravity": Vector3(0, 0.8, 0),
		"c0": Color(1.0, 0.8, 0.3, 0.6), "c1": Color(0.6, 0.3, 0.0, 0.0), "grow0": 0.6, "grow1": 1.4})
	Audio.play_sfx("decoy_deploy", global_position)
	_pulse()
	_pulse_t = 1.2

func _process(delta: float) -> void:
	if dead:
		return
	life -= delta
	_pulse_t -= delta
	var k := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.012)
	if is_instance_valid(_lamp):
		_lamp.scale = Vector3.ONE * (0.88 + 0.18 * k)
	if _pulse_t <= 0.0:
		_pulse_t = 1.4
		_pulse()
	if life <= 0.0:
		_expire(false)

func _pulse() -> void:
	if raid == null or not is_instance_valid(raid):
		return
	raid.alert_noise(global_position, radius)
	for b in get_tree().get_nodes_in_group("bugs"):
		if b == null or not is_instance_valid(b):
			continue
		if b.global_position.distance_to(global_position) > radius:
			continue
		b.target = self
		b.state = "chase"
		if not _lured.has(b):
			_lured.append(b)
	FX.ring(raid, global_position, LURE, 3.2, 0.7)
	FX.light(raid, global_position + Vector3(0, 1.2, 0), LURE, 2.0, 6.0, 0.2)

func take_damage(amount: float, _from := Vector3.ZERO) -> void:
	if dead:
		return
	hp -= amount
	A.burst(raid.fx if raid else self, global_position + Vector3(0, 1.0, 0), {"amount": 6, "life": 0.3, "size": 0.1, "vmin": 2.0, "vmax": 5.0,
		"gravity": Vector3(0, -14, 0), "damp": 1.5, "c0": Color(1.0, 0.9, 0.6), "c1": Color(1.0, 0.4, 0.1, 0.0)})
	if hp <= 0.0:
		_expire(true)

func _expire(exploded: bool) -> void:
	if dead:
		return
	dead = true
	set_process(false)
	for b in _lured:
		if is_instance_valid(b) and b.target == self:
			b.state = "idle"
			b.home = b.global_position
			b.target = raid.mech if raid != null and is_instance_valid(raid) and is_instance_valid(raid.mech) else null
	if exploded and raid != null and is_instance_valid(raid):
		raid.explode(global_position, 2.4, 18.0, "explosion")
	else:
		Audio.play_sfx("decoy_off", global_position)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(0.05, 0.05, 0.05), 0.3).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
