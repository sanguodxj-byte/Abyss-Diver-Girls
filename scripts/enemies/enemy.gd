extends "res://scripts/bug.gd"
## 新虫种的通用基类：数据驱动的位置 AI + 时间轴动作，建模交给 scripts\enemies\models.gd。
##
## 数据（data 字典，来自 data\ext\enemies.gd）：
##   ai            行为原型：lancer 冲刺挥砍 / shell 重甲撞击 / bomber 自爆 / burrower 潜地伏击 /
##                 jammer 干扰放电 / flyer 低空俯冲 / support 护盾脉 / artillery 曲线炮击 / juggernaut 精英冲锋
##   windup/strike/recover  前摇、出手、收招时长；aggressive 的时间轴都从这里取，保证每次出手都有可读的预兆
##   charge_speed/charge_time  冲刺类动作的速度与时长
##   aggro         察觉距离；interrupt 前摇期间累计伤害达到 max_hp 的这个比例就被打断
##   armor         常驻减伤比例；front_resist 正面对机甲的减伤比例；armor_pierce 无视机甲护甲的比例
##   blast_r/blast_dmg/pool_dur/pool_dps  自爆半径、伤害与残留酸池
##   burrow_time/burrow_speed/erupt_r     潜地时长、地下速度、破土半径
##   pulse_r/pulse_heal/pulse_shield      支援脉冲的半径、修复量、护盾量
##   volley/shell_time                    齐射弹数与酸壳飞行时间
##   jam_r/jam_cost                       干扰脉冲半径与抽走的能量
##   keep/flee                            远程保持距离与贴身撤退距离；hover 飞行高度
##   loot/drop                            残骸掉落表与掉落概率（本类自己开箱，基础类的 drop 已置零）
##
## 状态：state 只有 idle / chase 两种（raid.gd 用 state == "chase" 判定交战）；
## 具体动作放在 act 上，按 seq 时间轴推进：wind → （行动步骤）→ recover。

const ART = preload("res://scripts/art.gd")
const Hazards = preload("res://scripts/enemies/hazards.gd")
const Models = preload("res://scripts/enemies/models.gd")

# ---- 行为参数 ----
var ai := "lancer"
var aggro := 17.0
var windup_t := 0.55
var strike_t := 0.18
var recover_t := 0.5
var charge_speed := 16.0
var charge_time := 0.25
var armor := 0.0
var front_resist := 0.0
var armor_pierce := 0.0
var interrupt := 0.0
var blast_r := 4.0
var blast_dmg := 30.0
var pool_dur := 0.0
var pool_dps := 0.0
var fuse_t := 1.1
var burrow_time := 6.0
var burrow_speed := 9.0
var erupt_r := 2.4
var pulse_r := 0.0
var pulse_heal := 0.0
var pulse_shield := 0.0
var volley := 1
var shell_time := 1.4
var keep := 0.0
var flee := 0.0
var hover := 0.0
var jam_r := 0.0
var jam_cost := 0.0
var loot_table := "bug"
var drop_chance := 0.0
var weak_back := 0.0
var weak_core := 0.0

# ---- 动作时间轴 ----
var seq: Array = []
var seq_i := 0
var wind_dmg := 0.0
var guard_t := 0.0
var underground := false
var fuse_lit := false
var trail_t := 0.0
var volley_offsets: Array = []   ## 炮击型前摇时定下落点偏移，出手时照这些点抛，预警圈不骗人
var focus := 0.0          ## 蓄力/充能的 0~1 进度，供动画与发光用
var rise_depth := 1.6     ## 出生（或 Boss 苏醒）时从地下升起的深度，按体型放大

# ---- 模型部件（models.gd 填，动画用） ----
var wings: Array = []
var plates: Array = []
var crystals: Array = []
var sacs: Array = []
var abdomen: Node3D
var turret: Node3D
var core_mi: MeshInstance3D
var crown: Node3D
## 最近一次出手前摇画下的地面预告；测试与调试用它确认每一次前摇都有可见的落点提示
var telegraph: Node3D


func setup(k: String, r, tgt) -> void:
	super.setup(k, r, tgt)
	# 每个实例一份数值副本：掉落改由本类按 loot 表开箱，其它参数也可能在战斗里临时调整
	data = data.duplicate(true)
	ai = str(data.get("ai", "lancer"))
	aggro = float(data.get("aggro", 17.0))
	aggro_range = aggro
	windup_t = float(data.get("windup", 0.55))
	strike_t = float(data.get("strike", 0.18))
	recover_t = float(data.get("recover", 0.5))
	charge_speed = float(data.get("charge_speed", 16.0))
	charge_time = float(data.get("charge_time", 0.25))
	armor = float(data.get("armor", 0.0))
	front_resist = float(data.get("front_resist", 0.0))
	armor_pierce = float(data.get("armor_pierce", 0.0))
	interrupt = float(data.get("interrupt", 0.0))
	blast_r = float(data.get("blast_r", 4.0))
	blast_dmg = float(data.get("blast_dmg", 30.0))
	pool_dur = float(data.get("pool_dur", 0.0))
	pool_dps = float(data.get("pool_dps", 0.0))
	fuse_t = float(data.get("fuse", 1.1))
	burrow_time = float(data.get("burrow_time", 6.0))
	burrow_speed = float(data.get("burrow_speed", 9.0))
	erupt_r = float(data.get("erupt_r", 2.4))
	pulse_r = float(data.get("pulse_r", 0.0))
	pulse_heal = float(data.get("pulse_heal", 0.0))
	pulse_shield = float(data.get("pulse_shield", 0.0))
	volley = int(data.get("volley", 1))
	shell_time = float(data.get("shell_time", 1.4))
	keep = float(data.get("keep", 0.0))
	flee = float(data.get("flee", 0.0))
	hover = float(data.get("hover", 0.0))
	jam_r = float(data.get("jam_r", 0.0))
	jam_cost = float(data.get("jam_cost", 0.0))
	weak_back = float(data.get("weak_back", 0.0))
	weak_core = float(data.get("weak_core", 0.0))
	drop_chance = float(data.get("drop", 0.0))
	loot_table = str(data.get("loot", "bug"))
	data["drop"] = 0.0
	if hover > 0.0:
		_fit_collider(hover + 1.6)


## 飞行单位的身高变化：碰撞胶囊跟着抬高，地面上射来的子弹仍能命中
func _fit_collider(height: float) -> void:
	for c in get_children():
		if c is CollisionShape3D:
			var sh := CylinderShape3D.new()
			sh.radius = float(data.radius) * 1.15
			sh.height = height
			c.shape = sh
			c.position.y = height * 0.5


func _build_visual() -> void:
	visual = Node3D.new()
	add_child(visual)
	var s: float = data.scale
	# 影子贴地挂在根节点上：飞行种抬升 visual 时地面阴影留在原处
	ART.ground_decal(self, ART.blob_tex(), Color(1, 1, 1, 0.7), Models.decal_size(kind) * s, Vector3(0, 0.03, 0))
	var body := Node3D.new()
	body.name = "Body"
	visual.add_child(body)
	Models.build(self, body, kind, s)


# ================= 受击与死亡 =================
## 受击：先过常驻减伤与正面折射，再过弱点倍率；前摇期间的累计伤害够多就打断这次出手。
func take_damage(amount: float, from := Vector3.ZERO) -> void:
	_wake()
	if hp <= 0.0 or dying or guard_t > 0.0 or underground:
		return
	var amt: float = maxf(amount, 0.0) * (1.0 - clampf(armor, 0.0, 0.9))
	if front_resist > 0.0 and _from_front(from):
		var blocked := amt * clampf(front_resist, 0.0, 0.9)
		amt -= blocked
		_refract(blocked)
	amt *= _weak_scale(from)
	amt = maxf(amt, 1.0)
	hp -= amt
	_aggro_on_hit()
	flash_t = 0.07
	_set_flash(true)
	var push := clampf(amt / float(data.hp) * 6.0, 0.15, 1.0) / float(data.scale)
	hit_v += Vector3(randf_range(-1.0, -0.4), 0, randf_range(-0.6, 0.6)) * push * 4.0
	if interrupt > 0.0 and act == "wind":
		wind_dmg += amt
		if wind_dmg >= float(data.hp) * interrupt:
			_cancel_act()
	if hp <= 0.0:
		_sfx("death")
		_on_killed()
	else:
		_sfx("hurt")


## 弱点倍率：默认没有弱点；Boss 重写。
func _weak_scale(_from: Vector3) -> float:
	return 1.0


## 伤害是否从正面来：取来弹方向，没有来弹方向时取机甲位置（本项目里机甲是唯一伤害源）。
func _from_front(from: Vector3) -> bool:
	var src := from
	if src == Vector3.ZERO:
		if target == null or not is_instance_valid(target):
			return false
		src = target.global_position
	var to := src - global_position
	to.y = 0.0
	if to.length() < 0.1:
		return false
	var faced := -visual.global_transform.basis.z
	faced.y = 0.0
	return faced.normalized().dot(to.normalized()) > 0.55


## 正面的能量束被晶甲折射：一道亮闪与碎屑，玩家能看出这一下被弹开了
func _refract(blocked: float) -> void:
	if raid == null:
		return
	var p := global_position + Vector3(0, 1.2, 0)
	if target != null and is_instance_valid(target):
		p -= (target.global_position - global_position).normalized() * 0.6
	ART.burst(raid.fx, p, {"amount": 8, "life": 0.35, "size": 0.1, "vmin": 3.0, "vmax": 8.0, "gravity": Vector3(0, -12, 0),
		"c0": Color(0.85, 0.6, 1.0, 0.9), "c1": Color(0.35, 0.1, 0.5, 0.0), "grow0": 1.0, "grow1": 0.2})
	if blocked > 4.0:
		Audio.play_sfx("hit_metal", p)


func _cancel_act() -> void:
	seq = []
	act = ""
	act_t = 0.0
	wind_dmg = 0.0
	focus = 0.0
	atk_cd = maxf(atk_cd, 0.7)
	hit_v += Vector3(-0.9, 0, 0)
	if raid:
		ART.burst(raid.fx, global_position + Vector3(0, 1.0, 0), {"amount": 6, "life": 0.4, "size": 0.12, "additive": false, "vmin": 2.0, "vmax": 5.0,
			"gravity": Vector3(0, -14, 0), "c0": Color(0.4, 0.38, 0.36), "c1": Color(0.3, 0.28, 0.26, 0.0), "grow0": 1.0, "grow1": 0.5})


func _on_killed() -> void:
	# 自爆体被点掉也要炸：先塌，再延时引爆
	if ai == "bomber":
		fuse_lit = true
		_sfx("fuse")
		var r = raid
		var p := global_position
		var rad := blast_r
		var dm := blast_dmg
		var pd := pool_dur
		var pdp := pool_dps
		get_tree().create_timer(0.35).timeout.connect(func(): bomber_blast(r, p, rad, dm, pd, pdp))
	_loot()
	if raid:
		raid.on_bug_killed(self)
	_die()


## 残骸：按 data 里的 loot 表开箱；data.drop 已被本类置零，基础类不会再开一个。
## 箱子一律用 "bug" 这个残骸外观（loot_box.gd 的 STYLE 只认固定的几种），内容取本敌种的掉落表。
func _loot() -> void:
	if raid == null or drop_chance <= 0.0:
		return
	if randf() >= drop_chance:
		return
	var table := loot_table if GameData.LOOT_TABLES.has(loot_table) else "bug"
	var p := Vector3(global_position.x, 0, global_position.z)
	raid._place_box("bug", p, GameData.roll_loot(table, raid.rng))


## 爆浆虫的爆开：伤害机甲、顺带波及周围虫群、留一滩腐蚀液
static func bomber_blast(raid, p: Vector3, rad: float, dmg: float, pool_time: float, pool_dps: float) -> void:
	if raid == null or not is_instance_valid(raid.fx):
		return
	raid.explode(p, rad, dmg * 0.5)
	ART.burst(raid.fx, p + Vector3(0, 0.8, 0), {"amount": 22, "life": 0.6, "size": rad * 0.5, "vmin": rad * 1.2, "vmax": rad * 2.4, "spread": 90.0,
		"gravity": Vector3(0, 3.0, 0), "damp": 5.0, "c0": Color(0.85, 1.0, 0.35, 0.9), "c1": Color(0.25, 0.45, 0.0, 0.0), "grow0": 0.6, "grow1": 1.6})
	Audio.play_sfx("bug_bomber_attack", p + Vector3(0, 1.0, 0))
	var foes: Array = raid.bug_foes() if raid.has_method("bug_foes") else [raid.mech]
	for m in foes:
		if m != null and is_instance_valid(m) and not m.dead:
			if Vector2(m.global_position.x - p.x, m.global_position.z - p.z).length() < rad + 0.8:
				m.kick_v += Vector3(-1.6, 0.0, 0.0)
				m.take_damage(dmg)
	if pool_time > 0.0:
		var pool := Hazards.AcidPool.new()
		raid.fx.add_child(pool)
		pool.setup(raid, p, rad * 0.62, pool_time, pool_dps)


## 对机甲造成伤害：距离判定、破甲、击退与特效都在这里
func _hit_mech(dmg: float, knock := 0.0, reach := -1.0) -> bool:
	var m = target
	if m == null or not is_instance_valid(m) or m.dead:
		return false
	var r: float = reach if reach > 0.0 else float(data.range) + 1.4
	if global_position.distance_to(m.global_position) > r:
		return false
	var deal := dmg
	if armor_pierce > 0.0 and m.get("stats") != null:
		# 破甲：机甲护甲只按 (1 - armor_pierce) 生效，反推出等效的入射伤害
		var a: float = clampf(float(m.stats.get("armor", 0.0)), 0.0, 0.6)
		var left := a * (1.0 - clampf(armor_pierce, 0.0, 1.0))
		if left < a:
			deal = dmg * (1.0 - left) / maxf(1.0 - a, 0.1)
	if "aggressor" in m:
		m.aggressor = self
	m.take_damage(deal)
	if knock > 0.0:
		m.kick_v += Vector3(knock, 0.0, randf_range(-0.6, 0.6))
	if raid:
		var dir: Vector3 = (m.global_position - global_position).normalized()
		raid.spark(m.global_position + Vector3(0, 1.3, 0) - dir * 0.7, Color(1.0, 0.7, 0.35), 9)
		if m == raid.mech:
			raid.shake = maxf(raid.shake, clampf(dmg / 90.0, 0.06, 0.3))
	return true


func _sfx(what: String) -> void:
	Audio.play_sfx("bug_%s_%s" % [sfx, what], global_position + Vector3(0, 0.9, 0))

# ================= AI =================
var enraged := false


## 远处睡眠（见 bug.gd _sleep）期间 guard_t 不逐帧递减，醒来补扣
func _on_wake(slept: float) -> void:
	if guard_t > 0.0:
		guard_t = maxf(0.0, guard_t - slept)


func _physics_tick(delta: float) -> void:
	if dying:
		return
	if guard_t > 0.0:
		guard_t = maxf(0.0, guard_t - delta)
	delta = _lod_dt(delta)
	if delta <= 0.0:
		return
	_perc_t -= delta
	if _perc_t <= 0.0:
		_perc_t = _perceive_period() * randf_range(0.8, 1.2)
		_perceive()
	atk_cd = maxf(0.0, atk_cd - delta)
	if flash_t > 0.0:
		flash_t -= delta
		if flash_t <= 0.0:
			_set_flash(false)
	var to := Vector3.ZERO
	var d := 999.0
	var valid: bool = _alive(target)
	if valid:
		to = target.global_position - global_position
		to.y = 0.0
		d = to.length()
	if state != _last_state:
		if state == "chase" and _last_state == "idle":
			if lod == 0:
				_sfx("appear")
			atk_cd = maxf(atk_cd, 0.45)
		_last_state = state
	if act != "":
		_tick_act(delta)
	var dir := _think(delta, to, d, valid)
	dir = _nav_adjust(dir, to, d, delta)
	_move(delta, dir)
	_face(delta, to, dir)
	# 地下潜行时一路扬起尘土：轨迹可读，玩家有时间离开
	if underground and raid and lod == 0:
		trail_t -= delta
		if trail_t <= 0.0:
			trail_t = 0.22
			Hazards.dust_trail(raid, global_position)
	if lod == 0:
		var mv := clampf(Vector2(velocity.x, velocity.z).length() / maxf(float(data.speed), 0.1), 0.0, 1.0)
		_animate(delta, mv)


func _think(delta: float, to: Vector3, d: float, valid: bool) -> Vector3:
	# 血量掉到一半的精英与 Boss 进入暴怒：节奏加快，行为本身不变
	if not enraged and hp > 0.0 and hp < float(data.hp) * 0.5 and ai in ["juggernaut", "jammer", "shell"]:
		enraged = true
		atk_cd = minf(atk_cd, 0.4)
	if not valid:
		if state == "chase":
			_lose_target()
		return _patrol(delta)
	if state == "idle":
		return _patrol(delta)
	if d > _lose_dist() + 5.0:
		_lose_target()
		return Vector3.ZERO
	var fwd := to / maxf(d, 0.01)
	if ai == "burrower" and act == "burrow_move":
		# 地下潜行：贴近到破土距离就提前冒头
		if d < maxf(erupt_r, 2.2):
			_advance()
		return Vector3.ZERO
	if act != "":
		return Vector3.ZERO
	match ai:
		"lancer":
			if atk_cd <= 0.0 and d < 16.0:
				atk_cd = _rate()
				_start_act([["wind", windup_t], ["charge", charge_time], ["strike", 0.14], ["recover", recover_t]], fwd)
				return Vector3.ZERO
			return _approach(fwd, d, 4.0, 9.0)
		"shell":
			if atk_cd <= 0.0 and d < 9.0:
				atk_cd = _rate()
				_start_act([["wind", windup_t], ["charge", charge_time], ["strike", 0.16], ["recover", recover_t]], fwd)
				return Vector3.ZERO
			return fwd if d > float(data.range) * 0.9 else Vector3.ZERO
		"bomber":
			if fuse_lit:
				return fwd * 0.4
			if d < 4.2 and atk_cd <= 0.0:
				atk_cd = _rate()
				fuse_lit = true
				_start_act([["wind", fuse_t], ["strike", 0.3]], fwd)
				return Vector3.ZERO
			return fwd
		"burrower":
			if atk_cd <= 0.0 and d < 22.0:
				atk_cd = _rate()
				_start_act([["wind", windup_t], ["burrow_move", burrow_time], ["wind", 0.55], ["strike", 0.3], ["recover", recover_t]], fwd)
				return Vector3.ZERO
			return fwd
		"jammer":
			if atk_cd <= 0.0 and d < jam_r:
				atk_cd = _rate()
				_start_act([["wind", windup_t], ["jam", 0.3], ["recover", recover_t]], fwd)
				return Vector3.ZERO
			return fwd if d > float(data.range) * 0.8 else Vector3.ZERO
		"flyer":
			if atk_cd <= 0.0 and d < 15.0:
				atk_cd = _rate()
				_start_act([["wind", windup_t], ["dive", charge_time], ["strike", 0.16], ["recover", recover_t]], fwd)
				return Vector3.ZERO
			# 盘旋：切向绕圈 + 把距离拉回 9 米
			var t := fwd.cross(Vector3.UP) * strafe
			var radial := fwd * clampf((d - 9.0) * 0.4, -1.0, 1.0)
			return (t + radial).normalized()
		"support":
			# 支援虫站在虫群后面：离机甲保持 keep，靠近同伴
			var ally = _nearest_ally()
			var base := fwd * clampf((d - keep) * 0.5, -1.0, 1.0)
			if ally != null:
				var av: Vector3 = ally.global_position - global_position
				av.y = 0.0
				if av.length() > 6.0:
					base += av.normalized() * 0.8
			if atk_cd <= 0.0 and d < 20.0:
				atk_cd = _rate() + 2.0
				_start_act([["wind", windup_t], ["pulse", 0.3], ["recover", recover_t]], fwd)
			return base.normalized() * 0.7
		"artillery":
			if atk_cd <= 0.0 and d < float(data.range) and d > flee * 0.6:
				atk_cd = _rate()
				_start_act([["wind", windup_t], ["volley", 0.25], ["recover", recover_t]], fwd)
				return Vector3.ZERO
			if d < flee:
				return -fwd
			if d > keep + 8.0:
				return fwd
			return fwd.cross(Vector3.UP) * strafe * 0.5
		"juggernaut":
			if atk_cd <= 0.0 and d < 14.0:
				atk_cd = _rate()
				_start_act([["wind", windup_t], ["charge", charge_time], ["strike", 0.18], ["recover", recover_t]], fwd)
				return Vector3.ZERO
			return fwd if d > float(data.range) else fwd * 0.3
	return _approach(fwd, d, float(data.range) * 0.8, 2.0)


## 追击寻路：_think 给出的是「朝目标」的理想方向；朝目标靠近（与目标方向夹角小）时换成导航方向——
## 直线可走照旧直线，被建筑挡住就沿 A* 绕。后退、绕圈、横移和各种动作（冲刺、俯冲、潜地）保持原样
func _nav_adjust(dir: Vector3, to: Vector3, d: float, delta: float) -> Vector3:
	if state != "chase" or act != "" or underground or d < 2.5 or not _alive(target) or bool(data.get("boss", false)):
		return dir
	var L := dir.length()
	if L < 0.05 or dir.dot(to / maxf(d, 0.01)) < 0.5 * L:
		return dir
	return _chase_dir(to / maxf(d, 0.01), d, delta) * L


func _uses_nav() -> bool:
	return not bool(data.get("boss", false)) and not underground


## 接近目标：远则直线靠近，进入 weapon 距离后停下；太近则后退一点
func _approach(fwd: Vector3, d: float, near: float, back: float) -> Vector3:
	if d > near:
		return fwd
	if d < back:
		return -fwd * 0.7
	return fwd.cross(Vector3.UP) * strafe * 0.35


func _wander(delta: float) -> Vector3:
	wander_t -= delta
	if wander_t <= 0.0:
		wander_t = randf_range(2.0, 5.0)
		wander_to = home + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
	var w := wander_to - global_position
	w.y = 0.0
	if w.length() > 1.0:
		return w.normalized() * 0.35
	return Vector3.ZERO


func _rate() -> float:
	var r := float(data.rate)
	if enraged:
		r *= 0.6
	return r


func _nearest_ally():
	var best = null
	var bd := 14.0
	for b in get_tree().get_nodes_in_group("bugs"):
		if b == self or not is_instance_valid(b) or b.dying:
			continue
		var d: float = b.global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = b
	return best


func _face(delta: float, to: Vector3, dir: Vector3) -> void:
	var face := dir if dir.length() > 0.05 else to
	if act in ["charge", "strike", "dive", "wind", "volley", "jam", "pulse"]:
		face = act_dir
	if face.length() > 0.05:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-face.x, -face.z), clampf(9.0 * delta, 0.0, 1.0))


func _move(delta: float, dir: Vector3) -> void:
	var spd: float = float(data.speed)
	if act == "charge" or act == "dive":
		dir = act_dir
		spd = charge_speed
	elif act == "burrow_move":
		# 地下往机甲脚下掘进：方向实时更新，轨迹会一路跟过来
		if target != null and is_instance_valid(target):
			var live: Vector3 = target.global_position - global_position
			live.y = 0.0
			if live.length() > 0.1:
				act_dir = live.normalized()
		dir = act_dir
		spd = burrow_speed
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	if hover > 0.0 or underground:
		velocity.y = 0.0
	else:
		velocity.y = -1.0 if is_on_floor() else velocity.y - 30.0 * delta
	_slide(delta)


# ================= 动作时间轴：wind（前摇）→ 行动步骤 → recover（收招） =================
var step_len := 0.0


func _start_act(steps: Array, dir: Vector3) -> void:
	seq = steps
	seq_i = 0
	wind_dmg = 0.0
	focus = 0.0
	act_dir = Vector3(dir.x, 0.0, dir.z)
	act_dir = act_dir.normalized() if act_dir.length() > 0.01 else Vector3.FORWARD
	act = str(steps[0][0])
	act_t = float(steps[0][1])
	step_len = act_t
	_act_enter(act)


func _tick_act(delta: float) -> void:
	act_t -= delta
	if act == "wind":
		focus = clampf(1.0 - act_t / maxf(step_len, 0.05), 0.0, 1.0)
	if act_t > 0.0:
		return
	_advance()


## 推进到下一个步骤；整串走完回到自由行动
func _advance() -> void:
	seq_i += 1
	if seq_i >= seq.size():
		act = ""
		act_t = 0.0
		seq = []
		focus = 0.0
		if underground:
			_surface()
		return
	act = str(seq[seq_i][0])
	act_t = float(seq[seq_i][1])
	step_len = act_t
	_act_enter(act)


func _act_enter(name: String) -> void:
	step_len = act_t
	match name:
		"wind":
			if underground:
				_surface()
			focus = 0.0
			wind_dmg = 0.0
			_sfx("windup")
			_on_wind()
		"charge":
			_sfx("attack")
			_dash_fx()
		"dive":
			_sfx("attack")
			_dash_fx()
		"strike":
			_strike()
		"burrow_move":
			_burrow_in()
		"volley":
			_volley()
		"jam":
			_jam()
		"pulse":
			_pulse()
		_:
			pass


## 前摇的预告：每一种在蓄力时都要让玩家看得出来「接下来会发生什么」
func _on_wind() -> void:
	if raid == null:
		return
	var p := global_position
	match ai:
		"lancer", "juggernaut":
			# 重心后坐、刃/颚抬起：脚边一圈扬尘标出将要冲刺的方向
			ART.burst(raid.fx, p + Vector3(0, 0.25, 0) - act_dir * 0.8, {"amount": 7, "life": 0.7, "size": 1.1, "tex": ART.smoke_tex(), "additive": false,
				"dir": -act_dir, "spread": 55.0, "vmin": 1.2, "vmax": 3.0, "gravity": Vector3(0, 0.6, 0), "damp": 3.0,
				"c0": Color(0.66, 0.6, 0.5, 0.45), "c1": Color(0.6, 0.54, 0.46, 0.0), "grow0": 0.5, "grow1": 1.7})
			_telegraph_lane(charge_speed * charge_time + float(data.range) + 2.8, float(data.radius) * 2.6,
				windup_t + charge_time + strike_t + 0.25, Color(1.0, 0.48, 0.16))
		"shell":
			_telegraph_lane(charge_speed * charge_time + float(data.range) + 2.4, float(data.radius) * 2.4,
				windup_t + charge_time + strike_t + 0.25, Color(1.0, 0.52, 0.2))
		"bomber":
			ART.burst(raid.fx, p + Vector3(0, 1.0, 0), {"amount": 8, "life": 0.5, "size": 0.22, "vmin": 0.6, "vmax": 1.6, "spread": 60.0, "gravity": Vector3(0, 2.0, 0),
				"c0": Color(0.95, 0.85, 0.3, 0.8), "c1": Color(0.5, 0.35, 0.0, 0.0), "grow0": 1.0, "grow1": 0.2})
			_telegraph_ring(blast_r, windup_t + 0.35, Color(1.0, 0.62, 0.16))
		"burrower":
			ART.burst(raid.fx, p + Vector3(0, 0.15, 0), {"amount": 10, "life": 0.9, "size": 1.6, "tex": ART.smoke_tex(), "additive": false, "spread": 80.0,
				"vmin": 1.4, "vmax": 3.4, "gravity": Vector3(0, 1.0, 0), "damp": 2.6, "c0": Color(0.66, 0.58, 0.46, 0.5), "c1": Color(0.6, 0.52, 0.42, 0.0),
				"grow0": 0.5, "grow1": 1.8})
			_telegraph_ring(erupt_r + 0.6, windup_t + strike_t + 0.45, Color(1.0, 0.68, 0.3))
		"artillery":
			# 落点在这一刻就定下：先亮预警圈，出手时照同样的偏移抛射
			volley_offsets = []
			for i in volley:
				var off := Vector3(randf_range(-2.2, 2.2), 0, randf_range(-2.2, 2.2))
				volley_offsets.append(off)
				var mk := Hazards.Mark.new()
				raid.fx.add_child(mk)
				mk.setup(raid, target.global_position + off, blast_r, windup_t + 0.05, Color(0.72, 0.9, 0.3))
				telegraph = mk
		"jammer":
			ART.burst(raid.fx, p + Vector3(0, 1.4, 0), {"amount": 10, "life": 0.5, "size": 0.12, "vmin": 2.0, "vmax": 5.0, "spread": 90.0, "gravity": Vector3(0, -4, 0),
				"c0": Color(0.75, 0.55, 1.0, 0.9), "c1": Color(0.25, 0.1, 0.5, 0.0), "grow0": 1.0, "grow1": 0.3})
			_telegraph_ring(jam_r, windup_t + 0.35, Color(0.72, 0.45, 1.0))
		"support":
			ART.burst(raid.fx, p + Vector3(0, 1.2, 0), {"amount": 12, "life": 0.7, "size": 0.16, "vmin": 0.6, "vmax": 2.0, "spread": 120.0, "gravity": Vector3(0, 1.6, 0),
				"c0": Color(0.5, 1.0, 0.75, 0.9), "c1": Color(0.1, 0.4, 0.3, 0.0), "grow0": 1.0, "grow1": 0.2})
			_telegraph_ring(pulse_r, windup_t + 0.5, Color(0.4, 1.0, 0.72))
		"flyer":
			ART.burst(raid.fx, p + Vector3(0, hover * 0.6, 0), {"amount": 8, "life": 0.4, "size": 0.3, "dir": Vector3.DOWN, "spread": 40.0, "vmin": 2.0, "vmax": 5.0,
				"gravity": Vector3(0, -3, 0), "c0": Color(0.9, 0.85, 0.6, 0.5), "c1": Color(0.6, 0.55, 0.35, 0.0), "grow0": 1.0, "grow1": 0.3})
			var reach := 8.0
			if target != null and is_instance_valid(target):
				var tv: Vector3 = target.global_position - global_position
				tv.y = 0.0
				reach = clampf(tv.length() + 2.5, 6.0, 26.0)
			_telegraph_lane(reach, float(data.radius) * 3.2, windup_t + charge_time + strike_t + 0.3, Color(1.0, 0.7, 0.24))
		_:
			pass


## 范围预告：一圈按半径铺开的地面环带
func _telegraph_ring(radius: float, dur: float, c: Color) -> void:
	if raid == null or not is_instance_valid(raid.fx):
		return
	var tg := Hazards.Telegraph.new()
	raid.fx.add_child(tg)
	tg.setup_ring(raid, global_position, radius, dur, c)
	telegraph = tg


## 冲锋预告：从脚下沿 act_dir 铺出的窄带，末端是落点圈
func _telegraph_lane(length: float, width: float, dur: float, c: Color) -> void:
	if raid == null or not is_instance_valid(raid.fx):
		return
	var tg := Hazards.Telegraph.new()
	raid.fx.add_child(tg)
	tg.setup_lane(raid, global_position, act_dir, width, length, dur, c)
	telegraph = tg


## 冲刺起步：脚下一圈尘环 + 身后一道速度线，这一下是可以被侧闪躲开的直线
func _dash_fx() -> void:
	if raid == null:
		return
	var p := global_position
	_dash_trail(p, act_dir)
	ART.burst(raid.fx, p + Vector3(0, 0.2, 0) - act_dir * 0.6, {"amount": 9, "life": 0.6, "size": 1.3, "tex": ART.smoke_tex(), "additive": false, "dir": -act_dir,
		"spread": 60.0, "vmin": 2.0, "vmax": 4.5, "gravity": Vector3(0, 0.5, 0), "damp": 4.0, "c0": Color(0.7, 0.64, 0.54, 0.5), "c1": Color(0.66, 0.6, 0.52, 0.0),
		"grow0": 0.5, "grow1": 1.8})


## 冲刺速度线：从脚下沿冲刺方向拉出的一小段压扁的烟迹
func _dash_trail(p: Vector3, dir: Vector3) -> void:
	var e := ART.emitter(raid.fx, p + Vector3(0, 0.7, 0), {"amount": 12, "life": 0.34, "size": 0.7, "tex": ART.smoke_tex(), "additive": false, "dir": -dir, "spread": 8.0,
		"vmin": 1.0, "vmax": 2.0, "gravity": Vector3.ZERO, "damp": 6.0, "c0": Color(0.72, 0.66, 0.56, 0.45), "c1": Color(0.7, 0.64, 0.56, 0.0), "grow0": 0.6, "grow1": 2.0})
	e.flatness = 0.8


func _strike() -> void:
	match ai:
		"lancer":
			_hit_mech(float(data.dmg), 1.4, float(data.range) + 2.6)
			_slash_fx(act_dir)
		"shell":
			_hit_mech(float(data.dmg), 2.4, float(data.range) + 2.4)
		"juggernaut":
			_hit_mech(float(data.dmg), 2.8, float(data.range) + 2.8)
			if raid:
				raid.shake = maxf(raid.shake, 0.3)
		"jammer":
			_hit_mech(float(data.dmg), 1.2)
		"flyer":
			_hit_mech(float(data.dmg), 0.7, float(data.range) + 2.2)
		"bomber":
			_self_destruct()
		"burrower":
			_erupt()
		_:
			pass


## 镰刃挥落的弧光：一段短促的白刃拖影
func _slash_fx(dir: Vector3) -> void:
	if raid == null:
		return
	var p := global_position + Vector3(0, 1.0, 0) + dir * float(data.range) * 0.7
	var side := dir.cross(Vector3.UP)
	for k in 3:
		var mi: MeshInstance3D = ART.add(raid.fx, ART.capsule(0.05, 2.2 + k * 0.3), ART.emit(Color(1.0, 0.95, 0.85), 3.0),
			p + side * (k - 1) * 0.55 + Vector3(0, 0.2 * k, 0), Vector3(0, 0, 0))
		mi.look_at(p + dir * 3.0 + Vector3(0, -0.5, 0), Vector3.UP)
		mi.rotate_object_local(Vector3.FORWARD, PI * 0.5)
		var tw := mi.create_tween()
		tw.tween_property(mi, "scale", Vector3(0.2, 1.4, 0.2), 0.16)
		tw.tween_property(mi, "transparency", 1.0, 0.12)
		tw.tween_callback(mi.queue_free)


func _burrow_in() -> void:
	underground = true
	collision_layer = 0
	visual.visible = false
	trail_t = 0.0
	_sfx("windup")
	if raid:
		ART.burst(raid.fx, global_position + Vector3(0, 0.2, 0), {"amount": 14, "life": 0.8, "size": 1.8, "tex": ART.smoke_tex(), "additive": false, "spread": 90.0,
			"vmin": 1.6, "vmax": 4.2, "gravity": Vector3(0, 1.2, 0), "damp": 3.0, "c0": Color(0.6, 0.52, 0.4, 0.6), "c1": Color(0.55, 0.48, 0.38, 0.0), "grow0": 0.5, "grow1": 1.9})


## 从地下冒头：恢复碰撞与外观，扬起一圈土
func _surface() -> void:
	underground = false
	collision_layer = 4
	visual.visible = true
	if raid:
		Hazards.dust_trail(raid, global_position)
		ART.burst(raid.fx, global_position + Vector3(0, 0.3, 0), {"amount": 14, "life": 0.7, "size": 1.4, "additive": false, "spread": 85.0, "vmin": 2.0, "vmax": 5.0,
			"gravity": Vector3(0, 1.0, 0), "damp": 3.4, "c0": Color(0.55, 0.48, 0.38, 0.8), "c1": Color(0.5, 0.44, 0.34, 0.0), "grow0": 0.6, "grow1": 1.4})
		Audio.play_sfx("bug_burrower_erupt", global_position)


## 破土：从机甲脚下顶出来，把机甲挑离地面
func _erupt() -> void:
	if raid == null:
		return
	Audio.play_sfx("bug_burrower_attack", global_position)
	ART.burst(raid.fx, global_position + Vector3(0, 0.4, 0), {"amount": 18, "life": 0.8, "size": 1.5, "additive": false, "spread": 90.0, "vmin": 3.0, "vmax": 7.0,
		"gravity": Vector3(0, -14, 0), "c0": Color(0.5, 0.42, 0.32, 0.9), "c1": Color(0.45, 0.38, 0.3, 0.0), "grow0": 1.0, "grow1": 0.6})
	var m = target
	if m != null and is_instance_valid(m) and not m.dead and global_position.distance_to(m.global_position) < erupt_r + 1.2:
		m.velocity.y = 7.5
		m.kick_v += Vector3(-2.2, 0.0, 0)
		m.take_damage(float(data.dmg))
		raid.shake = maxf(raid.shake, 0.32)


## 曲线炮击：每发炮弹落点独立，飞行途中落点上一直有预警圈
func _volley() -> void:
	if raid == null or target == null or not is_instance_valid(target):
		return
	Audio.play_sfx("bug_mortar_launch", global_position + Vector3(0, 1.0, 0))
	var from := global_position + Vector3(0, 1.0 * float(data.scale), 0) - act_dir * 0.8
	for i in volley:
		var off: Vector3 = volley_offsets[i] if i < volley_offsets.size() else Vector3.ZERO
		var sh := Hazards.LobShell.new()
		raid.fx.add_child(sh)
		sh.setup(raid, from, target.global_position + off, shell_time + i * 0.12, blast_r, float(data.dmg), Color(0.66, 0.95, 0.3))
	raid.alert_noise(global_position, 26.0)


## 干扰脉冲：抽走动力炉电量，短时间里让机甲的能量读数往下跳
func _jam() -> void:
	if raid == null:
		return
	var m = target
	if m == null or not is_instance_valid(m) or m.dead:
		return
	if global_position.distance_to(m.global_position) > jam_r:
		return
	_sfx("jam")
	m.energy = maxf(0.0, m.energy - jam_cost)
	var a := global_position + Vector3(0, 1.6 * float(data.scale), 0)
	var b: Vector3 = m.global_position + Vector3(0, 1.8, 0)
	for k in 4:
		var mid: Vector3 = a.lerp(b, float(k) / 4.0) + Vector3(randf_range(-0.6, 0.6), randf_range(-0.4, 0.4), randf_range(-0.6, 0.6))
		ART.burst(raid.fx, mid, {"amount": 4, "life": 0.25, "size": 0.1, "vmin": 0.5, "vmax": 1.6, "gravity": Vector3.ZERO,
			"c0": Color(0.8, 0.6, 1.0, 0.95), "c1": Color(0.3, 0.1, 0.6, 0.0), "grow0": 1.0, "grow1": 0.2})
	raid.spark(b, Color(0.75, 0.6, 1.0), 12)
	raid.shake = maxf(raid.shake, 0.2)


## 护盾脉：给半径内的虫群上临时护盾（血量上限之外的护盾值）并修甲，自身也吃一份
func _pulse() -> void:
	if raid == null:
		return
	_sfx("pulse")
	var ring := ART.ground_decal(raid.fx, ART.ring_tex(), Color(0.45, 1.0, 0.75, 0.9), pulse_r * 0.5, Vector3(global_position.x, 0.06, global_position.z), true)
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector3.ONE * 4.0, 0.35)
	tw.parallel().tween_property(ring, "transparency", 1.0, 0.4)
	tw.tween_callback(ring.queue_free)
	for b in get_tree().get_nodes_in_group("bugs"):
		if not is_instance_valid(b) or b.dying:
			continue
		if b.global_position.distance_to(global_position) > pulse_r:
			continue
		shield_ally(raid, b, pulse_heal, pulse_shield)


## 给一只虫上护盾：超出上限的部分作为临时护盾，被打光就没了；外壳泡罩随护盾一起消失
static func shield_ally(raid, b, heal: float, shield: float) -> void:
	if b == null or not is_instance_valid(b) or b.hp <= 0.0:
		return
	var cap: float = float(b.data.hp) * 1.5
	b.hp = minf(b.hp + heal + shield, cap)
	var old = b.get_meta("shield_fx") if b.has_meta("shield_fx") else null
	if old != null and is_instance_valid(old):
		old.queue_free()
	var mi: MeshInstance3D = ART.add(b, ART.sphere(float(b.data.radius) * 1.5, -1, 16), ART.emit(Color(0.4, 1.0, 0.8), 1.1), Vector3(0, 0.9 * float(b.data.scale), 0),
		Vector3.ZERO, Vector3.ONE, false)
	mi.set_meta("shield", true)
	b.set_meta("shield_fx", mi)
	var tw := mi.create_tween()
	tw.tween_interval(3.2)
	tw.tween_property(mi, "transparency", 1.0, 0.6)
	tw.tween_callback(mi.queue_free)


## 自爆：先炸再死，残骸照开
func _self_destruct() -> void:
	if hp <= 0.0 or dying:
		return
	hp = 0.0
	bomber_blast(raid, global_position, blast_r, blast_dmg, pool_dur, pool_dps)
	_sfx("death")
	_loot()
	if raid:
		raid.on_bug_killed(self)
	_die()


# ================= 程序动画 =================
## 步频：小虫迈得急，重甲迈得沉；飞行种几乎不迈腿
func _cadence() -> float:
	match ai:
		"lancer": return 12.0
		"flyer": return 4.0
		"shell", "juggernaut": return 5.5
		"jammer": return 7.0
		"bomber", "burrower": return 8.5
		"support": return 6.0
		"artillery": return 7.0
		_: return 8.0


## 动作姿态：每种虫子的前摇都要在轮廓上看得出来（身体后坐 / 压低 / 抬腹 / 抬头）
func _pose(act_name: String) -> Dictionary:
	var pitch := 0.0
	var fwd := 0.0
	var dy := 0.0
	var roll := 0.0
	match act_name:
		"wind":
			match ai:
				"lancer": pitch = 0.3; fwd = 0.42; dy = -0.14
				"shell": pitch = -0.2; dy = 0.12
				"bomber": pitch = -0.12; dy = 0.2
				"burrower": pitch = -0.22; dy = 0.1
				"jammer": pitch = -0.18; dy = 0.1
				"flyer": pitch = -0.55; dy = 0.3
				"support": pitch = -0.1; dy = 0.24
				"artillery": pitch = -0.34; dy = 0.14
				"juggernaut": pitch = 0.22; fwd = 0.46; dy = -0.08
		"charge", "dive":
			if ai == "flyer":
				pitch = 0.6
				dy = -hover * 0.62
			else:
				pitch = -0.16
				fwd = -0.62
		"strike":
			match ai:
				"shell", "juggernaut": pitch = 0.26; fwd = -0.72; dy = -0.16
				"flyer": pitch = 0.24; dy = -0.2
				"bomber": dy = 0.34
				"burrower": pitch = -0.3; dy = 0.4
				_: pitch = -0.12; fwd = -0.54
		"jam", "pulse", "volley":
			pitch = -0.14
			dy = 0.06
		"recover":
			pitch = clampf(act_t, 0.0, 0.5) * 0.12
			roll = sin(act_t * 9.0) * 0.05
	return {"pitch": pitch, "fwd": fwd, "dy": dy, "roll": roll}


func _animate_impl(delta: float, mv: float) -> void:
	move_amt = move_toward(move_amt, clampf(mv, 0.0, 1.0), delta * 6.0)
	var cad := _cadence()
	anim_t += delta * (0.3 + move_amt)
	var amt := move_amt
	var swing := 0.4 if ai != "flyer" else 0.16
	var liftk := 0.42 if ai in ["lancer", "burrower"] else (0.34 if ai != "flyer" else 0.08)
	var k := clampf(16.0 * delta, 0.0, 1.0)
	for hip in legs:
		var ph: float = anim_t * cad + float(hip.get_meta("phase"))
		var side: float = float(hip.get_meta("side"))
		var sy: float = float(hip.get_meta("base_y")) - sin(ph) * swing * amt * side
		var lz: float = maxf(0.0, cos(ph)) * liftk * amt * side
		if act == "wind" and ai in ["shell", "juggernaut"]:
			lz += 0.1 * side
		hip.rotation.y = lerp_angle(hip.rotation.y, sy, k)
		hip.rotation.z = lerp(hip.rotation.z, lz, k)
	var body: Node3D = visual.get_node("Body")
	hit_v += (-hit_tilt * 160.0 - hit_v * 13.0) * delta
	hit_tilt += hit_v * delta
	var sc := float(data.scale)
	var by := absf(sin(anim_t * cad)) * 0.05 * amt * sc
	var roll := sin(anim_t * cad * 0.5) * 0.04 * amt
	var pose := _pose(act)
	var kk := clampf((22.0 if act == "strike" else 10.0) * delta, 0.0, 1.0)
	body.position.y = lerp(body.position.y, by + float(pose.dy) * sc, kk)
	body.position.z = lerp(body.position.z, float(pose.fwd) * sc, kk)
	body.rotation.x = lerp(body.rotation.x, float(pose.pitch), kk) + hit_tilt.x
	body.rotation.z = lerp(body.rotation.z, roll + float(pose.roll), kk) + hit_tilt.z
	# ---- 部件：翅 / 腹 / 盾盖 / 卵囊 / 晶簇 / 颚 / 刃臂 ----
	for w in wings:
		if not is_instance_valid(w):
			continue
		var side: float = float(w.get_meta("side", 1.0))
		var flap: float = sin(anim_t * (26.0 if act == "dive" else 19.0) + side) * (0.75 if ai == "flyer" else 0.1)
		if act == "recover" and ai == "flyer":
			flap = sin(anim_t * 30.0) * 0.9
		w.rotation.z = lerp(w.rotation.z, side * (-0.15 + flap * 0.5), clampf(14.0 * delta, 0.0, 1.0))
		w.rotation.x = lerp(w.rotation.x, flap * 0.35, clampf(14.0 * delta, 0.0, 1.0))
	if abdomen:
		var ap := sin(anim_t * 2.4) * 0.05
		if act == "wind" and ai == "artillery":
			ap = -0.55
		elif act == "volley":
			ap = 0.22
		elif act == "strike" and ai in ["shell", "juggernaut"]:
			ap = 0.3
		abdomen.rotation.x = lerp(abdomen.rotation.x, ap, clampf(7.0 * delta, 0.0, 1.0))
	if turret:
		var ty := 0.0 if act != "wind" else -0.35
		turret.rotation.x = lerp(turret.rotation.x, ty, clampf(8.0 * delta, 0.0, 1.0))
	if crown:
		var ck := 0.0
		if ai == "support":
			ck = 0.5 if act in ["wind", "pulse"] else 0.12
		elif ai in ["artillery", "shell"] and act == "wind":
			ck = 0.3
		crown.rotation.x = lerp(crown.rotation.x, ck, clampf(6.0 * delta, 0.0, 1.0))
	for s2 in sacs:
		if not is_instance_valid(s2):
			continue
		var puff: float = 1.0 + sin(anim_t * 4.0) * 0.07
		if ai == "bomber":
			puff += focus * 0.55
			if fuse_lit:
				puff += 0.25 + sin(anim_t * 22.0) * 0.12
		s2.scale = Vector3(puff, puff * 0.92, puff * 1.06)
	for cr in crystals:
		if not is_instance_valid(cr):
			continue
		var j: float = 1.0 + sin(anim_t * 3.0 + float(cr.get_index())) * 0.03
		cr.scale = cr.get_meta("base_scale", Vector3.ONE) * j
	for pl in plates:
		if not is_instance_valid(pl):
			continue
		var side: float = float(pl.get_meta("side", 1.0))
		var fl: float = 0.0
		if act == "wind":
			fl = 0.25 * side
		elif act == "strike":
			fl = -0.12 * side
		pl.rotation.z = lerp(pl.rotation.z, fl, clampf(9.0 * delta, 0.0, 1.0))
	for j2 in jaws:
		var open := 0.3 + sin(anim_t * 9.0) * 0.08
		if act == "wind":
			open = 0.95
		elif act == "strike":
			open = -0.05
		j2.rotation.y = lerp(j2.rotation.y, float(sign(j2.position.x)) * open, clampf(18.0 * delta, 0.0, 1.0))
	for sc2 in scythes:
		var rx := sin(anim_t * 3.0) * 0.05
		if act == "wind":
			rx = 0.75
		elif act == "strike":
			rx = -0.4
		sc2.rotation.x = lerp(sc2.rotation.x, rx, clampf(14.0 * delta, 0.0, 1.0))
	if core_mi and core_mi.material_override is StandardMaterial3D:
		var em: StandardMaterial3D = core_mi.material_override
		var e0: float = 1.6 + sin(anim_t * 3.2) * 0.4
		if act == "wind":
			e0 += focus * 4.0
		em.emission_energy_multiplier = lerp(em.emission_energy_multiplier, e0, clampf(8.0 * delta, 0.0, 1.0))
	# ---- 高度：飞行悬停 / 出生爬出 ----
	if hover > 0.0 and not underground:
		var want: float = hover + sin(anim_t * 1.9) * 0.2
		if act == "dive":
			want = 0.9
		elif act == "strike" and ai == "flyer":
			want = 0.8
		var wk := clampf(6.0 * delta, 0.0, 1.0)
		if spawn_t > 0.0:
			spawn_t = maxf(0.0, spawn_t - delta)
			visual.position.y = lerpf(-1.2, want, ease(1.0 - spawn_t / 0.7, 0.4))
		else:
			visual.position.y = lerp(visual.position.y, want, wk)
	elif spawn_t > 0.0:
		spawn_t = maxf(0.0, spawn_t - delta)
		var u: float = 1.0 - spawn_t / 0.7
		visual.position.y = lerpf(-rise_depth * sc, 0.0, ease(u, 0.4))
		visual.rotation.x = (1.0 - u) * 0.6
	else:
		if visual.position.y != 0.0:
			visual.position.y = lerp(visual.position.y, 0.0, clampf(10.0 * delta, 0.0, 1.0))
		visual.rotation.x = lerp(visual.rotation.x, 0.0, clampf(8.0 * delta, 0.0, 1.0))

