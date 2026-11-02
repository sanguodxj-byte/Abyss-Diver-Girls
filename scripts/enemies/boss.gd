extends "res://scripts/enemies/enemy.gd"
## Boss 基类：苏醒演出、阶段推进、弱点部位、登场/阶段/击破三类事件广播。
##
## 苏醒：Boss 一开始伏在场地里不动（state = idle），机甲进入 activation 距离才撑起身体——
##   那一刻广播 Events.boss_appeared(boss_id, title)，并给出 2.2 秒无敌窗口播完演出。
## 阶段：data.phases 是各阶段的血量比例上限（[1.0, 0.6, 0.28] 即 100%~60% 一阶段、60%~28% 二阶段、以下三阶段），
##   跨过阈值时广播 Events.boss_phase_changed(boss_id, phase)，子类在 _on_phase 里加招式、召唤、暴露核心。
## 弱点：weak_back（从背后打）与 weak_core（核心暴露期间从正面打）是伤害倍率；命中弱点会给一段明显的亮闪。
## HUD 血条：用 get_tree().get_first_node_in_group("boss") 找节点，读 boss_id / title / hp_ratio() / phase。

const BossModels = preload("res://scripts/enemies/boss_models.gd")

var boss_id := ""
var title := ""
var phase := 1
var phase_hp: Array = [1.0, 0.5]
var awake := false
var activation := 34.0
var core_open := 0.0
var summoned := 0
var summon_cap := 8
var pattern_i := 0
var _weak_flash := 0.0
## 晶核暴露程度 0~1：开合护板与核心辉光都跟着它走，玩家能直接看出弱点窗口的开与合
var core_vis := 0.0


func setup(k: String, r, tgt) -> void:
	super.setup(k, r, tgt)
	boss_id = k
	title = str(data.get("name", k))
	phase_hp = data.get("phases", [1.0, 0.5])
	rise_depth = 3.0
	add_to_group("boss")
	data["boss"] = true


func _build_visual() -> void:
	visual = Node3D.new()
	add_child(visual)
	var s: float = data.scale
	ART.ground_decal(self, ART.blob_tex(), Color(1, 1, 1, 0.8), BossModels.decal_size(kind) * s, Vector3(0, 0.03, 0))
	var body := Node3D.new()
	body.name = "Body"
	visual.add_child(body)
	BossModels.build(self, body, kind, s)
	if core_mi:
		core_mi.set_meta("base_boss_scale", core_mi.scale)


## 血条读数
func hp_ratio() -> float:
	return clampf(hp / maxf(float(data.hp), 1.0), 0.0, 1.0)


func _physics_process(delta: float) -> void:
	if dying:
		return
	if not awake:
		_idle_wait(delta)
		return
	super._physics_process(delta)
	if core_open > 0.0:
		core_open = maxf(0.0, core_open - delta)
	if _weak_flash > 0.0:
		_weak_flash = maxf(0.0, _weak_flash - delta)
	_check_phase()


## 苏醒前的伏击姿态：只有呼吸般起伏，不追不打
func _idle_wait(delta: float) -> void:
	anim_t += delta * 0.5
	_animate(delta, 0.0)
	if raid == null or not is_instance_valid(raid.mech):
		return
	if global_position.distance_to(raid.mech.global_position) < activation:
		_awaken()


func _awaken() -> void:
	awake = true
	state = "chase"
	guard_t = 2.2
	spawn_t = 1.3
	atk_cd = 1.4
	Audio.play_sfx(roar_id(), global_position + Vector3(0, 2.0, 0))
	if raid:
		raid.shake = maxf(raid.shake, 0.85)
		_ground_burst(5.0, Color(0.7, 0.6, 0.5))
	Events.boss_appeared.emit(boss_id, title)
	Events.combat_changed.emit(true)


## 各 Boss 的登场咆哮音效 id
func roar_id() -> String:
	return "boss_phase_shift"


## 地面尘环：登场与震地共用
func _ground_burst(radius: float, c: Color) -> void:
	if raid == null:
		return
	var p := global_position
	_ground_ring(p, radius, c)
	ART.burst(raid.fx, p + Vector3(0, 0.4, 0), {"amount": 26, "life": 1.2, "size": radius * 0.7, "tex": ART.smoke_tex(), "additive": false, "spread": 90.0,
		"vmin": radius * 0.7, "vmax": radius * 1.6, "gravity": Vector3(0, 1.2, 0), "damp": 3.4, "c0": Color(c.r, c.g, c.b, 0.6), "c1": Color(c.r, c.g, c.b, 0.0),
		"grow0": 0.5, "grow1": 2.0})
	ART.burst(raid.fx, p + Vector3(0, 0.6, 0), {"amount": 16, "life": 0.6, "size": 0.2, "vmin": radius * 0.8, "vmax": radius * 1.8, "spread": 80.0,
		"gravity": Vector3(0, -16, 0), "c0": Color(0.6, 0.55, 0.48, 0.9), "c1": Color(0.4, 0.36, 0.3, 0.0), "grow0": 1.0, "grow1": 0.6})


func _ground_ring(p: Vector3, radius: float, c: Color) -> void:
	if raid == null:
		return
	var ring := ART.ground_decal(raid.fx, ART.ring_tex(), Color(c.r, c.g, c.b, 0.8), radius * 0.5, Vector3(p.x, 0.07, p.z), true)
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector3.ONE * 4.0, 0.6)
	tw.parallel().tween_property(ring, "transparency", 1.0, 0.7)
	tw.tween_callback(ring.queue_free)


# ================= 阶段 =================
func _phase_for(ratio: float) -> int:
	var p := 1
	for i in range(1, phase_hp.size()):
		if ratio <= float(phase_hp[i]):
			p = i + 1
	return p


func _check_phase() -> void:
	if hp <= 0.0:
		return
	var want := _phase_for(hp_ratio())
	if want > phase:
		_enter_phase(want)


func _enter_phase(p: int) -> void:
	phase = p
	guard_t = 1.5
	atk_cd = maxf(atk_cd, 0.8)
	Audio.play_sfx("boss_phase_shift", global_position + Vector3(0, 2.0, 0))
	Audio.play_sfx(roar_id(), global_position + Vector3(0, 2.0, 0))
	if raid:
		raid.shake = maxf(raid.shake, 0.7)
		_ground_burst(4.0, Color(0.75, 0.45, 0.85))
		# 甲壳/晶簇碎裂：从身上炸出一圈碎屑
		ART.burst(raid.fx, global_position + Vector3(0, 1.6 * float(data.scale), 0), {"amount": 24, "life": 0.9, "size": 0.22, "spread": 120.0,
			"vmin": 4.0, "vmax": 11.0, "gravity": Vector3(0, -18, 0), "c0": Color(0.75, 0.55, 0.95, 0.9), "c1": Color(0.3, 0.1, 0.45, 0.0), "grow0": 1.0, "grow1": 0.3})
	Events.boss_phase_changed.emit(boss_id, p)
	_on_phase(p)


## 子类：进入新阶段时加招式、召唤或暴露核心
func _on_phase(_p: int) -> void:
	pass


# ================= 弱点 =================
func _from_back(from: Vector3) -> bool:
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
	return faced.normalized().dot(to.normalized()) < -0.45


func _weak_scale(from: Vector3) -> float:
	var mult := 1.0
	if weak_back > 0.0 and _from_back(from):
		mult = maxf(mult, weak_back)
	if weak_core > 0.0 and core_open > 0.0 and not _from_back(from):
		mult = maxf(mult, weak_core)
	if mult > 1.0:
		_weak_hit()
	return mult


## 弱点命中的反馈：一道刺眼的光与一圈碎屑，让玩家知道这一下确实打在了破绽上
func _weak_hit() -> void:
	if raid == null or _weak_flash > 0.0:
		return
	_weak_flash = 0.25
	var p := global_position + Vector3(0, 1.8 * float(data.scale), 0)
	ART.burst(raid.fx, p, {"amount": 14, "life": 0.45, "size": 0.22, "vmin": 4.0, "vmax": 9.0, "spread": 120.0,
		"c0": Color(1.0, 0.95, 0.7, 0.95), "c1": Color(1.0, 0.5, 0.1, 0.0), "grow0": 1.0, "grow1": 0.2})
	Audio.play_sfx("hit_chitin", p)


## 核心暴露：正面伤害倍率生效的窗口
func open_core(seconds: float) -> void:
	core_open = maxf(core_open, seconds)


## Boss 前摇的地面预告：冲撞与爪击画冲锋带，震地与蓄力画范围环。
## 酸雨与唤虫的落点由各自的抛射物与被召唤单位自带预警，这里只标出 Boss 正在引导。
func _on_wind() -> void:
	super._on_wind()
	if raid == null:
		return
	var sc := float(data.scale)
	var reach: float = float(data.range) + 3.0 + sc * 0.8
	match _next_step():
		"charge":
			_telegraph_lane(charge_speed * charge_time + reach, float(data.radius) * 1.9,
				windup_t + charge_time + strike_t + 0.25, Color(1.0, 0.42, 0.2))
		"claw", "spike":
			_telegraph_lane(reach + 2.0 * sc, float(data.radius) * 1.6, windup_t + 0.55, Color(1.0, 0.5, 0.25))
		"stomp":
			_telegraph_ring(float(data.range) + sc * 2.2, windup_t + 0.6, Color(1.0, 0.55, 0.25))
		"rain", "hatch", "summon", "core":
			_telegraph_ring(float(data.range), windup_t + 0.5, Color(0.82, 0.45, 1.0))
		_:
			pass


## 晶核暴露时护板向两侧打开、核心辉光抬升；合拢后恢复原状。
## 这一段只改外观，伤害倍率仍由 core_open 与 _weak_scale 决定。
func _animate(delta: float, mv: float) -> void:
	super._animate(delta, mv)
	core_vis = move_toward(core_vis, 1.0 if core_open > 0.0 else 0.0, delta * 3.0)
	for pl in plates:
		if not is_instance_valid(pl):
			continue
		var side: float = float(pl.get_meta("side", 1.0))
		pl.rotation.z += side * core_vis * 0.55
	if core_mi and is_instance_valid(core_mi) and core_mi.material_override is StandardMaterial3D:
		var base: Vector3 = core_mi.get_meta("base_boss_scale", Vector3.ONE)
		core_mi.scale = base * (1.0 + core_vis * 0.35)
		core_mi.material_override.emission_energy_multiplier += core_vis * 2.8


# ================= 出手 =================
## Boss 的步骤名与通用虫不同，先在这里截走，其余交给基类
func _act_enter(name: String) -> void:
	match name:
		"claw", "stomp", "slam", "spike", "rain", "hatch", "summon", "core", "roar":
			step_len = act_t
			_boss_step(name)
		"recover":
			# 连续冲撞之间急速回身：下一段若是冲撞，先转向机甲，让玩家看出下一发朝哪
			if _next_step() == "charge":
				act_dir = _aim_dir()
				visual.rotation.y = atan2(-act_dir.x, -act_dir.z)
				if raid:
					ART.burst(raid.fx, global_position + Vector3(0, 0.3, 0), {"amount": 10, "life": 0.6, "size": 1.6, "tex": ART.smoke_tex(), "additive": false,
						"spread": 80.0, "vmin": 2.0, "vmax": 4.5, "gravity": Vector3(0, 0.8, 0), "damp": 3.0, "c0": Color(0.66, 0.6, 0.52, 0.5),
						"c1": Color(0.6, 0.55, 0.48, 0.0), "grow0": 0.5, "grow1": 1.8})
			super._act_enter(name)
		_:
			super._act_enter(name)


## 冲撞落地：strike 步骤结算一次正面重击，并把机甲挑起一点
func _strike() -> void:
	var m = target
	if m == null or not is_instance_valid(m) or m.dead:
		return
	var reach: float = float(data.range) + 3.0 + float(data.scale) * 0.8
	if global_position.distance_to(m.global_position) > reach:
		return
	_hit_mech(float(data.dmg), 3.4, reach)
	m.velocity.y = maxf(m.velocity.y, 3.0)
	if raid:
		raid.shake = maxf(raid.shake, 0.5)
		_ground_ring(global_position, 3.0, Color(1.0, 0.78, 0.45))


func _next_step() -> String:
	if seq_i + 1 < seq.size():
		return str(seq[seq_i + 1][0])
	return ""


func _aim_dir() -> Vector3:
	if target == null or not is_instance_valid(target):
		return act_dir
	var v: Vector3 = target.global_position - global_position
	v.y = 0.0
	return v.normalized() if v.length() > 0.01 else act_dir


## Boss 的动作姿态：破绽步抬高上身，砸地压低
func _pose(act_name: String) -> Dictionary:
	var p: Dictionary = super._pose(act_name)
	match act_name:
		"claw", "strike":
			p.pitch = 0.24
			p.fwd = -0.5
		"spike", "rain", "hatch", "summon", "core":
			p.pitch = -0.26
			p.dy = 0.16
		"stomp":
			p.pitch = 0.3
			p.dy = -0.2
	return p


## 子类：自己的步骤效果
func _boss_step(_name: String) -> void:
	pass


## 子类：阶段化出招。Boss 不靠贴脸取胜，站定出手，所以默认原地不动
func _think(_delta: float, _to: Vector3, _d: float, _valid: bool) -> Vector3:
	return Vector3.ZERO


## 召虫：受 raid 的虫数上限约束，整场战斗有总量上限
func summon(kind: String, n: int, radius := 6.0) -> int:
	if raid == null:
		return 0
	var made := 0
	for i in n:
		if summoned >= summon_cap:
			break
		var a := randf() * TAU
		var p: Vector3 = global_position + Vector3(cos(a), 0, sin(a)) * radius
		var b = raid.spawn_bug(kind, Vector3(p.x, 0.5, p.z))
		if b == null:
			break
		summoned += 1
		made += 1
		b.state = "chase"
		b.spawn_t = 0.7
		if raid.fx:
			ART.burst(raid.fx, b.global_position + Vector3(0, 0.4, 0), {"amount": 10, "life": 0.6, "size": 0.5, "tex": ART.smoke_tex(), "additive": false,
				"spread": 80.0, "vmin": 1.5, "vmax": 4.0, "gravity": Vector3(0, 1.2, 0), "damp": 3.0, "c0": Color(0.6, 0.5, 0.45, 0.6),
				"c1": Color(0.55, 0.45, 0.4, 0.0), "grow0": 0.6, "grow1": 1.6})
	return made


# ================= 死亡 =================
func _on_killed() -> void:
	Events.boss_defeated.emit(boss_id)
	Audio.play_sfx(roar_id(), global_position + Vector3(0, 2.0, 0))
	# 连着几次爆开，最后才塌下去
	if raid:
		var p := global_position
		var sc := float(data.scale)
		for i in 6:
			var off := Vector3(randf_range(-2.0, 2.0), randf_range(0.4, 2.6 * sc), randf_range(-2.0, 2.0)) * (sc * 0.5)
			ART.burst(raid.fx, p + off, {"amount": 16, "life": 0.7, "size": 0.5 * sc, "vmin": 3.0, "vmax": 9.0, "spread": 120.0, "gravity": Vector3(0, -12, 0),
				"c0": Color(1.0, 0.85, 0.5), "c1": Color(1.0, 0.3, 0.05, 0.0), "grow0": 1.0, "grow1": 0.4})
		raid.shake = maxf(raid.shake, 1.0)
		raid.explode_fx(p + Vector3(0, 1.0, 0), 7.0, Color(1.0, 0.5, 0.2))
	_loot()
	if raid:
		raid.on_bug_killed(self)
	_die()


func _die() -> void:
	# 比普通虫更慢的塌陷：底座砸进土里、身上的发光件一个个熄灭
	dying = true
	remove_from_group("bugs")
	remove_from_group("boss")
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	for c in get_children():
		if c is CollisionShape3D:
			c.queue_free()
	_set_flash(false)
	var body: Node3D = visual.get_node_or_null("Body")
	if body == null:
		queue_free()
		return
	var sc := float(data.scale)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(body, "position:y", -0.9 * sc, 1.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(body, "rotation:z", randf_range(-0.35, 0.35), 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(body, "rotation:x", randf_range(-0.2, 0.3), 1.6)
	for hip in legs:
		var sd: float = float(hip.get_meta("side"))
		tw.tween_property(hip, "rotation:z", -sd * randf_range(0.4, 0.8), randf_range(0.6, 1.2)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(hip, "rotation:y", float(hip.get_meta("base_y")) + randf_range(-0.5, 0.5), 1.0)
	for w in wings:
		if is_instance_valid(w):
			tw.tween_property(w, "rotation:z", float(w.get_meta("side", 1.0)) * 1.2, 1.2)
	for j in jaws:
		tw.tween_property(j, "rotation:y", float(sign(j.position.x)) * 1.1, 1.0)
	for s2 in scythes:
		tw.tween_property(s2, "rotation:x", -0.6, 1.2)
	for m in find_children("*", "MeshInstance3D", true, false):
		var mat = m.material_override
		if mat is StandardMaterial3D and mat.emission_enabled:
			var dm: StandardMaterial3D = mat.duplicate()
			m.material_override = dm
			tw.tween_property(dm, "emission_energy_multiplier", 0.0, 2.4)
	var t2 := create_tween()
	t2.tween_interval(10.0)
	t2.tween_property(self, "position:y", position.y - 2.2 * sc, 3.0)
	t2.tween_callback(queue_free)
