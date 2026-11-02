extends RefCounted
## 模块品质词条：同一件模块带词条时用「基础 id#词条」表示（多个词条用 + 连接），
## 数值在基础条目的副本上叠加，核心模块表与已存档案里的旧 id 都不改动。
##
## 词条只改写条目里已经存在的数值字段，因此新模块不必为词条单独登记；
## 名字与说明由词条表生成，掉落时只决定 id 后缀，同一后缀永远解析出同一组数值。

const AFFIXES := {
	"imp": {
		"name": "改良",
		"desc": "改良：结构 +10%，伤害 +8%，射速 +4%，能源 +5%，重量 +2%。",
		"mul": {"hp": 1.10, "dmg": 1.08, "rate": 1.04, "energy": 1.05, "w": 1.02, "eff": 0.98},
	},
	"ovl": {
		"name": "过载",
		"desc": "过载：伤害 +22%，射速 +10%，能耗 +35%，冷却 -15%，结构 -6%。",
		"mul": {"dmg": 1.22, "rate": 1.10, "cost": 1.35, "cd": 0.85, "hp": 0.94},
	},
	"ltw": {
		"name": "轻量化",
		"desc": "轻量化：重量 -20%，速度 +4%，承重 -4%，货舱 -4%，结构 -6%。",
		"mul": {"w": 0.80, "speed": 1.04, "load": 0.96, "cargo": 0.96, "hp": 0.94},
	},
	"old": {
		"name": "老旧",
		"desc": "老旧：成交价 +60%，结构 -8%，伤害 -5%。",
		"mul": {"v": 1.60, "hp": 0.92, "dmg": 0.95},
	},
}

const WEIGHTS := {"imp": 34, "ovl": 22, "ltw": 28, "old": 16}
const SEP := "+"


## id 里的词条后缀（"arm_mg#imp" 解析为 ["imp"]）；没有词条时返回空数组
static func tags_of(id: String) -> Array:
	var k := id.find("#")
	if k < 0:
		return []
	var out: Array = []
	for t in id.substr(k + 1).split(SEP):
		if AFFIXES.has(t):
			out.append(t)
	return out


## 在基础条目副本上叠加词条；没有词条时原样返回
static func apply(id: String, base: Dictionary) -> Dictionary:
	var tags := tags_of(id)
	if tags.is_empty():
		return base
	var names: Array = []
	var lines: Array = []
	for t in tags:
		var a: Dictionary = AFFIXES[t]
		names.append(a.name)
		lines.append(a.desc)
		for k in a.mul:
			if not base.has(k):
				continue
			var cur = base[k]
			if typeof(cur) != TYPE_INT and typeof(cur) != TYPE_FLOAT:
				continue
			base[k] = _fit(cur, float(cur) * float(a.mul[k]))
	base["name"] = "%s·%s" % [str(base.get("name", "")), "·".join(names)]
	var d := str(base.get("desc", ""))
	for line in lines:
		d = line if d == "" else d + "\n" + line
	base["desc"] = d
	return base


## 整数字段保持整数，浮点字段收敛到两位小数
static func _fit(orig, v: float) -> Variant:
	if typeof(orig) == TYPE_INT:
		return int(round(v))
	return snappedf(v, 0.01)


## 按权重抽一个词条 id
static func roll(rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for t in WEIGHTS:
		total += float(WEIGHTS[t])
	var r := rng.randf() * total
	for t in WEIGHTS:
		r -= float(WEIGHTS[t])
		if r <= 0.0:
			return t
	return "imp"


## 给掉落出来的模块 id 挂词条：chance 为 0..1 的命中概率
static func decorate(id: String, rng: RandomNumberGenerator, chance: float) -> String:
	if id.contains("#") or rng.randf() > chance:
		return id
	return id + "#" + roll(rng)
