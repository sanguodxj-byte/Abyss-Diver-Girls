extends CharacterBody3D
## 玩家机甲：下半身跟移动方向，上半身跟鼠标（双摇杆式），左右键分别控制左右臂。

const MechVisual = preload("res://scripts/mech_visual.gd")
const A = preload("res://scripts/art.gd")

signal died(reason: String)
signal message(text: String)
signal fired(slot: String)          ## HUD：子弹栏整体下滑
signal reloaded(slot: String)       ## HUD：子弹逐颗落回弹槽

var raid
var loadout := {}
var stats := {}
var max_hp := 100.0
var hp := 100.0
var max_energy := 100.0
var energy := 100.0
var cargo: Array = []
var visual: Node3D
var torso: Node3D
var legs: Node3D
var muzzles := {}
var leg_parts: Array = []
var leg_type := "biped"
var torso_base_y := 2.0

var arm_cd := {"arm_l": 0.0, "arm_r": 0.0}
var ability_cd := 0.0
var dash_cd := 0.0
var dash_time := 0.0
var dash_dir := Vector3.ZERO
var shield_time := 0.0
var shield_mesh: MeshInstance3D
## 新模块带来的状态：防爆力场剩余时间与减伤比例、光学迷彩剩余时间、动力炉耗能倍率、底盘抗性
var guard_t := 0.0
var guard_ratio := 0.0
var stealth_t := 0.0
var drain_mul := 1.0
var acid_immune := false
var overload_immune := false
var emergency := 0.0          ## >0：能源耗尽后的应急倒计时
var aim_point := Vector3.ZERO
var input_locked := false
var dead := false
var walk_phase := 0.0
var hurt_flash := 0.0
## 弹匣
var ammo := {"arm_l": 0, "arm_r": 0}
var mag := {"arm_l": 0, "arm_r": 0}
var reload_t := {"arm_l": 0.0, "arm_r": 0.0}
## 部位完好度 0~1（HUD 全息投影着色；0 = 部位缺失，失去对应功能）
var parts := {"core": 1.0, "legs": 1.0, "arm_l": 1.0, "arm_r": 1.0, "back": 1.0, "gen": 1.0}
const PART_W := {"core": 0.3, "legs": 0.24, "arm_l": 0.13, "arm_r": 0.13, "back": 0.1, "gen": 0.1}
## E / R 技能冷却与持续效果
var skill_e_cd := 0.0
var skill_r_cd := 0.0
var overdrive_t := 0.0
var heal_t := 0.0
var heal_rate := 0.0
var leap_t := 0.0
var ram_t := 0.0
## 动画状态
var gait_phase := 0.0
var gait_amt := 0.0
var recoil := {"arm_l": 0.0, "arm_r": 0.0}
var kick := Vector3.ZERO          ## 躯干受击 / 后坐的角度偏移（弹簧回正）
var kick_v := Vector3.ZERO
const TORSO_TURN := 7.5
var slam := 0.0                   ## 空投落地重压（下蹲 + 前俯，缓慢起身）
var land_t := 0.0                 ## 落地 / 急停下蹲
var idle_t := 0.0
var _leg_base := []
## 双足重型步态参数
const STRIDE := 2.1               ## 单步跨度（米）
const STANCE := 0.56              ## 支撑相占比（重型机甲脚长时间贴地）
var _foot_prev := [0.0, 0.0]      ## 上一帧每条腿的步态相位，用于检测落脚瞬间
var _step_dip := 0.0              ## 落脚冲击造成的车身下沉（弹簧）
var _step_dip_v := 0.0
var _torso_y := 0.0               ## 躯干高度滞后跟随（惯性）
var _torso_yv := 0.0
var _thrusters: Array = []        ## 推进飞行时的喷口粒子
var DASH_DUR := 0.6
## 音效与事件状态
var _emerg_was := false
var _low_warned := false
var _overloaded := false
var _fire_held := {"arm_l": 0.0, "arm_r": 0.0}   ## 持续喷射类武器：距上一发的剩余保持时间，归零时停止循环音
var _quad_lift: Array = []


func setup(lo: Dictionary, carry: Array) -> void:
	loadout = lo.duplicate()
	stats = GameData.compute_stats(loadout)
	max_hp = max(30.0, stats.hp)
	hp = max_hp
	max_energy = max(30.0, stats.energy)
	energy = max_energy
	cargo = carry.duplicate()
	for slot in ["arm_l", "arm_r"]:
		var wid: String = lo.get(slot, "")
		if wid != "":
			mag[slot] = int(GameData.AMMO[GameData.module(wid).weapon].mag)
			ammo[slot] = mag[slot]
	_overloaded = GameData.speed_factor(stats, cargo_weight()) < 0.99
	var legs_mod: Dictionary = GameData.module(loadout.get("legs", ""))
	acid_immune = bool(legs_mod.get("acid_immune", false))
	overload_immune = bool(legs_mod.get("overload_immune", false))
	collision_layer = 2
	collision_mask = 1 | 4 | 8
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 1.0
	cap.height = 2.8
	cs.shape = cap
	cs.position.y = 1.4
	add_child(cs)
	visual = MechVisual.build(loadout)
	add_child(visual)
	torso = visual.get_meta("torso")
	legs = visual.get_meta("legs")
	muzzles = visual.get_meta("muzzles")
	leg_parts = visual.get_meta("leg_parts")
	leg_type = visual.get_meta("leg_type")
	torso_base_y = visual.get_meta("torso_base_y")
	shield_mesh = MeshInstance3D.new()
	shield_mesh.mesh = preload("res://scripts/art.gd").sphere(2.2)
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec4 col : source_color = vec4(0.35, 0.7, 1.0, 1.0);
void fragment() {
	float f = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.5);
	float bands = 0.5 + 0.5 * sin(UV.y * 80.0 - TIME * 6.0);
	ALBEDO = col.rgb * (f * 1.6 + 0.08 + bands * 0.06);
}"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	shield_mesh.material_override = sm
	shield_mesh.position.y = 1.6
	shield_mesh.visible = false
	add_child(shield_mesh)
	if leg_type == "tread" or leg_type == "hover":
		Audio.loop_start(_lk("legs"), "legs_%s_loop" % leg_type, self)


## 本机甲的循环音效 key（同时存在多台机甲时互不干扰）
func _lk(what: String) -> String:
	return "mech_%d_%s" % [get_instance_id(), what]


func cargo_weight() -> float:
	return GameData.weight_of(cargo)

func cargo_cap() -> float:
	return float(stats.cargo)

func speed_mult() -> float:
	var f: float = GameData.speed_factor(stats, cargo_weight())
	if overload_immune:
		f = 1.0
	if emergency > 0.0:
		f *= 0.45
	if parts.legs <= 0.0:
		f *= 0.55
	return f

func energy_seconds_left() -> float:
	return energy / max(0.01, float(stats.drain))


var _shown_damage := -1.0

func _physics_process(delta: float) -> void:
	var dmg_now := clampf(1.0 - hp / max_hp, 0.0, 1.0)
	if absf(dmg_now - _shown_damage) > 0.01:
		_shown_damage = dmg_now
		RenderingServer.global_shader_parameter_set("mech_damage", dmg_now)
	if dead:
		return
	for k in arm_cd:
		arm_cd[k] = max(0.0, arm_cd[k] - delta)
	ability_cd = max(0.0, ability_cd - delta)
	skill_e_cd = max(0.0, skill_e_cd - delta)
	skill_r_cd = max(0.0, skill_r_cd - delta)
	guard_t = max(0.0, guard_t - delta)
	stealth_t = max(0.0, stealth_t - delta)
	overdrive_t = max(0.0, overdrive_t - delta)
	for k in reload_t:
		if reload_t[k] > 0.0:
			reload_t[k] -= delta
			if reload_t[k] <= 0.0:
				reload_t[k] = 0.0
				ammo[k] = mag[k]
				reloaded.emit(k)
				Audio.play_sfx("wpn_reload_done", global_position + Vector3(0, 2.0, 0))
	for k in _fire_held:
		if _fire_held[k] > 0.0:
			_fire_held[k] -= delta
			if _fire_held[k] <= 0.0:
				Audio.loop_stop(_lk("fire_" + k))
	if heal_t > 0.0:
		heal_t -= delta
		hp = min(max_hp, hp + heal_rate * delta)
		for k in parts:
			if parts[k] > 0.0:
				parts[k] = min(1.0, parts[k] + 0.12 * delta)
	dash_cd = max(0.0, dash_cd - delta)
	hurt_flash = max(0.0, hurt_flash - delta)
	if shield_time > 0.0:
		shield_time -= delta
		shield_mesh.visible = shield_time > 0.0
		if shield_time <= 0.0:
			Audio.play_sfx("shield_down", global_position + Vector3(0, 1.6, 0))
	_audio_tick()

	if raid and raid.dropping:
		# 空投中由 raid 的补间控制位置，不叠加重力
		velocity = Vector3.ZERO
		_animate(delta, Vector3.ZERO)
		return
	var move := Vector3.ZERO
	if not input_locked:
		move.x = Input.get_axis("move_left", "move_right")
		move.z = Input.get_axis("move_up", "move_down")
	if move.length() > 0.1:
		move = move.normalized()
	else:
		move = Vector3.ZERO

	var spd: float = float(stats.speed) * speed_mult()
	if dash_time > 0.0 and leg_type == "biped":
		dash_time -= delta
		_thrust_fly(delta)
	elif dash_time > 0.0:
		dash_time -= delta
		var dsp := 24.0
		if leg_type == "tread":
			dsp = 19.0
		elif leg_type == "quad":
			dsp = 15.0
			visual.position.y = sin(clampf(1.0 - dash_time / 0.5, 0.0, 1.0) * PI) * 2.2
		velocity.x = dash_dir.x * dsp
		velocity.z = dash_dir.z * dsp
		if dash_time <= 0.0:
			visual.position.y = 0.0
			land_t = 0.35 if leg_type in ["quad", "tread"] else 0.2
			var sk: Dictionary = GameData.SKILLS.get(leg_type, {})
			if sk.has("dmg"):
				raid.explode(global_position, float(sk.r), float(sk.dmg), "mech_slam")
			else:
				Audio.play_sfx("mech_land", global_position)
	else:
		# 手感：起步有重量、松手快速刹停、急转向时额外制动（避免“溜冰”）
		var want := move * spd
		var hv := Vector3(velocity.x, 0, velocity.z)
		var rate := 5.0 if leg_type == "biped" else 9.0
		if move == Vector3.ZERO:
			rate = 8.0 if leg_type == "biped" else 16.0
		elif hv.length() > 1.0 and hv.normalized().dot(move) < 0.3:
			rate = 18.0
		hv = hv.lerp(want, clamp(rate * delta, 0.0, 1.0))
		velocity.x = hv.x
		velocity.z = hv.z
	if is_on_floor():
		velocity.y = -1.0
	else:
		velocity.y -= 40.0 * delta
	move_and_slide()

	# 下半身朝移动方向，上半身朝鼠标
	if move != Vector3.ZERO and leg_type != "hover":
		legs.rotation.y = lerp_angle(legs.rotation.y, atan2(-move.x, -move.z), clamp((5.0 if leg_type == "biped" else 10.0) * delta, 0.0, 1.0))
	var to := aim_point - global_position
	to.y = 0.0
	if to.length() > 0.6:
		torso.rotation.y = lerp_angle(torso.rotation.y, atan2(-to.x, -to.z), clamp(TORSO_TURN * delta, 0.0, 1.0))  # 上半身转向有惯性 → 拖曳感
	_animate(delta, move)

	# 能源
	var drain: float = float(stats.drain) * drain_mul * (1.6 if move != Vector3.ZERO else 1.0) * (1.5 if parts.gen <= 0.0 else 1.0)
	if emergency > 0.0:
		emergency -= delta
		if energy > 1.0:
			emergency = 0.0
			message.emit("主电源回路重启，退出应急模式")
		elif emergency <= 0.0:
			die("能源耗尽，机甲瘫痪")
			return
	else:
		use_energy(drain * delta)
	_energy_watch()

	if input_locked:
		return
	var map_on: bool = raid != null and raid.hud != null and raid.hud.map_open()
	if Input.is_action_pressed("fire_left") and not map_on:
		try_fire("arm_l")
	if Input.is_action_pressed("fire_right") and not map_on:
		try_fire("arm_r")
	if Input.is_action_just_pressed("dash"):
		try_dash(move)
	if Input.is_action_just_pressed("ability"):
		try_ability()
	if Input.is_action_just_pressed("skill_e"):
		try_skill_e()
	if Input.is_action_just_pressed("skill_r"):
		try_skill_r()
	if Input.is_action_just_pressed("use_fuel"):
		use_item("fuel_cell")
	if Input.is_action_just_pressed("use_repair"):
		use_item("repair_kit")


func _animate(delta: float, move: Vector3) -> void:
	var hv := Vector3(velocity.x, 0, velocity.z)
	var sp := hv.length()
	var top: float = maxf(float(stats.speed) * 0.55, 1.0)
	gait_amt = move_toward(gait_amt, clampf(sp / top, 0.0, 1.0), delta * 5.0)
	land_t = maxf(0.0, land_t - delta)
	slam = move_toward(slam, 0.0, delta * 0.75)
	idle_t += delta
	# 躯干弹簧（后坐 / 受击抖动）
	kick_v += (-kick * 120.0 - kick_v * 14.0) * delta
	kick += kick_v * delta
	var crouch := 0.0
	var bob := 0.0
	var dashing := dash_time > 0.0
	match leg_type:
		"biped", "reverse", "wraith", "spring":
			if dashing:
				# 推进飞行：双腿收起、向后拖
				var air := sin(clampf(1.0 - dash_time / DASH_DUR, 0.0, 1.0) * PI)
				for i in leg_parts.size():
					_biped_leg(leg_parts[i], 0.0, 0.0, 0.18 + air * 0.32, Vector2(0.35 * air + (0.12 if i == 0 else -0.08) * air, 0.0), 0.0)
				legs.rotation.z = lerp(legs.rotation.z, 0.0, clampf(8.0 * delta, 0.0, 1.0))
			else:
				# 重型步态：长支撑相、高抬腿、落脚冲击下沉 + 左右重心转移
				gait_phase += delta * sp * STANCE / STRIDE * TAU
				crouch = 0.24 * gait_amt + land_t * 0.5
				for i in leg_parts.size():
					var ph := gait_phase + PI * i
					var t := fposmod(ph, TAU) / TAU
					if t < _foot_prev[i] - 0.5 and gait_amt > 0.25:
						_footfall(leg_parts[i], i)
					_foot_prev[i] = t
					_biped_leg(leg_parts[i], ph, STRIDE, crouch, Vector2(-0.12, 0.0), STANCE)
				legs.rotation.z = sin(gait_phase) * 0.07 * gait_amt
			# 落脚下沉弹簧（欠阻尼，有一点回弹）
			_step_dip_v += (-_step_dip * 140.0 - _step_dip_v * 13.0) * delta
			_step_dip += _step_dip_v * delta
			bob = _step_dip
		"quad", "titan":
			if _leg_base.is_empty():
				for lp in leg_parts:
					_leg_base.append(lp.position)
			gait_phase += delta * (sp / 1.4) * TAU * 0.5
			if _quad_lift.size() != leg_parts.size():
				_quad_lift.resize(leg_parts.size())
				_quad_lift.fill(0.0)
			for i in leg_parts.size():
				var ph := gait_phase + PI * float(i % 2) + (PI * 0.5 if i >= 2 else 0.0)
				var sw := sin(ph) * 0.28 * gait_amt
				var lift := maxf(0.0, cos(ph)) * 0.32 * gait_amt
				# 抬起的腿重新着地 = 一次落脚
				if _quad_lift[i] > 0.02 and lift <= 0.0 and gait_amt > 0.3 and not dead:
					Audio.play_sfx("step_quad", global_position)
				_quad_lift[i] = lift
				leg_parts[i].rotation.z = lerp(leg_parts[i].rotation.z, sw, clampf(14.0 * delta, 0.0, 1.0))
				leg_parts[i].position = _leg_base[i] + Vector3(0, lift, 0)
				if dashing:
					leg_parts[i].rotation.x = lerp(leg_parts[i].rotation.x, 0.35 * (1.0 if i % 2 == 0 else -1.0), clampf(10.0 * delta, 0.0, 1.0))
				else:
					leg_parts[i].rotation.x = lerp(leg_parts[i].rotation.x, 0.0, clampf(10.0 * delta, 0.0, 1.0))
			bob = absf(sin(gait_phase * 2.0)) * 0.05 * gait_amt
			crouch = land_t * 0.8
		"hover":
			var lv: Vector3 = legs.global_transform.basis.inverse() * hv
			legs.rotation.x = lerp(legs.rotation.x, clampf(lv.z * 0.025, -0.25, 0.25), clampf(6.0 * delta, 0.0, 1.0))
			legs.rotation.z = lerp(legs.rotation.z, clampf(-lv.x * 0.025, -0.25, 0.25), clampf(6.0 * delta, 0.0, 1.0))
			bob = -sin(idle_t * 2.4) * 0.1
		"tread", "wheel":
			gait_phase += delta * sp * 3.0
			bob = sin(gait_phase * 2.3) * 0.015 * gait_amt
			crouch = land_t * 0.4
			var lv2: Vector3 = legs.global_transform.basis.inverse() * hv
			legs.rotation.x = lerp(legs.rotation.x, clampf(lv2.z * 0.01, -0.08, 0.08) + (-0.08 if dashing else 0.0), clampf(4.0 * delta, 0.0, 1.0))
	var sl := slam * slam * (3.0 - 2.0 * slam)
	crouch += sl * 0.42
	if not dashing or leg_type != "quad":
		legs.position.y = -crouch - bob
	# 躯干：跟随髋高度、行进前倾、呼吸、后坐/受击
	var breathe := sin(idle_t * 1.6) * 0.025 * (1.0 - gait_amt)
	var ty := torso_base_y - crouch - bob + breathe
	if leg_type == "biped":
		if _torso_y == 0.0:
			_torso_y = ty
		_torso_yv += ((ty - _torso_y) * 90.0 - _torso_yv * 11.0) * delta
		_torso_y += _torso_yv * delta
		torso.position.y = _torso_y
	else:
		torso.position.y = ty
	var lt: Vector3 = torso.global_transform.basis.inverse() * hv
	var lean_x := clampf(lt.z * 0.012, -0.12, 0.12) + (0.0 if not dashing else -0.18)
	var lean_z := clampf(-lt.x * 0.01, -0.1, 0.1)
	torso.rotation.x = lean_x * -1.0 + kick.x * 0.1 - sl * 0.32
	torso.rotation.z = lean_z + kick.z * 0.06 - sin(gait_phase) * (0.045 if leg_type == "biped" else 0.025) * gait_amt
	# 武器后坐：手臂沿躯干后方回缩再弹回
	var mods: Dictionary = visual.get_meta("modules")
	for slot in recoil:
		recoil[slot] = maxf(0.0, recoil[slot] - delta * 9.0)
		var arm: Node3D = mods.get(slot)
		if arm and is_instance_valid(arm) and arm.get_parent():
			var back: Vector3 = (arm.get_parent().global_transform.basis.inverse() * (torso.global_transform.basis * Vector3(0, 0, 1))).normalized()
			var r: float = recoil[slot]
			arm.position = back * 0.2 * r * r
	visual.scale = Vector3.ONE


## 双足步态：足端轨迹（支撑相贴地后移、摆动相抬脚前送）+ 两段 IK 解出髋 / 膝 / 踝角度
func _biped_leg(leg: Node3D, ph: float, stride: float, crouch: float, off := Vector2.ZERO, stance := 0.5) -> void:
	var kj: Node3D = leg.get_meta("knee")
	var aj: Node3D = leg.get_meta("ankle")
	var KN: Vector3 = leg.get_meta("KN")
	var AN: Vector3 = leg.get_meta("AN")
	var t := fposmod(ph, TAU) / TAU
	var dz := 0.0
	var dy := 0.0
	var toe := 0.0
	if stance <= 0.0:
		pass
	elif t < stance:
		# 支撑相：脚掌贴地匀速后移；末段脚跟抬起、脚尖蹬地
		var u := t / stance
		dz = lerpf(-stride * 0.5, stride * 0.5, u)
		toe = -0.35 * smoothstep(0.75, 1.0, u)
	else:
		# 摆动相：先高抬膝，再向前甩出，落地前脚尖上翘（脚跟先着地）
		var u := (t - stance) / (1.0 - stance)
		var e := u * u * (3.0 - 2.0 * u)
		dz = lerpf(stride * 0.5, -stride * 0.5, e)
		dy = pow(sin(u * PI), 0.8) * 0.62 * (1.0 - 0.35 * u)
		toe = 0.35 * sin(u * PI) - 0.15 * smoothstep(0.75, 1.0, u)
	dz *= gait_amt
	dy *= gait_amt
	toe *= gait_amt
	var T := Vector2(AN.z + dz + off.x, AN.y + dy + crouch + off.y)     # (z, y)
	var L1 := Vector2(KN.z, KN.y).length()
	var L2 := Vector2(AN.z - KN.z, AN.y - KN.y).length()
	var d := clampf(T.length(), absf(L1 - L2) + 0.01, L1 + L2 - 0.002)
	var th := atan2(T.y, T.x)
	var alpha := acos(clampf((L1 * L1 + d * d - L2 * L2) / (2.0 * L1 * d), -1.0, 1.0))
	# 与静止姿态同侧弯膝
	var th0 := atan2(AN.y, AN.z)
	var p1_0 := atan2(KN.y, KN.z)
	var sgn := 1.0 if wrapf(p1_0 - th0, -PI, PI) > 0.0 else -1.0
	var p1 := th + sgn * alpha
	var kp := Vector2(cos(p1), sin(p1)) * L1
	var p2 := atan2(T.y - kp.y, T.x - kp.x)
	var p2_0 := atan2(AN.y - KN.y, AN.z - KN.z)
	var r_hip := p1_0 - p1
	var r_knee := p2_0 - p2 - r_hip
	leg.rotation.x = r_hip
	kj.rotation.x = r_knee
	aj.rotation.x = -(r_hip + r_knee) + toe


func use_energy(amount: float) -> void:
	if emergency > 0.0 or dead:
		return
	energy -= amount
	if energy <= 0.0:
		energy = 0.0
		emergency = 15.0
		message.emit("▲ 动力炉断电 · 应急电源维持 15 秒")
		Audio.play_sfx("energy_emergency")
		Audio.loop_start(_lk("alarm"), "energy_alarm_loop", self, {"d3": false})
		Events.emergency_entered.emit()


## 应急模式的退出（恢复能源）与低能源告警；每个物理帧在扣能之后调用
func _energy_watch() -> void:
	var em := emergency > 0.0
	if _emerg_was and not em and not dead:
		Audio.loop_stop(_lk("alarm"))
		Audio.play_sfx("energy_restored")
		Events.emergency_exited.emit()
	_emerg_was = em
	var left := energy_seconds_left()
	if not _low_warned and not em and left < 45.0:
		_low_warned = true
		Audio.play_sfx("energy_low")
		Events.energy_low.emit(left)
	elif _low_warned and left > 60.0:
		_low_warned = false


func can_spend(amount: float) -> bool:
	return emergency <= 0.0 and energy >= amount


func try_fire(slot: String) -> void:
	var id: String = loadout.get(slot, "")
	if id == "" or arm_cd[slot] > 0.0 or parts[slot] <= 0.0 or reload_t[slot] > 0.0:
		return
	var m: Dictionary = GameData.module(id)
	if ammo[slot] <= 0:
		start_reload(slot)
		return
	if not can_spend(float(m.cost)):
		return
	use_energy(float(m.cost))
	arm_cd[slot] = 1.0 / float(m.rate) / (2.0 if overdrive_t > 0.0 else 1.0)
	recoil[slot] = 1.0
	kick_v += Vector3(-0.9 if m.weapon != "flamer" else -0.2, (0.5 if slot == "arm_l" else -0.5), 0.0) * (1.6 if m.weapon == "shotgun" else 1.0)
	var muzzle: Node3D = muzzles[slot]
	var origin := muzzle.global_position
	origin.y = clamp(origin.y, 1.2, 2.6)
	_fire_sfx(slot, str(m.weapon), origin)
	if overdrive_t <= 0.0:
		ammo[slot] -= 1
		fired.emit(slot)
		if ammo[slot] <= 0:
			Audio.play_sfx("wpn_empty", origin)
			start_reload(slot)
	# 子弹沿躯干实际朝向射出（躯干转向有惯性，准星内圈显示真实落点）
	var dir := aim_dir()
	var ws = ext_script(GameData.AMMO.get(str(m.weapon), {}))
	if ws != null:
		ws.fire(self, slot, origin, dir, m)
		return
	match m.weapon:
		"laser":
			raid.fire_laser(origin, dir, m)
			raid.alert_noise(global_position, noise(14.0))
		_:
			var n: int = int(m.get("pellets", 1))
			for i in n:
				var a := deg_to_rad(randf_range(-float(m.spread), float(m.spread)) * 0.5)
				raid.spawn_projectile(origin, dir.rotated(Vector3.UP, a), m, true)
			raid.alert_noise(global_position, noise(24.0 if m.weapon != "flamer" else 12.0))
	raid.muzzle_flash(origin, m.color, dir, m.weapon)


## 开火音效：fire_loop 类武器（弹匣表里标注）按住扳机时持续循环，其余每发一次 wpn_<weapon>_fire
func _fire_sfx(slot: String, weapon: String, origin: Vector3) -> void:
	if bool(GameData.AMMO.get(weapon, {}).get("fire_loop", false)):
		if _fire_held[slot] <= 0.0:
			Audio.play_sfx("wpn_%s_ignite" % weapon, origin)
			Audio.loop_start(_lk("fire_" + slot), "wpn_%s_loop" % weapon, self)
		_fire_held[slot] = maxf(0.15, arm_cd[slot] * 2.5)
	else:
		Audio.play_sfx("wpn_%s_fire" % weapon, origin)


## 躯干实际朝向（水平）
func aim_dir() -> Vector3:
	var d := -torso.global_transform.basis.z
	d.y = 0.0
	if d.length() < 0.01:
		return Vector3.FORWARD
	return d.normalized()


## 开火噪音半径：光学迷彩 / 静默滑步期间只剩很近的虫群能听见
func noise(radius: float) -> float:
	return radius * (0.2 if stealth_t > 0.0 else 1.0)


func start_reload(slot: String) -> void:
	var id: String = loadout.get(slot, "")
	if id == "" or reload_t[slot] > 0.0 or ammo[slot] >= mag[slot]:
		return
	var w: String = GameData.module(id).weapon
	reload_t[slot] = float(GameData.AMMO[w].reload)
	Audio.play_sfx("wpn_%s_reload" % w, global_position + Vector3(0, 2.0, 0))


func reload_frac(slot: String) -> float:
	var id: String = loadout.get(slot, "")
	if id == "" or reload_t[slot] <= 0.0:
		return 0.0
	return reload_t[slot] / float(GameData.AMMO[GameData.module(id).weapon].reload)


## 技能槽状态，HUD 用：{name, icon, cd(剩余), cd_max, ok}
func skill_info(key: String) -> Dictionary:
	var sk: Dictionary
	var cd := 0.0
	var ok := true
	match key:
		"space":
			sk = GameData.SKILLS.get(leg_type, GameData.SKILLS.biped)
			cd = dash_cd
			ok = parts.legs > 0.0
		"f":
			var bid: String = loadout.get("back", "")
			var bm: Dictionary = GameData.module(bid)
			var ab: String = bm.ability if bid != "" else "none"
			sk = GameData.SKILLS[ab].duplicate()
			if ab != "none":
				sk["cd"] = bm.cd
				sk["cost"] = bm.cost
			cd = ability_cd
			ok = ab != "none" and parts.back > 0.0
		"e":
			sk = GameData.SKILLS.get(GameData.base_id(loadout.get("core", "")), GameData.SKILLS.none)
			cd = skill_e_cd
		"r":
			sk = GameData.SKILLS.get(GameData.base_id(loadout.get("gen", "")), GameData.SKILLS.none)
			cd = skill_r_cd
			ok = parts.gen > 0.0
	var active := (key == "e" and (overdrive_t > 0.0 or guard_t > 0.0)) or (key == "r" and heal_t > 0.0) or (key == "f" and (shield_time > 0.0 or stealth_t > 0.0)) or (key == "space" and stealth_t > 0.0)
	return {"name": sk.name, "icon": sk.icon, "cd": cd, "cd_max": float(sk.get("cd", 1.0)), "ok": ok, "cost": float(sk.get("cost", 0.0)), "active": active}


func try_dash(move: Vector3) -> void:
	var sk: Dictionary = GameData.SKILLS.get(leg_type, GameData.SKILLS.biped)
	if dash_cd > 0.0:
		return
	if parts.legs <= 0.0 or not can_spend(float(sk.cost)):
		Audio.play_sfx("skill_denied")
		return
	var d := move
	if d == Vector3.ZERO:
		d = aim_point - global_position
		d.y = 0.0
	if d.length() < 0.1:
		return
	use_energy(float(sk.cost))
	dash_dir = d.normalized()
	dash_cd = float(sk.cd)
	_skill_sfx("space", leg_type, sk)
	var ss = ext_script(sk)
	if ss != null:
		ss.use(self, "space", sk, GameData.module(loadout.get("legs", "")))
		return
	match leg_type:
		"hover":
			# 闪移：瞬间位移，留下残光
			raid.spark(global_position + Vector3(0, 1.5, 0), Color(1.0, 0.7, 0.2), 14)
			var dist: float = float(sk.dist)
			velocity = Vector3.ZERO
			global_position += dash_dir * dist
			move_and_slide()
			raid.spark(global_position + Vector3(0, 1.5, 0), Color(1.0, 0.7, 0.2), 14)
			dash_time = 0.0
		"tread":
			dash_time = 0.4
		"quad":
			dash_time = 0.5
		_:
			dash_time = DASH_DUR
			_thrust_start()


func try_skill_e() -> void:
	var id: String = GameData.base_id(loadout.get("core", ""))
	var sk: Dictionary = GameData.SKILLS.get(id, {})
	if sk.is_empty() or skill_e_cd > 0.0:
		return
	if not can_spend(float(sk.cost)):
		message.emit("能源不足")
		Audio.play_sfx("skill_denied")
		return
	use_energy(float(sk.cost))
	skill_e_cd = float(sk.cd)
	_skill_sfx("e", id, sk)
	var ss = ext_script(sk)
	if ss != null:
		ss.use(self, "e", sk, GameData.module(loadout.get("core", "")))
		return
	match id:
		"core_scout":
			var p := aim_point
			p.y = 0.0
			raid.alert_noise(p, 30.0)
			raid.spark(p + Vector3(0, 0.5, 0), Color(1.0, 0.7, 0.2), 10)
			get_tree().create_timer(2.5).timeout.connect(func():
				if is_instance_valid(raid):
					raid.explode(p, float(sk.r), float(sk.dmg)))
		"core_std":
			overdrive_t = float(sk.dur)
			message.emit("火力过载已启动")
		"core_heavy":
			raid.explode(global_position, float(sk.r), float(sk.dmg))


func try_skill_r() -> void:
	var id: String = GameData.base_id(loadout.get("gen", ""))
	var sk: Dictionary = GameData.SKILLS.get(id, {})
	if sk.is_empty() or skill_r_cd > 0.0 or parts.gen <= 0.0:
		return
	if not can_spend(float(sk.cost)):
		message.emit("动力炉蓄能不足")
		Audio.play_sfx("skill_denied")
		return
	use_energy(float(sk.cost))
	skill_r_cd = float(sk.cd)
	_skill_sfx("r", id, sk)
	var ss = ext_script(sk)
	if ss != null:
		ss.use(self, "r", sk, GameData.module(loadout.get("gen", "")))
		return
	match id:
		"gen_cell":
			energy = min(max_energy, energy + float(sk.amt))
			emergency = 0.0
		"gen_reactor":
			raid.explode(global_position, float(sk.r), float(sk.dmg))
		"gen_crystal":
			heal_t = float(sk.dur)
			heal_rate = float(sk.amt) / float(sk.dur)


func try_ability() -> void:
	var id: String = loadout.get("back", "")
	if id == "" or parts.back <= 0.0:
		return
	var m: Dictionary = GameData.module(id)
	if m.ability == "none":
		message.emit("该背件无主动战术机能")
		Audio.play_sfx("skill_denied")
		return
	if ability_cd > 0.0:
		message.emit("%s 冷却中 %.1fs" % [m.name, ability_cd])
		Audio.play_sfx("skill_denied")
		return
	if not can_spend(float(m.cost)):
		message.emit("动力炉蓄能不足")
		Audio.play_sfx("skill_denied")
		return
	use_energy(float(m.cost))
	ability_cd = float(m.cd)
	_skill_sfx("f", str(m.ability), GameData.SKILLS.get(m.ability, {}))
	var ss = ext_script(GameData.SKILLS.get(m.ability, {}))
	if ss != null:
		ss.use(self, "f", GameData.SKILLS[m.ability], m)
		return
	match m.ability:
		"missile":
			raid.launch_missiles(global_position + Vector3(0, 3.0, 0), m)
		"shield":
			shield_time = float(m.dur)
			shield_mesh.visible = true


func use_item(id: String) -> void:
	if not cargo.has(id):
		message.emit("货舱未装载" + GameData.item_name(id))
		Audio.play_sfx("use_denied")
		return
	match id:
		"fuel_cell":
			cargo.erase(id)
			energy = min(max_energy, energy + 35.0)
			emergency = 0.0
			message.emit("应急燃料电池接入，补充 35 能量")
		"repair_kit":
			if hp >= max_hp:
				message.emit("机体结构完好，无需维修")
				Audio.play_sfx("use_denied")
				return
			cargo.erase(id)
			hp = min(max_hp, hp + 45.0)
			parts.core = hp / max_hp
			for k in parts:
				parts[k] = min(1.0, parts[k] + 0.4)
			message.emit("战地抢修完成，修复 45 结构")
		_:
			var us = ext_script(GameData.item(id))
			if us == null or not bool(us.use(self, id)):
				return
			cargo.erase(id)
	Audio.play_sfx("use_" + GameData.base_id(id))
	Events.item_used.emit(id)
	check_overload()


## 技能音效 skill_<图标名> + 广播 skill_used
func _skill_sfx(key: String, skill_id: String, sk: Dictionary) -> void:
	Audio.play_sfx("skill_" + str(sk.get("icon", skill_id)), global_position + Vector3(0, 1.6, 0))
	Events.skill_used.emit(key, skill_id)


## 注册表条目的行为脚本（字段 script = 脚本路径，规则见 scripts\game_data.gd「内容注册」一节）；没有时返回 null。
## 返回值不标类型：调用的是脚本里的 static func，要在运行时按名字解析。
func ext_script(entry: Dictionary):
	var p := str(entry.get("script", ""))
	if p == "":
		return null
	var s = load(p)
	if s == null:
		push_error("行为脚本无法加载：%s" % p)
	return s


## 货物变化后检查超载减速的进入 / 解除
func check_overload() -> void:
	var sf: float = GameData.speed_factor(stats, cargo_weight())
	var over := sf < 0.99
	if over == _overloaded:
		return
	_overloaded = over
	if over:
		Audio.play_sfx("cargo_overload")
	Events.overload_changed.emit(over, sf)


## 底盘循环音：履带随速度起落，悬浮的嗡鸣音高随速度升高
func _audio_tick() -> void:
	if leg_type != "tread" and leg_type != "hover":
		return
	var sp := Vector2(velocity.x, velocity.z).length()
	var k := clampf(sp / maxf(float(stats.speed), 1.0), 0.0, 1.2)
	if leg_type == "tread":
		Audio.loop_set(_lk("legs"), lerpf(-30.0, 0.0, minf(k * 1.4, 1.0)), 0.8 + 0.35 * k)
	else:
		Audio.loop_set(_lk("legs"), -4.0 + 4.0 * minf(k, 1.0), 0.9 + 0.3 * k)


func take_damage(amount: float) -> void:
	if dead:
		return
	if shield_time > 0.0:
		Audio.play_sfx("shield_hit", global_position + Vector3(0, 1.6, 0))
		return
	var armor: float = clamp(float(stats.armor), 0.0, 0.6)
	var eff := amount * (1.0 - armor)
	if guard_t > 0.0 and guard_ratio > 0.0:
		eff *= 1.0 - guard_ratio
	hp -= eff
	# 伤害随机落到某个部位：部位完好度下降，归零即缺失（躯干只跟随总结构）
	var r := randf()
	var acc := 0.0
	for k in PART_W:
		acc += PART_W[k]
		if r <= acc:
			if k != "core":
				var was: float = parts[k]
				parts[k] = max(0.0, parts[k] - eff / (max_hp * 0.3))
				if was > 0.0 and parts[k] <= 0.0:
					message.emit("▲ %s 损毁！" % GameData.SLOT_NAMES[k])
					Audio.play_sfx("mech_part_lost")
					Events.part_destroyed.emit(k)
			break
	parts.core = hp / max_hp
	hurt_flash = 0.25
	kick_v += Vector3(randf_range(1.2, 2.2), randf_range(-1.5, 1.5), randf_range(-1.8, 1.8)) * clampf(eff / 12.0, 0.4, 1.6)
	Audio.play_sfx("mech_hurt")
	if raid:
		raid.on_player_hurt(amount)
	Events.player_damaged.emit(eff, maxf(hp, 0.0), max_hp)
	if hp <= 0.0:
		hp = 0.0
		die("机甲结构损毁")


func die(reason: String) -> void:
	if dead:
		return
	dead = true
	for k in ["legs", "alarm", "fire_arm_l", "fire_arm_r"]:
		Audio.loop_stop(_lk(k))
	Audio.play_sfx("mech_destroyed")
	Events.mech_destroyed.emit(reason)
	# 模块化残骸：各模块从标准接口处崩脱、散落，底盘跪倒
	MechVisual.scatter(visual)
	var tw := create_tween()
	tw.tween_interval(0.15)
	tw.tween_property(visual.get_meta("legs"), "rotation:z", 0.5, 0.7).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(visual.get_meta("legs"), "position:y", -0.5, 0.7)
	died.emit(reason)


## 落脚瞬间：车身下沉、躯干微震、镜头轻抖、脚下扬尘
func _footfall(leg: Node3D, i: int) -> void:
	var w := gait_amt
	_step_dip_v -= 1.3 * w
	kick_v += Vector3(0.35, 0.0, 0.5 if i == 0 else -0.5) * w
	if raid:
		raid.shake = maxf(raid.shake, 0.06 * w)
		var aj: Node3D = leg.get_meta("ankle")
		var fp := aj.global_position
		Audio.play_sfx("step_biped", fp, {"vol": lerpf(-8.0, 0.0, clampf(w, 0.0, 1.0))})
		A.burst(raid.fx, Vector3(fp.x, 0.15, fp.z), {"amount": 5, "life": 0.9, "size": 0.9, "tex": A.smoke_tex(), "additive": false, "dir": Vector3(0, 0.2, 0),
			"spread": 90.0, "vmin": 1.0, "vmax": 2.2, "gravity": Vector3(0, 0.3, 0), "damp": 3.0, "radius": 0.25,
			"c0": Color(0.72, 0.66, 0.56, 0.55), "c1": Color(0.68, 0.62, 0.54, 0.0), "grow0": 0.5, "grow1": 1.6})


## 推进飞行：点火起跳
func _thrust_start() -> void:
	velocity = Vector3(velocity.x, 0, velocity.z)
	land_t = 0.18   # 起跳前微蹲
	_thrust_clear()
	for sx in [-0.42, 0.42]:
		var f := A.emitter(self, Vector3.ZERO, {"amount": 34, "life": 0.22, "size": 0.75, "spread": 9.0, "vmin": 9.0, "vmax": 13.0, "gravity": Vector3.ZERO,
			"c0": Color(1.0, 0.95, 0.8), "cmid": Color(1.0, 0.62, 0.22, 0.9), "c1": Color(0.7, 0.2, 0.05, 0.0), "grow0": 0.6, "grow1": 1.3})
		f.set_meta("sx", sx)
		_thrusters.append(f)
	var sm := A.emitter(self, Vector3.ZERO, {"amount": 26, "life": 1.0, "size": 1.4, "tex": A.smoke_tex(), "additive": false, "spread": 25.0, "vmin": 2.0, "vmax": 4.0,
		"gravity": Vector3(0, 0.6, 0), "c0": Color(0.8, 0.77, 0.72, 0.45), "c1": Color(0.75, 0.72, 0.68, 0.0), "grow0": 0.5, "grow1": 2.0})
	sm.set_meta("sx", 0.0)
	sm.set_meta("smoke", true)
	_thrusters.append(sm)
	if raid:
		var p := global_position
		A.burst(raid.fx, Vector3(p.x, 0.2, p.z), {"amount": 14, "life": 1.0, "size": 1.6, "tex": A.smoke_tex(), "additive": false, "dir": Vector3(1, 0, 0), "spread": 180.0,
			"vmin": 4.0, "vmax": 7.0, "gravity": Vector3(0, 0.4, 0), "damp": 5.0, "c0": Color(0.74, 0.68, 0.58, 0.7), "c1": Color(0.7, 0.64, 0.56, 0.0), "grow0": 0.5, "grow1": 2.0}).flatness = 0.9
		raid.shake = maxf(raid.shake, 0.12)


## 推进飞行过程：速度先快速拉起再滑翔减速，机身离地抛物线，喷口始终朝飞行反方向
func _thrust_fly(delta: float) -> void:
	var u := clampf(1.0 - dash_time / DASH_DUR, 0.0, 1.0)
	var prof := sin(minf(u * 1.6, 1.0) * PI * 0.5) * (1.0 - smoothstep(0.55, 1.0, u) * 0.75)
	var dsp := 15.0 * prof
	velocity.x = dash_dir.x * dsp
	velocity.z = dash_dir.z * dsp
	legs.rotation.y = lerp_angle(legs.rotation.y, atan2(-dash_dir.x, -dash_dir.z), clampf(12.0 * delta, 0.0, 1.0))
	legs.rotation.x = lerp(legs.rotation.x, -0.22 * sin(u * PI), clampf(10.0 * delta, 0.0, 1.0))
	visual.position.y = pow(sin(u * PI), 0.75) * 1.3
	var side := dash_dir.cross(Vector3.UP).normalized()
	for f in _thrusters:
		if not is_instance_valid(f):
			continue
		var sx: float = f.get_meta("sx")
		f.position = -dash_dir * 0.55 + side * sx + Vector3(0, visual.position.y + (1.0 if f.has_meta("smoke") else 2.1), 0)
		f.direction = (-dash_dir + Vector3(0, -0.55, 0)).normalized()
	if dash_time <= 0.0:
		_thrust_land()


func _thrust_land() -> void:
	visual.position.y = 0.0
	legs.rotation.x = 0.0
	land_t = 0.45
	Audio.play_sfx("mech_land", global_position)
	_step_dip_v -= 1.6
	kick_v += Vector3(1.4, 0, 0)
	_thrust_clear()
	if raid:
		raid.shake = maxf(raid.shake, 0.18)
		var p := global_position
		A.burst(raid.fx, Vector3(p.x, 0.2, p.z), {"amount": 12, "life": 1.1, "size": 1.5, "tex": A.smoke_tex(), "additive": false, "dir": Vector3(1, 0, 0), "spread": 180.0,
			"vmin": 3.0, "vmax": 6.0, "gravity": Vector3(0, 0.4, 0), "damp": 5.0, "c0": Color(0.74, 0.68, 0.58, 0.7), "c1": Color(0.7, 0.64, 0.56, 0.0), "grow0": 0.5, "grow1": 2.0}).flatness = 0.9


func _thrust_clear() -> void:
	for f in _thrusters:
		if is_instance_valid(f):
			f.emitting = false
			get_tree().create_timer(1.2).timeout.connect(f.queue_free)
	_thrusters.clear()
