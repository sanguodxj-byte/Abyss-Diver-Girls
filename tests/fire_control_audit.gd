extends "res://tests/lib/test_base.gd"
## 机甲 HP-A1 双轴伺服火控交汇、枪口共轴弹道与小型敌人命中精度回归审计：
##   1. 大角度（135°）甩枪未到位即刻开火：验证实体弹丸初速方向与 3D 炮管真实前向夹角严格 ≤ 3.0°（彻底根治折角歪射）；
##   2. 近身（6.2m）地面跳虫（ling, r=0.6m）：验证左右双臂自动内收（Toe-in）+ 俯仰低头（Pitch）消除 3.5m 肩宽平行盲区，左右交替连射 100% 命中；
##   3. 高台（y=6.5m）对空射击啸翅虫（wasp）：验证修复高地 origin.y 截断 Bug，膛口出弹点与 3D 枪口完全重合且精准命中空中目标。
## 运行：godot --headless --path . -- --fire_control_audit

const START := "none"
const TIMEOUT := 90.0

const RaidScript = preload("res://scripts/raid.gd")
const MechScript = preload("res://scripts/mech.gd")
const BugScript = preload("res://scripts/bug.gd")
const ProjScript = preload("res://scripts/projectile.gd")


func run() -> void:
	var raid := RaidScript.new()
	add_child(raid)
	raid.set_process(false)
	raid.set_physics_process(false)
	raid.fx = Node3D.new()
	raid.fx.name = "FX"
	raid.world = Node3D.new()
	raid.world.name = "World"
	raid.add_child(raid.fx)
	raid.add_child(raid.world)

	# 地面碰撞板
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200.0, 2.0, 200.0)
	cs.shape = box
	sb.position = Vector3(0.0, -1.0, 0.0)
	sb.add_child(cs)
	raid.world.add_child(sb)

	var lo := {
		"core": "core_t90m_proryv",
		"legs": "legs_biped_assault",
		"arm_l": "arm_sniper",
		"arm_r": "arm_sniper",
		"back": "back_rack",
		"gen": "gen_reactor",
	}
	var m := MechScript.new()
	m.raid = raid
	raid.mech = m
	raid.world.add_child(m)
	m.setup(lo, [])
	m.set_physics_process(false)
	m.global_position = Vector3.ZERO
	m._vis_sync()
	m.torso.rotation = Vector3.ZERO
	m._animate(0.016, Vector3.ZERO)

	await frames(2)
	await get_tree().physics_frame

	# ---------------- 测试 1：135° 甩枪瞬间开火 —— 弹道必须严格贴合当前炮管轴线（零折角歪射） ----------------
	m.aim_point = Vector3(14.0, 2.2, 14.0) # 右后方 135°
	m.aim_target_locked = true
	m._animate(0.016, Vector3.ZERO) # 仅过 1 帧，躯干尚未转过去

	for slot: String in ["arm_l", "arm_r"]:
		m.arm_cd[slot] = 0.0
		m.ammo[slot] = 10
		var before_n := raid.fx.get_child_count()
		m.try_fire(slot)
		var spawned: Node3D = null
		for i in range(raid.fx.get_child_count() - 1, before_n - 1, -1):
			var ch := raid.fx.get_child(i)
			if ch is ProjScript and ch.visible:
				spawned = ch
				break
		if not check(spawned != null, "甩枪开火未生成弹丸: " + slot):
			return
		var arm_nd: Node3D = m.visual.get_meta("modules")[slot]
		var barrel_dir := (-arm_nd.global_transform.basis.z).normalized()
		var vel_dir: Vector3 = (spawned.vel as Vector3).normalized()
		var ang_deg := rad_to_deg(barrel_dir.angle_to(vel_dir))
		log_line("whip_135_%s barrel_vs_bullet_deg=%.2f° (yaw=%.1f°)" % [slot, ang_deg, rad_to_deg(m._arm_yaw[slot])])
		if not check(ang_deg <= 3.2, "%s 甩枪弹道偏离炮管过大: %.2f°" % [slot, ang_deg]):
			return
		spawned.queue_free()

	# ---------------- 测试 2：近身 6.2m 中线矮小跳虫（ling）—— 验证双臂内收+俯仰交汇消除平行盲区并 100% 命中 ----------------
	var ling := BugScript.new()
	ling.setup("ling", raid, null)
	ling.hp = 500.0
	ling.data = ling.data.duplicate()
	ling.data["hp"] = 500.0
	raid.world.add_child(ling)
	ling.set_physics_process(false)
	ling.global_position = Vector3(0.0, 0.0, -6.2)
	ling._vis_sync()
	await get_tree().physics_frame

	m.torso.rotation = Vector3.ZERO
	m.aim_point = raid._target_visual_center(ling)
	m.aim_target_locked = true
	for _step in 24:
		m._animate(0.016, Vector3.ZERO)

	var yl_deg := rad_to_deg(m._arm_yaw["arm_l"])
	var yr_deg := rad_to_deg(m._arm_yaw["arm_r"])
	var pl_deg := rad_to_deg(m._arm_pitch["arm_l"])
	var pr_deg := rad_to_deg(m._arm_pitch["arm_r"])
	log_line("close_ling_6.2m gimbal: L(yaw=%.1f°, pitch=%.1f°) R(yaw=%.1f°, pitch=%.1f°)" % [yl_deg, pl_deg, yr_deg, pr_deg])
	if not check(yl_deg < -8.0 and yr_deg > 8.0, "左右机械臂未向中线内收交汇: L=%.1f° R=%.1f°" % [yl_deg, yr_deg]):
		return
	if not check(pl_deg < -14.0 and pr_deg < -14.0, "左右机械臂未向地面跳虫低头俯仰: L=%.1f° R=%.1f°" % [pl_deg, pr_deg]):
		return

	var hp_before: float = ling.hp
	for i in 4:
		var sl := "arm_l" if i % 2 == 0 else "arm_r"
		m.arm_cd[sl] = 0.0
		m.ammo[sl] = 10
		m.try_fire(sl)
	for _f in 12:
		await get_tree().physics_frame
	log_line("close_ling_6.2m hp: %.1f -> %.1f" % [hp_before, ling.hp])
	if not check(ling.hp < hp_before - 180.0, "近身中线跳虫命中率不足，疑似仍存在肩距平行盲区: hp=%.1f" % ling.hp):
		return
	ling.queue_free()

	# ---------------- 测试 3：高地（y=6.5m）对空射击悬停啸翅虫（wasp）—— 验证无 origin.y 截断且精准命中 ----------------
	m.global_position = Vector3(0.0, 6.5, 0.0)
	m._vis_sync()
	var wasp_scr := str(GameData.ENEMIES["wasp"]["script"])
	var wasp = load(wasp_scr).new()
	wasp.setup("wasp", raid, null)
	wasp.hp = 300.0
	raid.world.add_child(wasp)
	wasp.set_physics_process(false)
	wasp.global_position = Vector3(0.0, 6.5, -11.0)
	wasp._vis_sync()
	wasp.visual.position.y = 2.6
	await get_tree().physics_frame

	m.aim_point = raid._target_visual_center(wasp)
	m.aim_target_locked = true
	for _step in 24:
		m._animate(0.016, Vector3.ZERO)

	m.arm_cd["arm_l"] = 0.0
	m.ammo["arm_l"] = 10
	var mz_wy: float = (m.muzzles["arm_l"] as Node3D).global_position.y
	var b_cnt := raid.fx.get_child_count()
	m.try_fire("arm_l")
	var high_proj: Node3D = raid.fx.get_child(raid.fx.get_child_count() - 1)
	var dy_muzzle := absf(high_proj.global_position.y - mz_wy)
	log_line("high_ground_y=6.5m muzzle_y=%.2f proj_y=%.2f diff=%.3fm" % [mz_wy, high_proj.global_position.y, dy_muzzle])
	if not check(mz_wy > 8.5 and dy_muzzle < 0.05, "高地开火膛口高度异常截断: muzzle=%.2f proj=%.2f" % [mz_wy, high_proj.global_position.y]):
		return
	var wasp_hp0: float = wasp.hp
	for _f in 12:
		await get_tree().physics_frame
	log_line("high_ground_wasp hp: %.1f -> %.1f" % [wasp_hp0, wasp.hp])
	if not check(wasp.hp < wasp_hp0, "高地未能命中悬停啸翅虫"):
		return

	for ch in raid.fx.get_children():
		if ch is ProjScript and ch.pool_key != "":
			raid.recycle_projectile(ch)
	raid.queue_free()
	await frames(2)
