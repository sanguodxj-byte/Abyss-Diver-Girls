extends RefCounted
## 装备扩展数据：启动时由 GameData 并入核心表（规则见 scripts\game_data.gd 的「内容注册」一节）。
##
## MODULES  模块，字段与 GameData.MODULES 相同：name / slot（core legs arm back gen）/ w / v / rar（0..3）/ color，
##          以及按槽位的数值字段（躯干 hp cargo drain；底盘 speed load drain type；武器 weapon dmg rate cost spread speed range；
##          背部 ability cd cost；动力炉 energy eff）。建模脚本放 scripts\modules\<模块 id>.gd。
## ITEMS    消耗品或普通物品：name / cat（food misc use money）/ w / v / rar / desc；
##          消耗品加 script = 路径，脚本写 static func use(mech, id) -> bool（返回 true 时扣除一件，音效 use_<物品 id>）。
## AMMO     武器类型的弹匣：mag / reload / tex（assets\ui 下的子弹贴图名），持续喷射类加 fire_loop = true；
##          新弹道加 script = 路径，脚本写 static func fire(mech, slot, origin, dir, m)，负责弹道、炮口火光与 mech.raid.alert_noise。
## SKILLS   新技能：name / icon（assets\ui\ic_<icon>.png，音效 skill_<icon>）/ cd / cost 及效果参数；
##          底盘位移的键为底盘 type，背部技能的键为模块的 ability；
##          效果写在 script = 路径，脚本写 static func use(mech, key, sk, m)（冷却、扣能、音效与 skill_used 事件已由 mech.gd 处理）。
## LOOT_TABLES  新掉落表；SHOP 追加上架的物品 id。
## SFX      新音效的登记（格式同 scripts\audio\audio_registry.gd 的 SFX）；不登记也能按命名约定播放，登记后列入音频清单。
## RAID_SCRIPTS  行动扩展脚本路径（规则见 scripts\raid.gd 的 _run_ext_build），如新消耗品的按键处理。
## EXTEND   给已有条目补字段，如 {"LOOT_TABLES": {"military": {"pool": {"新物品 id": 权重}}}}。
## static func register(gd)  可选：登记 gd.add_item_resolver、gd.add_loot_hook、gd.add_stat_hook、InputMap 新动作。

const MODULES := {
	# ---- 躯干 ----
	"core_assault": {"name": "AS-2 突击 框架", "slot": "core", "gw": 2, "gh": 3, "w": 15, "v": 2000, "rar": 2, "hp": 170, "cargo": 20, "drain": 0.12, "armor": 0.02, "armor_class": 4, "ergo": 68, "recon": 1.0, "tags": ["侦察"], "color": Color(0.42, 0.34, 0.28), "desc": "军用前线突击机架，正面镶嵌 4 级碳化硼复合防弹插板，集成前线战术观瞄头（[侦察] 额外视距 +1）。"},
	"core_command": {"name": "CMD-1 指挥 框架", "slot": "core", "gw": 2, "gh": 3, "w": 13, "v": 2200, "rar": 2, "hp": 150, "cargo": 22, "drain": 0.11, "armor": 0.01, "armor_class": 3, "ergo": 76, "recon": 3.0, "tags": ["侦察"], "color": Color(0.34, 0.38, 0.42), "desc": "搭载毫米波观瞄火控与宽视野座舱的指挥机架（[侦察] 额外视距 +3），3 级防弹防护，人机工效与货舱容量极为出色。"},
	"core_fortress": {"name": "FT-5 要塞 框架", "slot": "core", "gw": 3, "gh": 3, "w": 26, "v": 3400, "rar": 3, "hp": 280, "cargo": 24, "drain": 0.17, "armor": 0.10, "armor_class": 6, "ergo": 38, "recon": 0.0, "color": Color(0.40, 0.42, 0.38), "desc": "6 级重型贫铀复合装甲座舱，正面倾斜防爆板提供 280 点结构与 10% 额外衬层减伤，但回转惯量较大。"},
	"core_heavy": {"name": "BW-3 重型 框架", "slot": "core", "gw": 3, "gh": 3, "w": 20, "v": 2400, "rar": 2, "hp": 220, "cargo": 24, "drain": 0.14, "armor_class": 5, "ergo": 46, "recon": 0.0, "color": Color(0.78, 0.302, 0.239), "desc": "5 级重装防卫机架，加厚焊接防弹钢板与 24kg 大容量背负框架，适合高烈度攻坚作业。"},
	"core_scout": {"name": "SC-1 轻型 框架", "slot": "core", "gw": 2, "gh": 2, "w": 8, "v": 400, "rar": 0, "hp": 90, "cargo": 12, "drain": 0.08, "armor_class": 2, "ergo": 82, "recon": 2.0, "tags": ["侦察"], "color": Color(0.922, 0.722, 0.251), "desc": "打捞团列装的 2 级轻量化钛铝合金侦察躯干（[侦察] 额外视距 +2），全重仅 8kg，转动惯量极小、人机工效冠绝全系。"},
	"core_std": {"name": "MK-II 中型 框架", "slot": "core", "gw": 2, "gh": 3, "w": 12, "v": 1000, "rar": 1, "hp": 140, "cargo": 18, "drain": 0.1, "armor_class": 3, "ergo": 64, "recon": 0.0, "color": Color(0.302, 0.58, 0.851), "desc": "均衡可靠的 3 级轧制均质钢制式机架，在结构强度、携行容量与人机工效之间取得良好平衡。"},
	# ---- 底盘（严格限定四类：履带 tread / 双足 biped / 四足 quad / 六足 hex，每类四款共 16 款） ----
	# 1) 履带底盘 × 4
	"legs_tread_light": {"name": "MT-2 轻型 高速履带底盘", "slot": "legs", "gw": 3, "gh": 2, "w": 11, "v": 650, "rar": 0, "speed": 7.4, "load": 52, "drain": 0.07, "armor": 0.06, "armor_class": 3, "ergo": 68, "type": "tread", "color": Color(0.40, 0.39, 0.31), "desc": "采用克里斯蒂大直径负重轮与挂胶高速履带的轻型侦察底盘，兼顾高巡航车速、3 级正面倾甲与全地形机动性。"},
	"legs_tread": {"name": "SAXX-1 中重 装甲履带底盘", "slot": "legs", "gw": 3, "gh": 2, "w": 16, "v": 1200, "rar": 1, "speed": 6.0, "load": 68, "drain": 0.08, "armor": 0.14, "armor_class": 5, "ergo": 52, "type": "tread", "color": Color(0.349, 0.38, 0.302), "desc": "全地形主战装甲履带底盘，厚重的螺栓侧裙板提供额外 14% 防弹减伤，可解除限速器全扭矩碾压冲锋。"},
	"legs_tread_heavy": {"name": "KV-6 重型 攻坚履带底盘", "slot": "legs", "gw": 3, "gh": 3, "w": 22, "v": 2100, "rar": 2, "speed": 5.5, "load": 92, "drain": 0.11, "armor": 0.17, "armor_class": 5, "ergo": 44, "type": "tread", "acid_immune": true, "color": Color(0.29, 0.33, 0.30), "desc": "加装前置液压楔形破障推土铲与全车重型反应装甲砖的攻坚履带底盘，密封履带舱免疫酸液腐蚀，提供 92kg 高承重。"},
	"legs_tread_siege": {"name": "DT-9 超重 四履带铰接底盘", "slot": "legs", "gw": 3, "gh": 3, "w": 27, "v": 3100, "rar": 3, "speed": 5.0, "load": 118, "drain": 0.14, "armor": 0.20, "armor_class": 6, "ergo": 38, "type": "tread", "overload_immune": true, "acid_immune": true, "color": Color(0.41, 0.37, 0.30), "desc": "四组独立摆臂式铰接履带舱与防核爆斜切船体构成的超重型工程底盘，接地比压极低，免疫酸液与超载减速，提供 20% 减伤与 6 级防护。"},
	# 2) 双足底盘 × 4
	"legs_biped_scout": {"name": "LN-3 轻型 侦察双足底盘", "slot": "legs", "gw": 2, "gh": 2, "w": 6, "v": 520, "rar": 0, "speed": 7.8, "load": 40, "drain": 0.06, "armor_class": 2, "ergo": 86, "type": "biped", "color": Color(0.45, 0.43, 0.37), "desc": "铬钼钢管镂空桁架与氮气减震筒构成的轻量化反关节侦察底盘，髋部外挂双联固体火箭推进荚舱，机动速度与人机工效冠绝双足系。"},
	"legs_biped": {"name": "ST-8 制式 机动双足底盘", "slot": "legs", "gw": 2, "gh": 2, "w": 8, "v": 350, "rar": 0, "speed": 6.4, "load": 48, "drain": 0.06, "armor_class": 2, "ergo": 75, "type": "biped", "color": Color(0.549, 0.549, 0.502), "desc": "结构紧凑可靠的打捞团制式双足伺服步行底盘，维护简便，髋部内置短距固体矢量推进器。"},
	"legs_biped_assault": {"name": "VK-5 中重 突击双足底盘", "slot": "legs", "gw": 2, "gh": 3, "w": 15, "v": 1850, "rar": 2, "speed": 6.0, "load": 72, "drain": 0.09, "armor": 0.10, "armor_class": 4, "ergo": 60, "type": "biped", "color": Color(0.34, 0.37, 0.41), "desc": "正关节人形重甲突击步行底盘，配备铰接防弹腰裙、高耸反应装甲撞膝盾与小腿辅助机动喷口，兼顾 4 级防弹与推进规避能力。"},
	"legs_titan": {"name": "TT-8 泰坦 重装双足底盘", "slot": "legs", "gw": 2, "gh": 3, "w": 26, "v": 3200, "rar": 3, "speed": 5.3, "load": 115, "drain": 0.13, "armor": 0.18, "armor_class": 6, "ergo": 42, "type": "biped", "overload_immune": true, "acid_immune": true, "color": Color(0.36, 0.38, 0.34), "desc": "泰坦级超重型反关节攻城双足底盘，双层重裙甲与四趾液压驻锄巨足免疫酸液与超载减速，提供 115kg 承重与 6 级重甲防护。"},
	# 3) 四足底盘 × 4
	"legs_quad_hound": {"name": "HD-4 轻型 猎犬四足底盘", "slot": "legs", "gw": 3, "gh": 2, "w": 10, "v": 1150, "rar": 1, "speed": 7.6, "load": 58, "drain": 0.08, "armor_class": 3, "ergo": 76, "type": "quad", "color": Color(0.43, 0.38, 0.31), "desc": "窄体仿生脊柱与内收式高动态液压四肢构成的猎犬奔袭底盘，集成前置激光雷达地形扫描头，崎岖废墟高速穿插能力极强。"},
	"legs_quad": {"name": "AR-4 制式 多地形四足底盘", "slot": "legs", "gw": 3, "gh": 2, "w": 14, "v": 1700, "rar": 2, "speed": 6.4, "load": 80, "drain": 0.09, "armor_class": 4, "ergo": 62, "type": "quad", "color": Color(0.502, 0.42, 0.6), "desc": "军用八角承力盘多地形四足底盘，承重高达 80kg，可通过液压蓄能弹射跃障，并在起跳点抛洒高粘滞阻拦网。"},
	"legs_quad_crab": {"name": "CR-6 重甲 堡垒四足底盘", "slot": "legs", "gw": 3, "gh": 3, "w": 19, "v": 2250, "rar": 2, "speed": 5.8, "load": 94, "drain": 0.11, "armor": 0.14, "armor_class": 5, "ergo": 50, "type": "quad", "acid_immune": true, "color": Color(0.40, 0.34, 0.28), "desc": "低矮暗堡车壳配合四扇超宽曲折防爆盾甲蟹足，外覆爆炸反应装甲砖与防酸密封套，行进间犹如移动防弹掩体。"},
	"legs_quad_mammoth": {"name": "MM-10 巨象 支腿四足底盘", "slot": "legs", "gw": 3, "gh": 3, "w": 25, "v": 3000, "rar": 3, "speed": 5.2, "load": 122, "drain": 0.13, "armor": 0.16, "armor_class": 6, "ergo": 40, "type": "quad", "overload_immune": true, "color": Color(0.39, 0.39, 0.33), "desc": "重工龙门箱梁平台与四根垂直双缸套筒液压打桩立柱构成的巨象底盘，八角调平驻锄巨足无视超载惩罚，提供 122kg 强悍运载力。"},
	# 4) 六足底盘 × 4
	"legs_hex_ant": {"name": "AT-6 轻型 工兵六足底盘", "slot": "legs", "gw": 3, "gh": 2, "w": 11, "v": 1100, "rar": 1, "speed": 7.0, "load": 72, "drain": 0.08, "armor_class": 3, "ergo": 70, "type": "hex", "color": Color(0.36, 0.39, 0.33), "desc": "敞露钢管桁架长车体配六条双管液压工兵步进肢，采用三角交替步态，以仅 11kg 自重即可稳健承载 72kg 战利品与重装模块。"},
	"legs_hex": {"name": "HX-6 中重 巡航六足底盘", "slot": "legs", "gw": 3, "gh": 2, "w": 16, "v": 2000, "rar": 2, "speed": 6.3, "load": 90, "drain": 0.10, "armor": 0.08, "armor_class": 4, "ergo": 58, "type": "hex", "color": Color(0.34, 0.37, 0.39), "desc": "军规六足多地形巡航底盘，三足常时着地的冗余液压伺服设计带来极佳射击稳定性与 90kg 大承重，可发动多足重装震踏。"},
	"legs_hex_beetle": {"name": "BT-9 重型 甲虫六足底盘", "slot": "legs", "gw": 3, "gh": 3, "w": 21, "v": 2500, "rar": 2, "speed": 5.6, "load": 106, "drain": 0.12, "armor": 0.15, "armor_class": 5, "ergo": 46, "type": "hex", "acid_immune": true, "color": Color(0.35, 0.34, 0.28), "desc": "宽体三防甲虫背壳与侧悬耳轴护裙严密遮蔽六足关节，前置双分叉破障撞角，全密封正压耐酸回路彻底免疫腐蚀地形。"},
	"legs_hex_colossus": {"name": "CL-12 巨像 攻城六足底盘", "slot": "legs", "gw": 3, "gh": 3, "w": 30, "v": 3600, "rar": 3, "speed": 4.9, "load": 140, "drain": 0.15, "armor": 0.20, "armor_class": 6, "ergo": 34, "type": "hex", "overload_immune": true, "acid_immune": true, "color": Color(0.30, 0.32, 0.33), "desc": "三段式铆接攻城堡垒船体搭载六根双缸液压打桩重足，配备前置锯齿破城撞铲，提供冠绝全系的 140kg 极限承重与 6 级重甲防护。"},
	# ---- 背部挂载 ----
	"back_rack": {"name": "RK-4 外挂 货架", "slot": "back", "gw": 2, "gh": 2, "w": 5, "v": 400, "rar": 0, "cargo": 18, "ability": "none", "color": Color(0.40, 0.40, 0.36), "desc": "模块化军规高强度铝合金快拆外挂货架，扩展 18kg 战利品携行容量。"},
	"back_rocket": {"name": "RP-7 火箭 巢", "slot": "back", "gw": 2, "gh": 3, "w": 8, "v": 2100, "rar": 2, "ability": "missile", "cd": 8.0, "cost": 8.0, "dmg": 28.0, "count": 8, "caliber": "80mm S-8KOM 破甲高爆火箭", "color": Color(0.38, 0.40, 0.34), "desc": "双联装 80mm 航空火箭发射巢，单次齐射倾泻 8 枚高爆破片火箭弹进行面杀伤火力覆盖。"},
	"back_vls": {"name": "VLS-12 垂发 单元", "slot": "back", "gw": 2, "gh": 3, "w": 11, "v": 2800, "rar": 3, "ability": "missile", "cd": 13.0, "cost": 12.0, "dmg": 42.0, "count": 12, "caliber": "120mm 攻顶巡飞弹", "color": Color(0.34, 0.36, 0.38), "desc": "12 单元冷发射垂直导弹井，发射毫米波末制导攻顶巡飞弹，对重甲目标实施饱和打击。"},
	"back_cargo": {"name": "CG-10 轻型 载货背包", "slot": "back", "gw": 2, "gh": 2, "w": 2, "v": 300, "rar": 0, "cargo": 12, "ability": "none", "color": Color(0.502, 0.42, 0.302), "desc": "防水防震的标准化密封打捞货箱，全重仅 2kg，提供 12kg 物资携行空间。"},
	"back_missile": {"name": "MS-6 中型 导弹挂架", "slot": "back", "gw": 2, "gh": 3, "w": 7, "v": 1900, "rar": 2, "ability": "missile", "cd": 7.0, "cost": 8.0, "dmg": 32.0, "count": 6, "caliber": "70mm 红外制导微弹", "color": Color(0.4, 0.451, 0.349), "desc": "6 联装红外成像寻的微弹发射架，锁定迅速、再装填周期短，适合中近距精确清剿。"},
	"back_shield": {"name": "SH-3 中型 力场护盾", "slot": "back", "gw": 2, "gh": 2, "w": 6, "v": 1600, "rar": 2, "ability": "shield", "cd": 11.0, "cost": 10.0, "dur": 4.0, "color": Color(0.349, 0.549, 0.902), "desc": "车载主动防御拦截系统，激发 4 秒全向电磁偏转幕拦截投射物，并向受损部位注入密封胶修复 35% 损伤。"},
	# ---- 动力炉 ----
	"gen_diesel": {"name": "DS-6 柴油 机组", "slot": "gen", "gw": 2, "gh": 2, "w": 9, "v": 700, "rar": 1, "energy": 240.0, "eff": 0.95, "color": Color(0.40, 0.36, 0.30), "desc": "军规双涡轮增压柴油发电机组，结构皮实耐造，提供 240 点电力储备与 5% 节电效率。"},
	"gen_hfc": {"name": "HFC-3 氢燃料 堆", "slot": "gen", "gw": 2, "gh": 2, "w": 10, "v": 1900, "rar": 2, "energy": 340.0, "eff": 0.88, "color": Color(0.36, 0.40, 0.42), "desc": "高功率质子交换膜氢氧燃料电池堆，运行安静且热效率高，提供 340 点电力储备与 12% 节电效率。"},
	"gen_turbine": {"name": "TB-5 涡轮 机组", "slot": "gen", "gw": 2, "gh": 2, "w": 12, "v": 2400, "rar": 2, "energy": 400.0, "eff": 0.92, "color": Color(0.38, 0.39, 0.36), "desc": "航空级燃气涡轮与飞轮储能复合动力机组，提供高达 400 点充沛电力与 8% 节电率，适合重火力装配。"},
	"gen_cell": {"name": "B-40 轻型 电池组", "slot": "gen", "gw": 1, "gh": 2, "w": 5, "v": 300, "rar": 0, "energy": 200.0, "eff": 1.0, "color": Color(1, 0.8, 0.2), "desc": "模块化工业锂硫蓄电池箱，全重仅 5kg，提供 200 点基础电力，适合对载重敏感的轻型低功耗侦察机架。"},
	"gen_crystal": {"name": "CR-8 试作中型 反应炉", "slot": "gen", "gw": 1, "gh": 2, "w": 8, "v": 3200, "rar": 3, "energy": 460.0, "eff": 0.8, "color": Color(0.851, 0.302, 1), "desc": "利用深渊虫晶压电效应的高能同位素温差反应炉，提供 460 点超大电力储备并将整机耗电降低 20%。"},
	"gen_reactor": {"name": "RT-1 试作中型 动力炉", "slot": "gen", "gw": 2, "gh": 2, "w": 10, "v": 1500, "rar": 1, "energy": 300.0, "eff": 0.9, "color": Color(0.2, 0.902, 1), "desc": "紧凑型液态金属冷却裂变堆，提供 300 点充沛电力与 10% 节电率，是主力中型机架的标准动力源。"},
	# ---- 手臂武装 ----
	"arm_hmg": {"name": "HMG-24 重型 机枪", "slot": "arm", "gw": 3, "gh": 1, "w": 8, "v": 900, "rar": 1, "weapon": "mg", "dmg": 13.0, "rate": 7.0, "spread": 3.5, "speed": 50.0, "range": 12.0, "reach_m": 36.0, "caliber": "14.5×114mm BS 钨芯穿甲燃烧弹", "pen": 38, "ergo": 58, "moa": 2.8, "color": Color(0.42, 0.43, 0.43), "desc": "14.5mm 重型机甲机枪，发射钨芯穿甲燃烧弹（3级穿深），有效射程 12，对中型甲壳与轻装甲目标压制力极强。"},
	"arm_gatling": {"name": "GAU-6 六管 转管炮", "slot": "arm", "gw": 3, "gh": 1, "w": 9, "v": 1900, "rar": 2, "weapon": "mg", "dmg": 13.0, "rate": 15.0, "spread": 5.5, "speed": 55.0, "range": 10.0, "reach_m": 30.0, "caliber": "20×102mm M53 穿甲弹", "pen": 24, "ergo": 44, "moa": 5.5, "color": Color(0.38, 0.40, 0.42), "desc": "电驱六管加特林速射机炮，标准射程 10，以 900 发/分的射速倾泻 20mm 弹雨，极高停止作用可瞬间撕碎无甲与轻甲虫潮。"},
	"arm_ac30": {"name": "AC-30 机炮", "slot": "arm", "gw": 3, "gh": 1, "w": 12, "v": 2200, "rar": 2, "weapon": "autocannon", "dmg": 29.0, "rate": 3.20, "spread": 1.2, "speed": 90.0, "range": 14.0, "reach_m": 42.0, "caliber": "30×165mm 3UBR8 脱壳穿甲弹", "pen": 52, "ergo": 46, "moa": 1.1, "color": Color(0.40, 0.41, 0.39), "desc": "30mm 长身管高初速自动机炮，发射次口径脱壳穿甲弹（5级穿深，远距射程 14），中远距离精准击穿重甲领主外壳。"},
	"arm_slug": {"name": "SLG-12 独头枪", "slot": "arm", "gw": 2, "gh": 1, "w": 7, "v": 1200, "rar": 1, "weapon": "shotgun", "dmg": 56.0, "pellets": 1, "rate": 1.6, "spread": 2.0, "speed": 42.0, "range": 8.0, "reach_m": 22.0, "caliber": "23×75mmR 钢芯独头弹", "pen": 39, "ergo": 64, "moa": 2.1, "color": Color(0.38, 0.36, 0.32), "desc": "23mm 线膛防暴大口径霰弹枪，装填车削实心钢芯独头弹（4级穿深，射程 8），近距单发传递恐怖钝击与穿甲动能。"},
	"arm_cannon": {"name": "CN-105 短管炮", "slot": "arm", "gw": 3, "gh": 1, "w": 13, "v": 2400, "rar": 2, "weapon": "cannon", "dmg": 62.0, "pellets": 1, "rate": 0.9, "spread": 1.0, "speed": 34.0, "range": 11.0, "reach_m": 33.0, "caliber": "105mm M456 破甲榴弹", "pen": 56, "ergo": 35, "moa": 1.4, "color": Color(0.45, 0.42, 0.34), "desc": "105mm 低后坐力滑膛突击炮，依靠聚能装药金属射流（5级穿深，射程 11）熔穿重型甲壳。"},
	"arm_rail": {"name": "RG-9 轨道炮", "slot": "arm", "gw": 4, "gh": 1, "w": 14, "v": 4200, "rar": 3, "weapon": "laser", "scope": true, "recon": 1.5, "tags": ["侦察"], "dmg": 115.0, "rate": 1, "cost": 1.60, "spread": 0.12, "speed": 135.0, "range": 16.0, "reach_m": 50.0, "caliber": "16mm 钨合金尾翼稳定脱壳穿甲杆", "pen": 68, "ergo": 32, "moa": 0.1, "color": Color(0.36, 0.38, 0.40), "desc": "超高速电磁轨道狙击武器（超远射程 16），以极高初速发射实体钨合金尾翼稳定脱壳长杆穿甲弹（6级顶级穿深），膛口抛离三瓣铝制弹托，右键开启光学狙击镜大幅拉远战术观瞄视距。"},
	"arm_flamer": {"name": "FT-20 燃烧弹投射器", "slot": "arm", "gw": 2, "gh": 1, "w": 7, "v": 1400, "rar": 2, "weapon": "flamer", "dmg": 4.5, "rate": 20.0, "spread": 16.0, "speed": 16.0, "range": 5.0, "reach_m": 9.0, "caliber": "40mm 增压铝热凝固汽油钢壳弹", "pen": 32, "ergo": 60, "moa": 16.0, "color": Color(0.72, 0.34, 0.16), "desc": "高压速射燃烧弹投射器（近距射程 5），连续发射装填铝热凝固汽油胶体的穿孔钢壳实体燃烧弹丸，近距贯穿并引燃密集集群目标。"},
	"arm_laser": {"name": "LZ-42 电磁线圈步枪", "slot": "arm", "gw": 3, "gh": 1, "w": 4, "v": 1800, "rar": 2, "weapon": "laser", "dmg": 42.0, "rate": 1.8, "cost": 1.60, "spread": 0.32, "speed": 96.0, "range": 13.0, "reach_m": 39.0, "caliber": "9×68mm 钨芯尾翼稳定钢针弹", "pen": 46, "ergo": 78, "moa": 0.2, "color": Color(0.40, 0.44, 0.47), "desc": "多级异步感应线圈精确射手步枪（4级钨芯穿深，远距射程 13），电磁加速发射实体钨钢尾翼穿甲长针，初速极高、弹道平直且人机工效优异。"},
	"arm_mg": {"name": "G-36 转管机炮", "slot": "arm", "gw": 2, "gh": 1, "w": 5, "v": 300, "rar": 0, "weapon": "mg", "dmg": 9.0, "rate": 9.0, "spread": 5.0, "speed": 48.0, "range": 10.0, "reach_m": 30.0, "caliber": "12.7×108mm B-32 穿甲燃烧弹", "pen": 28, "ergo": 72, "moa": 4.2, "color": Color(0.6, 0.6, 0.549), "desc": "打捞团标配的 12.7mm 三管旋转速射机炮（3级穿深，标准射程 10），人机工效高、供弹可靠，适合常规巡逻自卫。"},
	"arm_shotgun": {"name": "SG-7 重型霰弹枪", "slot": "arm", "gw": 2, "gh": 1, "w": 6, "v": 800, "rar": 1, "weapon": "shotgun", "dmg": 8.0, "pellets": 7, "rate": 1.6, "spread": 20.0, "speed": 40.0, "range": 7.0, "reach_m": 16.0, "caliber": "23×75mmR 8.5mm 鹿弹 (7粒)", "pen": 14, "ergo": 68, "moa": 18.0, "color": Color(0.702, 0.451, 0.251), "desc": "23mm 军用自动霰弹枪（射程 7），单发喷射 7 枚重型铅合金鹿弹（1级穿深），对无甲软目标具有毁灭性贴脸肉伤。"},
	"arm_sniper": {"name": "M99 精确狙击步枪", "slot": "arm", "gw": 4, "gh": 1, "w": 8, "v": 2100, "rar": 2, "weapon": "sniper", "scope": true, "recon": 2.0, "tags": ["侦察"], "dmg": 78.0, "rate": 0.65, "spread": 0.25, "speed": 145.0, "range": 22.0, "reach_m": 62.0, "caliber": "12.7×99mm M33 比赛级穿甲弹", "pen": 54, "ergo": 48, "moa": 0.3, "color": Color(0.36, 0.40, 0.34), "desc": "高精度大口径重型狙击步枪，搭载高倍光学狙击镜（右键开镜获得极远视野并将镜外遮蔽），射程 22，5 级钨钢穿深。"},
	"arm_amr": {"name": "NTW-20 反器材炮", "slot": "arm", "gw": 4, "gh": 1, "w": 13, "v": 4200, "rar": 3, "weapon": "sniper", "scope": true, "recon": 3.0, "tags": ["侦察"], "dmg": 150.0, "rate": 0.52, "spread": 0.14, "speed": 170.0, "range": 26.0, "reach_m": 76.0, "caliber": "20×110mm 高爆穿甲反器材弹", "pen": 66, "ergo": 30, "moa": 0.15, "color": Color(0.34, 0.36, 0.40), "desc": "重型 20mm 长管反器材狙击炮，搭载长焦光学狙击镜（右键开镜极远距离索敌），单发重创并贯穿 6 级重甲甲壳。"},
	# ---- 30 款现实军武机甲化手臂武器 ----
	"arm_rh120": {"name": "L55-120 莱茵金属 120mm 长管滑膛坦克炮", "slot": "arm", "gw": 4, "gh": 1, "w": 16, "v": 4600, "rar": 3, "weapon": "cannon", "dmg": 96.0, "rate": 0.65, "spread": 1.00, "speed": 36.0, "range": 18.0, "reach_m": 54.0, "caliber": "120×570mm Rh-120 尾翼稳定脱壳穿甲弹", "pen": 66, "ergo": 34, "moa": 1.00, "color": Color(0.302, 0.329, 0.271), "desc": "机甲化豹2A7主炮总成，还原楔形间隙复合炮盾、三段玻纤隔热护套、偏心抽烟器、MRS炮口基准镜与外挂MG3同轴机枪箱。（6级穿深，射程 18）"},
	"arm_2a46": {"name": "2A46-125 突破型 125mm 自动装填滑膛炮", "slot": "arm", "gw": 4, "gh": 1, "w": 15, "v": 4400, "rar": 3, "weapon": "cannon", "dmg": 92.0, "rate": 0.68, "spread": 1.10, "speed": 35.0, "range": 17.0, "reach_m": 51.0, "caliber": "125×575mm 2A46M 滑膛脱壳穿甲弹", "pen": 64, "ergo": 33, "moa": 1.10, "color": Color(0.275, 0.314, 0.247), "desc": "参照T-90M突破型主炮机甲化，配备4S23“化石”反应装甲防盾、五段铝皮抱箍隔热套筒、尾舱抛壳窗与松树-U热像仪。（6级穿深，射程 17）"},
	"arm_m68": {"name": "M68-105 斯崔克顶置式 105mm 线膛突击炮", "slot": "arm", "gw": 4, "gh": 1, "w": 13, "v": 3800, "rar": 2, "weapon": "cannon", "dmg": 72.0, "rate": 0.75, "spread": 1.20, "speed": 34.0, "range": 16.0, "reach_m": 48.0, "caliber": "105×617mmR M68 线膛破甲弹", "pen": 60, "ergo": 36, "moa": 1.20, "color": Color(0.400, 0.365, 0.302), "desc": "汲取M1128机动火炮系统无人炮舱构型，集成后置转轮自动装弹鼓、风琴橡胶防尘罩与多孔胡椒瓶制退器。（5级穿深，射程 16）"},
	"arm_ags152": {"name": "AGS-152 折面隐身水冷 152mm 舰载主炮舱", "slot": "arm", "gw": 4, "gh": 1, "w": 16, "v": 4800, "rar": 3, "weapon": "cannon", "dmg": 100.0, "rate": 0.65, "spread": 0.90, "speed": 38.0, "range": 18.0, "reach_m": 54.0, "caliber": "152mm AGS 水冷制导高爆弹", "pen": 68, "ergo": 32, "moa": 0.90, "color": Color(0.322, 0.345, 0.365), "desc": "融合朱姆沃尔特级AGS与博福斯隐身舰炮设计，采用四截面雷达散射折角炮塔壳、双紫铜水冷循环管与双室舰炮制退器。（6级穿深，射程 18）"},
	"arm_cg84": {"name": "CG84-X2 卡尔·古斯塔夫 M4 双联 84mm 无后坐力炮", "slot": "arm", "gw": 3, "gh": 1, "w": 9, "v": 3100, "rar": 2, "weapon": "launcher", "dmg": 70.0, "rate": 0.9, "spread": 1.50, "speed": 30.0, "range": 12.0, "reach_m": 36.0, "caliber": "84×246mmR 卡尔·古斯塔夫 串联破甲弹", "pen": 58, "ergo": 40, "moa": 1.50, "color": Color(0.290, 0.318, 0.263), "desc": "萨博M4碳纤缠绕无后坐力炮双联机甲化挂架，具备外扩文丘里尾喷口、FCD-558智能火控盒与外侧4发串联破甲备弹架。（5级穿深，射程 12）"},
	"arm_gau8": {"name": "GAU-8/30 复仇者七管 30mm 液压加特林机炮", "slot": "arm", "gw": 4, "gh": 1, "w": 15, "v": 4700, "rar": 3, "weapon": "autocannon", "dmg": 19.0, "rate": 10.5, "spread": 2.60, "speed": 72.0, "range": 13.0, "reach_m": 39.0, "caliber": "30×173mm GAU-8 贫铀穿甲弹", "pen": 52, "ergo": 42, "moa": 2.40, "color": Color(0.286, 0.306, 0.325), "desc": "将A-10攻击机传奇七管30mm贫铀穿甲转管炮完整浓缩于机械臂，含后置横置无链大弹鼓、双闭环输退弹道与双液压驱动马达。（5级穿深，射程 13）"},
	"arm_m242": {"name": "M242-25 大毒蛇 25mm 双路供弹链式机炮", "slot": "arm", "gw": 3, "gh": 1, "w": 9, "v": 2900, "rar": 2, "weapon": "autocannon", "dmg": 20.0, "rate": 6, "spread": 1.60, "speed": 76.0, "range": 14.0, "reach_m": 42.0, "caliber": "25×137mm M242 脱壳穿甲弹", "pen": 46, "ergo": 46, "moa": 1.50, "color": Color(0.388, 0.353, 0.294), "desc": "布雷德利步战车主力外动力链式自动炮，配备上下双层穿甲/高爆独立供弹箱、驱动电机鼓、纵向散热槽重枪管与开叉消焰器。（4级穿深，射程 14）"},
	"arm_2a72": {"name": "2A72-30 巴赫恰桁架稳管 30mm 自动炮", "slot": "arm", "gw": 3, "gh": 1, "w": 10, "v": 3100, "rar": 2, "weapon": "autocannon", "dmg": 21.0, "rate": 5.8, "spread": 1.80, "speed": 78.0, "range": 14.0, "reach_m": 42.0, "caliber": "30×165mm 2A72 穿甲弹", "pen": 48, "ergo": 45, "moa": 1.70, "color": Color(0.271, 0.310, 0.247), "desc": "俄系战车最具辨识度的空间三角形钢桁架稳管30mm自动炮，整合根部波纹复进簧套筒、PKTM并列机枪与双锥切槽制退器。（4级穿深，射程 14）"},
	"arm_phalanx": {"name": "MK15-20 密集阵 Block 1B 雷达近防炮系统", "slot": "arm", "gw": 4, "gh": 1, "w": 15, "v": 4650, "rar": 3, "weapon": "autocannon", "dmg": 18.0, "rate": 13, "spread": 3.40, "speed": 80.0, "range": 12.0, "reach_m": 36.0, "caliber": "20×102mm M61A1 脱壳穿甲弹", "pen": 30, "ergo": 50, "moa": 3.20, "color": Color(0.329, 0.353, 0.373), "desc": "舰载终极近程防御系统机甲化移植，主炮箱正上方耸立标志性海雾灰16棱硬表面搜索跟踪雷达塔、侧置HDTI红外吊舱、腹下大弹鼓与6管M61A2火神炮。（3级穿深，射程 12）"},
	"arm_bofors40": {"name": "L70-40 博福斯顶置弹夹 40mm 自动高炮", "slot": "arm", "gw": 4, "gh": 1, "w": 13, "v": 4100, "rar": 3, "weapon": "autocannon", "dmg": 40.0, "rate": 3.2, "spread": 0.90, "speed": 84.0, "range": 16.0, "reach_m": 48.0, "caliber": "40×365mmR 博福斯 3P 空炸弹", "pen": 58, "ergo": 40, "moa": 0.90, "color": Color(0.298, 0.325, 0.267), "desc": "传奇博福斯40毫米L/70高平两用自动炮，保留标志性顶置梯形供弹漏斗与外露黄铜桥夹、3P近炸编程线圈及锥形喇叭口消焰筒。（5级穿深，射程 16）"},
	"arm_m82": {"name": "M82-35 巴雷特机甲放大版 35mm 反器材狙击炮", "slot": "arm", "gw": 4, "gh": 1, "w": 9, "v": 3400, "rar": 2, "weapon": "sniper", "scope": true, "recon": 2.0, "tags": ["侦察"], "dmg": 92.0, "rate": 0.75, "spread": 0.24, "speed": 150.0, "range": 20.0, "reach_m": 60.0, "caliber": "12.7×99mm M33 比赛级穿甲弹", "pen": 58, "ergo": 46, "moa": 0.30, "color": Color(0.278, 0.294, 0.310), "desc": "将巴雷特M82A1按机甲尺度重构为35mm精密反器材步枪，采用上下分体冲压机匣、拉机柄抛壳窗、双排散热孔护木、前倾压筋弹匣、中置BORS狙击镜与V形箭头制退器。（5级穿深，射程 20）"},
	"arm_ntw57": {"name": "NTW-57 丹尼尔侧插弹匣 57mm 远射反装甲枪", "slot": "arm", "gw": 4, "gh": 1, "w": 12, "v": 4150, "rar": 3, "weapon": "sniper", "scope": true, "recon": 3.0, "tags": ["侦察"], "dmg": 135.0, "rate": 0.6, "spread": 0.18, "speed": 168.0, "range": 21.0, "reach_m": 63.0, "caliber": "20×110mm NTW 高爆穿甲弹", "pen": 68, "ergo": 30, "moa": 0.18, "color": Color(0.392, 0.357, 0.290), "desc": "源自南非NTW-20重型反器材系统，拥有全长下摇架缓冲滑轨、水平外侧横插重型弹匣、管式防撞提把瞄具护框与超长重枪管。（6级穿深，射程 21）"},
	"arm_m45": {"name": "M45-50X4 勃朗宁四联装机甲防空重机枪塔", "slot": "arm", "gw": 4, "gh": 1, "w": 12, "v": 3300, "rar": 2, "weapon": "mg", "dmg": 15.0, "rate": 12, "spread": 3.00, "speed": 64.0, "range": 12.0, "reach_m": 36.0, "caliber": "12.7×99mm M2HB 穿甲燃烧弹", "pen": 36, "ergo": 48, "moa": 3.00, "color": Color(0.294, 0.322, 0.263), "desc": "致敬经典M45“绞肉机”四联装勃朗宁M2HB防空机枪座，配备切角防盾、2×2四联打孔套筒重枪管、十字稳管箍与外挂双层墓碑弹药箱。（3级穿深，射程 12）"},
	"arm_aa12": {"name": "AA12-40 恒定后坐弹鼓全自动 40mm 破片霰弹炮", "slot": "arm", "gw": 3, "gh": 1, "w": 9, "v": 3000, "rar": 2, "weapon": "shotgun", "dmg": 7.0, "pellets": 8, "rate": 3, "spread": 12.00, "speed": 42.0, "range": 7.0, "reach_m": 21.0, "caliber": "FRAG-12 40mm 破片霰弹 (8粒)", "pen": 18, "ergo": 58, "moa": 11.00, "color": Color(0.275, 0.290, 0.306), "desc": "以AA-12全自动战斗霰弹枪为蓝本放大的40mm高爆破片霰弹武器，含一体式恒定后坐方匣、20发腹下圆盘弹鼓、内嵌战术灯与皇冠破门齿。（2级穿深，射程 7）"},
	"arm_ks60": {"name": "KS-60 截短高炮管 60mm 线膛箭霰弹镇暴重枪", "slot": "arm", "gw": 3, "gh": 1, "w": 8, "v": 2850, "rar": 2, "weapon": "shotgun", "dmg": 64.0, "rate": 1.6, "spread": 4.00, "speed": 44.0, "range": 6.0, "reach_m": 18.0, "caliber": "23×75mmR 线膛箭霰弹", "pen": 42, "ergo": 54, "moa": 4.00, "color": Color(0.302, 0.282, 0.247), "desc": "延续苏式KS-23用高射炮管改制霰弹枪的暴力哲学，采用上置线膛重管、下置全长管式弹仓、双导杆液压泵动护木与外侧5发备弹鞍架。（4级穿深，射程 6）"},
	"arm_tow2b": {"name": "TOW-2B 陶式双联装重型攻顶反坦克导弹箱", "slot": "arm", "gw": 4, "gh": 1, "w": 14, "v": 4300, "rar": 3, "weapon": "launcher", "dmg": 145.0, "rate": 0.55, "spread": 0.50, "speed": 60.0, "range": 19.0, "reach_m": 57.0, "caliber": "BGM-71F 陶式攻顶反坦克导弹", "pen": 70, "ergo": 36, "moa": 0.50, "color": Color(0.396, 0.361, 0.298), "desc": "布雷德利战车侧面双联陶式反坦克导弹箱机甲化重构，呈现前上方掀开式防爆护盖与双侧液压撑杆、前后贯通肋纹发射筒、攻顶探杆导弹锥头与TAS-4热像舱。（6级穿深，射程 19）"},
	"arm_kornet": {"name": "9M133-X4 短号-EM 四联装激光驾束导弹架", "slot": "arm", "gw": 4, "gh": 1, "w": 15, "v": 4550, "rar": 3, "weapon": "launcher", "dmg": 150.0, "rate": 0.6, "spread": 0.50, "speed": 62.0, "range": 20.0, "reach_m": 60.0, "caliber": "9M133M-2 短号激光驾束导弹", "pen": 72, "ergo": 35, "moa": 0.50, "color": Color(0.278, 0.314, 0.251), "desc": "俄制短号-EM重型反装甲导弹开放式四联装桁架，由三道镂空钢框抱持全长外露的4具螺旋玻纤发射筒与厚橡胶防撞端箍，顶置1PN79M热像制导头。（6级穿深，射程 20）"},
	"arm_lau61": {"name": "LAU-61 九头蛇十九管 70mm 蜂窝航空火箭巢", "slot": "arm", "gw": 4, "gh": 1, "w": 12, "v": 3650, "rar": 2, "weapon": "launcher", "dmg": 27.0, "rate": 7, "spread": 4.60, "speed": 58.0, "range": 15.0, "reach_m": 45.0, "caliber": "70mm 九头蛇航空火箭弹", "pen": 40, "ergo": 44, "moa": 4.40, "color": Color(0.298, 0.322, 0.267), "desc": "阿帕奇武装直升机经典19管70毫米航空火箭发射巢，采用北约BRU上置挂梁与内侧耳轴转换臂吊挂全长连续圆筒铝壳、19孔蜂窝前端面与缩径尾喷罩。（4级穿深，射程 15）"},
	"arm_m299": {"name": "M299-HF4 长弓地狱火四联装滑轨重型导弹架", "slot": "arm", "gw": 4, "gh": 1, "w": 14, "v": 4750, "rar": 3, "weapon": "launcher", "dmg": 165.0, "rate": 0.55, "spread": 0.40, "speed": 65.0, "range": 21.0, "reach_m": 63.0, "caliber": "AGM-114L 长弓地狱火导弹", "pen": 74, "ergo": 34, "moa": 0.40, "color": Color(0.271, 0.286, 0.302), "desc": "采用真实M299全开放式中央工字主梁与四条独立滑轨，4枚AGM-114L毫米波制导“地狱火”导弹从头锥到X形十字尾翼100%全长外露悬挂。（6级穿深，射程 21）"},
	"arm_ram116": {"name": "MK49-RAM 海拉姆十一联装滚体近防导弹箱", "slot": "arm", "gw": 4, "gh": 1, "w": 15, "v": 4600, "rar": 3, "weapon": "launcher", "dmg": 72.0, "rate": 2, "spread": 0.80, "speed": 70.0, "range": 17.0, "reach_m": 51.0, "caliber": "RIM-116 滚体近防导弹", "pen": 55, "ergo": 42, "moa": 0.80, "color": Color(0.333, 0.357, 0.376), "desc": "美德联合研制Mk 49舰载近防导弹发射箱机甲化版本，采用八角切边装甲前框、4+3+4交错11管发射阵、尾部泄压百叶与双ESM射频干涉仪角天线。（5级穿深，射程 17）"},
	"arm_m777": {"name": "M777-155 超轻型钛合金桁架 155mm 榴弹炮", "slot": "arm", "gw": 4, "gh": 1, "w": 16, "v": 4850, "rar": 3, "weapon": "cannon", "dmg": 140.0, "rate": 0.48, "spread": 0.70, "speed": 44.0, "range": 22.0, "reach_m": 66.0, "caliber": "155mm M777A2 神剑制导榴弹", "pen": 62, "ergo": 30, "moa": 0.70, "color": Color(0.322, 0.341, 0.294), "desc": "将BAE M777钛合金155毫米榴弹炮重构为重型曲直两用炮臂，具备断隔螺式炮闩、上置双筒液气平衡机、雪橇式摇架与宽翼双室制退器+炮口牵引环。（6级穿深，射程 22）"},
	"arm_tos220": {"name": "TOS-220 “烈日”六联装 220mm 装甲温压火箭炮", "slot": "arm", "gw": 4, "gh": 1, "w": 17, "v": 4900, "rar": 3, "weapon": "cannon", "dmg": 150.0, "rate": 0.46, "spread": 1.00, "speed": 46.0, "range": 14.0, "reach_m": 42.0, "caliber": "220mm TOS-1A 温压火箭弹", "pen": 60, "ergo": 28, "moa": 1.00, "color": Color(0.282, 0.318, 0.251), "desc": "一体贯通式TOS-1A“烈日”重型喷火坦克装甲定向器箱，3×2排列6管220毫米温压火箭弹，箱顶全长铺满5块Kontakt-5反应装甲瓦，侧面设防爆压筋。（5级穿深，射程 14）"},
	"arm_rpo93": {"name": "RPO-93X4 “大黄蜂”四联装 93mm 云爆突击包", "slot": "arm", "gw": 3, "gh": 1, "w": 10, "v": 3350, "rar": 2, "weapon": "launcher", "dmg": 100.0, "rate": 0.8, "spread": 1.40, "speed": 38.0, "range": 11.0, "reach_m": 33.0, "caliber": "93mm RPO-M 云爆弹", "pen": 55, "ergo": 40, "moa": 1.40, "color": Color(0.302, 0.325, 0.263), "desc": "采用开放式十字承力桁架与三道铝合金偏心快拆抱箍锁紧全长外露的4具93mm玻纤云爆筒，上排两具开盖待发露出黄铜弹头，下排两具保留十字密封盖。（5级穿深，射程 11）"},
	"arm_m10flm": {"name": "M10-FLM “打火机”装甲高压凝固汽油喷射器", "slot": "arm", "gw": 3, "gh": 1, "w": 13, "v": 3600, "rar": 2, "weapon": "flamer", "dmg": 8.0, "rate": 12, "spread": 16.00, "speed": 16.0, "range": 5.0, "reach_m": 15.0, "caliber": "40mm 增压凝固汽油弹", "pen": 30, "ergo": 60, "moa": 16.00, "color": Color(0.306, 0.329, 0.267), "desc": "参照美军M132“Zippo”装甲喷火车的M10-8高压液火发射器，腹下并列凝固汽油罐与高压氮气推进钢瓶，配穿孔隔热套与六杆防撞点火稳焰笼。（3级穿深，射程 5）"},
	"arm_mk108": {"name": "MK108-4X 四联装 30mm 短管薄壳高爆突击炮", "slot": "arm", "gw": 3, "gh": 1, "w": 13, "v": 3750, "rar": 2, "weapon": "autocannon", "dmg": 21.0, "rate": 6, "spread": 2.00, "speed": 60.0, "range": 9.0, "reach_m": 27.0, "caliber": "30×90mmR MK108 薄壳高爆弹", "pen": 36, "ergo": 46, "moa": 1.80, "color": Color(0.282, 0.302, 0.322), "desc": "以二战末期著名的MK 108“气锤”30毫米短管重机炮为原型的四联近距重火力吊舱，配顶置双压缩空气装填瓶、倾角炮盾与四根粗短锥口身管。（3级穿深，射程 9）"},
	"arm_pb09": {"name": "PB-09 火药燃气液压复合攻城打桩机", "slot": "arm", "gw": 4, "gh": 1, "w": 16, "v": 4700, "rar": 3, "weapon": "melee", "dmg": 170.0, "rate": 0.8, "cost": 0.30, "spread": 3.00, "speed": 30.0, "range": 3.0, "reach_m": 9.0, "caliber": "PB-09 火药燃气打桩钉", "pen": 78, "ergo": 28, "moa": 3.00, "color": Color(0.345, 0.322, 0.271), "desc": "机甲硬核近战巅峰——结合海上液压打桩锤与6室重型空包弹左轮燃气击发室，沿重型工字钢滑床将实心钨铬八棱穿甲桩瞬间轰入目标核心。（6级穿深，射程 3）"},
	"arm_hc40": {"name": "HC-40 创世纪工程拆解级液压鹰嘴破甲剪", "slot": "arm", "gw": 4, "gh": 1, "w": 15, "v": 4400, "rar": 3, "weapon": "melee", "dmg": 150.0, "rate": 0.9, "cost": 0.30, "spread": 2.60, "speed": 30.0, "range": 3.0, "reach_m": 9.0, "caliber": "HC-40 液压鹰嘴剪切刃", "pen": 74, "ergo": 30, "moa": 2.60, "color": Color(0.369, 0.337, 0.275), "desc": "源自万吨级废钢与舰船拆解液压鹰嘴剪，具备黄铜齿圈360°行星回转腕、上下双高压油缸、可更换镀铬直刃刀块与鹰嘴钩状咬合上下颚。（6级穿深，射程 3）"},
	"arm_cs88": {"name": "CS-88 威猛开沟机级碳化钨截齿装甲链锯臂", "slot": "arm", "gw": 4, "gh": 1, "w": 14, "v": 4350, "rar": 3, "weapon": "melee", "dmg": 23.0, "rate": 6, "cost": 0.30, "spread": 3.20, "speed": 40.0, "range": 4.0, "reach_m": 12.0, "caliber": "CS-88 碳化钨截齿链锯", "pen": 48, "ergo": 34, "moa": 3.00, "color": Color(0.306, 0.325, 0.275), "desc": "摒弃卡通薄片电锯，参照军用硬岩战壕开沟机打造：外置径向液压马达驱动1.6米锰钢导板，全周排布25节重型链座与斜置镀铬碳化钨截齿锥。（4级穿深，射程 4）"},
	"arm_th60": {"name": "TH-60 克虏伯 HB-7000 箱式液压碎岩破甲锤", "slot": "arm", "gw": 3, "gh": 1, "w": 15, "v": 4100, "rar": 2, "weapon": "melee", "dmg": 125.0, "rate": 0.95, "cost": 0.30, "spread": 2.80, "speed": 30.0, "range": 3.0, "reach_m": 9.0, "caliber": "TH-60 箱式液压碎岩锤", "pen": 76, "ergo": 28, "moa": 2.80, "color": Color(0.341, 0.325, 0.278), "desc": "将7吨级矿山与工事拆除液压破碎锤移植上臂，包含挖掘机双耳转接臂、4根外露贯通拉杆、橡胶减振衬垫、氮气蓄能器与粗壮扁楔合金钎杆。（6级穿深，射程 3）"},
	"arm_miclic": {"name": "M58-CLC 突击破障车火箭爆破索与反应装甲盾臂", "slot": "arm", "gw": 4, "gh": 1, "w": 17, "v": 4800, "rar": 3, "weapon": "launcher", "dmg": 150.0, "rate": 0.65, "spread": 1.20, "speed": 36.0, "range": 10.0, "reach_m": 30.0, "caliber": "M58 MICLIC 火箭爆破索", "pen": 65, "ergo": 36, "moa": 1.20, "color": Color(0.384, 0.349, 0.286), "desc": "集重装防盾与远程爆破清障于一体：前段敞口对开舱盖储药槽显露5圈盘卷C-4导爆索，龙门仰角滑轨搭载MK22固体牵引火箭，外侧披挂ERA破城巨盾。（6级穿深，射程 10）"},
}

const AMMO := {}

const SKILLS := {}

const ITEMS := {
	# ---- food ----
	"can_food": {"name": "罐头肉", "cat": "food", "w": 1.0, "v": 60, "rar": 0, "desc": "密封完好的战前午餐肉罐头，食堂烹制出击餐点的基础食材。"},
	"biscuit": {"name": "压缩饼干", "cat": "food", "w": 0.5, "v": 35, "rar": 0, "desc": "高热量真空军用口粮，虽然口感干硬但保质期极长。"},
	"water_tab": {"name": "净水片", "cat": "food", "w": 0.2, "v": 45, "rar": 0, "desc": "二氧化氯高效净水药片，可将地表污水转化为安全饮用水。"},
	"coffee": {"name": "旧世界咖啡豆", "cat": "food", "w": 0.6, "v": 260, "rar": 2, "desc": "铝箔真空包装的烘焙咖啡豆，在艇员与黑市商人中极为抢手。"},
	# ---- misc ----
	"circuit": {"name": "电路板", "cat": "misc", "w": 0.5, "v": 90, "rar": 1, "desc": "从工业终端拆下的多层印刷电路板，飞艇设施升级与研究的关键电子件。"},
	"wire": {"name": "铜线卷", "cat": "misc", "w": 1.5, "v": 70, "rar": 0, "desc": "无氧纯铜绕线卷，整备电力管线与电机维护的常备耗材。"},
	"bolts": {"name": "螺栓", "cat": "misc", "w": 0.8, "v": 25, "rar": 0, "desc": "高强度合金标准紧固件，机甲外甲铆接与舱室修缮的基础零件。"},
	"hdd": {"name": "旧世界硬盘", "cat": "misc", "w": 0.4, "v": 380, "rar": 2, "desc": "存有战前科研图纸与工业数据的磁存储阵列，研究室破译技术的核心素材。"},
	"toy": {"name": "发条玩具", "cat": "misc", "w": 0.3, "v": 160, "rar": 1, "desc": "拧紧发条仍能蹦跳的铁皮青蛙，艇上孩子们最喜欢的礼物。"},
	"chitin": {"name": "虫甲壳", "cat": "misc", "w": 1.0, "v": 80, "rar": 0, "desc": "深渊异体褪下或击碎的硬化几丁质甲壳，可用于合成轻质复合装甲。"},
	"bug_crystal": {"name": "虫晶", "cat": "misc", "w": 0.3, "v": 450, "rar": 3, "desc": "凝聚高浓度生物能量的深渊结晶体，高阶能源研究与反应炉制造的核心材料。"},
	# ---- use ----
	"fuel_cell": {"name": "燃料电池", "cat": "use", "w": 1.0, "v": 120, "rar": 1, "desc": "便携式一次性能源包（快捷键 1），战地使用时立即恢复 50 点机甲能源。"},
	"repair_kit": {"name": "维修包", "cat": "use", "w": 1.2, "v": 140, "rar": 1, "desc": "纳米修补凝胶喷罐（快捷键 2），战地使用时恢复 45 点结构并修复 50% 受损部位。"},
	"beacon": {"name": "呼叫信标", "cat": "use", "w": 0.5, "v": 300, "rar": 2, "desc": "加密高频导航信标（快捷键 T），在战区任意位置直接呼叫运输艇紧急撤离。"},
	# ---- money ----
	"credit_s": {"name": "信用芯片(小)", "cat": "money", "w": 0.05, "v": 100, "rar": 1, "desc": "不记名加密小额储值芯片，撤离带回或出售可兑换 100 信用点。"},
	"credit_l": {"name": "信用芯片(大)", "cat": "money", "w": 0.05, "v": 500, "rar": 2, "desc": "高权限大额结算芯片，撤离带回或出售可兑换 500 信用点。"},
	"gold": {"name": "金条", "cat": "money", "gw": 2, "gh": 1, "w": 1.0, "v": 1200, "rar": 3, "desc": "印有旧世界央行钢印的足金锭，黑市硬通货，估值高达 1200 信用点。"},
		# ---- 消耗品 ----
		"sonic_decoy": {"name": "声波诱饵信标", "cat": "use", "w": 0.8, "v": 260, "rar": 2, "script": "res://scripts/modules/item_decoy.gd", "desc": "战术声波发生器（快捷键 3），吸引14米内异体脱离机甲并在2.2秒后引爆。"},
		"extract_flare": {"name": "撤离引导烟幕", "cat": "use", "w": 0.6, "v": 220, "rar": 1, "script": "res://scripts/modules/item_flare.gd", "desc": "高压干扰烟幕罐（快捷键 4），使10米内异体失明减速并立即缩短50%撤离读秒。"},
		"energy_rod": {"name": "高能电池棒", "cat": "use", "w": 1.4, "v": 380, "rar": 2, "script": "res://scripts/modules/item_battery.gd", "desc": "军规超导电容棒（快捷键 5），立即回充80点机甲能源并清除断电惩罚。"},
		"coolant_pack": {"name": "冷却剂罐", "cat": "use", "w": 1.2, "v": 240, "rar": 1, "script": "res://scripts/modules/item_coolant.gd", "desc": "液氮循环冷却罐（快捷键 6），将冷却液压入动力炉回路，20 秒内整机耗电减半。"},
		"extract_barrier": {"name": "撤离屏障", "cat": "use", "w": 2.0, "v": 320, "rar": 2, "script": "res://scripts/modules/item_barrier.gd", "desc": "便携式力场发生器（快捷键 7），展开6秒防护力场并持续震退5.5米内逼近的异体。"},
		"surge_cell": {"name": "超频电芯", "cat": "use", "w": 1.3, "v": 400, "rar": 2, "script": "res://scripts/modules/item_surge.gd", "desc": "高能脉冲电芯（快捷键 8），强行灌入超额电流立即恢复 85 点机甲能源，随后 10 秒回路过热耗能上升。"},
}

const LOOT_TABLES := {}

const SHOP := ["sonic_decoy", "extract_flare", "energy_rod", "coolant_pack", "extract_barrier", "surge_cell",
	"arm_hmg", "arm_gatling", "arm_ac30", "arm_slug", "arm_cannon", "arm_rail", "arm_sniper", "arm_amr",
	"legs_tread_light", "legs_tread_heavy", "legs_tread_siege",
	"legs_biped_scout", "legs_biped_assault", "legs_titan",
	"legs_quad_hound", "legs_quad_mammoth",
	"legs_hex_ant", "legs_hex_colossus",
	"back_rack", "back_rocket", "back_vls",
	"core_assault", "core_command", "core_fortress",
	"gen_diesel", "gen_hfc", "gen_turbine"]

const SFX := {}

const RAID_SCRIPTS := ["res://scripts/modules/ops_consumables.gd"]

const EXTEND := {
	"LOOT_TABLES": {
		"military": {"pool": {"sonic_decoy": 12, "energy_rod": 10, "coolant_pack": 8, "surge_cell": 6}},
		"supply": {"pool": {"energy_rod": 6, "coolant_pack": 5, "surge_cell": 3}},
		"tool": {"pool": {"sonic_decoy": 5, "extract_flare": 6, "extract_barrier": 4}},
	},
}

## 新消耗品按键登记
static func register(gd) -> void:
	gd._key("use_decoy", [KEY_3])
	gd._key("use_flare", [KEY_4])
	gd._key("use_battery", [KEY_5])
	gd._key("use_coolant", [KEY_6])
	gd._key("use_barrier", [KEY_7])
	gd._key("use_surge", [KEY_8])
