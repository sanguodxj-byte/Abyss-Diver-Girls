extends RefCounted
## 敌人团队的扩展数据：启动时由 GameData 并入核心表（规则见 scripts\game_data.gd 的「内容注册」一节）。
##
## ENEMIES  新敌人种类，字段与 scripts\bug.gd 的 KINDS 相同：name / hp / speed / dmg / range / rate / radius / color / scale / drop；
##          可选 script = 继承 res://scripts/bug.gd 的脚本路径（重写外观、AI、动画），sfx = 音效前缀用的种类名（默认为自己的 id，
##          音效 id 为 bug_<前缀>_appear / windup / attack / hurt / death），boss = true。
##          raid.gd 的 spawn_bug(kind, pos) 按 script 实例化；Boss 脚本自行广播 Events.boss_appeared / boss_phase_changed / boss_defeated。
##          带 script 的种类另读这些行为字段（缺省值与含义见 scripts\enemies\enemy.gd）：
##            ai / windup / strike / recover / charge_speed / charge_time / aggro / interrupt / armor / front_resist
##            blast_r / blast_dmg / pool_dur / pool_dps / fuse / burrow_time / erupt_r / pulse_r / pulse_heal / pulse_shield
##            volley / shell_time / keep / flee / hover / jam_r / jam_cost / armor_pierce / weak_back / weak_core / loot / phases
## SPAWNS   每个战区的虫群分布（v0.6：十二种常规虫在地表五个战区都会出现，战区主题种类权重高、外来种类零星出现；
##          raid.gd 另乘 BUG_DENSITY 并把每群第一只设为巡逻群首）：{战区 id: {"packs": {区块字符: 每 4900 平方米的虫群数}, "kinds": {种类: 权重}, "pack_size": [最少, 最多],
##          "script": 可选，路径，脚本里写 static func spawn(raid, drop: Vector3)，接管该战区的初始布置（可调用 raid.spawn_default_bugs(drop)）}}。
##          没有登记的战区按 raid.gd 里原有的分布生成。
## LOOT_TABLES  新敌人的残骸掉落表（掉落箱种类在敌人脚本里决定）。
## SFX      新敌人与 Boss 音效的登记（格式同 scripts\audio\audio_registry.gd 的 SFX）；不登记也能按命名约定播放，登记后列入音频清单。
## RAID_SCRIPTS  行动扩展脚本路径（规则见 scripts\raid.gd 的 _run_ext_build），如 Boss 的登场布置。
## EXTEND   给已有条目补字段。

const ENEMY := "res://scripts/enemies/enemy.gd"
const BOSS_BROOD := "res://scripts/enemies/boss_brood.gd"
const BOSS_KING := "res://scripts/enemies/boss_king.gd"
const BOSS_QUEEN := "res://scripts/enemies/boss_queen.gd"

const ENEMIES := {
	# ---------------- 常规虫群：九种，各有专精与破绽 ----------------
	# 镰爪虫：铁锈工业带的高速突袭者。短促后撤蓄力 → 直线冲刺挥镰 → 长收招。
	"mantis": {"name": "镰爪虫", "hp": 72.0, "speed": 11.5, "dmg": 15.0, "range": 3.4, "rate": 2.6, "radius": 0.85,
		"color": Color(0.3, 0.26, 0.12), "scale": 1.1, "drop": 0.45, "script": ENEMY, "sfx": "mantis",
		"ai": "lancer", "windup": 0.62, "strike": 0.2, "recover": 0.62, "charge_speed": 27.0, "charge_time": 0.22,
		"aggro": 20.0, "interrupt": 0.16, "armor_pierce": 0.55, "loot": "mantis"},
	# 爆浆虫：尘土平原的自爆体。贴上机甲或被打死都会延时引爆，先炸出伤，再留一滩酸液。
	"bomber": {"name": "爆浆虫", "hp": 58.0, "speed": 7.6, "dmg": 34.0, "range": 3.8, "rate": 6.0, "radius": 0.8,
		"color": Color(0.36, 0.26, 0.06), "scale": 1.0, "drop": 0.5, "script": ENEMY, "sfx": "bomber",
		"ai": "bomber", "windup": 1.15, "strike": 0.3, "recover": 0.1, "fuse": 1.15,
		"blast_r": 4.6, "blast_dmg": 34.0, "pool_dur": 8.0, "pool_dps": 7.0, "aggro": 18.0, "loot": "bug"},
	# 晶背虫：赤湖与矿区的重甲反射体。正面硬得离谱，绕到侧后或用爆发伤害解决。
	"crystal_bug": {"name": "晶背虫", "hp": 240.0, "speed": 3.4, "dmg": 22.0, "range": 3.6, "rate": 2.2, "radius": 1.45,
		"color": Color(0.34, 0.2, 0.44), "scale": 1.7, "drop": 0.85, "script": ENEMY, "sfx": "crystal_bug",
		"ai": "shell", "windup": 0.85, "strike": 0.22, "recover": 0.7, "charge_speed": 12.0, "charge_time": 0.3,
		"aggro": 16.0, "armor": 0.15, "front_resist": 0.55, "loot": "crystal"},
	# 钻地虫：裂谷矿区的伏击者。钻入地下潜行、扬尘暴露轨迹，破土顶飞机甲后有一段硬直。
	"burrower": {"name": "钻地虫", "hp": 96.0, "speed": 6.4, "dmg": 20.0, "range": 3.2, "rate": 3.4, "radius": 0.9,
		"color": Color(0.26, 0.2, 0.14), "scale": 1.15, "drop": 0.55, "script": ENEMY, "sfx": "burrower",
		"ai": "burrower", "windup": 0.7, "strike": 0.25, "recover": 1.1, "burrow_time": 6.0, "burrow_speed": 9.5,
		"erupt_r": 2.6, "aggro": 19.0, "interrupt": 0.3, "loot": "bug"},
	# 改装机甲虫：诗织给旧甲虫焊上旧世界装甲与干扰天线，靠近后放电抽干动力炉。
	"mech_beetle": {"name": "改装机甲虫", "hp": 260.0, "speed": 4.6, "dmg": 24.0, "range": 2.9, "rate": 2.0, "radius": 1.4,
		"color": Color(0.24, 0.24, 0.2), "scale": 1.75, "drop": 0.9, "script": ENEMY, "sfx": "mech_beetle",
		"ai": "jammer", "windup": 0.95, "strike": 0.25, "recover": 0.8, "jam_r": 14.0, "jam_cost": 16.0,
		"aggro": 18.0, "armor": 0.28, "loot": "scrap"},
	# 啸翅虫：低空群飞的骚扰者。盘旋 → 昂身蓄力 → 俯冲割击 → 拉升硬直。
	"wasp": {"name": "啸翅虫", "hp": 30.0, "speed": 10.5, "dmg": 10.0, "range": 2.6, "rate": 2.2, "radius": 0.55,
		"color": Color(0.4, 0.34, 0.16), "scale": 0.75, "drop": 0.3, "script": ENEMY, "sfx": "wasp",
		"ai": "flyer", "windup": 0.55, "strike": 0.2, "recover": 0.85, "charge_speed": 19.0, "charge_time": 0.32,
		"hover": 2.4, "aggro": 18.0, "interrupt": 0.2, "loot": "bug"},
	# 盾脉虫：虫群的支援节点。张开护盾脉给周围虫上护盾并修甲，本体脆、移动慢。
	"shielder": {"name": "盾脉虫", "hp": 68.0, "speed": 5.2, "dmg": 6.0, "range": 2.2, "rate": 3.0, "radius": 0.8,
		"color": Color(0.2, 0.3, 0.26), "scale": 1.0, "drop": 0.45, "script": ENEMY, "sfx": "shielder",
		"ai": "support", "windup": 1.0, "strike": 0.3, "recover": 0.6, "pulse_r": 9.0, "pulse_heal": 18.0,
		"pulse_shield": 12.0, "keep": 13.0, "aggro": 16.0, "interrupt": 0.22, "loot": "bug"},
	# 曲炮虫：曲线炮击手。远距离抬起腹部抛射酸壳，落点有地面预警圈；贴身时会后退。
	"mortar": {"name": "曲炮虫", "hp": 110.0, "speed": 3.8, "dmg": 24.0, "range": 34.0, "rate": 5.5, "radius": 1.0,
		"color": Color(0.24, 0.28, 0.16), "scale": 1.25, "drop": 0.6, "script": ENEMY, "sfx": "mortar",
		"ai": "artillery", "windup": 1.2, "strike": 0.25, "recover": 0.9, "volley": 3, "shell_time": 1.4,
		"blast_r": 3.6, "keep": 30.0, "flee": 16.0, "aggro": 40.0, "interrupt": 0.3, "loot": "bug"},
	# 铁颚虫：甲虫的精英变体。双层叠甲、铁颚冲锋，半血后进入暴怒，冲锋间隔减半。
	"ironjaw": {"name": "铁颚虫", "hp": 380.0, "speed": 5.0, "dmg": 26.0, "range": 3.4, "rate": 1.8, "radius": 1.5,
		"color": Color(0.2, 0.18, 0.16), "scale": 1.95, "drop": 1.0, "script": ENEMY, "sfx": "ironjaw",
		"ai": "juggernaut", "windup": 0.9, "strike": 0.25, "recover": 0.9, "charge_speed": 17.0, "charge_time": 0.75,
		"aggro": 18.0, "armor": 0.35, "interrupt": 0.3, "loot": "elite"},

	# ---------------- Boss：登场、阶段、弱点全部走事件总线 ----------------
	# 赤湖巢母：盘踞菌毯的区域 Boss，背部卵囊是弱点；半血后开始齐射酸雨。
	"broodmother": {"name": "赤湖巢母", "hp": 900.0, "speed": 3.4, "dmg": 26.0, "range": 4.5, "rate": 2.4, "radius": 2.6,
		"color": Color(0.3, 0.16, 0.24), "scale": 2.4, "drop": 1.0, "script": BOSS_BROOD, "sfx": "broodmother", "boss": true,
		"ai": "boss", "windup": 0.9, "strike": 0.3, "recover": 0.9, "weak_back": 2.2, "loot": "boss_brood",
		"phases": [1.0, 0.6, 0.28]},
	# 裂谷铁甲王虫：双柱巨足震地，半血后连续冲撞，破甲后露出背部晶核。
	"king_beetle": {"name": "裂谷铁甲王虫", "hp": 1900.0, "speed": 3.6, "dmg": 34.0, "range": 5.0, "rate": 2.2, "radius": 3.2,
		"color": Color(0.18, 0.17, 0.15), "scale": 3.0, "drop": 1.0, "script": BOSS_KING, "sfx": "king_beetle", "boss": true,
		"ai": "boss", "windup": 1.0, "strike": 0.3, "recover": 1.0, "weak_back": 2.0, "loot": "boss_king",
		"phases": [1.0, 0.6, 0.25]},
	# 深渊母皇：终章三阶段母体，胸口晶核在三阶段完全暴露。
	"abyss_queen": {"name": "深渊母皇", "hp": 2800.0, "speed": 2.8, "dmg": 40.0, "range": 6.0, "rate": 2.0, "radius": 3.4,
		"color": Color(0.26, 0.14, 0.34), "scale": 3.3, "drop": 1.0, "script": BOSS_QUEEN, "sfx": "abyss_queen", "boss": true,
		"ai": "boss", "windup": 1.1, "strike": 0.35, "recover": 1.1, "weak_back": 1.8, "weak_core": 3.0, "loot": "boss_queen",
		"phases": [1.0, 0.66, 0.3]},
	# ---------------- 第二批补充：重装、远狙、支援与重锤 ----------------
	# 盾卫虫：正面挂着整块复合盾的推进体，正面极硬，逼玩家绕后。
	"aegis": {"name": "盾卫虫", "hp": 420.0, "speed": 3.2, "dmg": 26.0, "range": 3.2, "rate": 1.9, "radius": 1.35,
		"color": Color(0.32, 0.34, 0.3), "scale": 1.5, "drop": 0.8, "script": ENEMY, "sfx": "crystal_bug",
		"ai": "shell", "windup": 0.9, "strike": 0.24, "recover": 0.75, "charge_speed": 11.0, "charge_time": 0.32,
		"aggro": 20.0, "armor": 0.12, "front_resist": 0.65, "interrupt": 0.3, "loot": "crystal"},
	# 狙击虫：极远距离单发酸弹，弹道慢但伤害高，站在开阔地最危险。
	"lancer": {"name": "狙击虫", "hp": 70.0, "speed": 4.4, "dmg": 30.0, "range": 30.0, "rate": 3.6, "radius": 0.7,
		"color": Color(0.34, 0.3, 0.22), "scale": 1.0, "drop": 0.45, "script": ENEMY, "sfx": "wasp",
		"ai": "artillery", "windup": 1.25, "strike": 0.2, "recover": 0.9, "volley": 1, "shell_time": 1.1,
		"keep": 20.0, "flee": 8.0, "aggro": 26.0, "loot": "mantis"},
	# 指挥虫：不冲阵，靠脉冲给周围虫群补盾与修甲，优先点掉。
	"overseer": {"name": "指挥虫", "hp": 110.0, "speed": 4.2, "dmg": 10.0, "range": 16.0, "rate": 1.4, "radius": 0.9,
		"color": Color(0.3, 0.28, 0.36), "scale": 1.25, "drop": 0.7, "script": ENEMY, "sfx": "shielder",
		"ai": "support", "windup": 0.7, "strike": 0.2, "recover": 0.6, "pulse_r": 7.5, "pulse_heal": 16.0,
		"pulse_shield": 12.0, "aggro": 18.0, "loot": "scrap"},
	# 链锯虫：贴脸的高速切割体，起手快、收招短，逼玩家拉开距离。
	"ripper": {"name": "链锯虫", "hp": 180.0, "speed": 6.8, "dmg": 20.0, "range": 2.8, "rate": 1.1, "radius": 0.9,
		"color": Color(0.28, 0.26, 0.24), "scale": 1.2, "drop": 0.6, "script": ENEMY, "sfx": "mech_beetle",
		"ai": "lancer", "windup": 0.45, "strike": 0.16, "recover": 0.5, "charge_speed": 18.0, "charge_time": 0.28,
		"aggro": 19.0, "interrupt": 0.2, "loot": "scrap"},
	# 巢母：移动缓慢的虫群核心，靠修复脉冲维持整片虫群，血量高但输出低。
	"brood": {"name": "巢母", "hp": 900.0, "speed": 2.6, "dmg": 22.0, "range": 18.0, "rate": 2.0, "radius": 2.2,
		"color": Color(0.3, 0.26, 0.3), "scale": 2.6, "drop": 1.0, "script": ENEMY, "sfx": "broodmother",
		"ai": "support", "windup": 0.9, "strike": 0.25, "recover": 0.8, "pulse_r": 9.0, "pulse_heal": 24.0,
		"pulse_shield": 18.0, "aggro": 20.0, "armor": 0.08, "loot": "boss_brood"},
	# 破城巨像：慢速重锤，正面推进，靠体量与范围伤害压场地。
	"colossus": {"name": "破城巨像", "hp": 1800.0, "speed": 2.0, "dmg": 55.0, "range": 4.6, "rate": 2.4, "radius": 3.0,
		"color": Color(0.26, 0.26, 0.28), "scale": 3.2, "drop": 1.0, "script": ENEMY, "sfx": "ironjaw",
		"ai": "juggernaut", "windup": 1.0, "strike": 0.32, "recover": 0.9, "charge_speed": 12.0, "charge_time": 0.4,
		"aggro": 24.0, "armor": 0.15, "front_resist": 0.45, "interrupt": 0.4, "loot": "elite"},
}
const SPAWNS := {
	# 灰港市：城区街巷密度中等，跳虫与酸液虫为主，开阔地混少量啸翅虫。
	"greyport": {"packs": {"D": 1.6, "R": 1.8, "I": 1.6, "H": 1.5, "Y": 1.0, "M": 1.8, "P": 1.2, "F": 0.8, "W": 0.7, "T": 0.9, "C": 1.3, "S": 2.2, "K": 0.0},
		"kinds": {"ling": 40, "spitter": 22, "beetle": 15, "wasp": 10, "mantis": 4, "bomber": 4, "shielder": 3, "crystal_bug": 2, "burrower": 2, "mech_beetle": 2, "mortar": 2, "ironjaw": 1}, "pack_size": [2, 4]},
	# 铁锈工业带：厂房掩体多、零件多，镰爪虫在编组站与厂区之间巡逻。
	"ironbelt": {"packs": {"D": 1.2, "R": 1.5, "I": 2.2, "H": 1.4, "Y": 1.9, "M": 1.6, "P": 1.0, "F": 0.7, "W": 0.9, "T": 1.1, "C": 1.5, "S": 2.6, "K": 0.0},
		"kinds": {"ling": 28, "spitter": 17, "beetle": 13, "mantis": 20, "shielder": 8, "mech_beetle": 5, "mortar": 3, "wasp": 3, "bomber": 2, "burrower": 2, "crystal_bug": 1, "ironjaw": 1, "ripper": 8, "aegis": 5}, "pack_size": [2, 4]},
	# 尘土平原：视野开阔、虫群分散成小群，自爆虫贴着田埂冲过来。
	"dustfield": {"packs": {"D": 1.1, "R": 1.5, "I": 0.6, "H": 0.4, "Y": 0.4, "M": 1.3, "P": 1.0, "F": 1.0, "W": 0.9, "T": 1.2, "C": 1.7, "S": 2.3, "K": 0.3},
		"kinds": {"ling": 34, "spitter": 20, "beetle": 12, "bomber": 22, "wasp": 4, "burrower": 3, "mantis": 3, "shielder": 2, "mortar": 2, "crystal_bug": 1, "mech_beetle": 1, "ironjaw": 1, "lancer": 6}, "pack_size": [2, 3]},
	# 赤湖新区：林地与湖畔，晶背虫与盾脉虫成群；巢母由 spawn_redlake.gd 布置。
	"redlake": {"packs": {"D": 1.4, "R": 1.7, "I": 0.8, "H": 0.8, "Y": 0.5, "M": 1.4, "P": 1.6, "F": 1.2, "W": 0.9, "T": 1.8, "C": 1.6, "S": 2.4, "K": 0.0},
		"kinds": {"ling": 26, "spitter": 20, "beetle": 13, "crystal_bug": 17, "shielder": 9, "wasp": 5, "mortar": 3, "mantis": 2, "bomber": 2, "burrower": 2, "mech_beetle": 1, "ironjaw": 1, "overseer": 5}, "pack_size": [2, 4],
		"script": "res://scripts/enemies/spawn_redlake.gd"},
	# 裂谷矿区：路线少、伏击点多，钻地虫与曲炮虫封锁干河谷，精英铁颚虫游荡。
	"canyon": {"packs": {"D": 0.8, "R": 0.6, "I": 1.3, "H": 0.6, "Y": 0.9, "M": 1.5, "P": 0.4, "F": 0.4, "W": 1.4, "T": 0.8, "C": 1.9, "S": 2.7, "K": 0.0},
		"kinds": {"ling": 10, "beetle": 14, "mantis": 15, "burrower": 19, "mech_beetle": 12, "mortar": 13, "ironjaw": 7, "spitter": 4, "crystal_bug": 3, "wasp": 2, "bomber": 2, "shielder": 2, "lancer": 6, "ripper": 7}, "pack_size": [2, 3],
		"script": "res://scripts/enemies/spawn_canyon.gd"},

}

## 零号深渊井的虫群分布：战区由地图团队登记后才并入（战区未登记时不产生指向不存在战区的分布）
const ABYSS_SPAWN := {"packs": {"D": 0.0, "R": 0.0, "I": 1.4, "H": 0.0, "Y": 0.0, "M": 1.6, "P": 0.0, "F": 0.0, "W": 1.2, "T": 0.0, "C": 2.0, "S": 3.0, "K": 0.0},
	"kinds": {"burrower": 20, "crystal_bug": 18, "ironjaw": 14, "mech_beetle": 13, "mortar": 12, "wasp": 12, "mantis": 5, "bomber": 4, "shielder": 4, "spitter": 3, "beetle": 3, "ling": 2, "aegis": 6, "overseer": 4, "brood": 3, "colossus": 2}, "pack_size": [2, 4],
	"script": "res://scripts/enemies/spawn_abyss.gd"}


static func register(gd) -> void:
	if gd.MAPS.has("abyss_maw") and not gd.SPAWNS.has("abyss_maw"):
		gd.SPAWNS["abyss_maw"] = ABYSS_SPAWN.duplicate(true)
const LOOT_TABLES := {
	"mantis": {"name": "镰爪虫残骸", "rolls": [1, 2], "pool": {"chitin": 58, "bug_crystal": 14, "circuit": 12, "wire": 8, "fuel_cell": 8}},
	"crystal": {"name": "晶背虫残骸", "rolls": [2, 3], "pool": {"bug_crystal": 54, "chitin": 34, "gen_crystal": 4, "credit_s": 8}},
	"scrap": {"name": "改装虫残骸", "rolls": [2, 3], "pool": {"circuit": 34, "wire": 22, "bolts": 20, "@module": 12, "hdd": 5, "credit_s": 7}},
	"elite": {"name": "精英虫残骸", "rolls": [2, 4], "pool": {"chitin": 30, "bug_crystal": 28, "@module": 22, "credit_l": 8, "repair_kit": 12}},
	"boss_brood": {"name": "巢母残骸", "rolls": [3, 4], "pool": {"bug_crystal": 40, "@module": 26, "gen_crystal": 8, "credit_l": 14, "chitin": 12}},
	"boss_king": {"name": "王虫残骸", "rolls": [3, 5], "pool": {"bug_crystal": 32, "@module": 30, "credit_l": 18, "gen_crystal": 10, "repair_kit": 10}},
	"boss_queen": {"name": "母皇残骸", "rolls": [4, 6], "pool": {"bug_crystal": 34, "@module": 30, "credit_l": 20, "gold": 8, "gen_crystal": 8}},
}
const SFX := {
	# ---- 镰爪虫：骨刃出鞘、冲刺破风 ----
	"bug_mantis_appear": {"files": ["bug_mantis_appear_01.wav", "bug_mantis_appear_02.wav"], "when": "镰爪虫转入追击（enemy.gd）", "gap": 0.3},
	"bug_mantis_windup": {"files": ["bug_mantis_windup_01.wav", "bug_mantis_windup_02.wav"], "when": "镰爪虫后撤蓄力、双镰抬起"},
	"bug_mantis_attack": {"files": ["bug_mantis_attack_01.wav", "bug_mantis_attack_02.wav", "bug_mantis_attack_03.wav"], "when": "镰爪虫冲刺挥镰"},
	"bug_mantis_hurt": {"files": ["bug_mantis_hurt_01.wav", "bug_mantis_hurt_02.wav", "bug_mantis_hurt_03.wav"], "when": "镰爪虫受击", "gap": 0.08, "max": 4},
	"bug_mantis_death": {"files": ["bug_mantis_death_01.wav", "bug_mantis_death_02.wav"], "when": "镰爪虫死亡", "max": 3},
	# ---- 爆浆虫：毒囊抽气、引信滴答、爆开 ----
	"bug_bomber_appear": {"files": ["bug_bomber_appear_01.wav", "bug_bomber_appear_02.wav"], "when": "爆浆虫转入追击", "gap": 0.3},
	"bug_bomber_windup": {"files": ["bug_bomber_windup_01.wav", "bug_bomber_windup_02.wav"], "when": "爆浆虫鼓胀毒囊、开始自爆倒计时"},
	"bug_bomber_fuse": {"files": ["bug_bomber_fuse_01.wav", "bug_bomber_fuse_02.wav"], "when": "爆浆虫被击杀后进入延时引爆", "gap": 0.1},
	"bug_bomber_attack": {"files": ["bug_bomber_attack_01.wav", "bug_bomber_attack_02.wav"], "when": "爆浆虫炸开", "unit": 18.0, "dist": 90.0},
	"bug_bomber_hurt": {"files": ["bug_bomber_hurt_01.wav", "bug_bomber_hurt_02.wav"], "when": "爆浆虫受击", "gap": 0.08, "max": 4},
	"bug_bomber_death": {"files": ["bug_bomber_death_01.wav"], "when": "爆浆虫死亡", "max": 2},
	# ---- 晶背虫：晶体摩擦、折射嗡鸣 ----
	"bug_crystal_bug_appear": {"files": ["bug_crystal_bug_appear_01.wav", "bug_crystal_bug_appear_02.wav"], "when": "晶背虫转入追击", "gap": 0.35, "unit": 16.0},
	"bug_crystal_bug_windup": {"files": ["bug_crystal_bug_windup_01.wav", "bug_crystal_bug_windup_02.wav"], "when": "晶背虫压低重心撞来", "unit": 16.0},
	"bug_crystal_bug_attack": {"files": ["bug_crystal_bug_attack_01.wav", "bug_crystal_bug_attack_02.wav"], "when": "晶背虫身材相撞", "unit": 16.0},
	"bug_crystal_bug_hurt": {"files": ["bug_crystal_bug_hurt_01.wav", "bug_crystal_bug_hurt_02.wav"], "when": "晶背虫受击（正面折射时会多一道清脆回响）", "gap": 0.1, "max": 3},
	"bug_crystal_bug_death": {"files": ["bug_crystal_bug_death_01.wav", "bug_crystal_bug_death_02.wav"], "when": "晶背虫死亡、晶簇崩落", "max": 2, "unit": 16.0},
	# ---- 钻地虫：土石翻涌、破土 ----
	"bug_burrower_appear": {"files": ["bug_burrower_appear_01.wav", "bug_burrower_appear_02.wav"], "when": "钻地虫转入追击", "gap": 0.3},
	"bug_burrower_windup": {"files": ["bug_burrower_windup_01.wav", "bug_burrower_windup_02.wav"], "when": "钻地虫钻入土中（地面扬尘）"},
	"bug_burrower_erupt": {"files": ["bug_burrower_erupt_01.wav", "bug_burrower_erupt_02.wav"], "when": "钻地虫破土顶出", "unit": 18.0},
	"bug_burrower_attack": {"files": ["bug_burrower_attack_01.wav", "bug_burrower_attack_02.wav"], "when": "钻地虫破土撞击机甲"},
	"bug_burrower_hurt": {"files": ["bug_burrower_hurt_01.wav", "bug_burrower_hurt_02.wav"], "when": "钻地虫受击", "gap": 0.08, "max": 4},
	"bug_burrower_death": {"files": ["bug_burrower_death_01.wav", "bug_burrower_death_02.wav"], "when": "钻地虫死亡", "max": 3},
	# ---- 改装机甲虫：伺服卡顿、电弧放电、干扰器充能 ----
	"bug_mech_beetle_appear": {"files": ["bug_mech_beetle_appear_01.wav", "bug_mech_beetle_appear_02.wav"], "when": "改装机甲虫转入追击", "gap": 0.35, "unit": 18.0},
	"bug_mech_beetle_windup": {"files": ["bug_mech_beetle_windup_01.wav", "bug_mech_beetle_windup_02.wav"], "when": "改装机甲虫干扰天线充能", "unit": 18.0},
	"bug_mech_beetle_attack": {"files": ["bug_mech_beetle_attack_01.wav", "bug_mech_beetle_attack_02.wav"], "when": "改装机甲虫放出干扰脉冲", "unit": 18.0, "dist": 90.0},
	"bug_mech_beetle_jam": {"files": ["bug_mech_beetle_jam_01.wav", "bug_mech_beetle_jam_02.wav"], "when": "干扰脉冲命中机甲、动力炉被抽能", "unit": 18.0},
	"bug_mech_beetle_hurt": {"files": ["bug_mech_beetle_hurt_01.wav", "bug_mech_beetle_hurt_02.wav", "bug_mech_beetle_hurt_03.wav"], "when": "改装机甲虫受击（金属护板被敲响）", "gap": 0.09, "max": 4},
	"bug_mech_beetle_death": {"files": ["bug_mech_beetle_death_01.wav", "bug_mech_beetle_death_02.wav"], "when": "改装机甲虫死亡、护板脱落", "max": 2, "unit": 18.0},
	# ---- 啸翅虫：翅膜高频颤动、俯冲尖叫 ----
	"bug_wasp_appear": {"files": ["bug_wasp_appear_01.wav", "bug_wasp_appear_02.wav"], "when": "啸翅虫转入追击", "gap": 0.2, "max": 6},
	"bug_wasp_windup": {"files": ["bug_wasp_windup_01.wav", "bug_wasp_windup_02.wav"], "when": "啸翅虫昂身蓄力", "max": 5},
	"bug_wasp_attack": {"files": ["bug_wasp_attack_01.wav", "bug_wasp_attack_02.wav"], "when": "啸翅虫俯冲割击", "max": 5},
	"bug_wasp_hurt": {"files": ["bug_wasp_hurt_01.wav", "bug_wasp_hurt_02.wav", "bug_wasp_hurt_03.wav"], "when": "啸翅虫受击", "gap": 0.06, "max": 5},
	"bug_wasp_death": {"files": ["bug_wasp_death_01.wav", "bug_wasp_death_02.wav"], "when": "啸翅虫死亡坠地", "max": 4},
	# ---- 盾脉虫：护盾脉张开、治疗嗡鸣 ----
	"bug_shielder_appear": {"files": ["bug_shielder_appear_01.wav", "bug_shielder_appear_02.wav"], "when": "盾脉虫转入追击", "gap": 0.35},
	"bug_shielder_windup": {"files": ["bug_shielder_windup_01.wav", "bug_shielder_windup_02.wav"], "when": "盾脉虫张开伞盖、护盾脉充能"},
	"bug_shielder_pulse": {"files": ["bug_shielder_pulse_01.wav", "bug_shielder_pulse_02.wav"], "when": "盾脉虫护盾脉扩散、给周围虫上盾", "unit": 16.0},
	"bug_shielder_attack": {"files": ["bug_shielder_attack_01.wav"], "when": "盾脉虫撞击", "max": 3},
	"bug_shielder_hurt": {"files": ["bug_shielder_hurt_01.wav", "bug_shielder_hurt_02.wav"], "when": "盾脉虫受击", "gap": 0.08, "max": 4},
	"bug_shielder_death": {"files": ["bug_shielder_death_01.wav", "bug_shielder_death_02.wav"], "when": "盾脉虫死亡、护盾崩解", "max": 3},
	# ---- 曲炮虫：抬腹上膛、抛壳破空、落点炸开 ----
	"bug_mortar_appear": {"files": ["bug_mortar_appear_01.wav", "bug_mortar_appear_02.wav"], "when": "曲炮虫转入追击", "gap": 0.35, "unit": 20.0, "dist": 90.0},
	"bug_mortar_windup": {"files": ["bug_mortar_windup_01.wav", "bug_mortar_windup_02.wav"], "when": "曲炮虫抬起腹部瞄准", "unit": 20.0, "dist": 90.0},
	"bug_mortar_launch": {"files": ["bug_mortar_launch_01.wav", "bug_mortar_launch_02.wav", "bug_mortar_launch_03.wav"], "when": "曲炮虫抛射酸壳", "unit": 20.0, "dist": 90.0},
	"bug_mortar_attack": {"files": ["bug_mortar_attack_01.wav", "bug_mortar_attack_02.wav"], "when": "曲炮虫的酸壳落地炸开", "unit": 20.0, "dist": 90.0},
	"bug_mortar_hurt": {"files": ["bug_mortar_hurt_01.wav", "bug_mortar_hurt_02.wav"], "when": "曲炮虫受击", "gap": 0.08, "max": 4},
	"bug_mortar_death": {"files": ["bug_mortar_death_01.wav", "bug_mortar_death_02.wav"], "when": "曲炮虫死亡", "max": 3},
	# ---- 铁颚虫：重甲摩擦、铁颚开合 ----
	"bug_ironjaw_appear": {"files": ["bug_ironjaw_appear_01.wav", "bug_ironjaw_appear_02.wav"], "when": "铁颚虫转入追击", "gap": 0.4, "unit": 18.0},
	"bug_ironjaw_windup": {"files": ["bug_ironjaw_windup_01.wav", "bug_ironjaw_windup_02.wav"], "when": "铁颚虫开合铁颚蓄力冲锋", "unit": 18.0},
	"bug_ironjaw_attack": {"files": ["bug_ironjaw_attack_01.wav", "bug_ironjaw_attack_02.wav"], "when": "铁颚虫铁颚合拢或冲锋撞击", "unit": 18.0},
	"bug_ironjaw_hurt": {"files": ["bug_ironjaw_hurt_01.wav", "bug_ironjaw_hurt_02.wav", "bug_ironjaw_hurt_03.wav"], "when": "铁颚虫受击", "gap": 0.1, "max": 3},
	"bug_ironjaw_death": {"files": ["bug_ironjaw_death_01.wav", "bug_ironjaw_death_02.wav"], "when": "铁颚虫死亡", "max": 2, "unit": 18.0},
	# ---- Boss：登场咆哮、阶段切换、部位击破 ----
	"boss_brood_roar": {"files": ["boss_brood_roar_01.wav", "boss_brood_roar_02.wav"], "when": "赤湖巢母从菌毯中撑起身体、登场", "unit": 26.0, "dist": 150.0, "max": 1},
	"boss_brood_hatch": {"files": ["boss_brood_hatch_01.wav", "boss_brood_hatch_02.wav"], "when": "赤湖巢母卵囊裂开、孵出幼虫", "unit": 22.0, "dist": 120.0},
	"boss_king_roar": {"files": ["boss_king_roar_01.wav", "boss_king_roar_02.wav"], "when": "裂谷铁甲王虫撞开岩壁、登场", "unit": 30.0, "dist": 180.0, "max": 1},
	"boss_king_stomp": {"files": ["boss_king_stomp_01.wav", "boss_king_stomp_02.wav"], "when": "裂谷铁甲王虫双柱巨足砸地", "unit": 28.0, "dist": 150.0},
	"boss_king_core": {"files": ["boss_king_core_01.wav"], "when": "裂谷铁甲王虫背甲裂开、晶核暴露", "unit": 26.0, "dist": 140.0, "max": 1},
	"boss_queen_roar": {"files": ["boss_queen_roar_01.wav", "boss_queen_roar_02.wav"], "when": "深渊母皇在竖井底部苏醒", "unit": 34.0, "dist": 200.0, "max": 1},
	"boss_queen_wail": {"files": ["boss_queen_wail_01.wav", "boss_queen_wail_02.wav"], "when": "深渊母皇进入下一阶段的长鸣", "unit": 30.0, "dist": 180.0, "max": 1},
	"boss_queen_core": {"files": ["boss_queen_core_01.wav"], "when": "深渊母皇胸口晶核完全暴露", "unit": 30.0, "dist": 180.0, "max": 1},
	"boss_phase_shift": {"files": ["boss_phase_shift_01.wav", "boss_phase_shift_02.wav"], "when": "任一 Boss 阶段切换时甲壳/晶簇碎裂", "unit": 26.0, "dist": 160.0, "max": 1},
	"bug_broodmother_appear": {"files": ["bug_broodmother_appear_01.wav", "bug_broodmother_appear_02.wav"], "when": "赤湖巢母转入追击（enemy.gd 的 _sfx）"},
	"bug_broodmother_windup": {"files": ["bug_broodmother_windup_01.wav", "bug_broodmother_windup_02.wav"], "when": "赤湖巢母起手蓄力（enemy.gd 的 _sfx）"},
	"bug_broodmother_attack": {"files": ["bug_broodmother_attack_01.wav", "bug_broodmother_attack_02.wav"], "when": "赤湖巢母出手（enemy.gd 的 _sfx）"},
	"bug_broodmother_hurt": {"files": ["bug_broodmother_hurt_01.wav", "bug_broodmother_hurt_02.wav"], "when": "赤湖巢母受击（enemy.gd 的 _sfx）"},
	"bug_broodmother_death": {"files": ["bug_broodmother_death_01.wav", "bug_broodmother_death_02.wav"], "when": "赤湖巢母死亡（enemy.gd 的 _sfx）"},
	"bug_king_beetle_appear": {"files": ["bug_king_beetle_appear_01.wav", "bug_king_beetle_appear_02.wav"], "when": "裂谷铁甲王虫转入追击（enemy.gd 的 _sfx）", "unit": 24.0},
	"bug_king_beetle_windup": {"files": ["bug_king_beetle_windup_01.wav", "bug_king_beetle_windup_02.wav"], "when": "裂谷铁甲王虫起手蓄力（enemy.gd 的 _sfx）", "unit": 24.0},
	"bug_king_beetle_attack": {"files": ["bug_king_beetle_attack_01.wav", "bug_king_beetle_attack_02.wav"], "when": "裂谷铁甲王虫出手（enemy.gd 的 _sfx）", "unit": 24.0},
	"bug_king_beetle_hurt": {"files": ["bug_king_beetle_hurt_01.wav", "bug_king_beetle_hurt_02.wav"], "when": "裂谷铁甲王虫受击（enemy.gd 的 _sfx）", "unit": 24.0},
	"bug_king_beetle_death": {"files": ["bug_king_beetle_death_01.wav", "bug_king_beetle_death_02.wav"], "when": "裂谷铁甲王虫死亡（enemy.gd 的 _sfx）", "unit": 24.0},
	"bug_abyss_queen_appear": {"files": ["bug_abyss_queen_appear_01.wav", "bug_abyss_queen_appear_02.wav"], "when": "深渊母皇转入追击（enemy.gd 的 _sfx）", "unit": 26.0},
	"bug_abyss_queen_windup": {"files": ["bug_abyss_queen_windup_01.wav", "bug_abyss_queen_windup_02.wav"], "when": "深渊母皇起手蓄力（enemy.gd 的 _sfx）", "unit": 26.0},
	"bug_abyss_queen_attack": {"files": ["bug_abyss_queen_attack_01.wav", "bug_abyss_queen_attack_02.wav"], "when": "深渊母皇出手（enemy.gd 的 _sfx）", "unit": 26.0},
	"bug_abyss_queen_hurt": {"files": ["bug_abyss_queen_hurt_01.wav", "bug_abyss_queen_hurt_02.wav"], "when": "深渊母皇受击（enemy.gd 的 _sfx）", "unit": 26.0},
	"bug_abyss_queen_death": {"files": ["bug_abyss_queen_death_01.wav", "bug_abyss_queen_death_02.wav"], "when": "深渊母皇死亡（enemy.gd 的 _sfx）", "unit": 26.0},
}
const RAID_SCRIPTS := []
const EXTEND := {}
