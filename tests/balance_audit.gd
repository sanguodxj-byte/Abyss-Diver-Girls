extends "res://tests/lib/test_base.gd"
## 数值体系审计：把模块 / 武器 / 敌人 / 物品 / 典型装配的派生数值整理成 JSON，供平衡分析使用。
## godot --headless --path . -- --balance_audit
## 输出：review/balance_audit.json（全量）+ 控制台摘要（离群项）。

const OUT := "res://review/balance_audit.json"
const ARMOR_SAMPLES := [0.0, 0.15, 0.22, 0.28, 0.35]

## 占空比：面对单体、会移动的敌人时，该类武器能实际输出的时间占比。
## 用来把「射程 / 贴身成本」显式化——近战理论 DPS 高，但要贴到 3m 才打得着。
const UPTIME := {
	"melee": 0.30, "shotgun": 0.55, "flamer": 0.50, "mg": 0.70,
	"autocannon": 0.65, "cannon": 0.55, "sniper": 0.60,
	"launcher": 0.55, "laser": 0.70,
}
const UPTIME_DEFAULT := 0.6
## 风险调整 DPS 的护甲基准（终章 Boss 常见档位）
const BOSS_ARMOR_REF := 0.55


func run() -> void:
	await wait(0.3)
	var mods := _modules()
	var enemies := _enemies()
	var out := {
		"meta": {
			"starter": GameData.STARTER,
			"ammo": GameData.AMMO,
			"shop": GameData.SHOP,
		},
		"modules": mods,
		"enemies": enemies,
		"items": _items(),
		"loadouts": _loadouts(),
		"backs": _back_rows(),
		"enemy_ttk": _ttk(mods, enemies),
		"loot_tiers": _loot_tiers(),
	}
	var path := ProjectSettings.globalize_path(OUT)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		fail("无法写入 %s" % OUT)
		return
	f.store_string(JSON.stringify(out, "  "))
	f.close()
	log_line("报告：%s" % path)
	_summary(out)


func _num(d: Dictionary, k: String, def := 0.0) -> float:
	return float(d.get(k, def))


func _modules() -> Array:
	var rows: Array = []
	for id: String in GameData.MODULES:
		var m: Dictionary = GameData.module(id)
		var row := {
			"id": id, "name": str(m.get("name", id)), "slot": str(m.get("slot", "")),
			"rar": int(m.get("rar", 0)), "w": _num(m, "w"), "v": _num(m, "v"),
		}
		for k in ["hp", "cargo", "drain", "speed", "load", "armor", "armor_class", "ergo",
				"recon", "energy", "eff", "cd", "cost", "dur", "dmg", "count"]:
			if m.has(k):
				row[k] = _num(m, k)
		if str(m.get("slot", "")) == "arm":
			var weapon := str(m.get("weapon", "mg"))
			var mode := GameData.weapon_mode(weapon)
			var dmg := _num(m, "dmg")
			var rate := maxf(_num(m, "rate", 1.0), 0.01)
			var pellets := maxi(1, int(m.get("pellets", 1)))
			var per_shot := dmg * (float(pellets) if weapon == "shotgun" else 1.0)
			var ammo: Dictionary = GameData.AMMO.get(weapon, {})
			var mag := maxi(1, int(ammo.get("mag", 1))) if mode == "ammo" else 1
			var reload := _num(ammo, "reload", 0.0) if mode == "ammo" else 0.0
			var cycle := (float(mag) / rate + reload) if mode == "ammo" else (1.0 / rate)
			var pen := _num(m, "pen")
			var ap := clampf((pen - 15.0) / 62.0, 0.0, 0.85)
			var sustain := per_shot * float(mag) / maxf(cycle, 0.05)
			var uptime: float = float(UPTIME.get(weapon, UPTIME_DEFAULT))
			var sustain_vs_boss := sustain * (1.0 - BOSS_ARMOR_REF * (1.0 - ap))
			var risk_adj := sustain_vs_boss * uptime
			var dps_by_armor := {}
			for a: float in ARMOR_SAMPLES:
				var eff := per_shot * (1.0 - a * (1.0 - ap))
				dps_by_armor["%.2f" % a] = snappedf(eff * rate, 0.01)
			row.merge({
				"weapon": weapon, "mode": mode, "pen": pen, "ap": ap, "pellets": pellets, "mag": mag, "reload": reload,
				"burst_dps": snappedf(per_shot * rate, 0.01),
				"sustain_dps": snappedf(sustain, 0.01),
				"dps_by_armor": dps_by_armor,
				"uptime": uptime,
				"sustain_vs_boss": snappedf(sustain_vs_boss, 0.01),
				"risk_adj_dps": snappedf(risk_adj, 0.01),
				"v_per_risk_adj": snappedf(_num(m, "v") / maxf(risk_adj, 0.01), 0.1),
				"energy_per_s": snappedf(GameData.shot_energy_cost(m) * rate, 0.001),
				"dmg_per_energy": snappedf(per_shot / maxf(GameData.shot_energy_cost(m), 0.001), 0.01),
				"v_per_sustain_dps": snappedf(_num(m, "v") / maxf(sustain, 0.01), 0.1),
				"reach_m": _num(m, "reach_m", _num(m, "range") * 3.0),
				"spread": _num(m, "spread"),
				"falloff": GameData.weapon_falloff(m),
			})
		rows.append(row)
	return rows


func _enemies() -> Array:
	var rows: Array = []
	for id: String in GameData.ENEMIES:
		var e: Dictionary = GameData.ENEMIES[id]
		var windup := _num(e, "windup", 0.6)
		var strike := _num(e, "strike", 0.25)
		var recover := _num(e, "recover", 0.8)
		var cycle := maxf(windup + strike + recover, 0.05)
		var dmg := _num(e, "dmg")
		rows.append({
			"id": id, "name": str(e.get("name", id)), "boss": bool(e.get("boss", false)),
			"hp": _num(e, "hp"), "dmg": dmg, "speed": _num(e, "speed"),
			"armor": _num(e, "armor"), "front_resist": _num(e, "front_resist"),
			"attack_cycle": snappedf(cycle, 0.01),
			"dps": snappedf(dmg / cycle, 0.01),
			"tankiness": _num(e, "hp"),
		})
	return rows


func _back_rows() -> Array:
	var rows: Array = []
	for id: String in GameData.MODULES:
		var m: Dictionary = GameData.module(id)
		if str(m.get("slot", "")) != "back":
			continue
		var ability := str(m.get("ability", "none"))
		var row := {"id": id, "name": str(m.get("name", id)), "rar": int(m.get("rar", 0)),
			"v": _num(m, "v"), "w": _num(m, "w"), "cargo": _num(m, "cargo"), "ability": ability}
		if ability == "missile":
			var salvo := _num(m, "dmg") * _num(m, "count")
			var cd := maxf(_num(m, "cd", 1.0), 0.1)
			var cost := _num(m, "cost")
			row.merge({
				"salvo_dmg": snappedf(salvo, 0.1), "cd": cd, "cost": cost,
				"cd_dps": snappedf(salvo / cd, 0.01),
				"energy_per_s": snappedf(cost / cd, 0.001),
				"dmg_per_energy": snappedf(salvo / maxf(cost, 0.01), 0.01),
			})
		elif ability == "shield":
			var dur := _num(m, "dur")
			var cd := maxf(_num(m, "cd", 1.0), 0.1)
			row.merge({"dur": dur, "cd": cd, "uptime": snappedf(dur / cd, 0.001), "repair": 0.35})
		else:
			row.merge({"net_cargo": snappedf(_num(m, "cargo") - _num(m, "w"), 0.1)})
		rows.append(row)
	return rows


func _ttk(mods: Array, enemies: Array) -> Array:
	var by_id := {}
	for m: Dictionary in mods:
		by_id[m.id] = m
	var probe := ["arm_mg", "arm_gatling", "arm_gau8", "arm_rh120", "arm_m299", "arm_pb09"]
	var rows: Array = []
	for e: Dictionary in enemies:
		if not bool(e.get("boss", false)):
			continue
		var row := {"id": e.id, "hp": e.hp, "armor": e.armor, "front_resist": e.front_resist}
		for id: String in probe:
			var m: Dictionary = by_id.get(id, {})
			var ap := float(m.get("ap", 0.0))
			var dps: float = float(m.get("sustain_dps", 1.0)) * (1.0 - float(e.armor) * (1.0 - ap))
			row[id] = snappedf(dps, 0.1)
			row[id + "_ttk"] = snappedf(float(e.hp) / maxf(dps, 0.01), 0.1)
		rows.append(row)
	return rows


func _items() -> Array:
	var rows: Array = []
	for id: String in GameData.ITEMS:
		var it: Dictionary = GameData.ITEMS[id]
		var w := _num(it, "w", 0.1)
		var v := _num(it, "v")
		rows.append({
			"id": id, "name": str(it.get("name", id)), "cat": str(it.get("cat", "")),
			"rar": int(it.get("rar", 0)), "w": w, "v": v,
			"v_per_kg": snappedf(v / maxf(w, 0.05), 0.1),
		})
	return rows


func _loadouts() -> Array:
	var sets := {
		"starter": GameData.STARTER,
		"scout_laser": {"core": "core_scout", "legs": "legs_biped_scout", "arm_l": "arm_laser", "arm_r": "arm_laser", "back": "back_rack", "gen": "gen_cell"},
		"assault": {"core": "core_assault", "legs": "legs_biped_assault", "arm_l": "arm_ac30", "arm_r": "arm_gatling", "back": "back_rack", "gen": "gen_hfc"},
		"heavy": {"core": "core_fortress", "legs": "legs_tread_heavy", "arm_l": "arm_gau8", "arm_r": "arm_rh120", "back": "back_vls", "gen": "gen_turbine"},
		"siege": {"core": "core_fortress", "legs": "legs_hex_colossus", "arm_l": "arm_pb09", "arm_r": "arm_m777", "back": "back_vls", "gen": "gen_crystal"},
	}
	var rows: Array = []
	for name: String in sets:
		var lo: Dictionary = sets[name]
		var s: Dictionary = GameData.compute_stats(lo)
		var drain: float = _num(s, "drain")
		var fps := 0.0
		var burst := 0.0
		for slot in ["arm_l", "arm_r"]:
			var mid := str(lo.get(slot, ""))
			if GameData.is_module(mid):
				var m: Dictionary = GameData.module(mid)
				var rate := _num(m, "rate")
				fps += _num(m, "cost") * rate
				var pellets := maxi(1, int(m.get("pellets", 1)))
				burst += _num(m, "dmg") * float(pellets if str(m.get("weapon", "")) == "shotgun" else 1) * rate
		rows.append({
			"name": name, "loadout": lo,
			"hp": snappedf(_num(s, "hp"), 0.1), "cargo": _num(s, "cargo"),
			"energy": _num(s, "energy"), "drain": snappedf(drain, 0.001),
			"idle_s": snappedf(_num(s, "energy") / maxf(drain, 0.001), 1.0),
			"move_s": snappedf(_num(s, "energy") / maxf(drain * 1.6, 0.001), 1.0),
			"full_fire_s": snappedf(_num(s, "energy") / maxf(drain + fps, 0.001), 1.0),
			"drain_plus_fire": snappedf(drain + fps, 0.001),
			"speed": snappedf(_num(s, "speed"), 0.1), "mass": _num(s, "mass"),
			"load": _num(s, "load"), "armor": snappedf(_num(s, "armor"), 0.001),
			"armor_class": int(s.get("armor_class", 2)), "ergo": snappedf(_num(s, "ergo"), 0.1),
			"burst_dps": snappedf(burst, 0.1),
		})
	return rows


## 容器分档：同一张表在 1/2/3 档下的出货件数、模块概率与单箱期望货值
func _loot_tiers() -> Array:
	var rows: Array = []
	var rar_v := {}
	var rar_n := {}
	for id in GameData.MODULES:
		var m: Dictionary = GameData.MODULES[id]
		var r := int(m.get("rar", 0))
		rar_v[r] = float(rar_v.get(r, 0.0)) + _num(m, "v")
		rar_n[r] = int(rar_n.get(r, 0)) + 1
	for table in GameData.LOOT_TABLES:
		var t: Dictionary = GameData.LOOT_TABLES[table]
		for tier in [1, 2, 3]:
			var tr: Dictionary = GameData.LOOT_TIER[tier] as Dictionary
			var pool: Dictionary = (t.pool as Dictionary).duplicate()
			if pool.has("@module"):
				pool["@module"] = float(pool["@module"]) * float(tr.module)
			var total := 0.0
			for k in pool:
				total += float(pool[k])
			total = maxf(total, 0.001)
			var rw: Array = tr.rar
			var rw_sum := 0.0
			var mod_exp := 0.0
			for i in 5:
				rw_sum += float(rw[i])
				var cnt := maxi(int(rar_n.get(i, 0)), 1)
				mod_exp += float(rw[i]) * (float(rar_v.get(i, 0.0)) / float(cnt))
			mod_exp /= maxf(rw_sum, 0.001)
			var per := 0.0
			var mod_chance := 0.0
			for k in pool:
				var w := float(pool[k]) / total
				if str(k) == "@module":
					mod_chance = w
					per += w * mod_exp
				else:
					per += w * float(GameData.item(str(k)).get("v", 0.0))
			# 稀有产出层：每件物资小概率改从稀有池抽取
			var rc: float = GameData.RARE_CHANCE * float((GameData.RARE_TIER_MUL as Dictionary).get(tier, 1.0))
			var rare_pool: Dictionary = GameData.RARE_POOL
			var rare_total := 0.0
			for k2 in rare_pool:
				rare_total += float(rare_pool[k2])
			var rare_exp := 0.0
			for k2 in rare_pool:
				var w2 := float(rare_pool[k2]) / maxf(rare_total, 0.001)
				rare_exp += w2 * (mod_exp if str(k2) == "@module" else float(GameData.item(str(k2)).get("v", 0.0)))
			per += rc * rare_exp
			var rolls := (float(t.rolls[0]) + float(t.rolls[1])) / 2.0 + float(tr.rolls)
			rows.append({
				"table": table, "tier": tier, "rolls": snappedf(rolls, 0.01),
				"module_chance": snappedf(mod_chance, 0.001),
				"module_value": snappedf(mod_exp, 0.1),
				"rare_chance": snappedf(rc, 0.001),
				"rare_value": snappedf(rare_exp, 0.1),
				"expect_value": snappedf(rolls * per, 0.1),
			})
	return rows


func _summary(out: Dictionary) -> void:
	var arms: Array = []
	var mods: Array = []
	for r: Dictionary in out.modules:
		if str(r.slot) == "arm":
			arms.append(r)
			mods.append(r)
	arms.sort_custom(func(a, b): return float(a.risk_adj_dps) > float(b.risk_adj_dps))
	log_line("武器（按风险调整 DPS 排序 · up=占空比 · 基准 %.2f 甲）：" % BOSS_ARMOR_REF)
	for r: Dictionary in arms:
		log_line("  %-14s %-6s burst=%6.1f sustain=%6.1f pen=%2.0f ap=%.2f up=%.2f adj=%6.1f 能量%.2f/s ¥/adj=%s" % [
			r.id, r.weapon, r.burst_dps, r.sustain_dps, r.pen, r.ap,
			r.uptime, r.risk_adj_dps, r.energy_per_s, r.v_per_risk_adj])
	var enemies: Array = out.enemies
	enemies.sort_custom(func(a, b): return float(a.dps) > float(b.dps))
	log_line("敌人攻击 DPS 前 6：")
	for i in mini(6, enemies.size()):
		var e: Dictionary = enemies[i]
		log_line("  %-18s hp=%6.0f dps=%5.1f armor=%.2f front=%.2f" % [e.id, e.hp, e.dps, e.armor, e.front_resist])
	log_line("装配能源（待机 / 移动 / 双持持续开火）：")
	for r: Dictionary in out.loadouts:
		log_line("  %-12s hp=%4.0f 能量=%4.0f 耗能=%.3f 待机=%4.0fs 移动=%4.0fs 满射=%4.0fs" % [
			r.name, r.hp, r.energy, r.drain, r.idle_s, r.move_s, r.full_fire_s])
	log_line("距离衰减（near/far = 射程倍数，min = 最低伤害）：")
	for w in ["sniper", "laser", "cannon", "launcher", "autocannon", "mg", "flamer", "shotgun", "melee"]:
		var f: Dictionary = GameData.WEAPON_FALLOFF[w]
		log_line("  %-11s near=%.2f far=%.2f min=%.0f%%" % [w, f.near, f.far, f.min * 100.0])
	log_line("容器分档（每箱期望货值 · 档位由区块军事/保险箱占比决定）：")
	for r: Dictionary in out.loot_tiers:
		if str(r.table) in ["supply", "military", "safe"]:
			log_line("  %-9s tier%d rolls=%.1f 模块率=%2.0f%% 期望=¥%5.0f" % [
				r.table, r.tier, r.rolls, r.module_chance * 100.0, r.expect_value])
	log_line("背部模块：")
	for r: Dictionary in out.backs:
		var ab := str(r.ability)
		if ab == "missile":
			log_line("  %-13s v=%4.0f 齐射=%3.0f 冷却=%4.1fs 轮均DPS=%5.1f 能耗=%.2f/s" % [r.id, r.v, r.salvo_dmg, r.cd, r.cd_dps, r.energy_per_s])
		elif ab == "shield":
			log_line("  %-13s v=%4.0f 覆盖=%.0f%% (%.1fs/%.1fs) 部位修复=%.0f%%" % [r.id, r.v, r.uptime * 100.0, r.dur, r.cd, r.repair * 100.0])
		else:
			log_line("  %-13s v=%4.0f 货舱=%2.0f 净增=%2.0f" % [r.id, r.v, r.cargo, r.net_cargo])
	log_line("Boss TTK（秒 · 按持续 DPS，含护甲减伤）：")
	for r: Dictionary in out.enemy_ttk:
		log_line("  %-18s hp=%5.0f armor=%.2f mg=%5.1f gau8=%5.1f rh120=%5.1f m299=%5.1f" % [
			r.id, r.hp, r.armor, r["arm_mg_ttk"], r["arm_gau8_ttk"], r["arm_rh120_ttk"], r["arm_m299_ttk"]])
	log_line("模块价目离群（同槽位 v 与 rar 反向）已写入 JSON：%d 模块 / %d 物品" % [out.modules.size(), out.items.size()])