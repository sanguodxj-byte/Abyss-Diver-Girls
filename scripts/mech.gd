extends CharacterBody3D
## 玩家机甲：下半身跟移动方向，上半身跟鼠标（双摇杆式），左右键分别控制左右臂。

const Prof = preload("res://scripts/prof.gd")

const MechVisual = preload("res://scripts/mech_visual.gd")
const A = preload("res://scripts/art.gd")
const WeaponFX = preload("res://scripts/modules/weapon_fx.gd")
const Status = preload("res://scripts/modules/status.gd")
const SlowWeb = preload("res://scripts/modules/slow_web.gd")
const Growth = preload("res://scripts/progression/growth.gd")

signal died(reason: String)
signal message(text: String)
signal fired(slot: String)          ## HUD：子弹栏整体下滑
signal reloaded(slot: String)       ## HUD：子弹逐颗落回弹槽

var raid
var net_peer := 1
var net_move := Vector2.ZERO
var net_fire := 0
var net_done := false
var loadout := {}
var stats := {}
var max_hp := 100.0
var hp := 100.0
var max_energy := 200.0
var energy := 200.0
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
var _shield_surge := 0.0
var _skill_dist_acc := 0.0
var _skill_energy_acc := 0.0
var _skill_shot_acc := 0.0
## 新模块带来的状态：防爆力场剩余时间与减伤比例、光学迷彩剩余时间、动力炉耗能倍率、底盘抗性
var guard_t := 0.0
var guard_ratio := 0.0
var stealth_t := 0.0
var drain_mul := 1.0
var acid_immune := false
var overload_immune := false
var emergency := 0.0          ## >0：能源耗尽后的应急倒计时
var aim_point := Vector3.ZERO
var joy_move := Vector2.ZERO  ## 手机端左摇杆移动向量（-1..1）
var joy_aim := Vector2.ZERO   ## 手机端右摇杆瞄准/开火向量（-1..1）
var input_locked := false
var dead := false
var walk_phase := 0.0
var hurt_flash := 0.0
## 弹匣（实体物品：装填消耗一个，打空即消失）
var ammo := {"arm_l": 0, "arm_r": 0}
var mag := {"arm_l": 0, "arm_r": 0}
var reload_t := {"arm_l": 0.0, "arm_r": 0.0}
## 缺弹提示冷却，避免每次扣扳机都刷一条消息
## 部位完好度 0~1（HUD 全息投影着色；0 = 部位缺失，失去对应功能）
var parts := {"core": 1.0, "legs": 1.0, "arm_l": 1.0, "arm_r": 1.0, "back": 1.0, "gen": 1.0}
const PART_W := {"core": 0.3, "legs": 0.24, "arm_l": 0.13, "arm_r": 0.13, "back": 0.1, "gen": 0.1}
var overdrive_t := 0.0
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
var _leg_yaw := []
## 双足重型步态参数
const STRIDE := 2.45              ## 单步跨度（米）
const STANCE := 0.56              ## 支撑相占比（重型机甲脚长时间贴地）
var _foot_prev: Array = [0.0, 0.0] ## 上一帧每条腿的步态相位，用于检测落脚瞬间
var _step_dip := 0.0              ## 落脚冲击造成的车身下沉（弹簧）
var _step_dip_v := 0.0
var _torso_y := 0.0               ## 躯干高度滞后跟随（惯性）
var _torso_yv := 0.0
var _legs_prev_yaw := 0.0         ## 上一帧底盘朝向，用于计算转向角速度驱动多足转向步态
var _last_step_sfx_t := -1.0      ## 多足踏步音效节流时间戳
var _thrusters: Array = []        ## 推进飞行时的喷口粒子
var DASH_DUR := 0.6
## 音效与事件状态
var _emerg_was := false
var _alt_next := 0               ## 交替射击：0 = 优先左臂，1 = 优先右臂
var _alt_stagger_t := 0.0        ## 双臂连射交替半周期节流
var is_aiming := false           ## 右键远距观察 / 狙击镜 / 收紧散布 / 半速移动
const PLAYER_RING_COLORS := [
	Color(0.28, 0.88, 1.0, 0.62),
	Color(0.45, 0.96, 0.42, 0.62),
	Color(1.0, 0.68, 0.24, 0.62),
	Color(0.86, 0.46, 1.0, 0.62),
]
var player_ring: MeshInstance3D
var player_ring_color: Color = PLAYER_RING_COLORS[0]
var _low_warned := false
var _last_drain := 0.0            ## 上一帧实际耗能（含移动 ×1.6 / 动力炉漏电），供 HUD 剩余时间估算
var _overloaded := false
var _fire_held := {"arm_l": 0.0, "arm_r": 0.0}   ## 持续喷射类武器：距上一发的剩余保持时间，归零时停止循环音
var _quad_lift: Array = []


func setup(lo: Dictionary, carry: Array, prebuilt_visual: Node3D = null) -> void:
	loadout = lo.duplicate()
	stats = Net.stats_for(loadout, net_peer)
	max_hp = max(30.0, stats.hp)
	hp = max_hp
	max_energy = max(30.0, stats.energy)
	energy = max_energy
	_last_drain = float(stats.drain)
	cargo = carry.duplicate()
	for slot in ["arm_l", "arm_r"]:
		var wid: String = lo.get(slot, "")
		if wid != "":
			var w := str(GameData.module(wid).get("weapon", "mg"))
			if GameData.weapon_uses_ammo(w):
				mag[slot] = int(GameData.AMMO.get(w, {}).get("mag", 30))
				# 出发默认满装；装填只限制连续射击，不消耗货舱物品。
				ammo[slot] = mag[slot]
			else:
				mag[slot] = 0
				ammo[slot] = 0
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
	if prebuilt_visual != null:
		visual = prebuilt_visual
	else:
		visual = MechVisual.build(loadout)
		_batch_visual(visual)
	add_child(visual)
	_anchor_visual()
	torso = visual.get_meta("torso")
	legs = visual.get_meta("legs")
	muzzles = visual.get_meta("muzzles")
	leg_parts = visual.get_meta("leg_parts")
	leg_type = visual.get_meta("leg_type")
	torso_base_y = visual.get_meta("torso_base_y")
	shield_mesh = MeshInstance3D.new()
	shield_mesh.mesh = A.aegis_shield_mesh(1.52, 1.55, 6, 36)
	shield_mesh.material_override = A.aegis_shield_mat(Color(0.42, 0.78, 1.0, 0.88))
	shield_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shield_mesh.position.y = 1.55
	shield_mesh.visible = false
	add_child(shield_mesh)
	if get("faction") == null:
		player_ring = A.ground_vfx(self, A.player_ring_tex(), player_ring_color, 4.1, Vector3(0, 0.08, 0), false, 0.48, true, 5)
		player_ring.set_meta("player_ring", true)
	if leg_type == "tread":
		Audio.loop_start(_lk("legs"), "legs_tread_loop", self)
	_mark_occ_exempt()
	if _fp_passthrough:
		set_fp_passthrough(true)


func set_player_ring_color(c: Color) -> void:
	player_ring_color = Color(c.r, c.g, c.b, 0.62)
	if player_ring != null and is_instance_valid(player_ring) and player_ring.material_override is ShaderMaterial:
		(player_ring.material_override as ShaderMaterial).set_shader_parameter("col", player_ring_color)


## 本机甲的循环音效 key（同时存在多台机甲时互不干扰）
func _lk(what: String) -> String:
	return "mech_%d_%s" % [get_instance_id(), what]


func cargo_weight() -> float:
	return GameData.weight_of(cargo)

func cargo_cap() -> float:
	return float(stats.cargo)

func cargo_grid_rows() -> int:
	return GameData.cargo_grid_rows(cargo_cap())

func cargo_grid_cap() -> int:
	return GameData.cargo_grid_cap(cargo_cap())

func cargo_cells() -> int:
	return GameData.cargo_cells_used(cargo)

func can_fit_cargo_item(id: String) -> bool:
	if cargo_weight() + float(GameData.item(id).w) > cargo_cap() + 0.001:
		return false
	var next_c: Array = cargo.duplicate()
	next_c.append(id)
	return GameData.can_pack_cargo(next_c, cargo_cap())

func speed_mult() -> float:
	var f: float = GameData.speed_factor(stats, cargo_weight())
	if overload_immune:
		f = 1.0
	if emergency > 0.0:
		f *= 0.45
	if parts.legs <= 0.0:
		f *= 0.55
	elif float(parts.legs) < 0.5:
		# 底盘受损（完好度 < 50%）：液压管路渗漏导致渐进式减速
		f *= lerpf(0.78, 1.0, float(parts.legs) / 0.5)
	return f * (0.5 if is_aiming else 1.0)


## 人机工效倍率（0.72 ~ 1.22）：由整机人机工效 stats.ergo 决定躯干回转跟手度与装填速度
func ergo_factor() -> float:
	return clampf(0.75 + (float(stats.get("ergo", 60.0)) - 30.0) / 140.0, 0.72, 1.22)


## 手臂有效散布角（度）：手臂完好度低于 50% 时伺服电机抖动导致散布扩大（最高 +45%）；瞄准时收束弹道
func eff_spread(slot: String, base_spread: float) -> float:
	var p := float(parts.get(slot, 1.0))
	var dmg_pen := clampf((0.5 - p) / 0.5, 0.0, 1.0) * 0.45
	var aim_mul := (0.45 if is_scoping() else 0.65) if is_aiming else 1.0
	return base_spread * (1.0 + dmg_pen) * aim_mul


func has_sniper_scope() -> bool:
	for slot in ["arm_l", "arm_r"]:
		var id := str(loadout.get(slot, ""))
		if id != "" and float(parts.get(slot, 1.0)) > 0.0:
			var m: Dictionary = GameData.module(id)
			if bool(m.get("scope", false)) or str(m.get("weapon", "")) == "sniper":
				return true
	return false


func is_scoping() -> bool:
	return is_aiming and not dead and not net_done and not input_locked and has_sniper_scope()


## 手臂实际装填耗时（秒）：受人机工效加成，且手臂受损低于 50% 时供弹导轨卡滞（最高延长 35%）
func _reload_dur(slot: String) -> float:
	var id: String = loadout.get(slot, "")
	if id == "":
		return 1.8
	var w: String = GameData.module(id).weapon
	if not GameData.weapon_uses_ammo(w):
		return 1.8
	var base := float(GameData.AMMO[w].reload)
	var p := float(parts.get(slot, 1.0))
	var dmg_pen := clampf((0.5 - p) / 0.5, 0.0, 1.0) * 0.35
	var elite_mul := 0.85 if (_is_local_actor() and Growth.ability_elite("ab_firearm")) else 1.0
	return base / ergo_factor() * (1.0 + dmg_pen) * elite_mul


func _is_local_actor() -> bool:
	return not net_done and net_peer == Net.local_id()


func refresh_growth_stats() -> void:
	var old_max_hp := max_hp
	var old_max_en := max_energy
	stats = Net.stats_for(loadout, net_peer)
	_last_drain = float(stats.drain)
	max_hp = maxf(30.0, float(stats.hp))
	max_energy = maxf(30.0, float(stats.energy))
	if max_hp > old_max_hp and hp > 0.0:
		hp = minf(max_hp, hp + (max_hp - old_max_hp))
		parts.core = hp / max_hp
	if max_energy > old_max_en:
		energy = minf(max_energy, energy + (max_energy - old_max_en))

func energy_seconds_left() -> float:
	return energy / max(0.01, _last_drain if _last_drain > 0.0 else float(stats.drain))


var _shown_damage := -1.0

func _physics_process(delta: float) -> void:
	var _pt := Prof.t0()
	if raid != null and raid.coop != null and Net.is_client():
		return
	var local_mech = raid.mech if raid != null else null
	if raid != null and net_peer > 1: raid.mech = self
	_physics_tick(delta)
	if raid != null: raid.mech = local_mech
	Prof.add(_prof_key(), _pt)


func _prof_key() -> String:
	return "phys.mech"


func _physics_tick(delta: float) -> void:
	if net_done: return
	var dmg_now := clampf(1.0 - hp / max_hp, 0.0, 1.0)
	if net_peer == Net.local_id() and absf(dmg_now - _shown_damage) > 0.01:
		_shown_damage = dmg_now
		RenderingServer.global_shader_parameter_set("mech_damage", dmg_now)
	if dead:
		is_aiming = false
		return
	for k in arm_cd:
		arm_cd[k] = max(0.0, arm_cd[k] - delta)
	_alt_stagger_t = maxf(0.0, _alt_stagger_t - delta)
	ability_cd = max(0.0, ability_cd - delta)
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
	dash_cd = max(0.0, dash_cd - delta)
	hurt_flash = max(0.0, hurt_flash - delta)
	if shield_time > 0.0:
		shield_time -= delta
		shield_mesh.visible = shield_time > 0.0
		if shield_time <= 0.0:
			_shield_surge = 0.0
			Audio.play_sfx("shield_down", global_position + Vector3(0, 1.6, 0))
	if shield_mesh.visible:
		shield_mesh.rotation.y += delta * 0.55
		_shield_surge = maxf(0.0, _shield_surge - delta * 4.2)
		var smat := shield_mesh.material_override as ShaderMaterial
		if smat != null:
			smat.set_shader_parameter("surge", _shield_surge)
			var fade := clampf(shield_time / 0.4, 0.25, 1.0) if shield_time > 0.0 else 0.75
			smat.set_shader_parameter("fade", fade)
	_audio_tick()

	if raid and raid.dropping:
		# 空投中由 raid 的补间控制位置，不叠加重力
		is_aiming = false
		velocity = Vector3.ZERO
		_vis_sync()
		_animate(delta, Vector3.ZERO)
		return
	var move := move_vec()

	var spd: float = float(stats.speed) * speed_mult()
	if dash_time > 0.0 and leg_type == "biped":
		dash_time -= delta
		_thrust_fly(delta)
	elif dash_time > 0.0:
		dash_time -= delta
		var dsp := 19.0
		if leg_type == "tread":
			dsp = 19.0
		elif leg_type == "quad":
			dsp = 15.0
			visual.position.y = sin(clampf(1.0 - dash_time / 0.5, 0.0, 1.0) * PI) * 1.9
		elif leg_type == "hex":
			dsp = 14.0
			visual.position.y = sin(clampf(1.0 - dash_time / 0.46, 0.0, 1.0) * PI) * 1.15
		velocity.x = dash_dir.x * dsp
		velocity.z = dash_dir.z * dsp
		if dash_time <= 0.0:
			visual.position.y = 0.0
			land_t = 0.35 if leg_type in ["quad", "tread", "hex"] else 0.2
			var sk: Dictionary = GameData.SKILLS.get(leg_type, {})
			if sk.has("dmg"):
				raid.explode(global_position, float(sk.r), float(sk.dmg), "mech_slam", _is_local_actor())
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
	var _t1 := Prof.t0()
	var pos_before := global_position
	move_and_slide()
	if _is_local_actor():
		var step_d := Vector2(global_position.x - pos_before.x, global_position.z - pos_before.z).length()
		if step_d > 0.001 and step_d < 10.0:
			_skill_dist_acc += step_d
			if _skill_dist_acc >= 10.0:
				_skill_dist_acc -= 10.0
				Growth.record_skill_xp("ab_servo", 0.9)
				var load_ratio: float = (float(stats.get("mass", 0.0)) + cargo_weight()) / maxf(1.0, float(stats.get("load", 50.0)))
				if load_ratio >= 0.65:
					Growth.record_skill_xp("ab_rack", 1.6 if load_ratio > 1.0 else 1.0)
	_vis_sync()
	Prof.add("mech.move_and_slide", _t1)

	# 下半身朝移动方向，上半身朝鼠标
	if move != Vector3.ZERO:
		legs.rotation.y = lerp_angle(legs.rotation.y, atan2(-move.x, -move.z), clamp((5.0 if leg_type == "biped" else 10.0) * delta, 0.0, 1.0))
	var to := aim_point - global_position
	to.y = 0.0
	if to.length() > 0.6:
		torso.rotation.y = lerp_angle(torso.rotation.y, atan2(-to.x, -to.z), clamp(TORSO_TURN * ergo_factor() * delta, 0.0, 1.0))  # 上半身转向受人机工效影响
	var _t2 := Prof.t0()
	_animate(delta, move)
	if _is_local_actor() and raid != null and raid.has_method("sync_fp_camera"):
		raid.sync_fp_camera()
	Prof.add("mech.anim", _t2)

	# 能源（动力炉受损低于 50% 时出现渐进漏电，损毁时漏电 +50%）
	var gen_pen := 1.5 if parts.gen <= 0.0 else (lerpf(1.25, 1.0, float(parts.gen) / 0.5) if float(parts.gen) < 0.5 else 1.0)
	var drain: float = float(stats.drain) * drain_mul * (1.6 if move != Vector3.ZERO else 1.0) * gen_pen
	_last_drain = drain
	if emergency > 0.0:
		emergency -= delta
		if energy > 1.0:
			emergency = 0.0
			message.emit(Loc.t("主电源回路重启，退出应急模式", "Main reactor restarted — emergency mode cleared"))
		elif emergency <= 0.0:
			die(Loc.t("能源耗尽，机甲瘫痪", "Energy depleted — mech immobilized"))
			return
	else:
		use_energy(drain * delta)
	_energy_watch()

	if input_locked:
		is_aiming = false
		return
	var map_on: bool = raid != null and raid.hud != null and raid.hud.map_open()
	var hud_busy: bool = raid != null and raid.hud != null and raid.hud.is_touch_busy()
	var touch_aim: bool = raid != null and raid.hud != null and raid.hud.has_method("is_touch_aiming") and raid.hud.is_touch_aiming()
	var joy_firing: bool = (raid != null and raid.hud != null and raid.hud.has_method("is_touch_firing") and raid.hud.is_touch_firing()) or (joy_aim.length() >= 0.48)
	if raid != null and raid.coop != null:
		if _is_local_actor() and not Net.is_host():
			var blocked_cli: bool = map_on or raid.hud.pause_panel.visible or raid.hud.settings_panel.visible or Story.flow.is_playing()
			is_aiming = (not blocked_cli) and (((not hud_busy) and Input.is_action_pressed("fire_right")) or touch_aim)
			return
		if net_peer > 1:
			is_aiming = (net_fire & 2) != 0
			if net_fire & 1:
				fire_alternating(false)
			return
		if raid.hud.pause_panel.visible or raid.hud.settings_panel.visible or Story.flow.is_playing():
			is_aiming = false
			return
	is_aiming = (not map_on) and (((not hud_busy) and Input.is_action_pressed("fire_right")) or touch_aim)
	var fire_just: bool = (not map_on) and (not hud_busy) and Input.is_action_just_pressed("fire_left")
	var fire_held: bool = (not map_on) and ((Input.is_action_pressed("fire_left") and not hud_busy) or joy_firing)
	if fire_held:
		var _t3 := Prof.t0()
		fire_alternating(fire_just)
		Prof.add("mech.fire", _t3)
	else:
		_alt_stagger_t = 0.0
	if Input.is_action_just_pressed("dash"):
		try_dash(move)
	if Input.is_action_just_pressed("ability"):
		try_ability()
	if Input.is_action_just_pressed("reload"):
		reload_all()
	if Input.is_action_just_pressed("use_fuel"):
		use_item("fuel_cell")
	if Input.is_action_just_pressed("use_repair"):
		use_item("repair_kit")


func move_vec() -> Vector3:
	if net_done: return Vector3.ZERO
	if raid != null and raid.coop != null:
		if net_peer > 1 and Net.is_host():
			return Vector3(net_move.x, 0, net_move.y) if not input_locked else Vector3.ZERO
		if raid.hud.pause_panel.visible or raid.hud.settings_panel.visible or Story.flow.is_playing(): return Vector3.ZERO
	if input_locked:
		return Vector3.ZERO
	var in_x := 0.0
	var in_z := 0.0
	if joy_move.length() > 0.12:
		in_x = joy_move.x
		in_z = joy_move.y
	else:
		in_x = Input.get_axis("move_left", "move_right")
		in_z = Input.get_axis("move_up", "move_down")
	if Vector2(in_x, in_z).length() <= 0.1:
		return Vector3.ZERO
	if _is_local_actor() and raid != null and raid.has_method("is_first_person") and raid.is_first_person():
		var cam_fwd: Vector3 = raid.fp_forward_xz()
		var cam_right := Vector3(-cam_fwd.z, 0.0, cam_fwd.x)
		var m_fp: Vector3 = cam_fwd * (-in_z) + cam_right * in_x
		return m_fp.normalized() if m_fp.length() > 0.01 else Vector3.ZERO
	var move := Vector3(in_x, 0.0, in_z)
	return move.normalized()


func reload_all() -> void:
	if _net_action("reload", []): return
	start_reload("arm_l")
	start_reload("arm_r")


func _animate(delta: float, move: Vector3) -> void:
	var hv := Vector3(velocity.x, 0, velocity.z)
	var sp := hv.length()
	var top: float = maxf(float(stats.speed) * 0.55, 1.0)
	var yaw_rate := wrapf(legs.rotation.y - _legs_prev_yaw, -PI, PI) / maxf(delta, 0.001)
	_legs_prev_yaw = legs.rotation.y
	var turn_amt := clampf(absf(yaw_rate) / 3.0, 0.0, 0.68) if leg_type in ["quad", "hex"] else 0.0
	var target_gait := maxf(clampf(sp / top, 0.0, 1.0), turn_amt)
	gait_amt = move_toward(gait_amt, target_gait, delta * 5.5)
	land_t = maxf(0.0, land_t - delta)
	slam = move_toward(slam, 0.0, delta * 0.75)
	idle_t += delta
	# 躯干弹簧（后坐 / 受击抖动）
	kick_v += (-kick * 120.0 - kick_v * 14.0) * delta
	kick += kick_v * delta
	var crouch := 0.0
	var bob := 0.0
	var dashing := dash_time > 0.0
	var sl := slam * slam * (3.0 - 2.0 * slam)
	if _foot_prev.size() != leg_parts.size():
		_foot_prev.resize(leg_parts.size())
		_foot_prev.fill(0.0)
	match leg_type:
		"biped":
			if dashing:
				# 推进飞行：双腿收起、向后拖
				var air := sin(clampf(1.0 - dash_time / DASH_DUR, 0.0, 1.0) * PI)
				for i in leg_parts.size():
					_biped_leg(leg_parts[i], 0.0, 0.0, 0.18 + air * 0.32, Vector2(0.35 * air + (0.12 if i == 0 else -0.08) * air, 0.0), 0.0)
				legs.rotation.z = lerp(legs.rotation.z, 0.0, clampf(8.0 * delta, 0.0, 1.0))
			else:
				# 重型步态：长支撑相、高抬腿、落脚冲击下沉 + 左右重心转移
				gait_phase += delta * sp * STANCE / STRIDE * TAU
				crouch = 0.24 * gait_amt + land_t * 0.5 + sl * 0.42
				for i in leg_parts.size():
					var ph := gait_phase + PI * i
					var t := fposmod(ph, TAU) / TAU
					if t < float(_foot_prev[i]) - 0.5 and gait_amt > 0.25:
						_footfall(leg_parts[i], i)
					_foot_prev[i] = t
					_biped_leg(leg_parts[i], ph, STRIDE, crouch, Vector2(-0.12, 0.0), STANCE)
				legs.rotation.z = sin(gait_phase) * 0.07 * gait_amt
			# 落脚下沉弹簧（欠阻尼，有一点回弹）
			_step_dip_v += (-_step_dip * 140.0 - _step_dip_v * 13.0) * delta
			_step_dip += _step_dip_v * delta
			bob = _step_dip
		"quad":
			if _leg_base.is_empty():
				for lp in leg_parts:
					_leg_base.append(lp.position)
					_leg_yaw.append(lp.rotation.y)
			var eff_sp := maxf(sp, absf(yaw_rate) * 1.15)
			var quad_stride := 1.42
			var quad_stance := 0.58
			gait_phase += delta * (eff_sp * quad_stance / quad_stride) * TAU
			_step_dip_v += (-_step_dip * 155.0 - _step_dip_v * 14.5) * delta
			_step_dip += _step_dip_v * delta
			var breathe_crouch := sin(idle_t * 1.8) * 0.022 * (1.0 - gait_amt)
			crouch = 0.10 * gait_amt + land_t * 0.68 + sl * 0.42 + breathe_crouch
			bob = _step_dip + sin(gait_phase * 2.0) * 0.028 * gait_amt
			var lv_q: Vector3 = legs.global_transform.basis.inverse() * hv
			# 4足相位：对角耦合伴随前后肢 0.34 rad 动力传导差 [FL(0)=0, FR(1)=PI, RL(2)=PI-0.34, RR(3)=2*PI-0.34]
			const QUAD_OFF := [0.0, PI, PI - 0.34, TAU - 0.34]
			for i in leg_parts.size():
				var ph: float = gait_phase + float(QUAD_OFF[i % 4])
				var t := fposmod(ph, TAU) / TAU
				if not dashing and t < float(_foot_prev[i]) - 0.5 and gait_amt > 0.22 and not dead:
					_quad_footfall(leg_parts[i], i)
				_foot_prev[i] = t
				_multi_leg_ik(leg_parts[i], i, ph, quad_stride, quad_stance, lv_q, yaw_rate, crouch + bob, 0.38, dashing)
			var roll_tgt := clampf(-lv_q.x * 0.012, -0.06, 0.06) + sin(gait_phase) * 0.026 * gait_amt
			var pitch_tgt := clampf(lv_q.z * 0.012, -0.07, 0.07) + cos(gait_phase) * 0.018 * gait_amt
			legs.rotation.z = lerp(legs.rotation.z, roll_tgt, clampf(10.0 * delta, 0.0, 1.0))
			legs.rotation.x = lerp(legs.rotation.x, pitch_tgt, clampf(10.0 * delta, 0.0, 1.0))
		"hex":
			if _leg_base.is_empty():
				for lp in leg_parts:
					_leg_base.append(lp.position)
					_leg_yaw.append(lp.rotation.y)
			var eff_sp_h := maxf(sp, absf(yaw_rate) * 1.20)
			var hex_stride := 1.24
			var hex_stance := 0.56
			gait_phase += delta * (eff_sp_h * hex_stance / hex_stride) * TAU
			_step_dip_v += (-_step_dip * 165.0 - _step_dip_v * 15.5) * delta
			_step_dip += _step_dip_v * delta
			var breathe_h := sin(idle_t * 1.7) * 0.018 * (1.0 - gait_amt)
			crouch = 0.08 * gait_amt + land_t * 0.58 + sl * 0.40 + breathe_h
			bob = _step_dip + sin(gait_phase * 2.0) * 0.018 * gait_amt
			var lv_h: Vector3 = legs.global_transform.basis.inverse() * hv
			# 三角交替波浪步态：组A=[FL(0), MR(3), RL(4)]，组B=[FR(1), ML(2), RR(5)]，叠加后->中->前 0.16 rad 昆虫波浪相位
			const HEX_OFF := [0.32, PI + 0.32, PI + 0.16, 0.16, 0.0, PI]
			for i in leg_parts.size():
				var ph: float = gait_phase + float(HEX_OFF[i % 6])
				var t := fposmod(ph, TAU) / TAU
				if not dashing and t < float(_foot_prev[i]) - 0.5 and gait_amt > 0.20 and not dead:
					_quad_footfall(leg_parts[i], i)
				_foot_prev[i] = t
				_multi_leg_ik(leg_parts[i], i, ph, hex_stride, hex_stance, lv_h, yaw_rate, crouch + bob, 0.30, dashing)
			var roll_h := clampf(-lv_h.x * 0.010, -0.05, 0.05) + sin(gait_phase) * 0.018 * gait_amt
			var pitch_h := clampf(lv_h.z * 0.010, -0.06, 0.06)
			legs.rotation.z = lerp(legs.rotation.z, roll_h, clampf(11.0 * delta, 0.0, 1.0))
			legs.rotation.x = lerp(legs.rotation.x, pitch_h, clampf(11.0 * delta, 0.0, 1.0))
		"tread":
			gait_phase += delta * sp * 3.0
			bob = sin(gait_phase * 2.3) * 0.015 * gait_amt
			crouch = land_t * 0.4 + sl * 0.42
			var lv2: Vector3 = legs.global_transform.basis.inverse() * hv
			legs.rotation.x = lerp(legs.rotation.x, clampf(lv2.z * 0.01, -0.08, 0.08) + (-0.08 if dashing else 0.0), clampf(4.0 * delta, 0.0, 1.0))
	if not dashing or not (leg_type in ["quad", "hex"]):
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
	# 武器后坐：手臂沿躯干后方回缩再弹回；第一人称下双臂随视线俯仰角同步俯仰
	var mods: Dictionary = visual.get_meta("modules")
	var arm_pitch := 0.0
	if _fp_passthrough and raid != null and "fp_pitch" in raid:
		arm_pitch = clampf(float(raid.fp_pitch) * 0.75, deg_to_rad(-42.0), deg_to_rad(46.0))
	for slot in recoil:
		recoil[slot] = maxf(0.0, recoil[slot] - delta * 9.0)
		var arm: Node3D = mods.get(slot)
		if arm and is_instance_valid(arm) and arm.get_parent():
			var back: Vector3 = (arm.get_parent().global_transform.basis.inverse() * (torso.global_transform.basis * Vector3(0, 0, 1))).normalized()
			var r: float = recoil[slot]
			arm.position = back * 0.2 * r * r
			arm.rotation.x = arm_pitch
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


## 四足/六足三维速度耦合步态与二段解析 IK：基节偏航摆动 + 股节/胫节余弦定理解算 + 踝部驻锄水平抓地
func _multi_leg_ik(leg: Node3D, idx: int, ph: float, stride: float, stance: float, lv_legs: Vector3, yaw_rate: float, crouch: float, lift_max: float, dashing: bool) -> void:
	if _leg_base.size() > idx:
		leg.position = _leg_base[idx]
	leg.rotation.x = 0.0
	leg.rotation.z = 0.0
	if not leg.has_meta("femur") or not leg.has_meta("knee") or not leg.has_meta("ankle"):
		return
	var fm: Node3D = leg.get_meta("femur")
	var kj: Node3D = leg.get_meta("knee")
	var aj: Node3D = leg.get_meta("ankle")
	var KN: Vector3 = leg.get_meta("KN")
	var AN: Vector3 = leg.get_meta("AN")
	var base_yaw: float = float(leg.get_meta("base_yaw"))
	var R0 := maxf(AN.z, 0.25)
	var rest_dir := Vector2(sin(base_yaw), cos(base_yaw))
	var hip_xz := Vector2(leg.position.x, leg.position.z)
	var foot_rest_xz := hip_xz + rest_dir * R0
	# 合成足端在底盘局部空间中的线速度与转向切向速度
	var v_lin := Vector2(lv_legs.x, lv_legs.z)
	var v_turn := Vector2(-yaw_rate * foot_rest_xz.y, yaw_rate * foot_rest_xz.x)
	var v_tot := v_lin + v_turn
	var move_dir := Vector2(0.0, -1.0)
	if v_tot.length() > 0.12:
		move_dir = v_tot.normalized()
	var step_vec := Vector2.ZERO
	var dy := 0.0
	var foot_pitch := 0.0
	if dashing:
		var dash_dur := 0.50 if leg_type == "quad" else 0.46
		var u_d := clampf(1.0 - dash_time / dash_dur, 0.0, 1.0)
		var air := sin(u_d * PI)
		var fore_sgn := -1.0 if leg.position.z < 0.0 else (1.0 if leg.position.z > 0.0 else 0.0)
		if u_d < 0.25:
			# 起跳蹬伸：足端向后下方猛蹬
			var k_push := u_d / 0.25
			step_vec = -move_dir * (0.34 * k_push)
			dy = -0.22 * k_push
			foot_pitch = -0.28 * k_push
		elif u_d < 0.72:
			# 腾空收腿：前肢前探蓄势、后肢向后收拢，膝盖高折
			step_vec = move_dir * (-0.28 * fore_sgn) + rest_dir * (-0.12 * air)
			dy = 0.36 * air
			foot_pitch = 0.24 * air
		else:
			# 落地缓冲前伸：四/六足向外前张准备砸地驻锄
			var k_land := (u_d - 0.72) / 0.28
			step_vec = move_dir * (0.24 * (1.0 - k_land)) + rest_dir * (0.14 * sin(k_land * PI))
			dy = 0.20 * (1.0 - k_land)
			foot_pitch = 0.18 * (1.0 - k_land)
	else:
		var t := fposmod(ph, TAU) / TAU
		var s_len := stride * 0.46 * gait_amt
		if t < stance:
			# 支撑相：足掌锁死地面，相对车体从前向后匀速滑掠，中段微沉承重，末段踝部蹬地
			var u := t / stance
			step_vec = move_dir * lerpf(s_len, -s_len, u)
			dy = -sin(u * PI) * 0.035 * gait_amt
			foot_pitch = -0.22 * smoothstep(0.72, 1.0, u) * gait_amt
		else:
			# 摆动相：非对称摆线快抬腿、高折膝、向外微张绕障、前伸砸地
			var u := (t - stance) / maxf(1.0 - stance, 0.01)
			var e := u * u * (3.0 - 2.0 * u)
			var out_arc := sin(u * PI) * 0.09 * gait_amt
			step_vec = move_dir * lerpf(-s_len, s_len, e) + rest_dir * out_arc
			dy = pow(sin(u * PI), 0.76) * lift_max * (1.0 - 0.22 * u) * gait_amt
			foot_pitch = (0.28 * sin(u * PI) - 0.16 * smoothstep(0.74, 1.0, u)) * gait_amt
	var target_xz := rest_dir * R0 + step_vec
	var new_yaw := atan2(target_xz.x, target_xz.y)
	var dyaw := clampf(wrapf(new_yaw - base_yaw, -PI, PI), -0.44, 0.44)
	leg.rotation.y = base_yaw + dyaw
	var r_reach := clampf(target_xz.length(), R0 * 0.56, R0 * 1.38)
	var y_reach := AN.y + dy + crouch
	var T := Vector2(r_reach, y_reach)
	var L1 := Vector2(KN.z, KN.y).length()
	var L2 := Vector2(AN.z - KN.z, AN.y - KN.y).length()
	var d := clampf(T.length(), absf(L1 - L2) + 0.015, L1 + L2 - 0.004)
	var th := atan2(T.y, T.x)
	var alpha := acos(clampf((L1 * L1 + d * d - L2 * L2) / maxf(2.0 * L1 * d, 0.0001), -1.0, 1.0))
	var th0 := atan2(AN.y, AN.z)
	var p1_0 := atan2(KN.y, KN.z)
	var sgn := 1.0 if wrapf(p1_0 - th0, -PI, PI) > 0.0 else -1.0
	var p1 := th + sgn * alpha
	var kp := Vector2(cos(p1), sin(p1)) * L1
	var p2 := atan2(T.y - kp.y, T.x - kp.x)
	var p2_0 := atan2(AN.y - KN.y, AN.z - KN.z)
	var r_femur := p1_0 - p1
	var r_knee := p2_0 - p2 - r_femur
	fm.rotation.x = r_femur
	kj.rotation.x = r_knee
	aj.rotation.x = -(r_femur + r_knee) + foot_pitch


func use_energy(amount: float) -> void:
	if emergency > 0.0 or dead:
		return
	energy -= amount
	if _is_local_actor() and amount > 0.0:
		_skill_energy_acc += amount
		if _skill_energy_acc >= 10.0:
			var ticks := int(_skill_energy_acc / 10.0)
			_skill_energy_acc -= float(ticks) * 10.0
			Growth.record_skill_xp("ab_reactor", 0.85 * float(ticks))
	if energy <= 0.0:
		energy = 0.0
		emergency = 15.0
		message.emit(Loc.t("▲ 动力炉断电 · 应急电源维持 15 秒", "▲ Reactor offline — emergency power for 15s"))
		Audio.play_sfx("energy_emergency")
		Audio.loop_start(_lk("alarm"), "energy_alarm_loop", self, {"d3": false})
		_event("emergency_entered", [])


## 应急模式的退出（恢复能源）与低能源告警；每个物理帧在扣能之后调用
func _energy_watch() -> void:
	var em := emergency > 0.0
	if _emerg_was and not em and not dead:
		Audio.loop_stop(_lk("alarm"))
		Audio.play_sfx("energy_restored")
		_event("emergency_exited", [])
	_emerg_was = em
	var left := energy_seconds_left()
	if not _low_warned and not em and left < 45.0:
		_low_warned = true
		Audio.play_sfx("energy_low")
		_event("energy_low", [left])
	elif _low_warned and left > 60.0:
		_low_warned = false


func can_spend(amount: float) -> bool:
	return emergency <= 0.0 and energy >= amount


func _arm_ready(slot: String) -> bool:
	var id: String = loadout.get(slot, "")
	if id == "" or arm_cd[slot] > 0.0 or parts[slot] <= 0.0 or reload_t[slot] > 0.0:
		return false
	var m: Dictionary = GameData.module(id)
	var w := str(m.get("weapon", "mg"))
	if GameData.weapon_uses_ammo(w) and ammo[slot] <= 0:
		return false
	return can_spend(GameData.shot_energy_cost(m))

func _arm_active(slot: String) -> bool:
	return str(loadout.get(slot, "")) != "" and float(parts.get(slot, 1.0)) > 0.0


## 交替射击：左键点击/按住轮流触发左臂与右臂武装（单臂可用/另一臂冷却时自动接管）
func fire_alternating(force_click := false) -> void:
	if not force_click and _alt_stagger_t > 0.0:
		return
	var primary := "arm_l" if _alt_next == 0 else "arm_r"
	var secondary := "arm_r" if _alt_next == 0 else "arm_l"
	# 主次槽位均空弹且未在装填时先触发装填（仅实弹武器有弹匣）
	for sl in [primary, secondary]:
		var mid := str(loadout.get(sl, ""))
		if mid != "" and float(parts.get(sl, 1.0)) > 0.0 and GameData.weapon_uses_ammo(str(GameData.module(mid).get("weapon", "mg"))) and ammo[sl] <= 0 and reload_t[sl] <= 0.0:
			start_reload(sl)
	var chosen := ""
	if _arm_ready(primary):
		chosen = primary
	elif _arm_ready(secondary):
		chosen = secondary
	if chosen == "":
		return
	try_fire(chosen)
	var other := "arm_r" if chosen == "arm_l" else "arm_l"
	if _arm_active(other):
		_alt_next = 1 if chosen == "arm_l" else 0
		var om: Dictionary = GameData.module(str(loadout.get(other, "")))
		var o_half := 0.5 / maxf(float(om.get("rate", 1.0)), 0.5)
		_alt_stagger_t = minf(arm_cd[chosen] * 0.5, o_half)
	else:
		_alt_stagger_t = 0.0

func try_fire(slot: String) -> void:
	var id: String = loadout.get(slot, "")
	if id == "" or arm_cd[slot] > 0.0 or parts[slot] <= 0.0 or reload_t[slot] > 0.0:
		return
	if emergency > 0.0:
		return
	var m: Dictionary = GameData.module(id)
	var w := str(m.get("weapon", "mg"))
	var uses_ammo := GameData.weapon_uses_ammo(w)
	if uses_ammo and ammo[slot] <= 0:
		start_reload(slot)
		return
	var en_cost := GameData.shot_energy_cost(m)
	if en_cost > 0.0:
		if not can_spend(en_cost):
			return
		use_energy(en_cost)
	arm_cd[slot] = 1.0 / float(m.rate) / (2.0 if overdrive_t > 0.0 else 1.0)
	recoil[slot] = 1.0
	var kick_mul := 1.8 if w == "sniper" else (1.6 if w in ["shotgun", "cannon"] else 1.0)
	kick_v += Vector3(-0.9 if w != "flamer" else -0.2, (0.5 if slot == "arm_l" else -0.5), 0.0) * kick_mul
	var muzzle: Node3D = muzzles[slot]
	var origin := muzzle.global_position
	var fp_fire: bool = _is_local_actor() and raid != null and raid.has_method("is_first_person") and raid.is_first_person()
	if fp_fire:
		origin.y = clampf(origin.y, global_position.y + 0.55, global_position.y + 3.2)
	else:
		origin.y = clamp(origin.y, 1.2, 2.6)
	_fire_sfx(slot, w, origin)
	if uses_ammo and overdrive_t <= 0.0:
		ammo[slot] -= 1
		if ammo[slot] <= 0:
			Audio.play_sfx("wpn_empty", origin)
			start_reload(slot)
	fired.emit(slot)
	# 子弹沿躯干实际朝向射出（躯干转向有惯性，准星内圈显示真实落点）；所有武器统一发射实体弹药
	var dir := aim_dir()
	var to_aim := aim_point - origin
	if aim_point != Vector3.ZERO and to_aim.length() > 1.0:
		# 从实际枪口指向准星，修正肩侧枪口在远距离的横向偏移
		dir = to_aim.normalized()
	if _is_local_actor():
		_skill_shot_acc += 0.16 if float(m.get("rate", 1.0)) >= 8.0 else (0.35 if float(m.get("rate", 1.0)) >= 2.2 else 0.72)
		if _skill_shot_acc >= 1.2:
			_skill_shot_acc -= 1.2
			Growth.record_skill_xp("ab_firearm", 0.72)
	var ws = ext_script(GameData.AMMO.get(str(m.weapon), {}))
	if ws != null:
		ws.fire(self, slot, origin, dir, m)
		return
	var n: int = int(m.get("pellets", 1))
	var sp := eff_spread(slot, float(m.get("spread", 0.25)))
	var right_ax := dir.cross(Vector3.UP)
	right_ax = right_ax.normalized() if right_ax.length_squared() > 0.001 else Vector3.RIGHT
	var up_ax := right_ax.cross(dir).normalized()
	for i in n:
		var a := deg_to_rad(randf_range(-sp, sp) * 0.5)
		var shot_dir := dir.rotated(Vector3.UP, a)
		if absf(dir.y) > 0.02 or fp_fire:
			var b := deg_to_rad(randf_range(-sp, sp) * 0.35)
			shot_dir = dir.rotated(up_ax, a).rotated(right_ax, b).normalized()
		raid.spawn_projectile(origin, shot_dir, m, true)
	var noise_r := 16.0 if w == "laser" else (12.0 if w == "flamer" else (30.0 if w in ["cannon", "launcher"] else (10.0 if w == "melee" else 24.0)))
	raid.alert_noise(global_position, noise(noise_r))
	if w != "melee":
		raid.muzzle_flash(origin, m.color, dir, w, float(m.get("dmg", 10.0)))

## 开火音效：fire_loop 类武器（弹匣表里标注）按住扳机时持续循环，其余每发一次 wpn_<weapon>_fire
func _fire_sfx(slot: String, weapon: String, origin: Vector3) -> void:
	var am: Dictionary = GameData.AMMO.get(weapon, {})
	if bool(am.get("fire_loop", false)):
		if _fire_held[slot] <= 0.0:
			Audio.play_sfx("wpn_%s_ignite" % weapon, origin)
			Audio.loop_start(_lk("fire_" + slot), "wpn_%s_loop" % weapon, self)
		_fire_held[slot] = maxf(0.15, arm_cd[slot] * 2.5)
	else:
		Audio.play_sfx(str(am.get("sfx", "wpn_%s_fire" % weapon)), origin)


## 躯干实际发射朝向：水平保留躯干转向惯性，第一人称或显著高低差瞄准时合成垂直俯仰角
func aim_dir() -> Vector3:
	var d := -torso.global_transform.basis.z
	d.y = 0.0
	if d.length() < 0.01:
		d = Vector3.FORWARD
	else:
		d = d.normalized()
	var pitched: bool = (_is_local_actor() and raid != null and raid.has_method("is_first_person") and raid.is_first_person()) or absf(aim_point.y - (global_position.y + 1.8)) > 0.35
	if pitched:
		var ref_p := torso.global_position + Vector3(0.0, 0.28, 0.0)
		var to_aim := aim_point - ref_p
		var h_len := maxf(Vector2(to_aim.x, to_aim.z).length(), 0.6)
		var pitch_ang := clampf(atan2(to_aim.y, h_len), deg_to_rad(-55.0), deg_to_rad(55.0))
		return (d * cos(pitch_ang) + Vector3.UP * sin(pitch_ang)).normalized()
	return d


## 开火噪音半径：光学迷彩 / 静默滑步期间只剩很近的虫群能听见；战术撤收精英专精降低 15% 开火警觉半径
func noise(radius: float) -> float:
	var elite_mul := 0.85 if (_is_local_actor() and Growth.ability_elite("ab_covert")) else 1.0
	return radius * (0.2 if stealth_t > 0.0 else 1.0) * elite_mul


func start_reload(slot: String) -> void:
	var id: String = loadout.get(slot, "")
	if id == "" or reload_t[slot] > 0.0 or ammo[slot] >= mag[slot]:
		return
	var w: String = GameData.module(id).weapon
	if not GameData.weapon_uses_ammo(w):
		return
	reload_t[slot] = _reload_dur(slot)
	if _is_local_actor():
		Growth.record_skill_xp("ab_firearm", 0.42)
	if w == "sniper":
		Audio.play_sfx(["wpn_sniper_reload", "wpn_mg_reload"], global_position + Vector3(0, 2.0, 0))
	else:
		Audio.play_sfx("wpn_%s_reload" % w, global_position + Vector3(0, 2.0, 0))

func reload_frac(slot: String) -> float:
	var id: String = loadout.get(slot, "")
	if id == "" or reload_t[slot] <= 0.0:
		return 0.0
	return reload_t[slot] / maxf(0.1, _reload_dur(slot))

## 技能槽状态，HUD 用：{name, icon, cd(剩余), cd_max, ok}
func skill_info(key: String) -> Dictionary:
	var sk: Dictionary = GameData.SKILLS.none
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
	var active := (key == "f" and (shield_time > 0.0 or stealth_t > 0.0)) or (key == "space" and (dash_time > 0.0 or stealth_t > 0.0))
	return {"name": sk.name, "icon": sk.icon, "cd": cd, "cd_max": float(sk.get("cd", 1.0)), "ok": ok, "cost": float(sk.get("cost", 0.0)), "active": active}


func try_dash(move: Vector3) -> void:
	if _net_action("dash", [Vector2(move.x, move.z)]): return
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
	dash_cd = float(sk.cd) * (0.85 if (_is_local_actor() and Growth.ability_elite("ab_servo")) else 1.0)
	_skill_sfx("space", leg_type, sk)
	var ss = ext_script(sk)
	if ss != null:
		ss.use(self, "space", sk, GameData.module(loadout.get("legs", "")))
		return
	match leg_type:
		"tread":
			dash_time = 0.4
		"quad":
			dash_time = 0.5
			if is_instance_valid(raid):
				var web = SlowWeb.new()
				web.setup(raid, 3.8, 4.5)
				raid.fx.add_child(web)
				web.global_position = global_position
		"hex":
			dash_time = 0.46
		_:
			dash_time = DASH_DUR
			_thrust_start()


func try_ability() -> void:
	if _net_action("ability", []): return
	var id: String = loadout.get("back", "")
	if id == "" or parts.back <= 0.0:
		return
	var m: Dictionary = GameData.module(id)
	if m.ability == "none":
		message.emit(Loc.t("该背件无主动战术机能", "Backpack has no active tactical skill"))
		Audio.play_sfx("skill_denied")
		return
	if ability_cd > 0.0:
		message.emit(Loc.t("%s 冷却中 %.1fs" % [m.name, ability_cd], "%s on cooldown %.1fs" % [m.name, ability_cd]))
		Audio.play_sfx("skill_denied")
		return
	if not can_spend(float(m.cost)):
		message.emit(Loc.t("动力炉蓄能不足", "Insufficient reactor energy"))
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
			# 损管密封胶：按损伤量修复各部位 35%（躯干跟随总结构，不单独回复）
			for k in parts:
				if k != "core":
					parts[k] = minf(1.0, float(parts[k]) + (1.0 - float(parts[k])) * 0.35)


func can_use_item(id: String) -> bool:
	var b := GameData.base_id(id)
	if b in ["fuel_cell", "repair_kit", "beacon", "can_food", "biscuit", "water_tab", "coffee"]:
		return true
	return str(GameData.item(id).get("script", "")) != ""


func use_item_effect(id: String) -> bool:
	var b := GameData.base_id(id)
	var en_mul := 1.2 if (_is_local_actor() and Growth.ability_elite("ab_reactor")) else 1.0
	var hp_mul := 1.25 if (_is_local_actor() and Growth.ability_elite("ab_frame")) else 1.0
	match b:
		"fuel_cell":
			var gain_e := roundf(35.0 * en_mul)
			energy = min(max_energy, energy + gain_e)
			emergency = 0.0
			message.emit(Loc.t("应急燃料电池接入，补充 %d 能量" % int(gain_e), "Fuel cell plugged, +%d EN" % int(gain_e)))
		"repair_kit":
			var any_damaged := hp < max_hp
			for k in parts:
				if float(parts[k]) < 0.99:
					any_damaged = true
			if not any_damaged:
				message.emit(Loc.t("机体结构与各部位完好，无需维修", "Hull and limbs intact, no repair needed"))
				Audio.play_sfx("use_denied")
				return false
			var gain_hp := roundf(45.0 * hp_mul)
			hp = min(max_hp, hp + gain_hp)
			parts.core = hp / max_hp
			for k in parts:
				parts[k] = min(1.0, parts[k] + 0.4 * hp_mul)
			message.emit(Loc.t("战地抢修完成，修复 %d 结构与受损部位" % int(gain_hp), "Field repair complete: +%d HP & limb integrity" % int(gain_hp)))
		"can_food":
			hp = min(max_hp, hp + 15.0)
			energy = min(max_energy, energy + roundf(12.0 * en_mul))
			parts.core = hp / max_hp
			message.emit(Loc.t("食用战前罐头肉，恢复 15 结构与 %d 能量" % int(roundf(12.0 * en_mul)), "Canned rations consumed: +15 HP, +%d EN" % int(roundf(12.0 * en_mul))))
		"biscuit":
			hp = min(max_hp, hp + 8.0)
			energy = min(max_energy, energy + roundf(10.0 * en_mul))
			parts.core = hp / max_hp
			message.emit(Loc.t("食用压缩饼干，恢复 8 结构与 %d 能量" % int(roundf(10.0 * en_mul)), "Compact biscuit consumed: +8 HP, +%d EN" % int(roundf(10.0 * en_mul))))
		"water_tab":
			energy = min(max_energy, energy + roundf(14.0 * en_mul))
			emergency = 0.0
			message.emit(Loc.t("服用净水补给，恢复 %d 能量" % int(roundf(14.0 * en_mul)), "Purified water consumed: +%d EN" % int(roundf(14.0 * en_mul))))
		"coffee":
			energy = min(max_energy, energy + roundf(24.0 * en_mul))
			emergency = 0.0
			message.emit(Loc.t("饮用旧世界咖啡，恢复 %d 能量" % int(roundf(24.0 * en_mul)), "Old-world coffee consumed: +%d EN" % int(roundf(24.0 * en_mul))))
		_:
			var us = ext_script(GameData.item(id))
			if us == null or not bool(us.use(self, id)):
				return false
	Audio.play_sfx("use_" + b)
	_event("item_used", [id])
	return true


func use_item(id: String) -> void:
	if _net_action("item", [id]): return
	if id == "beacon" and raid != null:
		raid.call_transport()
		return
	if not cargo.has(id):
		message.emit(Loc.t("货舱未装载" + GameData.item_name(id), "Not in cargo: " + GameData.item_name(id)))
		Audio.play_sfx("use_denied")
		return
	if use_item_effect(id):
		cargo.erase(id)
		check_overload()


## 战地现场换装模块：替换指定槽位模块、重算整机属性与弹匣并重建 3D 外观，返回被替换下来的旧模块 id
func equip_module_in_raid(slot: String, new_id: String) -> String:
	if not GameData.slot_accepts(slot, new_id):
		return ""
	var old_id: String = str(loadout.get(slot, ""))
	var hp_ratio := clampf(hp / maxf(1.0, max_hp), 0.05, 1.0)
	loadout[slot] = new_id
	if raid != null and raid.mech == self:
		raid.loadout = loadout.duplicate()
	stats = Net.stats_for(loadout, net_peer)
	_last_drain = float(stats.drain)
	max_hp = max(30.0, float(stats.hp))
	hp = clampf(hp_ratio * max_hp, 1.0, max_hp)
	max_energy = max(30.0, float(stats.energy))
	energy = minf(energy, max_energy)
	parts[slot] = 1.0
	parts.core = hp / max_hp
	if slot == "arm_l" or slot == "arm_r":
		Audio.loop_stop(_lk("fire_" + slot))
		_fire_held[slot] = 0.0
		var wpn := str(GameData.module(new_id).get("weapon", "mg"))
		if GameData.weapon_uses_ammo(wpn):
			mag[slot] = int(GameData.AMMO.get(wpn, {}).get("mag", 30))
			# 战地换装初始化武器装填量，不需要库存弹匣。
			ammo[slot] = mag[slot]
		else:
			mag[slot] = 0
			ammo[slot] = 0
		reload_t[slot] = 0.0
		arm_cd[slot] = 0.0
	elif slot == "legs":
		Audio.loop_stop(_lk("legs"))
		var legs_mod: Dictionary = GameData.module(new_id)
		acid_immune = bool(legs_mod.get("acid_immune", false))
		overload_immune = bool(legs_mod.get("overload_immune", false))
	elif slot == "back":
		ability_cd = maxf(ability_cd, 1.5)
	if raid != null and raid.mech == self and raid.hud is CanvasLayer and raid.has_method("update_view_zoom"):
		raid.update_view_zoom(true)
	var old_torso_y := torso.rotation.y if torso != null and is_instance_valid(torso) else 0.0
	var old_legs_y := legs.rotation.y if legs != null and is_instance_valid(legs) else 0.0
	if visual != null and is_instance_valid(visual):
		if visual.get_parent():
			visual.get_parent().remove_child(visual)
		visual.queue_free()
	visual = MechVisual.build(loadout)
	_batch_visual(visual)
	if vis_anchor != null and is_instance_valid(vis_anchor):
		vis_anchor.add_child(visual)
	else:
		add_child(visual)
		_anchor_visual()
	torso = visual.get_meta("torso")
	legs = visual.get_meta("legs")
	muzzles = visual.get_meta("muzzles")
	leg_parts = visual.get_meta("leg_parts")
	leg_type = visual.get_meta("leg_type")
	torso_base_y = visual.get_meta("torso_base_y")
	torso.rotation.y = old_torso_y
	legs.rotation.y = old_legs_y
	_leg_base.clear()
	_leg_yaw.clear()
	_quad_lift.clear()
	_foot_prev = [0.0, 0.0]
	if leg_type == "tread":
		Audio.loop_start(_lk("legs"), "legs_tread_loop", self)
	_mark_occ_exempt()
	if _fp_passthrough:
		set_fp_passthrough(true)
	if raid != null and raid.mech == self and raid.hud != null:
		raid.hud.on_loadout_changed()
	check_overload()
	if not (Net.is_client() and raid != null and raid.coop != null and raid.coop.applying):
		Audio.play_ui("ui_equip")
		message.emit(Loc.t("战地换装：%s → %s" % [GameData.SLOT_NAMES.get(slot, slot), GameData.item_name(new_id)], "Field swap: %s -> %s" % [GameData.SLOT_NAMES.get(slot, slot), GameData.item_name(new_id)]))
	return old_id


## 技能音效 skill_<图标名> + 广播 skill_used
func _skill_sfx(key: String, skill_id: String, sk: Dictionary) -> void:
	Audio.play_sfx("skill_" + str(sk.get("icon", skill_id)), global_position + Vector3(0, 1.6, 0))
	_event("skill_used", [key, skill_id])


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
	_event("overload_changed", [over, sf])


## 底盘循环音：履带随速度起落
func _audio_tick() -> void:
	if leg_type != "tread":
		return
	var sp := Vector2(velocity.x, velocity.z).length()
	var k := clampf(sp / maxf(float(stats.speed), 1.0), 0.0, 1.2)
	Audio.loop_set(_lk("legs"), lerpf(-30.0, 0.0, minf(k * 1.4, 1.0)), 0.8 + 0.35 * k)


func take_damage(amount: float) -> void:
	if net_done or (raid != null and raid.coop != null and Net.is_client()): return
	if dead:
		return
	if shield_time > 0.0:
		_shield_surge = 1.0
		if raid:
			A.burst(raid.fx, global_position + Vector3(0, 1.5, 0), {
				"amount": 12, "life": 0.28, "size": 0.14, "vmin": 3.5, "vmax": 8.5,
				"gravity": Vector3(0, -8, 0), "c0": Color(0.65, 0.92, 1.0, 1.0),
				"c1": Color(0.25, 0.62, 1.0, 0.0), "grow0": 1.0, "grow1": 0.2
			})
		if _is_local_actor():
			Growth.record_skill_xp("ab_plating", clampf(amount * 0.09, 0.3, 2.5))
		Audio.play_sfx("shield_hit", global_position + Vector3(0, 1.6, 0))
		return
	var ac_bonus := float(maxi(0, int(stats.get("armor_class", 2)) - 2)) * 0.03
	var armor: float = clamp(float(stats.armor) + ac_bonus, 0.0, 0.65)
	var eff := amount * (1.0 - armor)
	if guard_t > 0.0 and guard_ratio > 0.0:
		eff *= 1.0 - guard_ratio
	if _is_local_actor() and amount > eff + 0.05:
		Growth.record_skill_xp("ab_plating", clampf((amount - eff) * 0.22, 0.2, 3.0))
	hp -= eff
	var part_loss_mul := 0.8 if (_is_local_actor() and Growth.ability_elite("ab_plating")) else 1.0
	# 伤害随机落到某个部位：部位完好度下降，归零即缺失（躯干只跟随总结构）
	var r := randf()
	var acc := 0.0
	for k in PART_W:
		acc += PART_W[k]
		if r <= acc:
			if k != "core":
				var was: float = parts[k]
				parts[k] = max(0.0, parts[k] - eff / (max_hp * 0.3) * part_loss_mul)
				if was > 0.0 and parts[k] <= 0.0:
					message.emit(Loc.t("▲ %s 损毁！" % GameData.SLOT_NAMES[k], "▲ %s DESTROYED!" % GameData.SLOT_NAMES[k]))
					Audio.play_sfx("mech_part_lost")
					_event("part_destroyed", [k])
			break
	parts.core = hp / max_hp
	hurt_flash = 0.25
	kick_v += Vector3(randf_range(1.2, 2.2), randf_range(-1.5, 1.5), randf_range(-1.8, 1.8)) * clampf(eff / 12.0, 0.4, 1.6)
	Audio.play_sfx("mech_hurt")
	if raid:
		raid.on_player_hurt(amount)
	_event("player_damaged", [eff, maxf(hp, 0.0), max_hp])
	if hp <= 0.0:
		hp = 0.0
		die(Loc.t("机甲结构损毁", "Mech hull destroyed"))


func die(reason: String) -> void:
	if dead:
		return
	dead = true
	for k in ["legs", "alarm", "fire_arm_l", "fire_arm_r"]:
		Audio.loop_stop(_lk(k))
	if player_ring != null and is_instance_valid(player_ring):
		player_ring.visible = false
	Audio.play_sfx("mech_destroyed")
	_event("mech_destroyed", [reason])
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
		Audio.play_sfx("step_biped", fp, {"vol": lerpf(-9.0, -1.5, clampf(w, 0.0, 1.0))})
		var dt: Color = raid.ground_dust_tint() if raid != null and raid.has_method("ground_dust_tint") else Color(0.72, 0.66, 0.56, 1.0)
		A.burst(raid.fx, Vector3(fp.x, 0.24, fp.z), {"amount": 4, "life": 0.70, "size": 0.76, "tex": A.dust_tex(), "additive": false, "dir": Vector3(0, 0.24, 0),
			"spread": 82.0, "vmin": 1.1, "vmax": 2.3, "gravity": Vector3(0, 0.25, 0), "damp": 4.2, "radius": 0.22,
			"c0": Color(dt.r, dt.g, dt.b, 0.0), "cmid": Color(dt.r, dt.g, dt.b, 0.38), "cmid_pos": 0.16, "c1": Color(dt.r * 0.9, dt.g * 0.9, dt.b * 0.9, 0.0),
			"grow0": 0.45, "grow1": 1.48, "soft_depth": 0.20})


func _quad_footfall(leg: Node3D = null, idx: int = 0) -> void:
	var w := gait_amt
	var dip_k := 0.55 if leg_type == "quad" else 0.36
	_step_dip_v -= dip_k * w
	var side_sgn := -1.0 if idx % 2 == 0 else 1.0
	kick_v += Vector3(0.18, 0.0, 0.24 * side_sgn) * w
	var fp := global_position
	if leg != null and is_instance_valid(leg) and leg.has_meta("ankle"):
		var aj: Node3D = leg.get_meta("ankle")
		if aj != null and is_instance_valid(aj):
			fp = aj.global_position
	if idle_t - _last_step_sfx_t >= 0.09:
		_last_step_sfx_t = idle_t
		Audio.play_sfx("step_quad", fp, {"vol": lerpf(-9.5, -2.2, clampf(w, 0.0, 1.0))})
	if raid != null and is_instance_valid(raid.fx):
		raid.shake = maxf(raid.shake, (0.038 if leg_type == "quad" else 0.028) * w)
		var dt: Color = raid.ground_dust_tint() if raid.has_method("ground_dust_tint") else Color(0.72, 0.66, 0.56, 1.0)
		A.burst(raid.fx, Vector3(fp.x, 0.20, fp.z), {"amount": 3, "life": 0.58, "size": 0.62, "tex": A.dust_tex(), "additive": false, "dir": Vector3(0, 0.22, 0),
			"spread": 78.0, "vmin": 0.9, "vmax": 1.9, "gravity": Vector3(0, 0.22, 0), "damp": 4.4, "radius": 0.18,
			"c0": Color(dt.r, dt.g, dt.b, 0.0), "cmid": Color(dt.r, dt.g, dt.b, 0.34), "cmid_pos": 0.16, "c1": Color(dt.r * 0.9, dt.g * 0.9, dt.b * 0.9, 0.0),
			"grow0": 0.42, "grow1": 1.38, "soft_depth": 0.18})


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
	var sm := A.emitter(self, Vector3.ZERO, {"amount": 20, "life": 0.78, "size": 0.96, "tex": A.smoke_tex(), "additive": false, "spread": 22.0, "vmin": 2.2, "vmax": 4.2,
		"gravity": Vector3(0, 0.6, 0), "c0": Color(0.78, 0.75, 0.70, 0.0), "cmid": Color(0.76, 0.73, 0.68, 0.36), "cmid_pos": 0.20, "c1": Color(0.72, 0.70, 0.66, 0.0), "grow0": 0.45, "grow1": 1.65, "soft_depth": 0.26})
	sm.set_meta("sx", 0.0)
	sm.set_meta("smoke", true)
	_thrusters.append(sm)
	if _fp_passthrough:
		set_fp_passthrough(true)
	if raid:
		var p := global_position
		var dt: Color = raid.ground_dust_tint() if raid.has_method("ground_dust_tint") else Color(0.74, 0.68, 0.58, 1.0)
		A.burst(raid.fx, Vector3(p.x, 0.26, p.z), {"amount": 14, "life": 0.85, "size": 1.25, "tex": A.dust_tex(), "additive": false, "flat": 0.90, "dir": Vector3(1, 0, 0), "spread": 180.0,
			"vmin": 4.2, "vmax": 7.5, "gravity": Vector3(0, 0.35, 0), "damp": 5.5, "c0": Color(dt.r, dt.g, dt.b, 0.0), "cmid": Color(dt.r, dt.g, dt.b, 0.48), "cmid_pos": 0.16,
			"c1": Color(dt.r * 0.9, dt.g * 0.9, dt.b * 0.9, 0.0), "grow0": 0.45, "grow1": 1.75, "soft_depth": 0.24})
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
		var dt: Color = raid.ground_dust_tint() if raid.has_method("ground_dust_tint") else Color(0.74, 0.68, 0.58, 1.0)
		A.burst(raid.fx, Vector3(p.x, 0.26, p.z), {"amount": 12, "life": 0.92, "size": 1.25, "tex": A.dust_tex(), "additive": false, "flat": 0.90, "dir": Vector3(1, 0, 0), "spread": 180.0,
			"vmin": 3.5, "vmax": 6.8, "gravity": Vector3(0, 0.35, 0), "damp": 5.5, "c0": Color(dt.r, dt.g, dt.b, 0.0), "cmid": Color(dt.r, dt.g, dt.b, 0.48), "cmid_pos": 0.16,
			"c1": Color(dt.r * 0.9, dt.g * 0.9, dt.b * 0.9, 0.0), "grow0": 0.45, "grow1": 1.75, "soft_depth": 0.24})
		var scorch := A.ground_vfx(raid.fx, A.scorch_tex(), Color(0.24, 0.21, 0.18, 0.36), 2.4, Vector3(p.x, 0.092, p.z), false, 0.44, true, 2)
		scorch.rotation.y = randf() * TAU
		var stw := scorch.create_tween()
		stw.tween_interval(3.0)
		stw.tween_property(scorch.material_override, "shader_parameter/col", Color(0.24, 0.21, 0.18, 0.0), 2.5)
		stw.tween_callback(scorch.queue_free)


func _thrust_clear() -> void:
	for f in _thrusters:
		if is_instance_valid(f):
			f.emitting = false
			get_tree().create_timer(1.2).timeout.connect(f.queue_free)
	_thrusters.clear()


# ---------------- 外观挂点 ----------------
## 外观子树挂在一个 top_level 的空节点（VisAnchor）下，而不是直接挂在机体上：
## move_and_slide 每次迭代都会改写机体变换，外观直接挂在机体下时，每次改写都要把整棵外观子树（机甲约 700 个节点、虫子约 80 个）
## 标脏并逐个通知渲染。挂点只在机体变换真正变了之后同步一次（移动后显式同步 + 变换通知兜底：传送、补间、死亡下沉都跟得上）
var vis_anchor: Node3D = null
const FP_HIDE_LAYER := 1 << 19
var _fp_passthrough := false


static var _occ_exempt_mats := {}

## 标记机甲自身涂装材质免于前景建筑虚化裁切（静态缓存去重副本，绝不污染建筑共享材质，也不占用实例着色器缓冲）
func _mark_occ_exempt() -> void:
	if visual == null or not is_instance_valid(visual):
		return
	for n in visual.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		mi.material_override = occ_exempt_material(mi.material_override)


static func occ_exempt_material(material: Material) -> Material:
	if material is ShaderMaterial and material.shader != null and material.shader.resource_path.contains("mech_paint"):
		var id := material.get_instance_id()
		var exempt: ShaderMaterial = _occ_exempt_mats.get(id)
		if exempt == null:
			exempt = material.duplicate() as ShaderMaterial
			exempt.set_shader_parameter("occ_exempt", 1.0)
			_occ_exempt_mats[id] = exempt
		return exempt
	return material


## 第一人称自身机体穿透控制：躯干/底盘/背包/动力炉/护盾穿透，左右双臂武器严禁被穿透并保持完整可见
func set_fp_passthrough(on: bool) -> void:
	_fp_passthrough = on
	var arm_l_node: Node = null
	var arm_r_node: Node = null
	if visual != null and is_instance_valid(visual) and visual.has_meta("modules"):
		var mods: Dictionary = visual.get_meta("modules")
		arm_l_node = mods.get("arm_l")
		arm_r_node = mods.get("arm_r")
		if not on:
			for a_node in [arm_l_node, arm_r_node]:
				if a_node is Node3D and is_instance_valid(a_node):
					(a_node as Node3D).rotation.x = 0.0
	for n in find_children("*", "VisualInstance3D", true, false):
		if not (n is VisualInstance3D) or (n is Light3D) or n.has_meta("player_ring"):
			continue
		var is_weapon := (arm_l_node != null and is_instance_valid(arm_l_node) and (n == arm_l_node or arm_l_node.is_ancestor_of(n))) \
			or (arm_r_node != null and is_instance_valid(arm_r_node) and (n == arm_r_node or arm_r_node.is_ancestor_of(n)))
		var vi := n as VisualInstance3D
		if is_weapon:
			if vi is MeshInstance3D and vi.has_meta("_orig_cast_shadow"):
				(vi as MeshInstance3D).cast_shadow = int(vi.get_meta("_orig_cast_shadow")) as GeometryInstance3D.ShadowCastingSetting
			vi.layers = 1
			continue
		if vi is MeshInstance3D:
			var mi := vi as MeshInstance3D
			if mi.get_parent() == visual and mi.position.y < 0.06:
				continue
			if not mi.has_meta("_orig_cast_shadow"):
				mi.set_meta("_orig_cast_shadow", int(mi.cast_shadow))
			var orig_cs := int(mi.get_meta("_orig_cast_shadow"))
			if on:
				if orig_cs != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
					mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
					mi.layers = 1
				else:
					mi.layers = FP_HIDE_LAYER
			else:
				mi.cast_shadow = orig_cs as GeometryInstance3D.ShadowCastingSetting
				mi.layers = 1
		else:
			vi.layers = FP_HIDE_LAYER if on else 1


func _anchor_visual() -> void:
	if visual == null or vis_anchor != null:
		return
	vis_anchor = Node3D.new()
	vis_anchor.name = "VisAnchor"
	vis_anchor.top_level = true
	add_child(vis_anchor)
	if visual.get_parent():
		visual.get_parent().remove_child(visual)
	vis_anchor.add_child(visual)
	set_notify_transform(true)
	_vis_sync()


func _vis_sync() -> void:
	if vis_anchor != null and is_inside_tree():
		var gt := global_transform
		if vis_anchor.transform != gt:
			vis_anchor.transform = gt


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED or what == NOTIFICATION_ENTER_TREE:
		_vis_sync()


# ---------------- 外观合批 ----------------
## 模块化外观一台机甲约 600 个网格节点：同一父节点下、同材质、不再被引用的静态叶子网格合成一个网格。
## 动画只改父节点（腿 / 膝 / 踝 / 躯干 / 武器座）的变换，叶子网格跟着父节点整体动，合批后外观与动画完全一致；
## 节点少了，机体移动时的变换传播、渲染实例与绘制调用都随之减少。被任何元数据引用的节点（枪口、膝踝、腿件、模块根）一律保留
const RB = preload("res://scripts/render_batch.gd")
static var _vis_merge_cache := {}


static func _collect_refs(v, out: Dictionary) -> void:
	if v is Node:
		out[v.get_instance_id()] = true
	elif v is Array:
		for e in v:
			_collect_refs(e, out)
	elif v is Dictionary:
		for e in v.values():
			_collect_refs(e, out)


## tree 非空时用于战斗中增援：每组完成后检查 2 ms 预算，保留完整网格和原来的合批分组。
## 常规装配仍同步执行；退出战区释放 root 后，挂起任务在恢复时立即结束。
static func _batch_visual(root: Node3D, tree: SceneTree = null) -> void:
	var slice_start := Prof.t0()
	var deadline := Time.get_ticks_usec() + 2000 if tree != null else 0
	var keep := {root.get_instance_id(): true}
	var all: Array = root.find_children("*", "", true, false)
	for n in all:
		var nm: String = n.name
		if nm == "TorsoMount" or nm.begins_with("Module_") or nm.begins_with("Socket_") or nm.begins_with("Hatch") or nm.begins_with("Missile") or nm == "Plug" or nm == "Receiver":
			keep[n.get_instance_id()] = true
		for mk in n.get_meta_list():
			_collect_refs(n.get_meta(mk), keep)
	for mk in root.get_meta_list():
		_collect_refs(root.get_meta(mk), keep)
	var parents := {}
	for n in all:
		if not (n is MeshInstance3D):
			continue
		var mi: MeshInstance3D = n
		if keep.has(mi.get_instance_id()) or mi.get_child_count() > 0 or mi.get_script() != null or not mi.visible:
			continue
		if mi.mesh == null or mi.material_override == null or mi.material_overlay != null or mi.skin != null:
			continue
		if not mi.get_meta_list().is_empty() or mi.transparency > 0.0 or mi.visibility_range_end > 0.0 or not RB.mergeable(mi.mesh):
			continue
		# 往上找最近的“会动的”祖先（被引用的节点或模块根）：中间没人引用的容器节点从不被改动，叶子网格可以直接并到那个祖先下
		var xf := mi.transform
		var p: Node = mi.get_parent()
		var ok := true
		while p != null and not keep.has(p.get_instance_id()):
			if not (p is Node3D) or not p.visible or p.top_level or p.has_meta("_detaching"):
				ok = false
				break
			xf = p.transform * xf
			p = p.get_parent()
		if not ok or not (p is Node3D) or p.has_meta("_detaching"):
			continue
		var st := RB.split_tint(mi.material_override, 2)
		var base_mat: Material = st[0]
		var tint_col: Color = st[1]
		var tint_mode := 0 if base_mat == mi.material_override else (2 if base_mat is StandardMaterial3D else 1)
		mi.set_meta("_bx", xf)
		mi.set_meta("_bt", tint_col)
		mi.set_meta("_bm", tint_mode)
		var key := "%d|%d|%d" % [base_mat.get_instance_id(), mi.layers, mi.gi_mode]
		var pid := p.get_instance_id()
		if not parents.has(pid):
			parents[pid] = {"node": p, "groups": {}}
		var g: Dictionary = parents[pid]["groups"]
		if not g.has(key):
			g[key] = {"mat": base_mat, "list": []}
		g[key]["list"].append(mi)
	for pid in parents:
		var p: Node3D = parents[pid]["node"]
		for key in parents[pid]["groups"]:
			var b: Dictionary = parents[pid]["groups"][key]
			var list: Array = b["list"]
			if list.size() < 2:
				for mi: MeshInstance3D in list:
					mi.remove_meta("_bx")
					mi.remove_meta("_bt")
					mi.remove_meta("_bm")
				continue
			var sig: String = key
			var sh_mode := GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for mi: MeshInstance3D in list:
				sig += "|%d:%s:%s" % [mi.mesh.get_instance_id(), mi.get_meta("_bx"), (mi.get_meta("_bt") as Color).to_html()]
				if mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
					sh_mode = mi.cast_shadow
			var h := sig.hash()
			var mesh: Mesh = _vis_merge_cache.get(h)
			if mesh == null:
				var bmat: Material = b["mat"]
				if RB._uses_local_triplanar(bmat):
					var tparts: Array = []
					var t_mode := 0
					for mi: MeshInstance3D in list:
						var tcol: Color = mi.get_meta("_bt")
						t_mode = int(mi.get_meta("_bm"))
						var bxf: Transform3D = mi.get_meta("_bx")
						for si in mi.mesh.get_surface_count():
							tparts.append([mi.mesh, si, bxf, tcol])
					mesh = RB._merge_local_triplanar(tparts, t_mode)
				else:
					var st_tool := SurfaceTool.new()
					st_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
					for mi: MeshInstance3D in list:
						var tcol: Color = mi.get_meta("_bt")
						var tmode: int = mi.get_meta("_bm")
						var bxf: Transform3D = mi.get_meta("_bx")
						for si in mi.mesh.get_surface_count():
							st_tool.append_from(RB._tinted_surface(mi.mesh, si, tcol, tmode), 0, bxf)
					mesh = st_tool.commit()
				_vis_merge_cache[h] = mesh
			var first: MeshInstance3D = list[0]
			var merged := MeshInstance3D.new()
			merged.mesh = mesh
			merged.material_override = b["mat"]
			merged.cast_shadow = sh_mode
			merged.layers = first.layers
			merged.gi_mode = first.gi_mode
			p.add_child(merged)
			for mi: MeshInstance3D in list:
				mi.get_parent().remove_child(mi)
				mi.free()
			if tree != null and Time.get_ticks_usec() >= deadline:
				Prof.add("spawn.batch_slice", slice_start)
				await tree.process_frame
				if not is_instance_valid(root):
					return
				slice_start = Prof.t0()
				deadline = Time.get_ticks_usec() + 2000
	for i in range(all.size() - 1, -1, -1):
		var n = all[i]
		if is_instance_valid(n) and n is Node3D and n.get_class() == "Node3D" and not keep.has(n.get_instance_id()) and n.get_child_count() == 0:
			if n.get_parent():
				n.get_parent().remove_child(n)
			n.free()
	if tree != null:
		Prof.add("spawn.batch_slice", slice_start)


func _net_action(action: String, args: Array) -> bool:
	if raid != null and raid.coop != null and Net.is_client() and not raid.coop.applying:
		Net.command(action, args)
		return true
	return net_done

func _event(event: String, args: Array) -> void:
	if Net.is_client() and raid != null and raid.coop != null and raid.coop.applying: return
	Net.player_event(net_peer, event, args)

func use_item_at_cargo(index: int) -> void:
	if _net_action("item_index", [index]): return
	if index < 0 or index >= cargo.size(): return
	var id: String = cargo[index]
	if use_item_effect(id):
		cargo.remove_at(index)
		check_overload()
		if raid != null and raid.hud != null: raid.hud.refresh_loot()
