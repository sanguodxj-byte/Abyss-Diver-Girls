extends RefCounted
## 聚焦激光：散热片阵列、聚焦线圈、冷却管
## 接口：插头 HP-A1（朝向躯干）；导出 muzzle
const A = preload("res://scripts/art.gd")
const K = preload("res://scripts/modules/kit.gd")


static func build(ctx: Dictionary) -> Node3D:
	var id: String = ctx.id
	var c: Color = ctx.color
	var lights: bool = ctx.get("lights", true)
	var M_FRAME := K.frame()
	var M_DARK := K.dark()
	var M_GUN := K.gunmetal()
	var M_ACC := K.accent()
	var side: float = ctx.get("side", 1.0)
	var root := K.module_root(ctx.get("slot", "arm_r"), id, Vector3(-side, 0, 0))
	var arm := K.node(root, Vector3(side * 0.25, 0, 0), Vector3.ZERO, "Body")
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	arm.add_child(muzzle)
	var M_ARM := K.armor(c, 0.50)
	var M_ARM2 := K.armor_sub(c, 0.54)

	# 战术多级电磁线圈穿甲步枪（LZ-42 军工实弹电磁加速风格：脉冲电容机匣 + 液冷散热鳍片叠 + 开槽铜绕组加速身管 + 多室钢制膛口制退器）
	K.shoulder(arm, side, M_ARM)

	# 1. 后部高压脉冲电容与自动供弹机匣 + 散热鳍片阵列
	K.bb(arm, Vector3(0.42, 0.44, 0.96), M_FRAME, Vector3(0, -0.02, -0.34), Vector3.ZERO, 0.035)
	for sx in [-1.0, 1.0]:
		K.plate(arm, K.crect(0.92, 0.38, [0.12, 0.04, 0.08, 0.12]), 0.05, M_ARM, Vector3(sx * 0.21, -0.02, -0.34), Vector3(0, 90, 0), 0.015)
	K.plate(arm, K.trap(0.84, 0.62, 0.10, 0.03), 0.42, M_ARM2, Vector3(0, 0.22, -0.36), Vector3(0, 90, 0), 0.02)
	K.plate(arm, K.crect(0.56, 0.045), 0.44, M_ACC, Vector3(0, 0.18, -0.36), Vector3(0, 90, 0), 0.005)
	for i in 9:
		K.bb(arm, Vector3(0.36, 0.08, 0.020), M_GUN, Vector3(0, -0.24, -0.02 - i * 0.082), Vector3.ZERO, 0.004)

	# 外侧钨钢针弹供弹鼓匣 + 高压编织母线管 + 实弹口径铭牌
	var M_MAG := A.paint(Color(0.24, 0.26, 0.24), 0.40, 0.48, {"wear": 0.42, "panel_scale": 0.0})
	K.bb(arm, Vector3(0.18, 0.26, 0.52), M_MAG, Vector3(side * 0.30, -0.10, -0.20), Vector3.ZERO, 0.018)
	for sz in [-0.36, -0.04]:
		K.bb(arm, Vector3(0.19, 0.27, 0.03), M_DARK, Vector3(side * 0.30, -0.10, sz), Vector3.ZERO, 0.006)
	K.cy(arm, 0.032, 0.06, K.brass(), Vector3(side * 0.28, -0.10, -0.49), Vector3(90, 0, 0), -1.0, 10)
	A.hose(arm, Vector3(side * 0.28, -0.10, -0.52), Vector3(side * 0.14, -0.08, -0.84), Vector3(side * 0.06, -0.06, 0), 0.026)
	A.hose(arm, Vector3(0, 0.20, 0.08), Vector3(0, 0.14, -0.62), Vector3(0, 0.12, 0), 0.026)
	A.stencil(arm, "EM-COIL 9x68", Vector3(side * 0.24, 0.06, -0.34), Vector3(0, side * 90.0, 0), 0.0022, Color(0.92, 0.78, 0.28, 0.85))

	# 2. 前段多级异步感应线圈加速身管：高强合金钢内管 + 六组外露紫铜加速线圈环 + 上下桁架护木 + 三道机械锁紧箍
	K.cy(arm, 0.086, 1.08, M_GUN, Vector3(0, -0.02, -1.34), Vector3(90, 0, 0), -1.0, 16)
	for ci in 6:
		var cz := -0.92 - ci * 0.155
		K.cy(arm, 0.118, 0.085, K.copper(), Vector3(0, -0.02, cz), Vector3(90, 0, 0), -1.0, 16)
		K.cy(arm, 0.123, 0.020, M_DARK, Vector3(0, -0.02, cz - 0.045), Vector3(90, 0, 0), -1.0, 16)
	K.plate(arm, K.trap(0.96, 0.82, 0.11, 0.03), 0.28, M_ARM, Vector3(0, 0.11, -1.32), Vector3(0, 90, 0), 0.02)
	K.plate(arm, K.trap(0.80, 0.92, 0.10, 0.03), 0.26, M_ARM2, Vector3(0, -0.15, -1.32), Vector3(0, 90, 0), 0.02)
	for zz in [-0.96, -1.34, -1.70]:
		K.bb(arm, Vector3(0.32, 0.30, 0.062), M_GUN, Vector3(0, -0.02, zz), Vector3.ZERO, 0.014)
		for sy in [-0.11, 0.11]:
			K.cy(arm, 0.016, 0.34, A.chrome(), Vector3(0, -0.02 + sy, zz), Vector3(0, 0, 90), -1.0, 6)
	# 外侧铜质汇流母排 + 黄铜稳压端子箱
	K.bb(arm, Vector3(0.024, 0.036, 0.68), K.copper(), Vector3(side * 0.165, -0.02, -1.32), Vector3.ZERO, 0.004)
	K.bb(arm, Vector3(0.046, 0.058, 0.082), K.brass(), Vector3(side * 0.168, -0.02, -1.14), Vector3.ZERO, 0.006)
	if lights:
		A.lens(arm, Vector3(side * 0.194, -0.02, -1.14), Vector3(0, 0, -side * 90.0), 0.011, Color(0.95, 0.68, 0.20), 1.0)

	# 3. 膛口多室矩形钢制脱壳分流制退器（Sabot Stripper Muzzle Brake）+ 真实深膛孔 + 顶置光学弹道测距瞄具
	var brake := K.node(arm, Vector3(0, -0.02, -1.90))
	K.bb(brake, Vector3(0.22, 0.20, 0.24), M_DARK, Vector3(0, 0, 0.01), Vector3.ZERO, 0.018)
	for bi in 3:
		var bz := 0.075 - bi * 0.068
		K.bb(brake, Vector3(0.24, 0.11, 0.026), M_GUN, Vector3(0, 0, bz), Vector3.ZERO, 0.004)
	K.cy(brake, 0.078, 0.06, M_GUN, Vector3(0, 0, -0.115), Vector3(90, 0, 0), 0.065, 14)
	K.cy(brake, 0.052, 0.08, K.bore_mat(), Vector3(0, 0, -0.118), Vector3(90, 0, 0), -1.0, 14)
	K.bb(arm, Vector3(0.11, 0.09, 0.30), M_DARK, Vector3(0, 0.20, -1.72), Vector3.ZERO, 0.012)
	K.cy(arm, 0.036, 0.08, M_GUN, Vector3(0, 0.20, -1.89), Vector3(90, 0, 0), 0.030, 12)
	A.lens(arm, Vector3(0, 0.20, -1.928), Vector3(-90, 0, 0), 0.022, Color(0.88, 0.66, 0.22), 0.9)

	muzzle.position = Vector3(0, -0.02, -2.0)
	root.set_meta("muzzle", muzzle)
	return root
