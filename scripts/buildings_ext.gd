extends RefCounted
## 扩展写实重工与城市建筑样式库（13 种新增建筑类型 + 远景 MultiMesh 轮廓同步）
## 所有部件统一走 raid._bldg_body / _ibox / _imesh，既走 60m MultiMesh 分块合批，又支持地标清场自动剥离。
## 严格限制任何外挑构件 <= 0.85m，配合 world_city 全局 4.15m OBB 间距，实现 100% 零穿模重叠。

const A = preload("res://scripts/art.gd")


static func build(raid, kind: String, p: Vector3, sz: Vector3, rot: float) -> bool:
	match kind:
		"arcade_shop":
			_arcade_shop(raid, p, sz, rot)
		"stepped_tower":
			_stepped_tower(raid, p, sz, rot)
		"courtyard_blk":
			_courtyard_blk(raid, p, sz, rot)
		"substation":
			_substation(raid, p, sz, rot)
		"terrace":
			_terrace(raid, p, sz, rot)
		"duplex":
			_duplex(raid, p, sz, rot)
		"tenement":
			_tenement(raid, p, sz, rot)
		"foundry":
			_foundry(raid, p, sz, rot)
		"chem_plant":
			_chem_plant(raid, p, sz, rot)
		"cold_store":
			_cold_store(raid, p, sz, rot)
		"loco_shed":
			_loco_shed(raid, p, sz, rot)
		"command_bunker":
			_command_bunker(raid, p, sz, rot)
		"silo_barn":
			_silo_barn(raid, p, sz, rot)
		_:
			return false
	return true


## 1. 骑楼商业街铺楼（arcade_shop）：首层退进骑楼柱廊与卷帘橱窗 + 雨棚招牌带 + 二至四层百叶窗立面 + 压顶花线女儿墙
static func _arcade_shop(raid, p: Vector3, sz: Vector3, rot: float) -> void:
	var c: Color = [Color(0.54, 0.50, 0.43), Color(0.49, 0.44, 0.39), Color(0.46, 0.47, 0.44)][raid.rng.randi() % 3]
	var sb = raid._bldg_body(sz, p + Vector3(0, sz.y * 0.5, 0))
	sb.rotation.y = -rot
	var hx := sz.x * 0.5
	var hz := sz.z * 0.5
	var hy := sz.y * 0.5
	var use_brick: bool = raid.rng.randf() < 0.5
	var M_WALL := A.brick(c) if use_brick else A.concrete(c)
	var M_DARK := A.concrete(c.darkened(0.35), false)
	var M_TRIM := A.concrete(c.lightened(0.14), false)
	var M_SHUT := A.corrugated(Color(0.22, 0.24, 0.26), 0.45, 0.42)
	var M_STEEL := A.metal(Color(0.17, 0.18, 0.19))
	var M_WIN := A.window_mat(0.18, Vector2(0.46, 0.52))
	var aw_c: Color = [Color(0.46, 0.23, 0.17), Color(0.20, 0.33, 0.38), Color(0.38, 0.35, 0.22)][raid.rng.randi() % 3]
	var M_AWN := A.roof_mat(aw_c, 0.35, true)
	var arcade_h := minf(2.6, sz.y * 0.42)
	# 首层内退店面体块 + 上部满跨楼体
	raid._ibox(sb, Vector3(sz.x - 0.12, arcade_h, maxf(2.0, sz.z - 1.35)), 0.02, M_DARK, Vector3(0, -hy + arcade_h * 0.5, -0.62))
	var up_h := maxf(1.6, sz.y - arcade_h)
	raid._ibox(sb, Vector3(sz.x, up_h, sz.z), 0.02, M_WALL, Vector3(0, -hy + arcade_h + up_h * 0.5, 0))
	raid._ibox(sb, Vector3(sz.x + 0.30, 0.18, sz.z + 0.30), 0.02, M_TRIM, Vector3(0, -hy + 0.09, 0), Vector3.ZERO, Vector3.ONE, false)
	raid._ibox(sb, Vector3(sz.x + 0.24, 0.22, sz.z + 0.24), 0.02, M_TRIM, Vector3(0, -hy + arcade_h, 0))
	# 临街骑楼方柱列 + 店面铁卷闸与遮阳雨棚
	var n_bays := maxi(2, int(sz.x / 2.7))
	for k in n_bays + 1:
		var px := -hx + 0.22 + float(k) * (sz.x - 0.44) / float(n_bays)
		raid._ibox(sb, Vector3(0.42, arcade_h, 0.44), 0.02, M_TRIM, Vector3(px, -hy + arcade_h * 0.5, hz - 0.24))
		raid._ibox(sb, Vector3(0.50, 0.28, 0.52), 0.02, M_DARK, Vector3(px, -hy + 0.14, hz - 0.24))
	for k in n_bays:
		var bx := -hx + (float(k) + 0.5) * sz.x / float(n_bays)
		var bw := sz.x / float(n_bays) - 0.58
		raid._ibox(sb, Vector3(bw, arcade_h * 0.76, 0.10), 0.01, M_SHUT, Vector3(bx, -hy + arcade_h * 0.40, hz - 1.24), Vector3.ZERO, Vector3.ONE, false)
		raid._ibox(sb, Vector3(bw + 0.12, 0.14, 0.62), 0.02, M_AWN, Vector3(bx, -hy + arcade_h - 0.22, hz + 0.24), Vector3(14, 0, 0))
	# 上部竖向壁柱与成排窄窗 + 阶梯式压顶山花女儿墙 + 屋顶空调机组
	var floors := maxi(1, int(up_h / 1.95))
	for f in floors:
		var wy := -hy + arcade_h + 0.92 + float(f) * (up_h / float(floors))
		if wy > hy - 0.45:
			break
		for k in n_bays:
			var bx := -hx + (float(k) + 0.5) * sz.x / float(n_bays)
			for sd in [-1.0, 1.0]:
				raid._ibox(sb, Vector3(0.92, 1.04, 0.08), 0.01, M_WIN, Vector3(bx, wy, sd * (hz + 0.03)), Vector3.ZERO, Vector3.ONE, false)
				raid._ibox(sb, Vector3(1.06, 0.09, 0.16), 0.01, M_TRIM, Vector3(bx, wy - 0.56, sd * (hz + 0.06)), Vector3.ZERO, Vector3.ONE, false)
	raid._ibox(sb, Vector3(sz.x - 0.22, 0.10, sz.z - 0.22), 0.02, A.tar_roof(Color(0.24, 0.25, 0.27)), Vector3(0, hy + 0.19, 0), Vector3.ZERO, Vector3.ONE, false)
	raid._ibox(sb, Vector3(sz.x + 0.26, 0.24, sz.z + 0.26), 0.02, M_TRIM, Vector3(0, hy + 0.10, 0))
	raid._ibox(sb, Vector3(sz.x * 0.52, 0.62, 0.30), 0.02, M_DARK, Vector3(0, hy + 0.44, hz - 0.14))
	raid._ibox(sb, Vector3(1.45, 0.78, 1.05), 0.03, M_STEEL, Vector3(-hx * 0.35, hy + 0.45, -hz * 0.25))


## 2. 阶梯退台商务办公塔楼（stepped_tower）：厚重裙房基座 + 二级收分塔身 + 竖向混凝土肋条幕墙 + 顶层电梯核心筒与冷却塔
static func _stepped_tower(raid, p: Vector3, sz: Vector3, rot: float) -> void:
	var c: Color = [Color(0.46, 0.47, 0.48), Color(0.50, 0.47, 0.42), Color(0.42, 0.44, 0.46)][raid.rng.randi() % 3]
	var sb = raid._bldg_body(sz, p + Vector3(0, sz.y * 0.5, 0))
	sb.rotation.y = -rot
	var hx := sz.x * 0.5
	var hz := sz.z * 0.5
	var hy := sz.y * 0.5
	var M_CON := A.concrete(c)
	var M_DARK := A.concrete(c.darkened(0.36), false)
	var M_TRIM := A.concrete(c.lightened(0.12), false)
	var M_GLS := A.window_mat(0.22, Vector2(0.95, 0.78))
	var M_STEEL := A.metal(Color(0.18, 0.19, 0.21))
	var pod_h := sz.y * 0.36
	var mid_h := sz.y * 0.40
	var top_h := sz.y - pod_h - mid_h
	# 裙房 + 中段退台 + 顶部收分体块
	raid._ibox(sb, Vector3(sz.x, pod_h, sz.z), 0.02, M_DARK, Vector3(0, -hy + pod_h * 0.5, 0))
	raid._ibox(sb, Vector3(sz.x + 0.28, 0.20, sz.z + 0.28), 0.02, M_TRIM, Vector3(0, -hy + pod_h, 0))
	var msx := sz.x * 0.80
	var msz := sz.z * 0.80
	raid._ibox(sb, Vector3(msx, mid_h, msz), 0.02, M_CON, Vector3(0, -hy + pod_h + mid_h * 0.5, -hz * 0.05))
	raid._ibox(sb, Vector3(msx + 0.22, 0.18, msz + 0.22), 0.02, M_TRIM, Vector3(0, -hy + pod_h + mid_h, -hz * 0.05))
	var tsx := sz.x * 0.62
	var tsz := sz.z * 0.62
	raid._ibox(sb, Vector3(tsx, top_h + 0.4, tsz), 0.02, M_CON, Vector3(0, hy - top_h * 0.5 + 0.1, -hz * 0.08))
	raid._ibox(sb, Vector3(tsx - 0.16, 0.08, tsz - 0.16), 0.02, A.tar_roof(Color(0.24, 0.25, 0.27)), Vector3(0, hy + 0.32, -hz * 0.08), Vector3.ZERO, Vector3.ONE, false)
	# 竖向遮阳混凝土肋条与深色窗带
	var n_ribs := maxi(3, int(msx / 1.45))
	for k in n_ribs:
		var rx := -msx * 0.5 + (float(k) + 0.5) * msx / float(n_ribs)
		for sd in [-1.0, 1.0]:
			raid._ibox(sb, Vector3(0.22, mid_h - 0.2, 0.24), 0.015, M_TRIM, Vector3(rx, -hy + pod_h + mid_h * 0.5, -hz * 0.05 + sd * (msz * 0.5 + 0.05)))
	for f in maxi(2, int(mid_h / 1.75)):
		var fy := -hy + pod_h + 0.85 + float(f) * 1.72
		if fy < -hy + pod_h + mid_h - 0.35:
			raid._ibox(sb, Vector3(msx + 0.06, 0.78, msz + 0.06), 0.01, M_GLS, Vector3(0, fy, -hz * 0.05), Vector3.ZERO, Vector3.ONE, false)
	# 首层入口钢结构门廊 + 顶层电梯机房与冷却塔
	raid._ibox(sb, Vector3(minf(3.2, sz.x * 0.45), 2.15, 0.18), 0.02, M_GLS, Vector3(0, -hy + 1.08, hz + 0.04), Vector3.ZERO, Vector3.ONE, false)
	raid._ibox(sb, Vector3(minf(3.8, sz.x * 0.52), 0.18, 0.78), 0.02, M_STEEL, Vector3(0, -hy + 2.25, hz + 0.36))
	raid._ibox(sb, Vector3(tsx * 0.46, 1.75, tsz * 0.46), 0.03, M_DARK, Vector3(tsx * 0.18, hy + 1.05, -hz * 0.12))
	raid._imesh(sb, A.cyl(0.68, 1.25, 0.76, 14), M_STEEL, Vector3(-tsx * 0.22, hy + 0.82, -hz * 0.08))
	raid._imesh(sb, A.cyl(0.04, 3.2, 0.07, 8), M_STEEL, Vector3(tsx * 0.18, hy + 3.4, -hz * 0.12), Vector3.ZERO, Vector3.ONE, false)


## 3. 围合内院街坊楼（courtyard_blk）：四周环翼围合下沉式天井内院 + 临街拱门过街楼洞 + 四坡压檐顶角楼感
static func _courtyard_blk(raid, p: Vector3, sz: Vector3, rot: float) -> void:
	var c: Color = [Color(0.50, 0.44, 0.38), Color(0.47, 0.46, 0.42), Color(0.44, 0.38, 0.34)][raid.rng.randi() % 3]
	var sb = raid._bldg_body(sz, p + Vector3(0, sz.y * 0.5, 0))
	sb.rotation.y = -rot
	var hx := sz.x * 0.5
	var hz := sz.z * 0.5
	var hy := sz.y * 0.5
	var M_WALL := A.brick(c)
	var M_DARK := A.concrete(c.darkened(0.36), false)
	var M_TRIM := A.concrete(c.lightened(0.12), false)
	var M_WIN := A.window_mat(0.16, Vector2(0.44, 0.48))
	var M_ROOF := A.tar_roof(Color(0.25, 0.26, 0.28))
	var wing_d := clampf(minf(sz.x, sz.z) * 0.29, 2.1, 3.4)
	# 底层院落地坪 + 四周四翼楼体围合中央采光天井
	raid._ibox(sb, Vector3(sz.x + 0.24, 0.38, sz.z + 0.24), 0.03, M_DARK, Vector3(0, -hy + 0.19, 0))
	raid._ibox(sb, Vector3(maxf(1.0, sz.x - wing_d * 1.8), 0.14, maxf(1.0, sz.z - wing_d * 1.8)), 0.02, M_ROOF, Vector3(0, -hy + 0.38, 0), Vector3.ZERO, Vector3.ONE, false)
	# 后翼、左右侧翼满高；前翼带过街门洞
	raid._ibox(sb, Vector3(sz.x, sz.y, wing_d), 0.02, M_WALL, Vector3(0, 0, -hz + wing_d * 0.5))
	raid._ibox(sb, Vector3(sz.x, 0.20, wing_d + 0.18), 0.02, M_TRIM, Vector3(0, hy + 0.06, -hz + wing_d * 0.5))
	raid._ibox(sb, Vector3(maxf(0.8, sz.x - 0.28), 0.06, maxf(0.8, wing_d - 0.16)), 0.01, M_ROOF, Vector3(0, hy + 0.17, -hz + wing_d * 0.5), Vector3.ZERO, Vector3.ONE, false)
	var mid_span_z := maxf(0.8, sz.z - wing_d * 2.0)
	for sx_s in [-1.0, 1.0]:
		raid._ibox(sb, Vector3(wing_d, sz.y, mid_span_z - 0.02), 0.02, M_WALL, Vector3(sx_s * (hx - wing_d * 0.5), 0, 0))
		raid._ibox(sb, Vector3(wing_d + 0.18, 0.20, maxf(0.6, mid_span_z - 0.44)), 0.02, M_TRIM, Vector3(sx_s * (hx - wing_d * 0.5), hy + 0.06, 0))
		raid._ibox(sb, Vector3(maxf(0.8, wing_d - 0.16), 0.06, maxf(0.6, mid_span_z - 0.48)), 0.01, M_ROOF, Vector3(sx_s * (hx - wing_d * 0.5), hy + 0.17, 0), Vector3.ZERO, Vector3.ONE, false)
	var gate_w := clampf(sz.x * 0.24, 2.0, 3.0)
	var side_fx := maxf(1.2, (sz.x - gate_w) * 0.5)
	for sx_f in [-1.0, 1.0]:
		raid._ibox(sb, Vector3(side_fx, sz.y, wing_d), 0.02, M_WALL, Vector3(sx_f * (hx - side_fx * 0.5), 0, hz - wing_d * 0.5))
	var lintel_h := maxf(1.2, sz.y - 2.6)
	raid._ibox(sb, Vector3(gate_w - 0.02, lintel_h - 0.02, wing_d - 0.04), 0.02, M_WALL, Vector3(0, hy - lintel_h * 0.5 - 0.01, hz - wing_d * 0.5))
	raid._ibox(sb, Vector3(gate_w, 2.5, wing_d * 0.85), 0.01, A.paint(Color(0.03, 0.03, 0.035), 0.1, 0.9), Vector3(0, -hy + 1.25, hz - wing_d * 0.5), Vector3.ZERO, Vector3.ONE, false)
	raid._ibox(sb, Vector3(sz.x + 0.22, 0.20, wing_d + 0.22), 0.02, M_TRIM, Vector3(0, hy + 0.06, hz - wing_d * 0.5))
	# 外立面规则窗列
	var floors := maxi(2, int(sz.y / 2.1))
	var n_wx := maxi(3, int(sz.x / 2.3))
	for f in floors:
		var wy := -hy + 1.05 + float(f) * ((sz.y - 0.9) / float(floors))
		if wy > hy - 0.5:
			break
		for i in n_wx:
			var wx := -hx + (float(i) + 0.5) * sz.x / float(n_wx)
			raid._ibox(sb, Vector3(0.84, 0.92, 0.08), 0.01, M_WIN, Vector3(wx, wy, -hz - 0.03), Vector3.ZERO, Vector3.ONE, false)
			if f > 0 or absf(wx) > gate_w * 0.65:
				raid._ibox(sb, Vector3(0.84, 0.92, 0.08), 0.01, M_WIN, Vector3(wx, wy, hz + 0.03), Vector3.ZERO, Vector3.ONE, false)


## 4. 高压配电变电所（substation）：无窗防爆竖肋混凝土室 + 外部油浸主变散热片箱 + 陶瓷高压绝缘套管架 + 重型百叶防爆钢门
static func _substation(raid, p: Vector3, sz: Vector3, rot: float) -> void:
	var sb = raid._bldg_body(sz, p + Vector3(0, sz.y * 0.5, 0))
	sb.rotation.y = -rot
	var hx := sz.x * 0.5
	var hz := sz.z * 0.5
	var hy := sz.y * 0.5
	var M_CON := A.concrete(Color(0.42, 0.43, 0.41))
	var M_DARK := A.concrete(Color(0.28, 0.29, 0.28), false)
	var M_STEEL := A.corrugated(Color(0.24, 0.27, 0.29), 0.58, 0.36)
	var M_INS := A.paint(Color(0.48, 0.24, 0.16), 0.15, 0.35)
	var M_COP := A.paint(Color(0.62, 0.40, 0.22), 0.72, 0.42, {"rust": 0.35})
	var main_w := sz.x * 0.66
	# 左侧无窗高压开关室 + 右侧开放式主变压器防火墙隔间
	raid._ibox(sb, Vector3(sz.x + 0.24, 0.48, sz.z + 0.24), 0.03, M_DARK, Vector3(0, -hy + 0.24, 0))
	raid._ibox(sb, Vector3(main_w, sz.y, sz.z), 0.02, M_CON, Vector3(-hx + main_w * 0.5, 0, 0))
	raid._ibox(sb, Vector3(main_w + 0.20, 0.24, sz.z + 0.20), 0.02, M_DARK, Vector3(-hx + main_w * 0.5, hy + 0.10, 0))
	var n_rib := maxi(3, int(main_w / 1.5))
	for k in n_rib:
		var rx := -hx + 0.4 + float(k) * (main_w - 0.8) / float(maxi(1, n_rib - 1))
		for sd in [-1.0, 1.0]:
			raid._ibox(sb, Vector3(0.20, sz.y - 0.5, 0.18), 0.015, M_DARK, Vector3(rx, 0.1, sd * (hz + 0.05)))
	# 散热百叶钢门与黄黑高压警示带
	raid._ibox(sb, Vector3(minf(2.4, main_w * 0.48), minf(2.4, sz.y * 0.65), 0.14), 0.02, M_STEEL, Vector3(-hx + main_w * 0.5, -hy + 1.35, hz + 0.05))
	raid._ibox(sb, Vector3(main_w, 0.18, 0.08), 0.01, A.hazard(), Vector3(-hx + main_w * 0.5, -hy + 0.62, hz + 0.05), Vector3.ZERO, Vector3.ONE, false)
	# 右侧变压器油箱 + 散热片排 + 储油枕 + 6 根高压瓷瓶套管 + 屋顶母线龙门架
	var tx_x := hx - (sz.x - main_w) * 0.5
	var tx_w := maxf(1.4, (sz.x - main_w) * 0.72)
	var tx_h := sz.y * 0.58
	raid._ibox(sb, Vector3(tx_w, tx_h, sz.z * 0.64), 0.03, M_STEEL, Vector3(tx_x, -hy + 0.48 + tx_h * 0.5, 0))
	for fz in [-0.24, 0.0, 0.24]:
		raid._ibox(sb, Vector3(tx_w + 0.34, tx_h * 0.78, 0.14), 0.01, M_DARK, Vector3(tx_x, -hy + 0.48 + tx_h * 0.5, fz * sz.z))
	raid._imesh(sb, A.cyl(0.32, sz.z * 0.52, 0.32, 12), M_STEEL, Vector3(tx_x, -hy + 0.48 + tx_h + 0.42, 0), Vector3(90, 0, 0))
	for bz in [-0.22, 0.0, 0.22]:
		for bx_i in [-0.24, 0.24]:
			raid._imesh(sb, A.cyl(0.09, 0.92, 0.14, 10), M_INS, Vector3(tx_x + bx_i * tx_w, -hy + 0.48 + tx_h + 0.46, bz * sz.z))
			raid._imesh(sb, A.cyl(0.03, 0.35, 0.03, 6), M_COP, Vector3(tx_x + bx_i * tx_w, -hy + 0.48 + tx_h + 1.05, bz * sz.z), Vector3.ZERO, Vector3.ONE, false)
	for gx_p in [-hx + 0.45, -hx + main_w - 0.45]:
		raid._ibox(sb, Vector3(0.16, 1.85, 0.16), 0.01, M_STEEL, Vector3(gx_p, hy + 0.95, 0))
	raid._ibox(sb, Vector3(main_w - 0.6, 0.16, 0.20), 0.01, M_STEEL, Vector3(-hx + main_w * 0.5, hy + 1.82, 0))
	A.stencil(sb, "HV-110KV", Vector3(-hx + main_w * 0.5, 0.45, hz + 0.09), Vector3.ZERO, 0.018, Color(0.92, 0.78, 0.28, 0.72))


## 5. 联排排屋（terrace）：3~5 开间砖混工人联排住宅 + 凸出屋面的砖砌防火墙山墙隔断 + 独立门阶与并列烟囱群
static func _terrace(raid, p: Vector3, sz: Vector3, rot: float) -> void:
	var c0: Color = [Color(0.48, 0.37, 0.31), Color(0.52, 0.46, 0.40), Color(0.44, 0.39, 0.35)][raid.rng.randi() % 3]
	var sb = raid._bldg_body(sz, p + Vector3(0, sz.y * 0.5, 0))
	sb.rotation.y = -rot
	var hx := sz.x * 0.5
	var hz := sz.z * 0.5
	var hy := sz.y * 0.5
	var M_WALL := A.brick(c0)
	var M_WALL2 := A.brick(c0.darkened(0.10))
	var M_BRICK := A.brick(Color(0.38, 0.25, 0.20), 0.30)
	var M_TRIM := A.concrete(c0.lightened(0.14), false)
	var M_WIN := A.window_mat(0.18, Vector2(0.46, 0.50))
	var M_DOOR := A.corrugated(Color(0.26, 0.19, 0.14), 0.35, 0.48)
	var roof_c: Color = [Color(0.22, 0.25, 0.28), Color(0.32, 0.21, 0.17)][raid.rng.randi() % 2]
	var M_ROOF := A.roof_mat(roof_c, 0.32, true)
	var n_units := clampi(roundi(sz.x / 3.8), 2, 5)
	var uw := sz.x / float(n_units)
	var rh := minf(2.0, sz.z * 0.28)
	raid._ibox(sb, Vector3(sz.x + 0.24, 0.42, sz.z + 0.24), 0.03, M_BRICK, Vector3(0, -hy + 0.21, 0))
	# 双坡贯通屋面（沿 X 轴延展）
	var outline := PackedVector2Array([Vector2(-0.5, 0.0), Vector2(0.0, 1.0), Vector2(0.5, 0.0)])
	raid._imesh(sb, A.prism(outline, 1.0, 0.01), M_ROOF, Vector3(0, hy, 0), Vector3(0, 90, 0), Vector3(sz.z + 0.36, rh, sz.x + 0.24))
	# 分户错色墙体 + 高出屋脊的分户砖砌防火墙 + 每户门阶与上下窗 + 砖烟囱
	for u in n_units + 1:
		var px := -hx + float(u) * uw
		raid._ibox(sb, Vector3(0.26, sz.y + 0.25, sz.z + 0.18), 0.02, M_BRICK, Vector3(px, 0.10, 0))
		raid._imesh(sb, A.prism(outline, 1.0, 0.01), M_BRICK, Vector3(px, hy + 0.16, 0), Vector3(0, 90, 0), Vector3(sz.z + 0.44, rh + 0.18, 0.28))
		if u < n_units:
			var ux := px + uw * 0.5
			raid._ibox(sb, Vector3(uw - 0.06, sz.y, sz.z), 0.01, M_WALL if u % 2 == 0 else M_WALL2, Vector3(ux, 0, 0))
			var door_x := ux - uw * 0.22
			var win_x := ux + uw * 0.20
			raid._ibox(sb, Vector3(0.88, 1.92, 0.10), 0.01, M_DOOR, Vector3(door_x, -hy + 0.98, hz + 0.04), Vector3.ZERO, Vector3.ONE, false)
			raid._ibox(sb, Vector3(1.16, 0.22, 0.62), 0.02, M_TRIM, Vector3(door_x, -hy + 0.11, hz + 0.30))
			raid._ibox(sb, Vector3(1.18, 0.12, 0.56), 0.02, M_BRICK, Vector3(door_x, -hy + 2.02, hz + 0.26), Vector3(8, 0, 0))
			raid._ibox(sb, Vector3(0.96, 0.98, 0.08), 0.01, M_WIN, Vector3(win_x, -hy + 1.25, hz + 0.03), Vector3.ZERO, Vector3.ONE, false)
			if sz.y > 3.6:
				for wx_u in [door_x, win_x]:
					raid._ibox(sb, Vector3(0.86, 0.92, 0.08), 0.01, M_WIN, Vector3(wx_u, hy - 1.05, hz + 0.03), Vector3.ZERO, Vector3.ONE, false)
					raid._ibox(sb, Vector3(0.86, 0.92, 0.08), 0.01, M_WIN, Vector3(wx_u, hy - 1.05, -hz - 0.03), Vector3.ZERO, Vector3.ONE, false)
			raid._ibox(sb, Vector3(0.56, 1.15, 0.56), 0.02, M_BRICK, Vector3(px + 0.32, hy + rh * 0.68, -hz * 0.18))


## 6. 双拼住宅小楼（duplex）：L 形错落双山墙主副跨 + 单坡侧附属工具间 + 双烟道与铁艺雨搭
static func _duplex(raid, p: Vector3, sz: Vector3, rot: float) -> void:
	var c: Color = [Color(0.55, 0.50, 0.44), Color(0.49, 0.43, 0.37), Color(0.52, 0.51, 0.47)][raid.rng.randi() % 3]
	var sb = raid._bldg_body(sz, p + Vector3(0, sz.y * 0.5, 0))
	sb.rotation.y = -rot
	var hx := sz.x * 0.5
	var hz := sz.z * 0.5
	var hy := sz.y * 0.5
	var M_WALL := A.brick(c) if raid.rng.randf() < 0.45 else A.concrete(c)
	var M_DARK := A.concrete(c.darkened(0.34), false)
	var M_TRIM := A.concrete(c.lightened(0.14), false)
	var M_ROOF := A.roof_mat(Color(0.28, 0.22, 0.19), 0.35, true)
	var M_WIN := A.window_mat(0.18, Vector2(0.48, 0.48))
	var main_w := sz.x * 0.68
	var side_w := sz.x - main_w
	var side_h := sz.y * 0.72
	# 主楼 + 矮一层的侧拼工具车库跨
	raid._ibox(sb, Vector3(sz.x + 0.24, 0.40, sz.z + 0.24), 0.03, M_DARK, Vector3(0, -hy + 0.20, 0))
	raid._ibox(sb, Vector3(main_w, sz.y, sz.z), 0.02, M_WALL, Vector3(-hx + main_w * 0.5, 0, 0))
	raid._ibox(sb, Vector3(side_w + 0.1, side_h, sz.z * 0.88), 0.02, A.corrugated(c.darkened(0.14), 0.38, 0.34), Vector3(hx - side_w * 0.5, -hy + side_h * 0.5, -hz * 0.05))
	var outline := PackedVector2Array([Vector2(-0.5, 0.0), Vector2(0.0, 1.0), Vector2(0.5, 0.0)])
	var rh := minf(1.85, main_w * 0.30)
	raid._imesh(sb, A.prism(outline, 1.0, 0.01), M_ROOF, Vector3(-hx + main_w * 0.5, hy, 0), Vector3.ZERO, Vector3(main_w + 0.36, rh, sz.z + 0.34))
	var shed_outline := PackedVector2Array([Vector2(-0.5, 0.0), Vector2(-0.5, 1.0), Vector2(0.5, 0.15), Vector2(0.5, 0.0)])
	raid._imesh(sb, A.prism(shed_outline, 1.0, 0.01), M_ROOF, Vector3(hx - side_w * 0.5, -hy + side_h, -hz * 0.05), Vector3.ZERO, Vector3(side_w + 0.28, 0.85, sz.z * 0.90))
	# 窗户、车库铁门与双烟囱
	for sd in [-1.0, 1.0]:
		for k in 2:
			var wx := -hx + (float(k) + 0.5) * main_w * 0.5
			raid._ibox(sb, Vector3(0.95, 0.95, 0.08), 0.01, M_WIN, Vector3(wx, 0.25, sd * (hz + 0.03)), Vector3.ZERO, Vector3.ONE, false)
			raid._ibox(sb, Vector3(1.08, 0.09, 0.15), 0.01, M_TRIM, Vector3(wx, -0.26, sd * (hz + 0.05)), Vector3.ZERO, Vector3.ONE, false)
	raid._ibox(sb, Vector3(maxf(1.2, side_w * 0.72), side_h * 0.68, 0.10), 0.01, A.corrugated(Color(0.20, 0.22, 0.24), 0.45, 0.44), Vector3(hx - side_w * 0.5, -hy + side_h * 0.36, hz * 0.88 - hz * 0.05), Vector3.ZERO, Vector3.ONE, false)
	raid._ibox(sb, Vector3(0.62, 1.35, 0.62), 0.02, A.brick(Color(0.36, 0.24, 0.19), 0.32), Vector3(-hx + main_w * 0.30, hy + rh * 0.65, 0.25))


## 7. 外廊式工人筒子楼（tenement）：沧桑板式高层宿舍 + 贯通钢混悬挑外走道与钢护栏 + 端部外挂楼梯塔 + 屋顶水塔
static func _tenement(raid, p: Vector3, sz: Vector3, rot: float) -> void:
	var c: Color = [Color(0.46, 0.44, 0.40), Color(0.43, 0.39, 0.35), Color(0.40, 0.42, 0.41)][raid.rng.randi() % 3]
	var sb = raid._bldg_body(sz, p + Vector3(0, sz.y * 0.5, 0))
	sb.rotation.y = -rot
	var hx := sz.x * 0.5
	var hz := sz.z * 0.5
	var hy := sz.y * 0.5
	var M_WALL := A.brick(c) if raid.rng.randf() < 0.55 else A.concrete(c)
	var M_DARK := A.concrete(c.darkened(0.36), false)
	var M_STEEL := A.corrugated(Color(0.22, 0.24, 0.25), 0.65, 0.38)
	var M_WIN := A.window_mat(0.16, Vector2(0.44, 0.58))
	raid._ibox(sb, sz, 0.02, M_WALL)
	raid._ibox(sb, Vector3(sz.x + 0.26, 0.56, sz.z + 0.26), 0.03, M_DARK, Vector3(0, -hy + 0.28, 0))
	# 一端突出混凝土楼梯塔
	var st_w := minf(2.4, sz.x * 0.24)
	raid._ibox(sb, Vector3(st_w, sz.y + 1.5, 0.58), 0.03, M_DARK, Vector3(-hx + st_w * 0.5 + 0.2, 0.72, hz + 0.26))
	var floors := maxi(2, int(sz.y / 2.25))
	var gal_w := maxf(1.5, sz.x - st_w - 0.5)
	var gal_cx := hx - gal_w * 0.5 - 0.15
	for f in floors:
		var fy := -hy + 0.65 + float(f) * ((sz.y - 0.85) / float(floors))
		if fy > hy - 0.65:
			break
		if f >= 1:
			# 贯通悬挑外走廊楼板（外挑 0.68m <= 0.85m）+ 钢横杆护栏 + 竖撑
			raid._ibox(sb, Vector3(gal_w, 0.14, 0.68), 0.02, M_DARK, Vector3(gal_cx, fy - 0.36, hz + 0.32))
			raid._ibox(sb, Vector3(gal_w, 0.54, 0.06), 0.01, M_STEEL, Vector3(gal_cx, fy - 0.04, hz + 0.62), Vector3.ZERO, Vector3.ONE, false)
		var n_doors := maxi(2, int(gal_w / 2.35))
		for d_i in n_doors:
			var dx := gal_cx - gal_w * 0.5 + (float(d_i) + 0.5) * gal_w / float(n_doors)
			raid._ibox(sb, Vector3(0.76, 1.32, 0.08), 0.01, M_WIN, Vector3(dx, fy + 0.28, hz + 0.03), Vector3.ZERO, Vector3.ONE, false)
			raid._ibox(sb, Vector3(0.92, 0.88, 0.08), 0.01, M_WIN, Vector3(dx, fy + 0.25, -hz - 0.03), Vector3.ZERO, Vector3.ONE, false)
	# 女儿墙与屋顶高架圆柱水箱
	raid._ibox(sb, Vector3(sz.x + 0.20, 0.26, sz.z + 0.20), 0.02, M_DARK, Vector3(0, hy + 0.12, 0))
	raid._ibox(sb, Vector3(sz.x - 0.24, 0.06, sz.z - 0.24), 0.02, A.tar_roof(Color(0.25, 0.26, 0.28)), Vector3(0, hy + 0.255, 0), Vector3.ZERO, Vector3.ONE, false)
	raid._imesh(sb, A.cyl(0.72, 1.35, 0.72, 14), M_STEEL, Vector3(hx * 0.45, hy + 1.15, -hz * 0.20))
	for lx in [-0.45, 0.45]:
		raid._ibox(sb, Vector3(0.08, 0.65, 0.75), 0.01, M_STEEL, Vector3(hx * 0.45 + lx, hy + 0.45, -hz * 0.20), Vector3.ZERO, Vector3.ONE, false)


## 8. 锯齿天窗铸造车间（foundry）：红砖与钢骨混筑厂房 + 多跨连续北向锯齿采光顶 + 旋风除尘器与高耸排烟铁囱
static func _foundry(raid, p: Vector3, sz: Vector3, rot: float) -> void:
	var c: Color = [Color(0.39, 0.27, 0.22), Color(0.34, 0.31, 0.28), Color(0.31, 0.34, 0.36)][raid.rng.randi() % 3]
	var sb = raid._bldg_body(sz, p + Vector3(0, sz.y * 0.5, 0))
	sb.rotation.y = -rot
	var hx := sz.x * 0.5
	var hz := sz.z * 0.5
	var hy := sz.y * 0.5
	var M_WALL := A.brick(c, 0.26)
	var M_STEEL := A.metal(Color(0.18, 0.19, 0.21))
	var M_DOOR := A.corrugated(Color(0.20, 0.21, 0.23), 0.65, 0.34)
	var M_ROOF := A.roof_mat(Color(0.24, 0.22, 0.21), 0.62, true)
	var M_GLS := A.glass(Color(0.24, 0.36, 0.42))
	raid._ibox(sb, sz, 0.02, M_WALL)
	raid._ibox(sb, Vector3(sz.x + 0.26, 0.85, sz.z + 0.26), 0.03, A.concrete(Color(0.30, 0.29, 0.27), false), Vector3(0, -hy + 0.425, 0))
	# 外露重型工字钢排架柱
	var n_col := maxi(3, int(sz.x / 2.6))
	for k in n_col + 1:
		var cx := -hx + float(k) * sz.x / float(n_col)
		for sd in [-1.0, 1.0]:
			raid._ibox(sb, Vector3(0.24, sz.y + 0.12, 0.26), 0.02, M_STEEL, Vector3(cx, 0.04, sd * (hz + 0.08)))
	# 多跨连续锯齿天窗屋顶（3~4 道平行锯齿脊，63° 俯视工业辨识度极强）
	var n_saw := clampi(roundi(sz.z / 3.2), 2, 4)
	var saw_d := sz.z / float(n_saw)
	var saw_h := clampf(saw_d * 0.34, 0.85, 1.35)
	var saw_prof := PackedVector2Array([Vector2(-0.5, 0.0), Vector2(-0.28, 1.0), Vector2(0.5, 0.0)])
	for s_i in n_saw:
		var sz_c := -hz + (float(s_i) + 0.5) * saw_d
		raid._imesh(sb, A.prism(saw_prof, 1.0, 0.01), M_ROOF, Vector3(0, hy, sz_c), Vector3(0, 90, 0), Vector3(saw_d + 0.08, saw_h, sz.x + 0.22))
		raid._ibox(sb, Vector3(sz.x * 0.90, saw_h * 0.62, 0.08), 0.01, M_GLS, Vector3(0, hy + saw_h * 0.44, sz_c - saw_d * 0.36), Vector3(-12, 0, 0), Vector3.ONE, false)
	# 铸造车间高大门洞 + 侧置旋风除尘锥筒与高烟囱
	var dw := minf(4.2, sz.x * 0.45)
	var dh := sz.y * 0.72
	raid._ibox(sb, Vector3(dw, dh, 0.14), 0.02, M_DOOR, Vector3(-hx * 0.22, -hy + dh * 0.5, hz + 0.05))
	raid._ibox(sb, Vector3(dw + 0.3, 0.18, 0.55), 0.02, A.hazard(), Vector3(-hx * 0.22, -hy + dh + 0.14, hz + 0.26))
	var cyc_x := hx - 0.85
	raid._imesh(sb, A.cyl(0.62, 1.65, 0.62, 14), M_STEEL, Vector3(cyc_x, hy + 0.45, hz * 0.35))
	raid._imesh(sb, A.cyl(0.16, 1.10, 0.62, 14), M_STEEL, Vector3(cyc_x, hy - 0.92, hz * 0.35))
	raid._imesh(sb, A.cyl(0.26, 4.4, 0.38, 14), M_STEEL, Vector3(cyc_x, hy + 2.2, -hz * 0.32))
	raid._imesh(sb, A.cyl(0.34, 0.18, 0.30, 14), A.hazard(), Vector3(cyc_x, hy + 4.3, -hz * 0.32))


## 9. 化工分馏车间（chem_plant）：防爆工艺厂房 + 钢构管廊架 + 双立式不锈钢分馏塔 + 卧式压力储罐与检修盘梯
static func _chem_plant(raid, p: Vector3, sz: Vector3, rot: float) -> void:
	var sb = raid._bldg_body(sz, p + Vector3(0, sz.y * 0.5, 0))
	sb.rotation.y = -rot
	var hx := sz.x * 0.5
	var hz := sz.z * 0.5
	var hy := sz.y * 0.5
	var M_HALL := A.corrugated(Color(0.34, 0.38, 0.39), 0.52, 0.30)
	var M_STEEL := A.metal(Color(0.18, 0.20, 0.22))
	var M_TANK := A.paint(Color(0.58, 0.59, 0.56), 0.62, 0.44, {"rust": 0.45, "wear": 0.42, "panel_scale": 0.9})
	var M_PIPE := A.paint(Color(0.56, 0.44, 0.18), 0.52, 0.50, {"rust": 0.48})
	var hall_w := sz.x * 0.56
	raid._ibox(sb, Vector3(sz.x + 0.20, 0.46, sz.z + 0.20), 0.03, A.concrete(Color(0.34, 0.34, 0.32), false), Vector3(0, -hy + 0.23, 0))
	# 左半工艺泵房 + 右半钢桁架反应塔装置区
	raid._ibox(sb, Vector3(hall_w, sz.y * 0.84, sz.z * 0.88), 0.02, M_HALL, Vector3(-hx + hall_w * 0.5, -hy + sz.y * 0.42, 0))
	raid._ibox(sb, Vector3(hall_w + 0.18, 0.18, sz.z * 0.90), 0.02, M_STEEL, Vector3(-hx + hall_w * 0.5, -hy + sz.y * 0.84, 0))
	var rx := hx - (sz.x - hall_w) * 0.5
	var rw := maxf(1.8, (sz.x - hall_w) * 0.82)
	for lx in [-0.42, 0.42]:
		for lz in [-0.36, 0.36]:
			raid._ibox(sb, Vector3(0.18, sz.y + 1.6, 0.18), 0.01, M_STEEL, Vector3(rx + lx * rw, 0.8, lz * sz.z))
	for lv in [0.0, hy * 0.75]:
		raid._ibox(sb, Vector3(rw + 0.16, 0.14, sz.z * 0.78), 0.01, M_STEEL, Vector3(rx, lv, 0))
	# 双立式精馏塔 + 顶部封头 + 连接横管 + 泵房顶卧式回流罐
	for tz_s in [-0.22, 0.24]:
		var col_r := clampf(rw * 0.24, 0.48, 0.85)
		var col_h := sz.y + (2.6 if tz_s < 0 else 1.4)
		raid._imesh(sb, A.cyl(col_r, col_h, col_r, 16), M_TANK, Vector3(rx, -hy + col_h * 0.5 + 0.3, tz_s * sz.z))
		raid._imesh(sb, A.sphere(col_r, -1, 14), M_TANK, Vector3(rx, -hy + col_h + 0.3, tz_s * sz.z))
		for ring_y in [0.35, 0.72]:
			raid._imesh(sb, A.torus(col_r - 0.02, col_r + 0.10, 16), M_STEEL, Vector3(rx, -hy + col_h * ring_y, tz_s * sz.z), Vector3.ZERO, Vector3(1, 0.45, 1), false)
	raid._imesh(sb, A.cyl(0.16, sz.x * 0.55, 0.16, 10), M_PIPE, Vector3(0, hy * 0.78, 0), Vector3(0, 0, 90))
	raid._imesh(sb, A.cyl(0.56, sz.z * 0.56, 0.56, 14), M_TANK, Vector3(-hx + hall_w * 0.48, -hy + sz.y * 0.84 + 0.68, 0), Vector3(90, 0, 0))


## 10. 港区保温冷库（cold_store）：无窗厚重聚氨酯夹芯金属板外墙 + 密封防撞装卸冷链口 + 屋顶大型蒸发式氨冷凝器阵列
static func _cold_store(raid, p: Vector3, sz: Vector3, rot: float) -> void:
	var c: Color = [Color(0.52, 0.56, 0.58), Color(0.46, 0.51, 0.55), Color(0.55, 0.55, 0.52)][raid.rng.randi() % 3]
	var sb = raid._bldg_body(sz, p + Vector3(0, sz.y * 0.5, 0))
	sb.rotation.y = -rot
	var hx := sz.x * 0.5
	var hz := sz.z * 0.5
	var hy := sz.y * 0.5
	var M_PANEL := A.corrugated(c, 0.30, 0.34)
	var M_TRIM := A.paint(Color(0.20, 0.30, 0.38), 0.45, 0.55, {"wear": 0.45, "rust": 0.38, "panel_scale": 1.2})
	var M_BASE := A.concrete(Color(0.38, 0.38, 0.36), false)
	var M_SEAL := A.rubber()
	var M_STEEL := A.metal(Color(0.22, 0.24, 0.26))
	raid._ibox(sb, sz, 0.03, M_PANEL)
	raid._ibox(sb, Vector3(sz.x + 0.24, 0.95, sz.z + 0.24), 0.03, M_BASE, Vector3(0, -hy + 0.475, 0))
	raid._ibox(sb, Vector3(sz.x + 0.20, 0.28, sz.z + 0.20), 0.02, M_TRIM, Vector3(0, hy - 0.10, 0))
	for sx_c in [-1.0, 1.0]:
		for sz_c in [-1.0, 1.0]:
			raid._ibox(sb, Vector3(0.32, sz.y - 0.28, 0.32), 0.02, M_TRIM, Vector3(sx_c * (hx - 0.06), 0.04, sz_c * (hz - 0.06)))
	# 双冷链气密装卸门封口（橡胶门封垫 + 0.72m 内敛月台）
	var n_docks := 2 if sz.x >= 8.5 else 1
	for d_i in n_docks:
		var dx := (float(d_i) - float(n_docks - 1) * 0.5) * 3.6
		raid._ibox(sb, Vector3(2.35, 2.55, 0.34), 0.03, M_SEAL, Vector3(dx, -hy + 2.15, hz + 0.16))
		raid._ibox(sb, Vector3(1.85, 2.15, 0.12), 0.02, M_STEEL, Vector3(dx, -hy + 2.05, hz + 0.28), Vector3.ZERO, Vector3.ONE, false)
		raid._ibox(sb, Vector3(2.65, 0.85, 0.72), 0.03, M_BASE, Vector3(dx, -hy + 0.425, hz + 0.36))
	# 屋顶氨制冷蒸发式冷凝机组 + 结霜输冷管桥
	var n_cond := maxi(2, int(sz.x / 4.2))
	for k in n_cond:
		var cx := -hx * 0.55 + float(k) * (sz.x * 0.55) / float(maxi(1, n_cond - 1))
		raid._ibox(sb, Vector3(1.95, 1.28, 1.45), 0.03, M_STEEL, Vector3(cx, hy + 0.64, -hz * 0.18))
		for fx_c in [-0.48, 0.48]:
			raid._imesh(sb, A.cyl(0.38, 0.22, 0.42, 12), M_TRIM, Vector3(cx + fx_c, hy + 1.35, -hz * 0.18))
	raid._imesh(sb, A.cyl(0.14, sz.x * 0.78, 0.14, 10), A.paint(Color(0.78, 0.82, 0.85), 0.25, 0.65), Vector3(0, hy + 0.32, hz * 0.26), Vector3(0, 0, 90))
	A.stencil(sb, "COLD-04", Vector3(-hx * 0.55, hy * 0.38, hz + 0.08), Vector3.ZERO, 0.02, Color(0.84, 0.90, 0.95, 0.68))


## 11. 铁路内燃机车检修库（loco_shed）：拱顶双股道机务车库 + 高耸通风天窗气楼 + 排烟风帽序列 + 砖钢混立柱
static func _loco_shed(raid, p: Vector3, sz: Vector3, rot: float) -> void:
	var use_br: bool = raid.rng.randi() % 2 == 0
	var c := Color(0.42, 0.29, 0.22) if use_br else Color(0.33, 0.35, 0.37)
	var sb = raid._bldg_body(sz, p + Vector3(0, sz.y * 0.5, 0))
	sb.rotation.y = -rot
	var hx := sz.x * 0.5
	var hz := sz.z * 0.5
	var hy := sz.y * 0.5
	var M_WALL := A.brick(c, 0.26) if use_br else A.corrugated(c, 0.52, 0.30)
	var M_DARK := A.concrete(c.darkened(0.34), false)
	var M_STEEL := A.corrugated(Color(0.18, 0.19, 0.21), 0.55, 0.36)
	var M_ROOF := A.roof_mat(Color(0.24, 0.25, 0.27), 0.58, true)
	var M_GLS := A.glass(Color(0.25, 0.38, 0.44))
	raid._ibox(sb, sz, 0.02, M_WALL)
	raid._ibox(sb, Vector3(sz.x + 0.24, 0.75, sz.z + 0.24), 0.03, M_DARK, Vector3(0, -hy + 0.375, 0))
	# 双坡屋面 + 贯通纵向高侧采光通风气楼 + 机车排烟风筒列
	var outline := PackedVector2Array([Vector2(-0.5, 0.0), Vector2(0.0, 1.0), Vector2(0.5, 0.0)])
	var rh := minf(1.45, sz.x * 0.16)
	raid._imesh(sb, A.prism(outline, 1.0, 0.01), M_ROOF, Vector3(0, hy, 0), Vector3.ZERO, Vector3(sz.x + 0.30, rh, sz.z + 0.30))
	raid._ibox(sb, Vector3(sz.x * 0.38, 0.95, sz.z * 0.82), 0.02, M_STEEL, Vector3(0, hy + rh * 0.72 + 0.35, 0))
	for sd_m in [-1.0, 1.0]:
		raid._ibox(sb, Vector3(0.08, 0.56, sz.z * 0.78), 0.01, M_GLS, Vector3(sd_m * sz.x * 0.195, hy + rh * 0.72 + 0.38, 0), Vector3.ZERO, Vector3.ONE, false)
	raid._ibox(sb, Vector3(sz.x * 0.44, 0.14, sz.z * 0.86), 0.02, M_ROOF, Vector3(0, hy + rh * 0.72 + 0.88, 0))
	for sj in 3:
		var jz := (float(sj) - 1.0) * sz.z * 0.28
		raid._imesh(sb, A.cyl(0.20, 1.05, 0.24, 10), A.metal(Color(0.18, 0.19, 0.20)), Vector3(0, hy + rh * 0.72 + 1.38, jz))
	# 正面双股道高拱形机车库大门 + 黄黑限界框
	var n_tracks := 2 if sz.x >= 7.6 else 1
	for t_i in n_tracks:
		var tx := (float(t_i) - float(n_tracks - 1) * 0.5) * (sz.x * 0.46)
		var tw := minf(3.2, sz.x / float(n_tracks) - 1.2)
		var th := sz.y * 0.78
		raid._ibox(sb, Vector3(tw + 0.26, th, 0.16), 0.02, A.hazard(), Vector3(tx, -hy + th * 0.5, hz + 0.05))
		raid._ibox(sb, Vector3(tw - 0.08, th - 0.16, 0.18), 0.02, M_STEEL, Vector3(tx, -hy + (th - 0.16) * 0.5, hz + 0.09))
	# 侧墙高窄工业采光长窗
	var n_sw := maxi(3, int(sz.z / 2.8))
	for i in n_sw:
		var wz := -hz + (float(i) + 0.5) * sz.z / float(n_sw)
		for sx_s in [-1.0, 1.0]:
			raid._ibox(sb, Vector3(0.08, sz.y * 0.54, 1.12), 0.01, M_GLS, Vector3(sx_s * (hx + 0.03), 0.28, wz), Vector3.ZERO, Vector3.ONE, false)


## 12. 战术防炮击指挥掩体（command_bunker）：大倾角抗弹钢筋混凝土斜墙 + 阶梯防跳弹观察射孔 + 装甲防爆顶板 + 相控阵通讯桅杆
static func _command_bunker(raid, p: Vector3, sz: Vector3, rot: float) -> void:
	var sb = raid._bldg_body(sz, p + Vector3(0, sz.y * 0.5, 0))
	sb.rotation.y = -rot
	var hx := sz.x * 0.5
	var hz := sz.z * 0.5
	var hy := sz.y * 0.5
	var M_CON := A.concrete(Color(0.41, 0.42, 0.39))
	var M_CAP := A.concrete(Color(0.32, 0.33, 0.30), false)
	var M_ARM := A.paint(Color(0.24, 0.27, 0.22), 0.52, 0.60, {"rust": 0.45, "wear": 0.52, "panel_scale": 1.3})
	var M_DARK := A.metal(Color(0.14, 0.15, 0.16))
	# 收分抗弹主堡体 + 阶梯加厚防钻地弹顶盖 + 四角斜扶壁肋
	A.add(sb, A.bevel_box(sz, 0.26, 0.86), M_CON, Vector3.ZERO)
	raid._ibox(sb, Vector3(sz.x + 0.42, 0.55, sz.z + 0.42), 0.04, M_CAP, Vector3(0, -hy + 0.275, 0))
	raid._ibox(sb, Vector3(sz.x + 0.36, 0.52, sz.z + 0.36), 0.06, M_CAP, Vector3(0, hy + 0.18, 0))
	for sx_b in [-1.0, 1.0]:
		for sz_b in [-1.0, 1.0]:
			raid._ibox(sb, Vector3(0.55, sz.y * 0.85, 0.62), 0.03, M_CAP, Vector3(sx_b * (hx - 0.22), -hy * 0.12, sz_b * (hz + 0.12)), Vector3(sz_b * -12.0, 0, 0))
	# 正面通长装甲观察窄缝 + 防爆气密双扇门
	raid._ibox(sb, Vector3(sz.x * 0.68, 0.58, 0.32), 0.03, M_ARM, Vector3(0, hy * 0.36, hz + 0.08))
	raid._ibox(sb, Vector3(sz.x * 0.58, 0.22, 0.36), 0.01, A.window_mat(0.35, Vector2(0.62, 0.24)), Vector3(0, hy * 0.34, hz + 0.12), Vector3.ZERO, Vector3.ONE, false)
	raid._ibox(sb, Vector3(1.95, 2.10, 0.24), 0.02, M_DARK, Vector3(0, -hy + 1.08, -hz - 0.06))
	# 顶部战术雷达天线罩、装甲换气塔与桁架通讯桅杆
	raid._imesh(sb, A.sphere(0.95, 1.1, 18), A.paint(Color(0.54, 0.55, 0.50), 0.2, 0.65, {"panel_scale": 1.4}), Vector3(-hx * 0.36, hy + 0.42, -hz * 0.18))
	raid._ibox(sb, Vector3(1.45, 0.88, 1.45), 0.03, M_ARM, Vector3(hx * 0.34, hy + 0.82, hz * 0.15))
	raid._imesh(sb, A.cyl(0.08, 3.6, 0.14, 8), M_DARK, Vector3(hx * 0.34, hy + 2.8, -hz * 0.25))
	raid._ibox(sb, Vector3(1.65, 0.42, 0.16), 0.02, M_ARM, Vector3(hx * 0.34, hy + 4.2, -hz * 0.25), Vector3(0, 28, 0))
	A.stencil(sb, "CMD-HQ", Vector3(-hx * 0.52, -hy + 1.25, hz + 0.14), Vector3.ZERO, 0.022, Color(0.88, 0.84, 0.66, 0.72))


## 13. 谷仓与镀锌钢板立筒仓组合（silo_barn）：折线形双坡红木谷仓 + 双联镀锌波纹钢圆筒粮仓与锥顶绞龙提升机
static func _silo_barn(raid, p: Vector3, sz: Vector3, rot: float) -> void:
	var sb = raid._bldg_body(sz, p + Vector3(0, sz.y * 0.5, 0))
	sb.rotation.y = -rot
	var hx := sz.x * 0.5
	var hz := sz.z * 0.5
	var hy := sz.y * 0.5
	var M_BARN := A.corrugated(Color(0.46, 0.24, 0.17), 0.45, 0.34)
	var M_TRIM := A.paint(Color(0.66, 0.63, 0.56), 0.1, 0.85, {"wear": 0.52})
	var M_GALV := A.corrugated(Color(0.60, 0.62, 0.61), 0.32, 0.38)
	var M_ROOF := A.roof_mat(Color(0.25, 0.27, 0.29), 0.48, true)
	var M_BASE := A.concrete(Color(0.40, 0.39, 0.36), false)
	var barn_w := sz.x * 0.64
	var silo_x := hx - (sz.x - barn_w) * 0.5
	var silo_r := clampf(minf((sz.x - barn_w) * 0.44, sz.z * 0.21), 1.15, 2.05)
	raid._ibox(sb, Vector3(sz.x + 0.20, 0.42, sz.z + 0.20), 0.03, M_BASE, Vector3(0, -hy + 0.21, 0))
	# 折线曼萨德/双折坡红谷仓（Gambrel roof）+ 白色交叉木筋大门
	raid._ibox(sb, Vector3(barn_w, sz.y * 0.82, sz.z * 0.90), 0.02, M_BARN, Vector3(-hx + barn_w * 0.5, -hy + sz.y * 0.41, 0))
	var gambrel := PackedVector2Array([Vector2(-0.5, 0.0), Vector2(-0.34, 0.68), Vector2(0.0, 1.0), Vector2(0.34, 0.68), Vector2(0.5, 0.0)])
	var gr_h := minf(2.4, barn_w * 0.34)
	raid._imesh(sb, A.prism(gambrel, 1.0, 0.01), M_ROOF, Vector3(-hx + barn_w * 0.5, -hy + sz.y * 0.82, 0), Vector3.ZERO, Vector3(barn_w + 0.28, gr_h, sz.z * 0.94))
	var dw := minf(2.8, barn_w * 0.52)
	var dh := sz.y * 0.62
	raid._ibox(sb, Vector3(dw, dh, 0.10), 0.01, M_BARN, Vector3(-hx + barn_w * 0.5, -hy + dh * 0.5 + 0.2, hz * 0.90 + 0.04), Vector3.ZERO, Vector3.ONE, false)
	raid._ibox(sb, Vector3(dw + 0.16, 0.12, 0.12), 0.01, M_TRIM, Vector3(-hx + barn_w * 0.5, -hy + dh + 0.22, hz * 0.90 + 0.05), Vector3.ZERO, Vector3.ONE, false)
	# 右侧双联镀锌波纹钢圆筒立筒粮仓 + 锥顶 + 斜向输粮绞龙管
	var silo_h := sz.y + 2.4
	for sz_s in [-0.24, 0.24]:
		var sp := Vector3(silo_x, -hy + 0.42 + silo_h * 0.5, sz_s * sz.z)
		raid._imesh(sb, A.cyl(silo_r, silo_h, silo_r, 18), M_GALV, sp)
		raid._imesh(sb, A.cyl(0.18, silo_r * 0.58, silo_r + 0.06, 18), M_ROOF, Vector3(silo_x, -hy + 0.42 + silo_h + silo_r * 0.29, sz_s * sz.z))
		for ry_i in [0.28, 0.56, 0.84]:
			raid._imesh(sb, A.torus(silo_r - 0.02, silo_r + 0.06, 18), M_ROOF, Vector3(silo_x, -hy + 0.42 + silo_h * ry_i, sz_s * sz.z), Vector3.ZERO, Vector3(1, 0.4, 1), false)
	raid._imesh(sb, A.cyl(0.14, sz.x * 0.58, 0.14, 8), M_GALV, Vector3(0, hy + 1.15, 0), Vector3(0, 0, -68))


## 远景外围城区建筑 MultiMesh 形态映射（使战区边界内外的 20 种建筑轮廓自然贯通）
static func add_backdrop(kind: String, bs: Basis, p0: Vector3, sx: float, sz: float, h: float, brng: RandomNumberGenerator,
		hull_con0: Array, hull_con1: Array, hull_brick: Array, hull_wh: Array, hull_mil: Array,
		trim_dark: Array, roof_dark: Array, win_dark: Array, gable_slate: Array, gable_rust: Array,
		barrel_wh: Array, saw_shed: Array, tank_cyls: Array) -> bool:
	match kind:
		"terrace", "duplex":
			hull_brick.append(Transform3D(bs.scaled_local(Vector3(sx, h, sz)), p0 + Vector3(0.0, h * 0.5, 0.0)))
			win_dark.append(Transform3D(bs.scaled_local(Vector3(sx * 0.82, 0.72, sz + 0.08)), p0 + Vector3(0.0, h * 0.55, 0.0)))
			var rh := minf(sx, sz) * 0.30
			var r_bs := bs * (Basis(Vector3.UP, PI * 0.5) if kind == "terrace" else Basis.IDENTITY)
			var r_sc := Vector3(sz + 0.36, rh, sx + 0.24) if kind == "terrace" else Vector3(sx + 0.36, rh, sz + 0.32)
			(gable_slate if brng.randf() < 0.55 else gable_rust).append(Transform3D(r_bs.scaled_local(r_sc), p0 + Vector3(0.0, h, 0.0)))
		"stepped_tower":
			hull_con1.append(Transform3D(bs.scaled_local(Vector3(sx, h * 0.38, sz)), p0 + Vector3(0.0, h * 0.19, 0.0)))
			hull_con0.append(Transform3D(bs.scaled_local(Vector3(sx * 0.78, h * 0.62, sz * 0.78)), p0 + Vector3(0.0, h * 0.69, 0.0)))
			win_dark.append(Transform3D(bs.scaled_local(Vector3(sx * 0.80, h * 0.42, sz * 0.80)), p0 + Vector3(0.0, h * 0.66, 0.0)))
			trim_dark.append(Transform3D(bs.scaled_local(Vector3(sx * 0.36, 1.5, sz * 0.36)), p0 + Vector3(0.0, h + 0.75, 0.0)))
		"courtyard_blk":
			var wd := clampf(minf(sx, sz) * 0.30, 2.0, 3.2)
			for sd_z in [-1.0, 1.0]:
				hull_brick.append(Transform3D(bs.scaled_local(Vector3(sx, h, wd)), p0 + bs * Vector3(0.0, h * 0.5, sd_z * (sz * 0.5 - wd * 0.5))))
			for sd_x in [-1.0, 1.0]:
				hull_brick.append(Transform3D(bs.scaled_local(Vector3(wd, h, maxf(1.0, sz - wd * 2.02))), p0 + bs * Vector3(sd_x * (sx * 0.5 - wd * 0.5), h * 0.5, 0.0)))
		"foundry":
			hull_brick.append(Transform3D(bs.scaled_local(Vector3(sx, h, sz)), p0 + Vector3(0.0, h * 0.5, 0.0)))
			var s_bs := bs * Basis(Vector3.UP, PI * 0.5)
			for s_i in 2:
				var oz := (float(s_i) - 0.5) * sz * 0.48
				saw_shed.append(Transform3D(s_bs.scaled_local(Vector3(sz * 0.50, 1.05, sx + 0.20)), p0 + bs * Vector3(0.0, h, oz)))
		"chem_plant":
			hull_wh.append(Transform3D(bs.scaled_local(Vector3(sx * 0.56, h * 0.84, sz * 0.86)), p0 + bs * Vector3(-sx * 0.20, h * 0.42, 0.0)))
			tank_cyls.append(Transform3D(Basis.IDENTITY.scaled(Vector3(1.5, h + 2.4, 1.5)), p0 + bs * Vector3(sx * 0.24, (h + 2.4) * 0.5, -sz * 0.18)))
			tank_cyls.append(Transform3D(Basis.IDENTITY.scaled(Vector3(1.3, h + 1.2, 1.3)), p0 + bs * Vector3(sx * 0.24, (h + 1.2) * 0.5, sz * 0.20)))
		"cold_store", "loco_shed":
			hull_wh.append(Transform3D(bs.scaled_local(Vector3(sx, h, sz)), p0 + Vector3(0.0, h * 0.5, 0.0)))
			trim_dark.append(Transform3D(bs.scaled_local(Vector3(sx * 0.46, 1.0, sz * 0.72)), p0 + Vector3(0.0, h + 0.5, 0.0)))
		"command_bunker", "substation":
			hull_mil.append(Transform3D(bs.scaled_local(Vector3(sx, h, sz)), p0 + Vector3(0.0, h * 0.5, 0.0)))
			trim_dark.append(Transform3D(bs.scaled_local(Vector3(sx + 0.32, 0.48, sz + 0.32)), p0 + Vector3(0.0, h + 0.20, 0.0)))
		"silo_barn":
			hull_brick.append(Transform3D(bs.scaled_local(Vector3(sx * 0.64, h * 0.85, sz * 0.88)), p0 + bs * Vector3(-sx * 0.18, h * 0.42, 0.0)))
			var g_bs := bs
			gable_rust.append(Transform3D(g_bs.scaled_local(Vector3(sx * 0.66, 1.8, sz * 0.90)), p0 + bs * Vector3(-sx * 0.18, h * 0.85, 0.0)))
			tank_cyls.append(Transform3D(Basis.IDENTITY.scaled(Vector3(2.6, h + 2.2, 2.6)), p0 + bs * Vector3(sx * 0.28, (h + 2.2) * 0.5, -sz * 0.20)))
			tank_cyls.append(Transform3D(Basis.IDENTITY.scaled(Vector3(2.6, h + 2.2, 2.6)), p0 + bs * Vector3(sx * 0.28, (h + 2.2) * 0.5, sz * 0.20)))
		_:
			return false
	return true
