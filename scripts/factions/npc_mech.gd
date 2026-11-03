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
	_paint()
	_add_marker()


func is_rover() -> bool:
	return faction == "rover"


# ================================================================ 外观
static var _tint_cache := {}

## 敌对涂装：流浪者的装甲漆成锈红、灯光改成红色；队友只把灯光换成青色识别灯
func _paint() -> void:
	for mi in visual.find_children("*", "MeshInstance3D", true, false):
		var m = mi.material_override
		if not (m is StandardMaterial3D):
			continue
		var key := "%s_%d" % [faction, m.get_instance_id()]
		if not _tint_cache.has(key):
			var d: StandardMaterial3D = m.duplicate()
			if d.emission_enabled:
				d.emission = ROVER_GLOW if faction == "rover" else ALLY_GLOW
				d.albedo_color = d.emission
			elif faction == "rover":
				d.albedo_color = d.albedo_color.lerp(ROVER_TINT, 0.55)
			_tint_cache[key] = d
		mi.material_override = _tint_cache[key]


func _add_marker() -> void:
	var c := ROVER_GLOW if faction == "rover" else ALLY_GLOW
	marker = Node3D.new()
	add_child(marker)
	marker.position.y = 5.6
	var mi := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.7, 0.8, 0.12)
	mi.mesh = pm
	mi.rotation_degrees.z = 180.0
	mi.material_override = A2.emit(c, 4.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.add_child(mi)
	var ring := A2.ground_decal(self, A2.ring_tex(), Color(c.r, c.g, c.b, 0.55), 3.6, Vector3(0, 0.05, 0), true)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	name_label = Label3D.new()
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.no_depth_test = true
	name_label.font_size = 40
	name_label.pixel_size = 0.016
	name_label.modulate = c.lightened(0.25)
	name_label.outline_size = 8
	name_label.outline_modulate = Color(0, 0, 0, 0.85)
	name_label.position.y = 6.5
	name_label.text = "流浪者" if faction == "rover" else _pilot_name()
	add_child(name_label)


func _pilot_name() -> String:
	var tbl: Dictionary = {}
	var p := "res://data/ext/progression.gd"
	if ResourceLoader.exists(p):
		var c: Dictionary = load(p).get_script_constant_map()
		for k in ["PILOTS", "CREW"]:
			tbl.merge(c.get(k, {}))
	var nm := str(tbl.get(pilot, {}).get("name", pilot if pilot != "" else "队友"))
	return "%s · T%d" % [nm, tier]


# ================================================================ 运行
func _lod_dt(delta: float) -> float:
	var d2 := 0.0
	if raid and is_instance_valid(raid.mech):
		d2 = global_position.distance_squared_to(raid.mech.global_position)
	_near = d2 < 30.0 * 30.0
	lod = 0 if d2 < 48.0 * 48.0 else (1 if d2 < 120.0 * 120.0 else 2)
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


func _physics_process(delta: float) -> void:
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
	if marker and lod == 0:
		marker.rotation.y += delta * 2.0
	_think_t -= delta
	if _think_t <= 0.0:
		_think_t = (0.25 if lod == 0 else 0.5) * randf_range(0.85, 1.15)
		_choose_target()
	var move := _steer(delta)
	var spd: float = float(stats.speed) * speed_mult() * (0.95 if faction == "rover" else 1.05)
	# 队友掉队超过 12 米且没在交战：加速追上（重型脚步的队友不然永远跟不上轻装玩家）
	if faction == "ally" and not _ok(ai_target) and goal != Vector3.INF and global_position.distance_to(goal) > 12.0:
		spd *= 1.6
	var hv := Vector3(velocity.x, 0, velocity.z)
	hv = hv.lerp(move * spd, clampf(7.0 * delta, 0.0, 1.0))
	velocity.x = hv.x
	velocity.z = hv.z
	velocity.y = -1.0 if is_on_floor() else velocity.y - 40.0 * delta
	_slide(delta)
	if move.length() > 0.1 and leg_type != "hover":
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
		if aim.dot(to / maxf(dist, 0.01)) > 0.93:
			for slot in ["arm_l", "arm_r"]:
				var id: String = loadout.get(slot, "")
				if id != "" and dist < float(GameData.module(id).get("range", 20.0)) * 0.95:
					_npc_fire(slot)
	# 程序动画（双足 IK 等）很贵：30 米内逐帧，画面边缘降到 30Hz，画面外不跑
	if lod == 0:
		_anim_acc += delta
		if _near or _anim_acc >= 0.033:
			_animate(_anim_acc, move)
			_anim_acc = 0.0


static func _ok(n) -> bool:
	return is_instance_valid(n) and n.get("dead") != true and n.get("dying") != true


## 画面外（LOD 中 / 远）不跑物理：直接平移，用建筑占地格子挡一下（撞上就沿侧面绕），近处照常 move_and_slide
func _slide(dt: float) -> void:
	if lod > 0 and raid and raid.has_method("ai_free"):
		var step := Vector3(velocity.x, 0.0, velocity.z) * dt
		if step.length_squared() < 0.0001:
			return
		var np := global_position + step
		var H: float = raid.HALF - 4.0
		if raid.ai_free(np, 1.2, true) and absf(np.x) < H and absf(np.z) < H:
			global_position = np
			return
		if raid.ai_free(global_position, 1.2, true):
			if _detour_t <= 0.0:
				_detour = step.cross(Vector3.UP).normalized() * (1.0 if randf() < 0.5 else -1.0)
				_detour_t = randf_range(0.8, 1.5)
			# 沿侧面挪一步；两侧都堵（墙角）就交给下面的真实物理去滑
			for side in [_detour, -_detour]:
				var alt: Vector3 = global_position + side * step.length()
				if raid.ai_free(alt, 1.2, true) and absf(alt.x) < H and absf(alt.z) < H:
					global_position = alt
					return
		# 已经压在建筑占地格子里（或贴着地图边）：退回真实物理 move_and_slide，不然会原地踏步
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
		var m = raid.mech
		if _ok(m):
			var d: float = p.distance_to(m.global_position)
			var known: bool = (ai_target == m or aggressor == m) and d < _lose_r()
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
		# 盯玩家的成员只在虫子贴脸（8 米内）时才回头打虫
		var bug_r: float = 8.0 if (slot_i % 2 == 1 and best == m) else 34.0
		if raid.has_method("vision_range"):
			bug_r = minf(bug_r, raid.vision_range())
		var b = raid.nearest_bug(p, bug_r)
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


## 朝 to 走的方向：直线可走就直线，被建筑挡住就沿导航网格（机甲间隙）的 A* 路径绕；悬浮腿也照样受建筑碰撞，同样寻路
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
			r = maxf(r, float(GameData.module(id).get("range", 20.0)))
	return r if r > 0.0 else 20.0


# ================================================================ 开火
func _npc_fire(slot: String) -> void:
	var id: String = loadout.get(slot, "")
	if id == "" or arm_cd[slot] > 0.0 or reload_t[slot] > 0.0 or parts[slot] <= 0.0:
		return
	var m: Dictionary = GameData.module(id)
	if ammo[slot] <= 0:
		_reload(slot)
		return
	arm_cd[slot] = 1.0 / maxf(float(m.get("rate", 1.0)), 0.05) * (1.3 if faction == "rover" else 1.0)
	recoil[slot] = 1.0
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
		var w := str(m.get("weapon", "mg"))
		if float(m.get("rate", 1.0)) < 4.0 or _sfx_gap[slot] % 3 == 0:
			Audio.play_sfx("wpn_%s_fire" % w if not bool(GameData.AMMO.get(w, {}).get("fire_loop", false)) else "wpn_%s_ignite" % w, origin)
		raid.muzzle_flash(origin, m.get("color", Color(1, 0.7, 0.3)), dir, w)


func _reload(slot: String) -> void:
	var id: String = loadout.get(slot, "")
	if id == "" or reload_t[slot] > 0.0:
		return
	var w: String = str(GameData.module(id).get("weapon", "mg"))
	reload_t[slot] = float(GameData.AMMO.get(w, {}).get("reload", 2.0)) * 1.2


func _shot(m: Dictionary, origin: Vector3, dir: Vector3) -> void:
	var mask := ROVER_MASK if faction == "rover" else ALLY_MASK
	var dmg: float = float(m.get("dmg", 8.0)) * dmg_mul
	var w := str(m.get("weapon", "mg"))
	var rng_m: float = float(m.get("range", 20.0))
	var speed: float = float(m.get("speed", 40.0))
	var c: Color = m.get("color", Color(1, 0.7, 0.3))
	match w:
		"laser", "arc":
			_beam(origin, dir, rng_m, dmg, mask, c)
		"flamer", "cryo":
			var p = raid._proj(origin, dir * maxf(speed, 12.0) * randf_range(0.8, 1.1), dmg, rng_m / maxf(speed, 12.0), mask, c, 0.35)
			p.pierce = true
			p.grow = 3.0
			p.hit_sfx = "-"
			p.source = self
		_:
			if speed <= 0.0:
				speed = 60.0
			var n: int = int(m.get("pellets", 1))
			for i in n:
				var a := deg_to_rad(randf_range(-float(m.get("spread", 2.0)), float(m.get("spread", 2.0))) * 0.5)
				var p = raid._tracer(origin, dir.rotated(Vector3.UP, a) * speed, dmg, rng_m / speed, Color(1.0, 0.35, 0.25) if faction == "rover" else Color(0.5, 0.9, 1.0), 0.12, 0.065)
				p.mask = mask
				p.source = self


func _beam(origin: Vector3, dir: Vector3, length: float, dmg: float, mask: int, c: Color) -> void:
	var to := origin + dir * length
	var q := PhysicsRayQueryParameters3D.create(origin, to, mask)
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	var end := to
	if not r.is_empty():
		end = r.position
		if "aggressor" in r.collider:
			r.collider.aggressor = self
		if r.collider.has_method("take_damage"):
			r.collider.take_damage(dmg)
		if lod == 0:
			raid.spark(end, c, 10)
	if lod > 0:
		return
	var len := origin.distance_to(end)
	if len < 0.2:
		return
	var beam := Node3D.new()
	raid.fx.add_child(beam)
	beam.global_position = (origin + end) * 0.5
	beam.look_at(end, Vector3.UP)
	A2.add(beam, A2.cyl(0.12, len, 0.12, 8), raid._beam_mat(c), Vector3.ZERO, Vector3(90, 0, 0), Vector3.ONE, false)
	var tw := beam.create_tween()
	tw.tween_property(beam, "scale", Vector3(0.05, 0.05, 1.0), 0.16).set_ease(Tween.EASE_IN)
	tw.tween_callback(beam.queue_free)


# ================================================================ 受击 / 死亡
func take_damage(amount: float) -> void:
	if dead:
		return
	var armor: float = clampf(float(stats.get("armor", 0.0)), 0.0, 0.6)
	var eff := amount * (1.0 - armor)
	hp -= eff
	hurt_flash = 0.2
	kick_v += Vector3(randf_range(0.8, 1.6), randf_range(-1.0, 1.0), randf_range(-1.2, 1.2)) * clampf(eff / 14.0, 0.3, 1.2)
	if _ok(aggressor) and (aggressor == raid.mech or aggressor.is_in_group("allies")):
		killed_by_player = true
	elif aggressor == null and faction == "rover":
		killed_by_player = true   # 爆炸等无来源伤害只来自玩家
	if hp <= 0.0:
		hp = 0.0
		die("击毁")


func die(_reason: String) -> void:
	if dead:
		return
	dead = true
	Audio.loop_stop(_lk("legs"))
	remove_from_group("npc_mechs")
	remove_from_group("rovers")
	remove_from_group("allies")
	collision_layer = 0
	collision_mask = 1
	velocity = Vector3.ZERO
	var p := global_position
	if raid and is_instance_valid(raid.fx):
		raid.explode_fx(p + Vector3(0, 1.6, 0), 3.2, Color(1.0, 0.5, 0.2))
		Audio.play_sfx("explosion", p + Vector3(0, 1.0, 0))
	MechVisual.scatter(visual)
	if marker:
		marker.queue_free()
		marker = null
	if name_label:
		name_label.queue_free()
		name_label = null
	if faction == "rover" and raid:
		_drop_loot(p)
		if killed_by_player:
			raid.kills += 1
			if raid.hud:
				raid.hud.msg("流浪者机甲被击毁，残骸里散出物资箱。")
	elif faction == "ally" and raid and raid.hud:
		raid.hud.msg("▲ 队友 %s 的机甲失去战斗能力" % _pilot_name().split(" · ")[0])
	npc_died.emit(self)
	var tw := create_tween()
	tw.tween_interval(14.0)
	tw.tween_property(self, "position:y", position.y - 3.0, 3.0)
	tw.tween_callback(queue_free)


## 流浪者残骸：一个军械箱，内容来自 rover 掉落表，另有一半概率拆下它身上的一件模块
func _drop_loot(p: Vector3) -> void:
	var items: Array = []
	if GameData.LOOT_TABLES.has("rover"):
		items = GameData.roll_loot("rover", raid.rng)
	if randf() < 0.5:
		var slots: Array = []
		for s in loadout:
			if str(loadout[s]) != "":
				slots.append(s)
		if not slots.is_empty():
			items.append(str(loadout[slots[randi() % slots.size()]]))
	if items.is_empty():
		items = ["bolts"]
	var b = raid._place_box("military", Vector3(p.x + 1.5, 0, p.z), items)
	if b:
		b.title = "流浪者残骸"


func _footfall(leg: Node3D, i: int) -> void:
	if lod != 0 or raid == null or not is_instance_valid(raid.mech):
		return
	if global_position.distance_to(raid.mech.global_position) > 30.0:
		return
	_step_dip_v -= 1.0 * gait_amt
	var aj: Node3D = leg.get_meta("ankle")
	Audio.play_sfx("step_biped", aj.global_position, {"vol": -10.0})
