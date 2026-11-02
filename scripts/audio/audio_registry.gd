extends RefCounted
## 音频清单：音效 id、音乐槽及其播放参数（核心表）。启动时 GameData 把它与 data\ext 各文件的 SFX / MUSIC 常量合并，
## AudioManager 读合并后的表；没有登记的 id 照样能播，参数按前缀默认值。
##
## 文件约定（id 只用小写字母、数字、下划线）：
##   音效  res://assets/audio/sfx/<文件名>，条目的 files 逐个列出全部变体文件名：单个文件为 <id>.wav，
##         多个变体为 <id>_01.wav、<id>_02.wav……；每次播放随机挑一个，不连续重复。
##         没有登记的 id 按同样的命名查找（<id>.wav 与从 <id>_01.wav 起的连续编号，也认 .ogg），所以新音效只放文件即可播放。
##   音乐  res://assets/audio/music/<file>，没有登记的槽按 <slot>.ogg 查找（也认 .mp3 / .wav）
##   配音  res://assets/audio/voice/<voice_id>.mp3（也认 .ogg / .wav）
## 新文件放进约定路径、运行一次 godot --import 后即可播放；文件缺失时静默跳过。
## 全部登记文件的存在性由 godot --headless --path . -- --audio_manifest 列出。
##
## 音效条目字段：files 变体文件名列表、when 触发时机、vol 音量 dB、pitch 随机音高幅度、
##   gap 同一 id 两次播放的最小间隔（秒）、max 同时发声上限、bus 总线、d3 是否按世界位置定位、
##   unit / dist 3D 衰减的单位距离与最大距离（米）。未写的字段取 PREFIX 与 DEFAULT。
## 音乐槽字段：file 文件名、loop 是否循环、scene 播放场景。

const DEFAULT := {"bus": "SFX", "vol": 0.0, "pitch": 0.05, "gap": 0.0, "max": 6, "d3": true, "unit": 12.0, "dist": 70.0}

## 按 id 前缀的默认参数（取最长匹配）
const PREFIX := {
	"ui_": {"bus": "UI", "pitch": 0.0, "d3": false, "max": 4},
	"hub_": {"bus": "UI", "pitch": 0.0, "d3": false, "max": 3},
	"shop_": {"bus": "UI", "pitch": 0.0, "d3": false, "max": 3},
	"cargo_": {"bus": "SFX", "pitch": 0.03, "d3": false, "max": 3},
	"request_": {"bus": "UI", "pitch": 0.0, "d3": false, "max": 2},
	"loot_": {"d3": false, "max": 3, "pitch": 0.04},
	"wpn_": {"max": 8, "pitch": 0.06},
	"hit_": {"max": 6, "gap": 0.03, "pitch": 0.1},
	"bug_": {"max": 6, "pitch": 0.08},
	"step_": {"max": 4, "gap": 0.08, "pitch": 0.08, "vol": -4.0},
	"skill_": {"max": 3},
	"mech_": {"max": 3},
	"energy_": {"d3": false, "max": 2, "pitch": 0.0},
	"use_": {"d3": false, "max": 2},
	"drop_": {"d3": false, "max": 2, "pitch": 0.02},
	"extract_": {"d3": false, "max": 2, "pitch": 0.0},
	"transport_": {"unit": 18.0, "dist": 120.0, "max": 2, "pitch": 0.0},
	"nest_": {"max": 4},
}

const SFX := {
	# ---- 武器 ----
	"wpn_mg_fire": {"files": ["wpn_mg_fire_01.wav", "wpn_mg_fire_02.wav", "wpn_mg_fire_03.wav"], "when": "速射机炮每发射一发（mech.gd try_fire）"},
	"wpn_shotgun_fire": {"files": ["wpn_shotgun_fire_01.wav", "wpn_shotgun_fire_02.wav", "wpn_shotgun_fire_03.wav"], "when": "霰弹臂每轰一次（mech.gd try_fire）"},
	"wpn_flamer_ignite": {"files": ["wpn_flamer_ignite.wav"], "when": "火焰喷射器按下扳机开始喷射的瞬间（mech.gd try_fire）"},
	"wpn_flamer_loop": {"files": ["wpn_flamer_loop.wav"], "when": "火焰喷射器持续喷射时循环，松开扳机 0.15 秒后淡出（mech.gd）"},
	"wpn_laser_fire": {"files": ["wpn_laser_fire_01.wav", "wpn_laser_fire_02.wav", "wpn_laser_fire_03.wav"], "when": "聚焦激光每射击一次（mech.gd try_fire）"},
	"wpn_mg_reload": {"files": ["wpn_mg_reload.wav"], "when": "速射机炮开始换弹（mech.gd start_reload）"},
	"wpn_shotgun_reload": {"files": ["wpn_shotgun_reload.wav"], "when": "霰弹臂开始换弹（mech.gd start_reload）"},
	"wpn_flamer_reload": {"files": ["wpn_flamer_reload.wav"], "when": "火焰喷射器开始更换燃料罐（mech.gd start_reload）"},
	"wpn_laser_reload": {"files": ["wpn_laser_reload.wav"], "when": "聚焦激光开始更换电池（mech.gd start_reload）"},
	"wpn_reload_done": {"files": ["wpn_reload_done_01.wav", "wpn_reload_done_02.wav"], "when": "任一武器换弹完成（mech.gd _physics_process）"},
	"wpn_empty": {"files": ["wpn_empty_01.wav", "wpn_empty_02.wav"], "when": "最后一发打空、自动换弹前（mech.gd try_fire）", "gap": 0.2},
	# ---- 命中与爆炸 ----
	"hit_metal": {"files": ["hit_metal_01.wav", "hit_metal_02.wav", "hit_metal_03.wav", "hit_metal_04.wav"], "when": "子弹或激光打在墙体、废墟、容器、机甲等非生物表面（projectile.gd / raid.gd fire_laser）"},
	"hit_chitin": {"files": ["hit_chitin_01.wav", "hit_chitin_02.wav", "hit_chitin_03.wav", "hit_chitin_04.wav"], "when": "子弹或激光打在虫子或虫巢上（projectile.gd / raid.gd fire_laser）"},
	"hit_spit": {"files": ["hit_spit_01.wav", "hit_spit_02.wav"], "when": "酸液弹落地或命中（projectile.gd，hit_sfx 由 raid.gd spawn_spit 设定）", "gap": 0.05},
	"explosion": {"files": ["explosion_01.wav", "explosion_02.wav", "explosion_03.wav"], "when": "导弹、震地冲击、过热排放、诱饵无人机、虫巢爆炸（raid.gd explode）", "max": 4, "gap": 0.04, "unit": 20.0, "dist": 110.0},
	"mech_slam": {"files": ["mech_slam_01.wav", "mech_slam_02.wav"], "when": "履带冲撞、蛛足跃击落地造成范围伤害（mech.gd → raid.gd explode）", "max": 2},
	# ---- 底盘 ----
	"step_biped": {"files": ["step_biped_01.wav", "step_biped_02.wav", "step_biped_03.wav", "step_biped_04.wav"], "when": "双足每次落脚（mech.gd _footfall）"},
	"step_quad": {"files": ["step_quad_01.wav", "step_quad_02.wav", "step_quad_03.wav", "step_quad_04.wav"], "when": "四足每条腿落地（mech.gd _animate）", "vol": -6.0},
	"legs_tread_loop": {"files": ["legs_tread_loop.wav"], "when": "履带底盘全程循环，音量与音高随速度变化（mech.gd）", "max": 1, "pitch": 0.0},
	"legs_hover_loop": {"files": ["legs_hover_loop.wav"], "when": "悬浮底盘全程循环的推力嗡鸣，音高随速度升高（mech.gd）", "max": 1, "pitch": 0.0},
	"mech_land": {"files": ["mech_land_01.wav", "mech_land_02.wav"], "when": "推进冲刺、跃击等位移结束落地（mech.gd）", "max": 2},
	# ---- 技能（skill_<图标名>，新技能沿用图标名即可发声） ----
	"skill_dash": {"files": ["skill_dash_01.wav", "skill_dash_02.wav"], "when": "双足推进冲刺点火（mech.gd try_dash）"},
	"skill_ram": {"files": ["skill_ram.wav"], "when": "履带冲撞起步（mech.gd try_dash）"},
	"skill_leap": {"files": ["skill_leap.wav"], "when": "四足跃击起跳（mech.gd try_dash）"},
	"skill_blink": {"files": ["skill_blink_01.wav", "skill_blink_02.wav"], "when": "悬浮相位闪移（mech.gd try_dash）"},
	"skill_missile": {"files": ["skill_missile.wav"], "when": "蜂巢导弹齐射（mech.gd try_ability）"},
	"skill_shield": {"files": ["skill_shield.wav"], "when": "相位护盾展开（mech.gd try_ability）"},
	"skill_decoy": {"files": ["skill_decoy.wav"], "when": "诱饵无人机投放（mech.gd try_skill_e）"},
	"skill_overdrive": {"files": ["skill_overdrive.wav"], "when": "火力过载启动（mech.gd try_skill_e）"},
	"skill_quake": {"files": ["skill_quake.wav"], "when": "震地冲击（mech.gd try_skill_e）"},
	"skill_charge": {"files": ["skill_charge.wav"], "when": "应急充能（mech.gd try_skill_r）"},
	"skill_vent": {"files": ["skill_vent.wav"], "when": "过热排放（mech.gd try_skill_r）"},
	"skill_repair": {"files": ["skill_repair.wav"], "when": "纳米修复启动（mech.gd try_skill_r）"},
	"skill_denied": {"files": ["skill_denied.wav"], "when": "技能冷却中、能源不足或模块缺失时按下技能键（mech.gd）", "d3": false, "gap": 0.25, "max": 1},
	"shield_hit": {"files": ["shield_hit_01.wav", "shield_hit_02.wav", "shield_hit_03.wav"], "when": "护盾挡下一次伤害（mech.gd take_damage）", "gap": 0.06, "max": 3},
	"shield_down": {"files": ["shield_down.wav"], "when": "相位护盾持续时间结束（mech.gd _physics_process）", "max": 1},
	# ---- 机甲状态 ----
	"mech_hurt": {"files": ["mech_hurt_01.wav", "mech_hurt_02.wav", "mech_hurt_03.wav"], "when": "机甲受到伤害（mech.gd take_damage）", "d3": false, "gap": 0.12, "max": 2},
	"mech_part_lost": {"files": ["mech_part_lost.wav"], "when": "某个部位完好度归零（mech.gd take_damage）", "d3": false},
	"mech_destroyed": {"files": ["mech_destroyed.wav"], "when": "机甲瘫痪或结构损毁（mech.gd die）", "d3": false, "max": 1},
	"mech_vent": {"files": ["mech_vent.wav"], "when": "空投落地后起身排气（raid.gd _drop_impact）", "max": 1},
	"energy_low": {"files": ["energy_low.wav"], "when": "剩余能源跌破 45 秒（mech.gd _physics_process）"},
	"energy_emergency": {"files": ["energy_emergency.wav"], "when": "能源耗尽、进入应急模式的瞬间（mech.gd use_energy）"},
	"energy_alarm_loop": {"files": ["energy_alarm_loop.wav"], "when": "应急模式期间循环的告警（mech.gd），退出或瘫痪时停止", "max": 1, "vol": -6.0},
	"energy_restored": {"files": ["energy_restored.wav"], "when": "应急模式中恢复能源（mech.gd _physics_process）"},
	# ---- 消耗品（use_<物品 id>） ----
	"use_fuel_cell": {"files": ["use_fuel_cell.wav"], "when": "接入燃料电池（mech.gd use_item）"},
	"use_repair_kit": {"files": ["use_repair_kit.wav"], "when": "使用维修包（mech.gd use_item）"},
	"use_beacon": {"files": ["use_beacon.wav"], "when": "发射呼叫信标（raid.gd call_transport）"},
	"use_denied": {"files": ["use_denied.wav"], "when": "货舱里没有该消耗品、结构完好无需维修、运输机已在途（mech.gd use_item / raid.gd call_transport）", "gap": 0.2, "max": 1},
	# ---- 虫族（bug_<种类>_<动作>；敌人条目的 sfx 字段可改用别的种类前缀） ----
	"bug_ling_appear": {"files": ["bug_ling_appear_01.wav", "bug_ling_appear_02.wav", "bug_ling_appear_03.wav"], "when": "跳虫从地下爬出，或由闲逛转入追击（bug.gd）", "gap": 0.25, "max": 3},
	"bug_ling_windup": {"files": ["bug_ling_windup_01.wav", "bug_ling_windup_02.wav"], "when": "跳虫扑咬前摇（bug.gd _begin wind）"},
	"bug_ling_attack": {"files": ["bug_ling_attack_01.wav", "bug_ling_attack_02.wav", "bug_ling_attack_03.wav"], "when": "跳虫刃臂出手（bug.gd _strike）"},
	"bug_ling_hurt": {"files": ["bug_ling_hurt_01.wav", "bug_ling_hurt_02.wav", "bug_ling_hurt_03.wav"], "when": "跳虫受击（bug.gd take_damage）", "gap": 0.08, "max": 4},
	"bug_ling_death": {"files": ["bug_ling_death_01.wav", "bug_ling_death_02.wav", "bug_ling_death_03.wav"], "when": "跳虫死亡（bug.gd take_damage）", "max": 4},
	"bug_spitter_appear": {"files": ["bug_spitter_appear_01.wav", "bug_spitter_appear_02.wav"], "when": "酸液虫爬出或转入追击（bug.gd）", "gap": 0.3, "max": 2},
	"bug_spitter_windup": {"files": ["bug_spitter_windup_01.wav", "bug_spitter_windup_02.wav"], "when": "酸液虫喷吐前摇、炮口充能（bug.gd _begin wind）"},
	"bug_spitter_attack": {"files": ["bug_spitter_attack_01.wav", "bug_spitter_attack_02.wav", "bug_spitter_attack_03.wav"], "when": "酸液虫喷出酸液弹（bug.gd _strike）"},
	"bug_spitter_hurt": {"files": ["bug_spitter_hurt_01.wav", "bug_spitter_hurt_02.wav", "bug_spitter_hurt_03.wav"], "when": "酸液虫受击（bug.gd take_damage）", "gap": 0.08, "max": 4},
	"bug_spitter_death": {"files": ["bug_spitter_death_01.wav", "bug_spitter_death_02.wav"], "when": "酸液虫死亡（bug.gd take_damage）", "max": 3},
	"bug_beetle_appear": {"files": ["bug_beetle_appear_01.wav", "bug_beetle_appear_02.wav"], "when": "甲虫爬出或转入追击（bug.gd）", "gap": 0.4, "max": 2, "unit": 16.0},
	"bug_beetle_windup": {"files": ["bug_beetle_windup_01.wav", "bug_beetle_windup_02.wav"], "when": "甲虫高举破碎钳蓄力（bug.gd _begin wind）", "unit": 16.0},
	"bug_beetle_attack": {"files": ["bug_beetle_attack_01.wav", "bug_beetle_attack_02.wav"], "when": "甲虫砸下破碎钳（bug.gd _strike）", "unit": 16.0},
	"bug_beetle_hurt": {"files": ["bug_beetle_hurt_01.wav", "bug_beetle_hurt_02.wav", "bug_beetle_hurt_03.wav"], "when": "甲虫受击（bug.gd take_damage）", "gap": 0.1, "max": 3},
	"bug_beetle_death": {"files": ["bug_beetle_death_01.wav", "bug_beetle_death_02.wav"], "when": "甲虫死亡（bug.gd take_damage）", "max": 2, "unit": 16.0},
	"nest_loop": {"files": ["nest_loop.wav"], "when": "虫巢的鼓动声，机甲进入 42 米内时循环（nest.gd）", "max": 3, "unit": 8.0, "dist": 45.0, "pitch": 0.0},
	"nest_spawn": {"files": ["nest_spawn_01.wav", "nest_spawn_02.wav"], "when": "虫巢孵出一只虫子（nest.gd）"},
	"nest_hurt": {"files": ["nest_hurt_01.wav", "nest_hurt_02.wav"], "when": "虫巢受击（nest.gd take_damage）", "gap": 0.15, "max": 2},
	"nest_destroyed": {"files": ["nest_destroyed.wav"], "when": "虫巢被摧毁（nest.gd take_damage），同时有 explosion", "max": 2},
	# ---- 搜刮（loot_open_<掉落表 id>，没有专属文件时用 loot_open） ----
	"loot_open": {"files": ["loot_open_01.wav", "loot_open_02.wav"], "when": "打开没有专属音效的容器（raid.gd open_container）"},
	"loot_open_supply": {"files": ["loot_open_supply.wav"], "when": "打开补给箱（raid.gd open_container）"},
	"loot_open_tool": {"files": ["loot_open_tool.wav"], "when": "打开工具箱（raid.gd open_container）"},
	"loot_open_military": {"files": ["loot_open_military.wav"], "when": "打开军用储物箱（raid.gd open_container）"},
	"loot_open_safe": {"files": ["loot_open_safe.wav"], "when": "撬开保险柜（raid.gd open_container）"},
	"loot_open_bug": {"files": ["loot_open_bug.wav"], "when": "翻找虫尸（raid.gd open_container）"},
	"loot_open_nest": {"files": ["loot_open_nest.wav"], "when": "翻找巢穴残骸（raid.gd open_container）"},
	"loot_reveal": {"files": ["loot_reveal_01.wav", "loot_reveal_02.wav", "loot_reveal_03.wav"], "when": "容器里的物品逐个显现（raid.gd _update_loot）"},
	"loot_reveal_rare": {"files": ["loot_reveal_rare.wav"], "when": "显现的物品稀有度为稀有或传说（raid.gd _update_loot）"},
	"loot_take": {"files": ["loot_take_01.wav", "loot_take_02.wav"], "when": "物品放进货舱（raid.gd take_from_box）"},
	"loot_put": {"files": ["loot_put.wav"], "when": "物品从货舱放回容器（raid.gd put_into_box）"},
	"loot_close": {"files": ["loot_close.wav"], "when": "关闭搜刮面板（raid.gd close_box）"},
	"cargo_full": {"files": ["cargo_full.wav"], "when": "货舱装不下，拾取被拒（raid.gd take_from_box）", "gap": 0.2, "max": 1},
	"cargo_overload": {"files": ["cargo_overload.wav"], "when": "货物超过底盘承重、开始减速（mech.gd check_overload）", "max": 1},
	# ---- 空投 ----
	"drop_fall": {"files": ["drop_fall.wav"], "when": "空投开始，机甲从高空坠落（raid.gd _drop_sequence）"},
	"drop_retro": {"files": ["drop_retro.wav"], "when": "离地 9 米反推点火（raid.gd _drop_sequence）"},
	"drop_impact": {"files": ["drop_impact.wav"], "when": "空投着陆冲击（raid.gd _drop_impact）"},
	# ---- 撤离与运输机 ----
	"extract_start": {"files": ["extract_start.wav"], "when": "进入撤离区开始读条（raid.gd _update_extract）"},
	"extract_cancel": {"files": ["extract_cancel.wav"], "when": "读条中离开撤离区（raid.gd _update_extract）"},
	"extract_success": {"files": ["extract_success.wav"], "when": "撤离读条完成（raid.gd _update_extract）"},
	"transport_arrive": {"files": ["transport_arrive.wav"], "when": "运输机抵达、下降着陆（raid.gd _spawn_transport_ship）"},
	"transport_idle_loop": {"files": ["transport_idle_loop.wav"], "when": "运输机停在降落区期间循环（raid.gd）", "max": 1},
	"transport_depart": {"files": ["transport_depart.wav"], "when": "运输机等待超时起飞离开（raid.gd _update_transport）"},
	# ---- 界面（按钮、列表、分页自动接线：ui_click / ui_hover / ui_tab；控件 meta "sfx" 可改用别的 id，空串表示不发声） ----
	"ui_click": {"files": ["ui_click_01.wav", "ui_click_02.wav"], "when": "按下按钮、选中列表项、选择弹出菜单项（audio_manager.gd 自动接线）", "gap": 0.03},
	"ui_hover": {"files": ["ui_hover.wav"], "when": "鼠标移入可用按钮（audio_manager.gd 自动接线）", "gap": 0.04, "vol": -8.0},
	"ui_confirm": {"files": ["ui_confirm.wav"], "when": "空投出击、出击准备、返回飞空艇、放弃行动等确认操作（hub.gd / menu.gd / result_screen.gd / hud.gd）"},
	"ui_cancel": {"files": ["ui_cancel.wav"], "when": "关闭设置面板、退出游戏（menu.gd）"},
	"ui_tab": {"files": ["ui_tab.wav"], "when": "切换分页（audio_manager.gd 自动接线）"},
	"ui_open": {"files": ["ui_open.wav"], "when": "打开暂停菜单、大地图、设置面板（hud.gd / menu.gd）"},
	"ui_close": {"files": ["ui_close.wav"], "when": "关闭暂停菜单、大地图（hud.gd）"},
	"ui_denied": {"files": ["ui_denied.wav"], "when": "操作被拒绝：信用点不足、货舱装不下、无法出击（hub.gd）", "gap": 0.15},
	# ---- 机库 ----
	"hub_detach": {"files": ["hub_detach.wav"], "when": "换装时旧模块从接口分离（hub.gd _on_popup）"},
	"hub_dock": {"files": ["hub_dock_01.wav", "hub_dock_02.wav"], "when": "新模块滑入接口对接（hub.gd _on_popup，分离后 0.45 秒）"},
	"hub_explode": {"files": ["hub_explode.wav"], "when": "切到拆解视图（hub.gd _toggle_explode）"},
	"hub_assemble": {"files": ["hub_assemble.wav"], "when": "切回组装视图（hub.gd _toggle_explode）"},
	"hub_starter": {"files": ["hub_starter.wav"], "when": "领取应急机架（hub.gd _starter_frame）"},
	"cargo_load": {"files": ["cargo_load.wav"], "when": "仓库物品装入出击货舱（hub.gd _move_to_cargo）"},
	"cargo_unload": {"files": ["cargo_unload.wav"], "when": "出击货舱物品放回仓库（hub.gd _cargo_back）"},
	"shop_buy": {"files": ["shop_buy.wav"], "when": "商店购买成功（hub.gd _buy）"},
	"shop_sell": {"files": ["shop_sell_01.wav", "shop_sell_02.wav"], "when": "出售物品或一键出售杂物（hub.gd）"},
	"request_complete": {"files": ["request_complete.wav"], "when": "提交后勤委托成功（hub.gd）"},
}

## 音乐槽：file 为 res://assets/audio/music/ 下的文件名；scene 为播放场景
const MUSIC := {
	"menu": {"file": "menu.ogg", "loop": true, "scene": "主菜单"},
	"hangar": {"file": "hangar.ogg", "loop": true, "scene": "飞空艇机库"},
	"greyport_explore": {"file": "greyport_explore.ogg", "loop": true, "scene": "灰港市探索（未交战）"},
	"ironbelt_explore": {"file": "ironbelt_explore.ogg", "loop": true, "scene": "铁锈工业带探索（未交战）"},
	"dustfield_explore": {"file": "dustfield_explore.ogg", "loop": true, "scene": "尘土平原探索（未交战）"},
	"redlake_explore": {"file": "redlake_explore.ogg", "loop": true, "scene": "赤湖新区探索（未交战）"},
	"canyon_explore": {"file": "canyon_explore.ogg", "loop": true, "scene": "裂谷矿区探索（未交战）"},
	"combat": {"file": "combat.ogg", "loop": true, "scene": "任意战区交战中（与探索曲交叉淡化）"},
	"boss": {"file": "boss.ogg", "loop": true, "scene": "Boss 登场到击破"},
	"extract": {"file": "extract.ogg", "loop": true, "scene": "撤离读条中"},
	"result_success": {"file": "result_success.ogg", "loop": false, "scene": "结算：撤离成功"},
	"result_fail": {"file": "result_fail.ogg", "loop": false, "scene": "结算：行动失败"},
}


const SFX_DIR := "res://assets/audio/sfx"
const MUSIC_DIR := "res://assets/audio/music"


## 合并后的音效参数（DEFAULT ← 最长前缀 ← 条目）；table 为空时用本文件的 SFX
static func sfx_info(id: String, table = null) -> Dictionary:
	var t: Dictionary = SFX if table == null else table
	var d: Dictionary = DEFAULT.duplicate()
	var best := ""
	for p: String in PREFIX:
		if id.begins_with(p) and p.length() > best.length():
			best = p
	if best != "":
		d.merge(PREFIX[best], true)
	if t.has(id):
		d.merge(t[id], true)
	return d


## 登记的变体文件完整路径（res://assets/audio/sfx/<文件名>）；没有登记时返回空数组
static func sfx_paths(id: String, table = null) -> Array:
	var t: Dictionary = SFX if table == null else table
	var out: Array = []
	for f in t.get(id, {}).get("files", []):
		out.append(SFX_DIR.path_join(str(f)))
	return out


## 音乐槽参数；没有登记的槽按 <slot>.ogg、循环播放；table 为空时用本文件的 MUSIC
static func music_info(slot: String, table = null) -> Dictionary:
	var t: Dictionary = MUSIC if table == null else table
	if t.has(slot):
		return t[slot]
	return {"file": slot + ".ogg", "loop": true}


static func music_path(slot: String, table = null) -> String:
	return MUSIC_DIR.path_join(str(music_info(slot, table).file))

