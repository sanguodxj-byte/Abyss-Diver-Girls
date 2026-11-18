extends "res://scripts/mech.gd"
## AI 驾驶的机甲：「流浪者」（rover，敌对派系：攻击玩家、战斗队友与虫群）与「战斗队友」（ally，跟随玩家、攻击虫群与流浪者）。
## 外观与数值全部沿用 mech.gd / mech_visual.gd 的模块装配（setup(loadout) 不变），这里只换掉输入、开火、受击与死亡：
##   移动目标由 factions.gd 的小队逻辑每帧给出（goal），交战目标自己按 0.25~0.5 秒一次挑选；
##   开火不走玩家的 try_fire（那条路会发 HUD 信号、用玩家的子弹掩码），按武器数值自己发射曳光弹 / 火焰 / 光束，子弹掩码按阵营区分；
##   受击不触发玩家的受伤反馈（镜头震动、HUD 红框、全局损伤着色器参数），死亡时散架、流浪者掉落物资箱。
## 碰撞层：流浪者 16、队友 32（玩家 2、虫群 4）。

const A2 = preload("res://scripts/art.gd")

signal npc_died(npc)

var faction := "rover"
var tier := 1
var pilot := ""
var dmg_mul := 1.0
var squad = null                ## factions.gd 里的小队字典（流浪者）
var slot_i := 0                 ## 队友跟随站位 / 流浪者队形序号
var goal := Vector3.INF         ## 小队逻辑给的移动目标；INF = 原地
var goal_scale := 1.0           ## 行进速度比例（队形里等人时放慢）
var ai_target = null
var aggressor = null
var lod := 0
var killed_by_player := false
var marker: Node3D
var name_label: Label3D
var _hit_meshes: Array = []
var _hit_meshes_ready := false
var _hit_flash_q := 0
var _ring_fx: MeshInstance3D

var _think_t := 0.0
var _lod_acc := 0.0
var _los := true
var _strafe := 1.0
var _strafe_t := 0.0
var _stuck_t := 0.0
var _stuck_pos := Vector3.ZERO
var _detour := Vector3.ZERO
var _detour_t := 0.0
var _sfx_gap := {"arm_l": 0, "arm_r": 0}
var nav_agent = preload("res://scripts/nav_grid.gd").Agent.new()   ## 沿导航网格（机甲间隙）绕开建筑
var _near := false
var _anim_acc := 0.0

const ROVER_MASK := 1 | 2 | 4 | 32     ## 流浪者子弹：地形 + 玩家 + 虫群 + 队友
const ALLY_MASK := 1 | 4 | 16          ## 队友子弹：地形 + 虫群 + 流浪者
const ROVER_TINT := Color(0.42, 0.2, 0.14)
const ROVER_GLOW := Color(1.0, 0.22, 0.12)
const ALLY_GLOW := Color(0.35, 0.85, 1.0)


func setup_npc(lo: Dictionary, fac: String, t := 1) -> void:
	setup(lo, [])
	faction = fac
	tier = clampi(t, 1, 3)
	add_to_group("npc_mechs")
	add_to_group("rovers" if faction == "rover" else "allies")
	collision_layer = 16 if faction == "rover" else 32
	collision_mask = 1 | 2 | 4 | 8 | 16 | 32
	var hp_mul := 1.0
	if faction == "rover":
		hp_mul = 1.15
		dmg_mul = 0.42
	else:
		hp_mul = [1.0, 1.35, 1.8][tier - 1]
		dmg_mul = [0.6, 0.8, 1.05][tier - 1]
	max_hp = maxf(90.0, max_hp * hp_mul)
	hp = max_hp
	_strafe = 1.0 if randf() < 0.5 else -1.0
	if faction == "rover":
		_add_raider_kit()
	_paint()
	_add_marker()


func is_rover() -> bool:
	return faction == "rover"


# ================================================================ 外观
static var _tint_cache := {}

## 流浪者战地改装件：躯干顶部防滚护杠、双联锈蚀排烟直管（深黑烟膛）、鞭状敌我识别天线与前向格栅附加装甲
func _add_raider_kit() -> void:
	if torso == null:
		return
	var cid := str(torso.get_meta("id", "core_std"))
	# [bar_y, bar_z, bar_w, post_h, ex_x, ex_y, ex_z, slat_y, slat_z, slat_w]
	var cfg_map := {
		"core_std": [1.06, 0.08, 1.18, 0.34, 0.56, 0.96, 0.56, 0.16, -0.76, 1.04],
		"core_scout": [0.94, 0.08, 1.08, 0.24, 0.48, 0.92, 0.56, 0.10, -0.92, 0.92],
		"core_heavy": [1.42, 0.06, 1.38, 0.30, 0.82, 1.36, 0.62, 0.22, -0.98, 1.36],
		"core_assault": [1.34, 0.10, 1.18, 0.28, 0.56, 1.26, 0.62, 0.34, -0.88, 1.14],
		"core_command": [1.58, 0.12, 1.16, 0.28, 0.52, 1.44, 0.54, 0.44, -0.75, 1.06],
		"core_fortress": [2.12, 0.22, 1.56, 0.34, 0.76, 1.92, 0.98, 0.56, -1.38, 1.54],
	}
	var cfg: Array = cfg_map.get(cid, cfg_map["core_std"])
	var bar_y: float = cfg[0]; var bar_z: float = cfg[1]; var bar_w: float = cfg[2]; var post_h: float = cfg[3]
	var ex_x: float = cfg[4]; var ex_y: float = cfg[5]; var ex_z: float = cfg[6]
	var slat_y: float = cfg[7]; var slat_z: float = cfg[8]; var slat_w: float = cfg[9]
	var post_x := bar_w * 0.5 - 0.04
	var kit := Node3D.new()
	kit.name = "RaiderKit"
	torso.add_child(kit)
	var m_iron := A2.metal(Color(0.18, 0.19, 0.20))
	var m_rust := A2.paint(Color(0.42, 0.22, 0.15), 0.30, 0.72, {"rust": 0.65, "wear": 0.60})
	var m_bore := A2.rubber()
	var m_haz := A2.hazard()
	# 顶部战地焊接防滚横梁 + 警示黄端牌 + 敌我识别红闪信标座
	A2.add(kit, A2.bevel_box(Vector3(bar_w, 0.06, 0.08), 0.015), m_iron, Vector3(0, bar_y, bar_z))
	for sx: float in [-1.0, 1.0]:
		A2.add(kit, A2.bevel_box(Vector3(0.06, post_h, 0.06), 0.012), m_iron, Vector3(sx * post_x, bar_y - post_h * 0.5 + 0.01, bar_z), Vector3(0, 0, sx * -8.0))
		A2.add(kit, A2.bevel_box(Vector3(0.16, 0.12, 0.03), 0.008), m_haz, Vector3(sx * post_x, bar_y - 0.04, bar_z - 0.06))
		# 双侧锈蚀柴油直排烟管 + 空心黑烟口
		A2.add(kit, A2.cyl(0.055, 0.56, 0.065, 10), m_rust, Vector3(sx * ex_x, ex_y, ex_z), Vector3(-10, 0, sx * -4.0))
		A2.add(kit, A2.cyl(0.042, 0.10, 0.042, 8), m_bore, Vector3(sx * (ex_x + 0.02), ex_y + 0.26, ex_z + 0.05), Vector3(-10, 0, sx * -4.0), Vector3.ONE, false)
	# 右后鞭状通讯天线 + 装甲信标灯罩
	A2.add(kit, A2.cyl(0.045, 0.12, 0.055, 8), m_iron, Vector3(post_x * 0.62, bar_y + 0.06, bar_z))
	A2.add(kit, A2.cyl(0.032, 0.09, 0.032, 8), A2.emit(ROVER_GLOW, 2.2), Vector3(post_x * 0.62, bar_y + 0.155, bar_z), Vector3.ZERO, Vector3.ONE, false)
	A2.add(kit, A2.cyl(0.008, 0.82, 0.016, 6), m_iron, Vector3(-post_x * 0.65, bar_y + 0.42, bar_z), Vector3(-6, 0, 5), Vector3.ONE, false)
	# 胸前战地焊接双横档格栅防破甲护栏（Slat Armor）
	for sx: float in [-1.0, 1.0]:
		A2.add(kit, A2.bevel_box(Vector3(0.04, 0.24, 0.14), 0.008), m_iron, Vector3(sx * (slat_w * 0.5 - 0.05), slat_y + 0.08, slat_z + 0.07))
	for ky in 2:
		A2.add(kit, A2.bevel_box(Vector3(slat_w, 0.038, 0.028), 0.006), m_rust if ky == 0 else m_iron, Vector3(0, slat_y + ky * 0.15, slat_z))


## 敌对涂装：流浪者的装甲赋予高风化铁锈炭灰涂装（保留裸钢/镀铬/橡胶与警示条对比度）、光学窗改为猩红；队友仅替换青色识别灯
func _paint() -> void:
	for mi in visual.find_children("*", "MeshInstance3D", true, false):
		var m = mi.material_override
		if m == null:
			continue
		var key := "%s_%d" % [faction, m.get_instance_id()]
		if m is StandardMaterial3D:
			if not _tint_cache.has(key):
				var d: StandardMaterial3D = m.duplicate()
				if d.emission_enabled:
					d.emission = ROVER_GLOW if faction == "rover" else ALLY_GLOW
					d.albedo_color = d.emission
				elif faction == "rover":
					if d.metallic >= 0.68:
						d.albedo_color = d.albedo_color.lerp(Color(0.52, 0.48, 0.44), 0.22)
					else:
						d.albedo_color = d.albedo_color.lerp(Color(0.52, 0.30, 0.22), 0.42)
				_tint_cache[key] = d
			mi.material_override = _tint_cache[key]
		elif m is ShaderMaterial and m.shader != null and (m.shader.resource_path == "res://shaders/mech_paint.gdshader" or m.shader.resource_path == "res://shaders/mech_paint_mobile.gdshader"):
			if not _tint_cache.has(key):
				var sm: ShaderMaterial = m.duplicate()
				sm.set_shader_parameter("takes_damage", 0.0)
				if faction == "rover":
					var mb := float(sm.get_shader_parameter("metal_base") if sm.get_shader_parameter("metal_base") != null else 0.15)
					var stp := float(sm.get_shader_parameter("stripes") if sm.get_shader_parameter("stripes") != null else 0.0)
					if mb < 0.55 and stp < 0.5:
						var bc: Color = sm.get_shader_parameter("base_color")
						sm.set_shader_parameter("base_color", Color(bc.r * 0.86, bc.g * 0.66, bc.b * 0.56, bc.a))
						sm.set_shader_parameter("rust", 0.52)
						sm.set_shader_parameter("wear", 0.60)
						sm.set_shader_parameter("grime", 0.58)
						sm.set_shader_parameter("dust", 0.34)
				_tint_cache[key] = sm
			mi.material_override = _tint_cache[key]


func _add_marker() -> void:
	var c := ROVER_GLOW if faction == "rover" else ALLY_GLOW
	marker = Node3D.new()
	add_child(marker)
	marker.position.y = 5.6
	# 精悍战术菱形双折角敌我识别标（取代厚重发光三角块）
	var m_em := A2.emit(c, 2.8)
	var m_dk := A2.metal(Color(0.12, 0.13, 0.15))
	for sx: float in [-1.0, 1.0]:
		var bar := A2.add(marker, A2.bevel_box(Vector3(0.065, 0.48, 0.045), 0.01), m_em,
			Vector3(sx * 0.14, 0.0, 0.0), Vector3(0, 0, sx * -32.0), Vector3.ONE, false)
		bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var top_bar := A2.add(marker, A2.bevel_box(Vector3(0.045, 0.24, 0.04), 0.008), m_dk,
			Vector3(sx * 0.19, 0.24, 0.0), Vector3(0, 0, sx * 32.0), Vector3.ONE, false)
		top_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var core_dot := A2.add(marker, A2.bevel_box(Vector3(0.11, 0.11, 0.05), 0.015), m_em,
		Vector3(0, 0.12, 0), Vector3(0, 0, 45.0), Vector3.ONE, false)
	core_dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring_fx = A2.ground_vfx(self, A2.ring_tex(), Color(c.r, c.g, c.b, 0.55), 3.6, Vector3(0, 0.112, 0), true, 0.44, false, 3)
	_ring_fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring_fx.set_meta("no_flash", true)
	name_label = Label3D.new()
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.no_depth_test = true
	name_label.font_size = 40
	name_label.pixel_size = 0.016
	name_label.modulate = c.lightened(0.25)
	name_label.outline_size = 8
	name_label.outline_modulate = Color(0, 0, 0, 0.85)
	name_label.position.y = 6.5
	name_label.text = Loc.t("流浪者", "Rover") if faction == "rover" else _pilot_name()
	add_child(name_label)


func _pilot_name() -> String:
	var d: Dictionary = Growth.pilot_data(pilot)
	if d.is_empty():
		d = Growth.crew_data(pilot)
	var nm := str(d.get("name", pilot if pilot != "" else Loc.t("队友", "Ally")))
	return "%s · T%d" % [nm, tier]


# ================================================================ 运行
func _lod_dt(delta: float) -> float:
	var d2 := 0.0
	if raid and is_instance_valid(raid.mech):
		d2 = global_position.distance_squared_to(raid.mech.global_position)
		if "cam_focus" in raid and raid.cam_focus != Vector3.ZERO:
			d2 = minf(d2, global_position.distance_squared_to(raid.cam_focus))
	_near = d2 < 30.0 * 30.0
	lod = 0 if d2 < 48.0 * 48.0 else (1 if d2 < 120.0 * 120.0 else 2)
	var vis := lod == 0 or raid == null
	if vis_anchor != null and vis_anchor.visible != vis:
		vis_anchor.visible = vis
	if marker != null and marker.visible != vis:
		marker.visible = vis
	if name_label != null and name_label.visible != vis:
		name_label.visible = vis
	if lod == 0:
		delta += _lod_acc
		_lod_acc = 0.0
		return delta
	_lod_acc += delta
	if _lod_acc < (0.1 if lod == 1 else 0.25):
		return 0.0
	var dt := minf(_lod_acc, 0.4)
	_lod_acc = 0.0
	return dt


func _prof_key() -> String:
	return "phys.npc"


func _physics_tick(delta: float) -> void:
	if dead or raid == null:
		return
	delta = _lod_dt(delta)
	if delta <= 0.0:
		return
	for k in arm_cd:
		arm_cd[k] = maxf(0.0, arm_cd[k] - delta)
	for k in reload_t:
		if reload_t[k] > 0.0:
			reload_t[k] -= delta
			if reload_t[k] <= 0.0:
				reload_t[k] = 0.0
				ammo[k] = mag[k]
	hurt_flash = maxf(0.0, hurt_flash - delta)
	_update_hit_flash()
	if marker and lod == 0:
		marker.rotation.y += delta * 2.0
	_think_t -= delta
	if _think_t <= 0.0:
		_think_t = (0.25 if lod == 0 else 0.5) * randf_range(0.85, 1.15)
		var _t1 := Prof.t0()
		_choose_target()
		Prof.add("npc.think", _t1)
	var _t2 := Prof.t0()
	var move := _steer(delta)
	Prof.add("npc.steer", _t2)
	var spd: float = float(stats.speed) * speed_mult() * (0.95 if faction == "rover" else 1.05)
	# 队友掉队超过 12 米且没在交战：加速追上（重型脚步的队友不然永远跟不上轻装玩家）
	if faction == "ally" and not _ok(ai_target) and goal != Vector3.INF and global_position.distance_to(goal) > 12.0:
		spd *= 1.6
	var hv := Vector3(velocity.x, 0, velocity.z)
	hv = hv.lerp(move * spd, clampf(7.0 * delta, 0.0, 1.0))
	velocity.x = hv.x
	velocity.z = hv.z
	velocity.y = -1.0 if is_on_floor() else velocity.y - 40.0 * delta
	var _t3 := Prof.t0()
	_slide(delta)
	_vis_sync()
	Prof.add("npc.slide", _t3)
	if move.length() > 0.1:
		legs.rotation.y = lerp_angle(legs.rotation.y, atan2(-move.x, -move.z), clampf(6.0 * delta, 0.0, 1.0))
	var valid := _ok(ai_target)
	var face := Vector3.ZERO
	if valid:
		aim_point = ai_target.global_position + Vector3(0, 1.4, 0)
		face = aim_point - global_position
	elif move.length() > 0.1:
		face = move
	face.y = 0.0
	if face.length() > 0.5:
		torso.rotation.y = lerp_angle(torso.rotation.y, atan2(-face.x, -face.z), clampf(TORSO_TURN * 0.8 * delta, 0.0, 1.0))
	if valid and _los:
		var to: Vector3 = ai_target.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		var aim := aim_dir()
		var max_fire_d := INF
		if faction == "rover" and ai_target == raid.mech and raid != null and raid.has_method("vision_toward_player"):
			max_fire_d = raid.vision_toward_player(global_position)
		if dist <= max_fire_d and aim.dot(to / maxf(dist, 0.01)) > 0.93:
			for slot in ["arm_l", "arm_r"]:
				var id: String = loadout.get(slot, "")
				if id != "" and dist < GameData.weapon_range_m(GameData.module(id)) * 0.95:
					var _t5 := Prof.t0()
					_npc_fire(slot)
					Prof.add("npc.fire", _t5)
	# 程序动画（双足 IK 等）很贵：30 米内逐帧，画面边缘降到 30Hz，画面外不跑
	_npc_audio_tick()
	if lod == 0:
		_anim_acc += delta
		if _near or _anim_acc >= 0.033:
			var _t4 := Prof.t0()
			_animate(_anim_acc, move)
			Prof.add("npc.anim", _t4)
			_anim_acc = 0.0


static func _ok(n) -> bool:
	return is_instance_valid(n) and n.get("dead") != true and n.get("dying") != true and n.get("net_done") != true


## 画面外（LOD 中 / 远）不跑物理：直接平移，用建筑占地格子挡一下（撞上就沿侧面绕），近处照常 move_and_slide
func _slide(dt: float) -> void:
	if lod > 0 and raid and raid.has_method("ai_free"):
		var step := Vector3(velocity.x, 0.0, velocity.z) * dt
		if step.length_squared() < 0.0001:
			return
		var np := global_position + step
		var has_ib: bool = raid.has_method("in_bounds")
		var H: float = raid.HALF - 4.0
		if raid.ai_free(np, 1.2, true) and (raid.in_bounds(np, 4.0) if has_ib else (absf(np.x) < H and absf(np.z) < H)):
			global_position = np
			return
		if raid.ai_free(global_position, 1.2, true):
			if _detour_t <= 0.0:
				_detour = step.cross(Vector3.UP).normalized() * (1.0 if randf() < 0.5 else -1.0)
				_detour_t = randf_range(0.8, 1.5)
			# 沿侧面挪一步；两侧都堵（墙角）就交给下面的真实物理去滑
			for side in [_detour, -_detour]:
				var alt: Vector3 = global_position + side * step.length()
				if raid.ai_free(alt, 1.2, true) and (raid.in_bounds(alt, 4.0) if has_ib else (absf(alt.x) < H and absf(alt.z) < H)):
					global_position = alt
					return
		# 已经压在建筑占地格子里（或贴着地图边）：退回真实物理 move_and_slide，不然会原地踏步
	var _pt := Prof.t0()
	var pd := get_physics_process_delta_time()
	if pd > 0.0 and dt > pd * 1.5:
		var k := dt / pd
		velocity.x *= k
		velocity.z *= k
		move_and_slide()
		velocity.x /= k
		velocity.z /= k
	else:
		move_and_slide()
	Prof.add("npc.move_and_slide", _pt)


## 流浪者的视野与虫群一致：察觉距离封顶 raid.vision_range()（看玩家机甲时按屏幕方向收紧），且要有视线
func _sees(t, d: float) -> bool:
	if raid == null or not raid.has_method("vision_range"):
		return d < 44.0
	var r: float = raid.vision_toward_player(global_position) if t == raid.mech else raid.vision_range()
	return d < r and raid.has_los(global_position, t.global_position)


## 已经在打的目标、打过自己的单位：不要求视线，拉开到 raid.lose_range()（视野 × 1.5）才放掉
func _lose_r() -> float:
	return raid.lose_range() if raid and raid.has_method("lose_range") else 46.0


## 挑目标：流浪者在玩家 / 队友 / 近处虫子里挑最近的（对玩家略有偏好），队友只打离玩家不远的虫子和流浪者
func _choose_target() -> void:
	var p := global_position
	var best = null
	var bs := INF
	var cur_ok := _ok(ai_target)
	if faction == "rover":
		var m = raid.nearest_player(p)
		if _ok(m):
			var d: float = p.distance_to(m.global_position)
			var ally_agg: bool = is_instance_valid(aggressor) and aggressor.is_in_group("allies") and raid.has_los(p, m.global_position)
			var known: bool = (ai_target == m or aggressor == m or ally_agg) and d < _lose_r()
			if known or _sees(m, d):
				best = m
				# 小队里单号成员专盯玩家机甲（队友和虫子吸走全部火力时玩家也照样挨打）
				bs = d * (0.45 if slot_i % 2 == 1 else 0.8)
		for a in get_tree().get_nodes_in_group("allies"):
			if _ok(a):
				var d: float = p.distance_to(a.global_position)
				var known: bool = (ai_target == a or aggressor == a) and d < _lose_r()
				if d < bs and (known or _sees(a, d)):
					best = a
					bs = d
		# 盯玩家的成员只在虫子贴脸（8 米内）时才回头打虫；流浪者不主动招惹战区首领
		var bug_r: float = 8.0 if (slot_i % 2 == 1 and best == m) else 34.0
		if raid.has_method("vision_range"):
			bug_r = minf(bug_r, raid.vision_range())
		var b = raid.nearest_bug(p, bug_r, false)
		if b != null and p.distance_to(b.global_position) < bs and (b == ai_target or _sees(b, p.distance_to(b.global_position))):
			best = b
			bs = p.distance_to(b.global_position)
	else:
		var anchor: Vector3 = raid.mech.global_position if _ok(raid.mech) else p
		for r in get_tree().get_nodes_in_group("rovers"):
			if _ok(r):
				var d: float = p.distance_to(r.global_position)
				if d < 42.0 and anchor.distance_to(r.global_position) < 48.0 and d * 0.9 < bs:
					best = r
					bs = d * 0.9
		var b = raid.nearest_bug(p, 32.0)
		if b != null and anchor.distance_to(b.global_position) < 40.0 and p.distance_to(b.global_position) < bs:
			best = b
			bs = p.distance_to(b.global_position)
	var hunter: bool = faction == "rover" and slot_i % 2 == 1 and best == raid.mech
	if _ok(aggressor) and aggressor != best and not hunter:
		var da: float = p.distance_to(aggressor.global_position)
		if da < _lose_r() and da * 0.7 < bs:
			best = aggressor
			bs = da * 0.7
	# 粘住当前目标：新目标不明显更近就不换，免得来回扭头
	if cur_ok and best != ai_target and best != null:
		var dc: float = p.distance_to(ai_target.global_position)
		if dc < _lose_r() and dc < bs + 6.0:
			best = ai_target
	ai_target = best
	_los = true
	if best != null:
		var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 2.0, 0), best.global_position + Vector3(0, 1.4, 0), 1)
		_los = get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## 移动方向（长度 = 相对全速的比例）
func _steer(delta: float) -> Vector3:
	var want := Vector3.ZERO
	var p := global_position
	if _ok(ai_target):
		var to: Vector3 = ai_target.global_position - p
		to.y = 0.0
		var d := to.length()
		var fwd := to / maxf(d, 0.01)
		var keep := clampf(_weapon_range() * 0.6, 7.0, 22.0)
		if faction == "rover" and ai_target == raid.mech and raid != null and raid.has_method("vision_toward_player"):
			keep = minf(keep, raid.vision_toward_player(p) * 0.8)
		_strafe_t -= delta
		if _strafe_t <= 0.0:
			_strafe_t = randf_range(1.5, 3.5)
			_strafe = -_strafe
		if not _los or d > keep + 4.0:
			want = _nav_to(ai_target.global_position, delta)
		elif d < keep - 4.0:
			want = -fwd * 0.7
		else:
			want = fwd.cross(Vector3.UP) * _strafe * 0.45
		# 队友不追太远：离玩家超过 24 米就往回收
		if faction == "ally" and _ok(raid.mech):
			var back: Vector3 = raid.mech.global_position - p
			back.y = 0.0
			if back.length() > 24.0:
				want = (want * 0.3 + back.normalized()).normalized()
	elif goal != Vector3.INF:
		var w := goal - p
		w.y = 0.0
		var L := w.length()
		if L > 2.5:
			want = _nav_to(goal, delta) * clampf(goal_scale * minf(L / 6.0, 1.0), 0.0, 1.0)
	# 卡住（贴墙）时向侧面绕一段
	if _detour_t > 0.0:
		_detour_t -= delta
		return (_detour + want * 0.4).normalized() * maxf(want.length(), 0.6)
	if want.length() > 0.3:
		_stuck_t += delta
		if _stuck_t > 1.4:
			if p.distance_to(_stuck_pos) < 0.8:
				nav_agent.stuck()
				_detour = want.cross(Vector3.UP).normalized() * (1.0 if randf() < 0.5 else -1.0)
				_detour_t = randf_range(0.9, 1.6)
			_stuck_pos = p
			_stuck_t = 0.0
	return want


## 朝 to 走的方向：直线可走就直线，被建筑挡住就沿导航网格（机甲间隙）的 A* 路径绕
func _nav_to(to: Vector3, delta: float) -> Vector3:
	if raid == null or raid.get("nav") == null:
		var w := to - global_position
		w.y = 0.0
		return w.normalized() if w.length_squared() > 0.0001 else Vector3.ZERO
	return nav_agent.steer(raid.nav, global_position, to, delta, true, 0.5 if lod == 0 else 1.0)


func _weapon_range() -> float:
	var r := 0.0
	for slot in ["arm_l", "arm_r"]:
		var id: String = loadout.get(slot, "")
		if id != "":
			r = maxf(r, GameData.weapon_range_m(GameData.module(id)))
	return r if r > 0.0 else 20.0


# ================================================================ 开火
func _npc_fire(slot: String) -> void:
	var id: String = loadout.get(slot, "")
	if id == "" or arm_cd[slot] > 0.0 or reload_t[slot] > 0.0 or parts[slot] <= 0.0:
		return
	var m: Dictionary = GameData.module(id)
	var w := str(m.get("weapon", "mg"))
	var uses_ammo := GameData.weapon_uses_ammo(w)
	if uses_ammo and ammo[slot] <= 0:
		_reload(slot)
		return
	arm_cd[slot] = 1.0 / maxf(float(m.get("rate", 1.0)), 0.05) * (1.3 if faction == "rover" else 1.0)
	recoil[slot] = 1.0
	if uses_ammo:
		ammo[slot] -= 1
		if ammo[slot] <= 0:
			_reload(slot)
	var muzzle: Node3D = muzzles.get(slot)
	var origin: Vector3 = muzzle.global_position if muzzle else global_position + Vector3(0, 2.0, 0)
	origin.y = clampf(origin.y, 1.2, 2.6)
	var dir := aim_dir()
	var inacc := 4.0 if faction == "rover" else 2.0
	dir = dir.rotated(Vector3.UP, deg_to_rad(randf_range(-inacc, inacc)))
	_shot(m, origin, dir)
	if lod == 0:
		_sfx_gap[slot] += 1
		var am: Dictionary = GameData.AMMO.get(w, {})
		if bool(am.get("fire_loop", false)):
			Audio.play_sfx("wpn_%s_ignite" % w, origin)
		elif float(m.get("rate", 1.0)) < 4.0 or _sfx_gap[slot] % 3 == 0:
			Audio.play_sfx(str(am.get("sfx", "wpn_%s_fire" % w)), origin)
		raid.muzzle_flash(origin, m.get("color", Color(1, 0.7, 0.3)), dir, w, float(m.get("dmg", 10.0)))


func _reload(slot: String) -> void:
	var id: String = loadout.get(slot, "")
	if id == "" or reload_t[slot] > 0.0:
		return
	var w: String = str(GameData.module(id).get("weapon", "mg"))
	if not GameData.weapon_uses_ammo(w):
		return
	reload_t[slot] = float(GameData.AMMO.get(w, {}).get("reload", 2.0)) * 1.2


func _shot(m: Dictionary, origin: Vector3, dir: Vector3) -> void:
	var mask := ROVER_MASK if faction == "rover" else ALLY_MASK
	var dmg: float = float(m.get("dmg", 8.0)) * dmg_mul
	var raw_dmg: float = float(m.get("dmg", 8.0))
	var w := str(m.get("weapon", "mg"))
	var rng_m: float = GameData.weapon_range_m(m)
	var speed: float = float(m.get("speed", 40.0))
	var c: Color = m.get("color", Color(1, 0.7, 0.3))
	var fo := GameData.weapon_falloff(m)
	match w:
		"laser", "arc":
			var is_rail := raw_dmg >= 60.0
			var spd_l := maxf(speed, 135.0 if is_rail else 96.0)
			var col_l := Color(0.55, 0.52, 1.0) if faction == "rover" else (Color(0.30, 0.86, 1.0) if is_rail else Color(0.24, 0.82, 1.0))
			var p_l = raid._tracer(origin, dir * spd_l, dmg, clampf(rng_m / maxf(spd_l, 20.0) * 6.0, 2.5, 6.0), col_l, 0.14 if is_rail else 0.10, 0.095 if is_rail else 0.072, "apfsds" if is_rail else "coil")
			p_l.mask = mask
			p_l.source = self
			p_l.apply_falloff(fo)
		"flamer", "cryo":
			var life_f := clampf(rng_m / maxf(speed, 12.0) * 6.0, 2.5, 6.0)
			var p = raid._proj(origin, dir * maxf(speed, 12.0) * randf_range(0.86, 1.12), dmg, life_f, mask, c, 0.34, false, w)
			p.pierce = true
			p.grow = 0.0
			p.hit_sfx = "-"
			p.source = self
			p.apply_falloff(fo)
		_:
			if speed <= 0.0:
				speed = 60.0
			var n: int = int(m.get("pellets", 1))
			for i in n:
				var a := deg_to_rad(randf_range(-float(m.get("spread", 2.0)), float(m.get("spread", 2.0))) * 0.5)
				var cal := "sniper_ap" if (w == "sniper" and raw_dmg >= 100.0) else ("sniper" if w == "sniper" else ("cannon" if (w in ["shotgun", "cannon", "launcher", "melee"] and raw_dmg >= 55.0) else ("slug" if (w in ["shotgun", "cannon", "launcher", "melee"] and n == 1) else ("pellet" if w == "shotgun" else ("ac30" if raw_dmg >= 20.0 else ("hmg" if raw_dmg >= 12.0 else "mg"))))))
				var wake_c := Color(1.0, 0.24, 0.14) if faction == "rover" else (
					Color(1.0, 0.74, 0.24) if w == "sniper" else (
					Color(1.0, 0.38, 0.12) if (cal == "cannon" or cal == "ac30") else (
					Color(1.0, 0.54, 0.16) if (cal == "hmg" or cal == "slug") else Color(1.0, 0.66, 0.20))))
				var p = raid._tracer(origin, dir.rotated(Vector3.UP, a) * speed, dmg, clampf(rng_m / maxf(speed, 20.0) * 6.0, 2.5, 6.0), wake_c, 0.12, 0.065, cal)
				p.mask = mask
				p.source = self
				p.apply_falloff(fo)


# ================================================================ 受击 / 死亡
func take_damage(amount: float) -> void:
	if dead:
		return
	var armor: float = clampf(float(stats.get("armor", 0.0)), 0.0, 0.6)
	var eff := amount * (1.0 - armor)
	var prev_hp := hp
	hp -= eff
	if faction == "rover" and raid != null and raid.hud != null and raid.hud.has_method("notify_enemy_hit"):
		raid.hud.notify_enemy_hit(self, prev_hp, hp, max_hp)
	hurt_flash = 0.13
	_update_hit_flash()
	kick_v += Vector3(randf_range(0.8, 1.6), randf_range(-1.0, 1.0), randf_range(-1.2, 1.2)) * clampf(eff / 14.0, 0.3, 1.2)
	if _ok(aggressor) and (aggressor == raid.mech or aggressor.is_in_group("coop_players") or aggressor.is_in_group("allies")):
		killed_by_player = true
	elif aggressor == null and faction == "rover":
		killed_by_player = true   # 爆炸等无来源伤害只来自玩家
	if hp <= 0.0:
		hp = 0.0
		die("destroyed")


func _collect_hit_meshes() -> void:
	if _hit_meshes_ready or not is_instance_valid(visual):
		return
	_hit_meshes_ready = true
	_hit_meshes.clear()
	for n in visual.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi == null or mi.get_meta("no_flash", false) or (mi.mesh is PlaneMesh):
			continue
		_hit_meshes.append(mi)


func _update_hit_flash() -> void:
	var q := clampi(int(ceil(clampf(hurt_flash / 0.13, 0.0, 1.0) * 5.0)), 0, 5) if hurt_flash > 0.0 else 0
	if q == _hit_flash_q:
		return
	_hit_flash_q = q
	_collect_hit_meshes()
	var mat: Material = A2.hit_flash_overlay(float(q) / 5.0) if q > 0 else null
	for mi in _hit_meshes:
		if is_instance_valid(mi):
			mi.material_overlay = mat


func die(_reason: String) -> void:
	if dead:
		return
	dead = true
	Audio.loop_stop(_lk("legs"))
	remove_from_group("npc_mechs")
	remove_from_group("rovers")
	remove_from_group("allies")
	collision_layer = 0
	collision_mask = 0
	for c in get_children():
		if c is CollisionShape3D:
			c.queue_free()
	velocity = Vector3.ZERO
	hurt_flash = 0.0
	_update_hit_flash()
	set_physics_process(false)
	set_process(false)
	set_notify_transform(false)
	var p := global_position
	if raid and is_instance_valid(raid.fx):
		raid.explode_fx(p + Vector3(0, 1.6, 0), 3.2, Color(1.0, 0.5, 0.2))
		Audio.play_sfx("explosion", p + Vector3(0, 1.0, 0))
	MechVisual.scatter(visual)
	if marker:
		marker.queue_free()
		marker = null
	if _ring_fx and is_instance_valid(_ring_fx):
		_ring_fx.queue_free()
		_ring_fx = null
	if name_label:
		name_label.queue_free()
		name_label = null
	if is_instance_valid(visual):
		for n in visual.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi == null:
				continue
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.material_overlay = null
			if not (mi.mesh is PlaneMesh) and mi.visibility_range_end <= 0.0:
				mi.visibility_range_end = 75.0
				mi.visibility_range_end_margin = 5.0
	if not Net.is_client():
		if faction == "rover" and raid:
			_drop_loot(p)
			if killed_by_player:
				raid.kills += 1
				if raid.hud:
					raid.hud.msg(Loc.t("流浪者机甲被击毁，残骸里散出物资箱。", "Rover mech destroyed; supply crate dropped in wreckage."))
		elif faction == "ally" and raid and raid.hud:
			raid.hud.msg(Loc.t("▲ 队友 %s 的机甲失去战斗能力" % _pilot_name().split(" · ")[0], "▲ Wingmate %s's mech incapacitated" % _pilot_name().split(" · ")[0]))
	npc_died.emit(self)


## 流浪者残骸：一个军械箱，内容来自 rover 掉落表，身上每件已装备模块各有 80% 概率爆出
func _drop_loot(p: Vector3) -> void:
	var items: Array = []
	if GameData.LOOT_TABLES.has("rover"):
		items = GameData.roll_loot("rover", raid.rng)
	for slot in ["core", "legs", "arm_l", "arm_r", "back", "gen"]:
		var mid := str(loadout.get(slot, ""))
		if mid != "" and GameData.is_module(mid) and raid.rng.randf() < 0.80:
			items.append(mid)
	if items.is_empty():
		items = ["bolts"]
	var b = raid._place_box("military", Vector3(p.x + 1.5, 0, p.z), items)
	if b:
		b.set_meta("rover_wreck", true)
		b.title = Loc.t("流浪者残骸", "Rover Wreck")


func refresh_lang() -> void:
	if name_label != null and is_instance_valid(name_label):
		name_label.text = Loc.t("流浪者", "Rover") if faction == "rover" else _pilot_name()


func _npc_audio_tick() -> void:
	if leg_type != "tread":
		return
	if lod != 0 or not _near:
		Audio.loop_set(_lk("legs"), -48.0, 0.85)
		return
	var sp := Vector2(velocity.x, velocity.z).length()
	var k := clampf(sp / maxf(float(stats.speed), 1.0), 0.0, 1.2)
	Audio.loop_set(_lk("legs"), lerpf(-42.0, -12.0, minf(k * 1.4, 1.0)), 0.8 + 0.3 * k)


func _footfall(leg: Node3D, i: int) -> void:
	if lod != 0 or raid == null or not is_instance_valid(raid.mech):
		return
	if global_position.distance_to(raid.mech.global_position) > 26.0:
		return
	_step_dip_v -= 1.0 * gait_amt
	var aj: Node3D = leg.get_meta("ankle")
	Audio.play_sfx("step_biped", aj.global_position, {"vol": -13.5})


func _quad_footfall(_leg_node: Node3D = null, _idx: int = -1) -> void:
	if lod != 0 or raid == null or not is_instance_valid(raid.mech):
		return
	if global_position.distance_to(raid.mech.global_position) > 26.0:
		return
	Audio.play_sfx("step_quad", global_position, {"vol": -14.0})
